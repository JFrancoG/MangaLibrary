import CoreGraphics
import Foundation
import Testing
@testable import MangaLibrary

@Suite("Bounded prepared cover retention", .tags(.fast))
struct ReadingCoverCacheTests {
    @Test
    func `retains prepared pixels and resolves changed source bytes independently`() async throws {
        let cache = ReadingCoverCache()
        let red = try ReadingCoverTestImages.jpeg(pattern: .red)
        let blue = try ReadingCoverTestImages.jpeg(pattern: .blue)

        let first = try #require(try await cache.prepare(red))
        let repeated = try #require(try await cache.prepare(red))

        #expect(await cache.entries.count == 1)
        #expect(await cache.retainedByteCount == first.data.count)
        #expect(repeated == first)
        let redPixel = try ReadingCoverTestImages.pixel(ReadingCoverTestImages.decoded(repeated.data), x: 16, y: 16)
        #expect(redPixel[0] > 200 && redPixel[2] < 60)

        let changed = try #require(try await cache.prepare(blue))

        let retained = await cache.entries.map(\.resource)
        #expect(retained.count == 2)
        #expect(retained.contains(first))
        #expect(retained.contains(changed))
        #expect(await cache.retainedByteCount == first.data.count + changed.data.count)
        let bluePixel = try ReadingCoverTestImages.pixel(ReadingCoverTestImages.decoded(changed.data), x: 16, y: 16)
        #expect(bluePixel[2] > 200 && bluePixel[0] < 60)
    }

    @Test
    func `the entry limit evicts the least recently used source and preserves a reused one`() async throws {
        let cache = ReadingCoverCache()
        let sources = try (1...129).map { width in
            try ReadingCoverTestImages.encoded([
                ReadingCoverTestImages.image(width: width, height: 16, pattern: .red)
            ])
        }
        for source in sources.prefix(128) {
            _ = try #require(try await cache.prepare(source))
        }

        _ = try #require(try await cache.prepare(sources[0]))
        _ = try #require(try await cache.prepare(sources[128]))

        let retained = await cache.entries.map(\.resource)
        let widths = try retained.map { try ReadingCoverTestImages.decoded($0.data).width }
        #expect(retained.count == 128)
        #expect(Set(widths) == Set([1] + Array(3...129)))
        #expect(await cache.retainedByteCount == retained.reduce(0) { $0 + $1.data.count })
    }

    @Test
    func `the byte limit evicts older JPEGs before the entry limit is reached`() async throws {
        let cache = ReadingCoverCache()
        var prepared: [ReadingCoverResource] = []
        for seed in UInt32(1)...64 {
            let source = try ReadingCoverTestImages.noisySource(seed: seed)
            prepared.append(try #require(try await cache.prepare(source)))
        }
        try #require(prepared.reduce(0) { $0 + $1.data.count } > 2_097_152)
        try #require(Set(prepared.map(\.identifier)).count == 64)
        let first = try #require(prepared.first)
        let newest = try #require(prepared.last)

        let retained = await cache.entries.map(\.resource)
        let retainedBytes = retained.reduce(0) { $0 + $1.data.count }

        #expect(!retained.isEmpty)
        #expect(retained.count < 64)
        #expect(retainedBytes <= 2_097_152)
        #expect(await cache.retainedByteCount == retainedBytes)
        #expect(!retained.contains(first))
        #expect(retained.contains(newest))
    }

    @Test(arguments: [Data(), Data([0, 1, 2]), Data(repeating: 0, count: 8_388_609)])
    func `unusable source bytes neither enter the cache nor remove a usable cover`(_ source: Data) async throws {
        let cache = ReadingCoverCache()
        let valid = try ReadingCoverTestImages.jpeg(pattern: .red)
        let existing = try #require(try await cache.prepare(valid))

        #expect(try await cache.prepare(source) == nil)

        #expect(await cache.entries.map(\.resource) == [existing])
        #expect(await cache.retainedByteCount == existing.data.count)
    }

    @Test(arguments: [false, true])
    func `cancellation preserves retained resources and their recency`(cachedSource: Bool) async throws {
        let cache = ReadingCoverCache()
        let red = try ReadingCoverTestImages.jpeg(pattern: .red)
        let split = try ReadingCoverTestImages.jpeg()
        let blue = try ReadingCoverTestImages.jpeg(pattern: .blue)
        _ = try #require(try await cache.prepare(red))
        _ = try #require(try await cache.prepare(split))
        let before = await cache.entries.map(\.resource)
        let beforeBytes = await cache.retainedByteCount
        let source = cachedSource ? red : blue

        await #expect(throws: CancellationError.self) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.cancelAll()
                group.addTask {
                    _ = try await cache.prepare(source)
                }
                try await group.waitForAll()
            }
        }

        #expect(await cache.entries.map(\.resource) == before)
        #expect(await cache.retainedByteCount == beforeBytes)
    }
}
