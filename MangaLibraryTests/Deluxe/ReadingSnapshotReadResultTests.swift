import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Reading outcomes behind the shared session fence", .tags(.fast))
struct ReadingSnapshotReadResultTests {
    @Test
    func `a stable permitted fence exposes the complete approved reading batch`() throws {
        let reader = try Self.reader(fence: "fence-open-a", snapshot: "content")

        let result = try reader.readResult()

        guard case let .snapshot(snapshot) = result else {
            Issue.record("Expected the authorized content from the independent DX1 fixture")
            return
        }
        #expect(snapshot.items.map(\.mangaID) == [20, 10, 30])
        #expect(snapshot.items.map(\.readingVolume) == [3, 2, 300])
        #expect(snapshot.totalEligibleCount == 3)
        #expect(snapshot.generatedAt == Date(timeIntervalSince1970: 1_788_652_800))
        #expect(try reader.read()?.items.map(\.mangaID) == [20, 10, 30])
    }

    @Test
    func `an authorized empty collection remains distinct from denied or unavailable data`() throws {
        let reader = try Self.reader(fence: "fence-open-a", snapshot: "empty")

        let result = try reader.readResult()

        guard case let .snapshot(snapshot) = result else {
            Issue.record("Expected the authorized empty collection from the independent DX1 fixture")
            return
        }
        #expect(snapshot.state == .empty)
        #expect(snapshot.items.isEmpty)
        #expect(snapshot.totalEligibleCount == 0)
        #expect(try reader.read()?.state == .empty)
    }

    @Test(arguments: ["content", "redacted", "missing", "malformed"])
    func `a stable closed fence expresses redaction independently of residual bytes`(_ snapshot: String) throws {
        let reader = try Self.reader(fence: "fence-closed", snapshot: snapshot)

        #expect(try reader.readResult() == .redacted)
        #expect(try reader.read() == nil)
    }

    @Test(arguments: [
        ("missing", "content"),
        ("malformed", "content"),
        ("fence-open-b", "content"),
        ("fence-open-a", "missing"),
        ("fence-open-a", "malformed"),
        ("fence-open-a", "future-format"),
        ("fence-open-a", "redacted"),
        ("fence-open-a", "unavailable")
    ])
    func `an unusable boundary never becomes redaction or an empty collection`(fence: String, snapshot: String) throws {
        let reader = try Self.reader(fence: fence, snapshot: snapshot)

        #expect(try reader.readResult() == .unavailable)
        #expect(try reader.read() == nil)
    }

    @Test
    func `a permitted session cannot authorize a manifest from another publication epoch`() throws {
        let fenceData = try #require(try Self.data("fence-open-a"))
        let fenceText = try #require(String(data: fenceData, encoding: .utf8))
        let otherEpoch = Data(fenceText.replacingOccurrences(
            of: "11111111-1111-4111-8111-111111111111",
            with: "22222222-2222-4222-8222-222222222222"
        ).utf8)
        let content = try Self.data("content")
        let reader = ReadingSnapshotReader(readFence: { otherEpoch }, readSnapshot: { content })

        #expect(try reader.readResult() == .unavailable)
        #expect(try reader.read() == nil)
    }

    @Test(arguments: ["fence-closed", "fence-open-b"])
    func `a fence replaced during the manifest read invalidates the observation`(_ replacement: String) throws {
        let initial = try #require(try Self.data("fence-open-a"))
        let replacement = try #require(try Self.data(replacement))
        let content = try Self.data("content")
        let current = Mutex(initial)
        let reader = ReadingSnapshotReader(
            readFence: { current.withLock { $0 } },
            readSnapshot: {
                current.withLock {
                    $0 = replacement
                }
                return content
            }
        )

        #expect(try reader.readResult() == .unavailable)
    }

    @Test(arguments: [0, 1, 2])
    func `file failures propagate from the new result boundary`(_ failedRead: Int) throws {
        let reader = try Self.failingReader(at: failedRead)

        #expect(throws: ReadingSnapshotReadFailure.inaccessible) {
            try reader.readResult()
        }
    }

    @Test(arguments: [0, 1, 2])
    func `the optional adapter preserves file failure propagation`(_ failedRead: Int) throws {
        let reader = try Self.failingReader(at: failedRead)

        #expect(throws: ReadingSnapshotReadFailure.inaccessible) {
            try reader.read()
        }
    }
}

private extension ReadingSnapshotReadResultTests {
    static func reader(fence: String, snapshot: String) throws -> ReadingSnapshotReader {
        let fence = try data(fence)
        let snapshot = try data(snapshot)
        return ReadingSnapshotReader(readFence: { fence }, readSnapshot: { snapshot })
    }

    static func data(_ name: String) throws -> Data? {
        if name == "missing" {
            return nil
        }
        if name == "malformed" {
            return Data("incomplete JSON".utf8)
        }
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try Data(contentsOf: repository.appending(path: "Contracts/Deluxe/\(name).json"))
    }

    static func failingReader(at failedRead: Int) throws -> ReadingSnapshotReader {
        let fence = try data("fence-closed")
        let snapshot = try data("content")
        let reads = Mutex(0)
        let nextRead: @Sendable () throws -> Void = {
            let index = reads.withLock {
                let index = $0
                $0 += 1
                return index
            }
            if index == failedRead {
                throw ReadingSnapshotReadFailure.inaccessible
            }
        }
        return ReadingSnapshotReader(
            readFence: {
                try nextRead()
                return fence
            },
            readSnapshot: {
                try nextRead()
                return snapshot
            }
        )
    }
}

private enum ReadingSnapshotReadFailure: Error, Equatable {
    case inaccessible
}
