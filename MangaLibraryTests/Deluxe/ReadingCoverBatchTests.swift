import CoreGraphics
import Foundation
import Synchronization
import Testing
import UniformTypeIdentifiers
@testable import MangaLibrary

@Suite(.tags(.integration))
struct ReadingCoverBatchTests {
    @Test
    func `fetches only the first fifty four potentially transportable covers`() async throws {
        let projection = projection(count: 100, title: String(repeating: "a", count: 512))
        let source = try ReadingCoverTestImages.jpeg(pattern: .red)
        let fetched = Mutex<[Int]>([])

        let covers = try await ReadingCoverBatch.prepare(projection: projection) { url in
            fetched.withLock { $0.append(Int(url.lastPathComponent) ?? 0) }
            return source
        }

        #expect(fetched.withLock { $0 } == Array(1...54))
        #expect(covers.keys.sorted() == Array(Int64(1)...54))
        #expect(Set(covers.values.map(\.identifier)).count == 1)
    }

    @Test
    func `skips missing sources and fetches repeated URLs only once`() async throws {
        let firstURL = try #require(URL(string: "https://covers.invalid/one"))
        let secondURL = try #require(URL(string: "https://covers.invalid/two"))
        let projection = projection(urls: [firstURL, nil, firstURL, secondURL])
        let source = try ReadingCoverTestImages.jpeg(pattern: .red)
        let fetched = Mutex<[URL]>([])

        let covers = try await ReadingCoverBatch.prepare(projection: projection) { url in
            fetched.withLock { $0.append(url) }
            return source
        }

        #expect(fetched.withLock { $0 } == [firstURL, secondURL])
        #expect(covers.keys.sorted() == [1, 3, 4])
        let resource = try #require(covers[1])
        #expect(covers[3] == resource)
        #expect(covers[4] == resource)
        let image = try ReadingCoverTestImages.decoded(resource.data)
        let pixel = try ReadingCoverTestImages.pixel(image, x: 16, y: 16)
        #expect(Int(pixel[0]) > Int(pixel[1]) + 100)
        #expect(Int(pixel[0]) > Int(pixel[2]) + 100)
    }

    @Test
    func `optional failures are memoized while later valid covers remain usable`() async throws {
        let urls = try ["nil", "error", "invalid", "valid"].map { path in
            try #require(URL(string: "https://covers.invalid/\(path)"))
        }
        let projection = projection(urls: [urls[0], urls[0], urls[1], urls[1], urls[2], urls[2], urls[3]])
        let source = try ReadingCoverTestImages.jpeg(pattern: .blue)
        let fetched = Mutex<[URL]>([])

        let covers = try await ReadingCoverBatch.prepare(projection: projection) { url in
            fetched.withLock { $0.append(url) }
            switch url.lastPathComponent {
            case "nil": return nil
            case "error": throw SourceFailure.unavailable
            case "invalid": return Data([0, 1, 2])
            default: return source
            }
        }

        #expect(fetched.withLock { $0 } == urls)
        #expect(covers.keys.sorted() == [7])
        let resource = try #require(covers[7])
        let image = try ReadingCoverTestImages.decoded(resource.data)
        let pixel = try ReadingCoverTestImages.pixel(image, x: 16, y: 16)
        #expect(Int(pixel[2]) > Int(pixel[0]) + 100)
        #expect(Int(pixel[2]) > Int(pixel[1]) + 100)
    }

    @Test
    func `an invalid reading beyond the transport prefix prevents every fetch`() async {
        let initial = projection(count: 100, title: String(repeating: "a", count: 512))
        let invalid = CollectionReadingProjection.Item(
            mangaID: 101,
            title: nil,
            readingVolume: 0,
            totalVolumes: nil,
            coverURL: nil
        )
        let projection = CollectionReadingProjection(authority: initial.authority, items: initial.items + [invalid])
        let fetched = Mutex(0)

        await #expect(throws: ReadingSnapshotError.self) {
            try await ReadingCoverBatch.prepare(projection: projection) { _ in
                fetched.withLock { $0 += 1 }
                return nil
            }
        }

        #expect(fetched.withLock { $0 } == 0)
    }

    @Test
    func `source cancellation stops before the next candidate`() async {
        let projection = projection(count: 2)
        let fetched = Mutex(0)

        await #expect(throws: CancellationError.self) {
            try await ReadingCoverBatch.prepare(projection: projection) { _ in
                fetched.withLock { $0 += 1 }
                throw CancellationError()
            }
        }

        #expect(fetched.withLock { $0 } == 1)
    }

    @Test
    func `an already cancelled task does not fetch any source`() async {
        let projection = projection(count: 2)
        let fetched = Mutex(0)

        await withTaskGroup(of: Void.self) { group in
            group.cancelAll()
            group.addTask {
                await #expect(throws: CancellationError.self) {
                    try await ReadingCoverBatch.prepare(projection: projection) { _ in
                        fetched.withLock { $0 += 1 }
                        return nil
                    }
                }
            }
        }

        #expect(fetched.withLock { $0 } == 0)
    }

    @Test
    func `retained unique JPEG bytes stop at eight mebibytes`() async throws {
        let projection = projection(count: 300)

        let covers = try await ReadingCoverBatch.prepare(projection: projection) { url in
            try noisySource(seed: UInt32(url.lastPathComponent) ?? 0)
        }

        let unique = Dictionary(covers.values.map { ($0.identifier, $0.data) }, uniquingKeysWith: { first, _ in first })
        #expect(unique.count > 100)
        #expect(unique.count < 300)
        #expect(unique.values.reduce(0) { $0 + $1.count } <= 8_388_608)
        #expect(unique.values.reduce(0) { $0 + $1.count } > 8_323_072)
    }

    private enum SourceFailure: Error {
        case unavailable
    }

    private func projection(count: Int, title: String? = nil) -> CollectionReadingProjection {
        projection(urls: (1...count).map { URL(string: "https://covers.invalid/\($0)") }, title: title)
    }

    private func projection(urls: [URL?], title: String? = nil) -> CollectionReadingProjection {
        CollectionReadingProjection(
            authority: SessionAuthority(userID: UUID(), generation: UUID()),
            items: urls.enumerated().map { offset, url in
                .init(
                    mangaID: Int64(offset + 1),
                    title: title,
                    readingVolume: 1,
                    totalVolumes: nil,
                    coverURL: url
                )
            }
        )
    }

    private func noisySource(seed: UInt32) throws -> Data {
        let dimension = 352
        var state = seed
        var bytes = Data(capacity: dimension * dimension * 4)
        for _ in 0..<(dimension * dimension) {
            state = state &* 1_664_525 &+ 1_013_904_223
            let level = UInt8(truncatingIfNeeded: state >> 24)
            bytes.append(level)
            bytes.append(level)
            bytes.append(level)
            bytes.append(255)
        }
        let provider = try #require(CGDataProvider(data: bytes as CFData))
        let image = try #require(CGImage(
            width: dimension,
            height: dimension,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: dimension * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        return try ReadingCoverTestImages.encoded([image], type: .png)
    }
}
