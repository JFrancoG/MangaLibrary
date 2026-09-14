import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite(.tags(.integration))
struct ReadingCoverBatchTests {
    @Test(arguments: [false, true])
    func `collection contributes at most 128 extra distinct URLs without displacing reading covers`(
        focusNewAddition: Bool
    ) async throws {
        let readingURL = try #require(URL(string: "https://covers.invalid/reading"))
        let reading = CollectionReadingProjection.Item(
            mangaID: 1_000,
            title: nil,
            readingVolume: 1,
            totalVolumes: nil,
            coverURL: readingURL
        )
        var collection = (1...260).map { identifier in
            CollectionReadingProjection.CollectionItem(
                mangaID: Int64(identifier),
                title: nil,
                ownedVolumeCount: 0,
                totalVolumes: nil,
                isComplete: false,
                coverURL: URL(string: "https://covers.invalid/extra\((identifier + 1) / 2)")
            )
        }
        collection.append(CollectionReadingProjection.CollectionItem(
            mangaID: 1_000,
            title: nil,
            ownedVolumeCount: 0,
            totalVolumes: nil,
            isComplete: false,
            coverURL: readingURL
        ))
        let projection = CollectionReadingProjection(
            authority: SessionAuthority(userID: UUID(), generation: UUID()),
            items: [reading],
            collectionItems: collection
        )
        let fetched = Mutex<[String]>([])
        let source = try ReadingCoverTestImages.jpeg(pattern: .red)

        let covers = try await ReadingCoverBatch.prepare(
            projection: projection,
            preferredCollectionStartMangaID: focusNewAddition ? 260 : nil
        ) { url in
            fetched.withLock {
                $0.append(url.lastPathComponent)
            }
            return source
        }

        let expectedURLs = focusNewAddition
            ? ["reading", "extra130"] + (1...127).map { "extra\($0)" }
            : ["reading"] + (1...128).map { "extra\($0)" }
        let expectedIDs = focusNewAddition
            ? Array(Int64(1)...254) + [259, 260, 1_000]
            : Array(Int64(1)...256) + [1_000]
        #expect(fetched.withLock { $0 } == expectedURLs)
        #expect(covers.keys.sorted() == expectedIDs)
    }

    @Test
    func `prepares the preferred trailing cover instead of the displaced prefix tail`() async throws {
        let projection = projection(count: 100, title: String(repeating: "a", count: 512))
        let source = try ReadingCoverTestImages.jpeg(pattern: .red)
        let fetched = Mutex<[Int]>([])

        let covers = try await ReadingCoverBatch.prepare(projection: projection, preferredStartMangaID: 100) { url in
            fetched.withLock {
                $0.append(Int(url.lastPathComponent) ?? 0)
            }
            return source
        }

        #expect(fetched.withLock { $0 } == Array(1...53) + [100])
        #expect(covers.keys.sorted() == Array(Int64(1)...53) + [100])
    }

    @Test
    func `fetches only the first fifty four potentially transportable covers`() async throws {
        let projection = projection(count: 100, title: String(repeating: "a", count: 512))
        let source = try ReadingCoverTestImages.jpeg(pattern: .red)
        let fetched = Mutex<[Int]>([])

        let covers = try await ReadingCoverBatch.prepare(projection: projection) { url in
            fetched.withLock {
                $0.append(Int(url.lastPathComponent) ?? 0)
            }
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
            fetched.withLock {
                $0.append(url)
            }
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
            fetched.withLock {
                $0.append(url)
            }
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
                fetched.withLock {
                    $0 += 1
                }
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
                fetched.withLock {
                    $0 += 1
                }
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
                        fetched.withLock {
                            $0 += 1
                        }
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
            try ReadingCoverTestImages.noisySource(seed: UInt32(url.lastPathComponent) ?? 0)
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
}
