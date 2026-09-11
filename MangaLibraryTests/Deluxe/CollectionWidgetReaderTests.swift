import Darwin
import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Collection authorization across reused slots", .tags(.fast))
struct CollectionWidgetReaderTests {
    @Test
    func `no current readings can still authorize every active collection entry`() throws {
        let reader = CollectionWidgetReader(
            readFence: { Fixture.openFence },
            readSnapshot: { Fixture.manifest() },
            readCollection: { slot in
                guard slot == 1 else { throw Fixture.Failure.inaccessible }
                return Fixture.collection
            }
        )

        guard case let .snapshot(manifest, collection) = try reader.readResult() else {
            Issue.record("Expected the complete collection independently of the empty reading projection")
            return
        }
        #expect(manifest.state == .empty)
        #expect(collection.items.map(\.mangaID) == [10, 20])
        #expect(collection.items.map(\.ownedVolumeCount) == [0, 2])
        #expect(collection.items.map(\.isComplete) == [false, true])
    }

    @Test
    func `an authorized empty resource is an empty collection rather than unavailable`() throws {
        let reader = CollectionWidgetReader(
            readFence: { Fixture.openFence },
            readSnapshot: {
                Fixture.manifest(
                    digest: "0b733ff83495ea5f11a0d8e9f0eadb1f42b656427412399bffeae0627df52f57",
                    byteCount: 30
                )
            },
            readCollection: { _ in Data(#"{"formatVersion":1,"items":[]}"#.utf8) }
        )

        guard case let .snapshot(_, collection) = try reader.readResult() else {
            Issue.record("An authorized empty array must retain its empty state")
            return
        }
        #expect(collection.items.isEmpty)
    }

    @Test(arguments: [false, true])
    func `a missing or null legacy descriptor never invents collection data`(_ explicitNull: Bool) throws {
        let text = Fixture.manifestText(reference: explicitNull ? #", "collectionReference":null"# : "")
        let reader = CollectionWidgetReader(
            readFence: { Fixture.openFence },
            readSnapshot: { Data(text.utf8) },
            readCollection: { _ in
                throw Fixture.Failure.inaccessible
            }
        )

        #expect(try reader.readResult() == .unavailable)
    }

    @Test
    func `a stable closed fence redacts residual collection without opening either slot`() throws {
        let reader = CollectionWidgetReader(
            readFence: { Fixture.closedFence },
            readSnapshot: { Data("corrupt residual manifest".utf8) },
            readCollection: { _ in
                throw Fixture.Failure.inaccessible
            }
        )

        #expect(try reader.readResult() == .redacted)
    }

    @Test(arguments: [
        ("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"),
        ("11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222"),
        (#""state":"empty""#, #""state":"unavailable""#)
    ])
    func `a valid resource cannot authorize a different manifest session epoch or state`(
        original: String,
        replacement: String
    ) throws {
        let text = try #require(String(data: Fixture.manifest(), encoding: .utf8))
        let otherManifest = Data(text.replacingOccurrences(of: original, with: replacement).utf8)
        let reader = CollectionWidgetReader(
            readFence: { Fixture.openFence },
            readSnapshot: { otherManifest },
            readCollection: { _ in
                throw Fixture.Failure.inaccessible
            }
        )

        #expect(try reader.readResult() == .unavailable)
    }

    @Test(arguments: [false, true])
    func `retirement during either manifest or collection read invalidates the observation`(_ duringSlot: Bool) throws {
        let currentFence = Mutex(Fixture.openFence)
        let reader = CollectionWidgetReader(
            readFence: { currentFence.withLock { $0 } },
            readSnapshot: {
                if !duringSlot {
                    currentFence.withLock {
                        $0 = Fixture.closedFence
                    }
                }
                return Fixture.manifest()
            },
            readCollection: { _ in
                if duringSlot {
                    currentFence.withLock {
                        $0 = Fixture.closedFence
                    }
                }
                return Fixture.collection
            }
        )

        #expect(try reader.readResult() == .unavailable)
    }

    @Test(arguments: ["missing", "later publication", "truncated", "oversized"])
    func `slot reuse or damaged bytes never fall back to another collection`(_ damage: String) throws {
        let resource: Data?
        switch damage {
        case "missing":
            resource = nil
        case "later publication":
            resource = Data(Fixture.collectionText.replacingOccurrences(of: "Alba", with: "Otro").utf8)
        case "truncated":
            resource = Fixture.collection.dropLast()
        default:
            resource = Data(repeating: 32, count: 1_048_577)
        }
        let reader = CollectionWidgetReader(
            readFence: { Fixture.openFence },
            readSnapshot: { Fixture.manifest() },
            readCollection: { _ in resource }
        )

        #expect(try reader.readResult() == .unavailable)
    }

    @Test
    func `a matching digest does not make malformed collection JSON readable`() throws {
        let reader = CollectionWidgetReader(
            readFence: { Fixture.openFence },
            readSnapshot: {
                Fixture.manifest(
                    digest: "021fb596db81e6d02bf3d2586ee3981fe519f275c0ac9ca76bbcf2ebb4097d96",
                    byteCount: 1
                )
            },
            readCollection: { _ in Data("{".utf8) }
        )

        #expect(try reader.readResult() == .unavailable)
    }

    @Test(arguments: [0, 1, 2, 3])
    func `file failures propagate at every stage without returning cached data`(_ failureIndex: Int) throws {
        let nextIndex = Mutex(0)
        let check: @Sendable () throws -> Void = {
            let index = nextIndex.withLock {
                let index = $0
                $0 += 1
                return index
            }
            if index == failureIndex {
                throw Fixture.Failure.inaccessible
            }
        }
        let reader = CollectionWidgetReader(
            readFence: {
                try check()
                return Fixture.openFence
            },
            readSnapshot: {
                try check()
                return Fixture.manifest()
            },
            readCollection: { _ in
                try check()
                return Fixture.collection
            }
        )

        #expect(throws: Fixture.Failure.inaccessible) {
            try reader.readResult()
        }
    }
}

@Suite("Bounded collection files", .tags(.integration))
struct CollectionWidgetFileReaderTests {
    @Test
    func `the live adapter selects the authorized slot and ignores the corrupt inactive one`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        try Data("inactive bytes".utf8).write(to: harness.directory.appending(path: "collection-0.json"))

        guard case let .snapshot(_, collection) = try harness.reader.readResult() else {
            Issue.record("Expected the complete active collection from the selected regular file")
            return
        }
        #expect(collection.items.map(\.mangaID) == [10, 20])
    }

    @Test
    func `missing collection storage remains unavailable and is not recreated`() throws {
        let harness = try Harness()
        defer { harness.remove() }
        let slot = harness.directory.appending(path: "collection-1.json")
        try FileManager.default.removeItem(at: slot)

        #expect(try harness.reader.readResult() == .unavailable)
        #expect(!FileManager.default.fileExists(atPath: slot.path))
    }

    @Test(arguments: [1_048_576, 1_048_577])
    func `the resource file adapter enforces its own inclusive one MiB limit`(_ count: Int) throws {
        let harness = try Harness()
        defer { harness.remove() }
        let bytes = Data(repeating: 32, count: count)
        try bytes.write(to: harness.directory.appending(path: "collection-1.json"))

        if count == 1_048_576 {
            #expect(try harness.reader.readCollection(1) == bytes)
        } else {
            #expect(throws: (any Error).self) {
                try harness.reader.readCollection(1)
            }
        }
    }

    @Test(arguments: ["link", "directory", "pipe"])
    func `the selected slot cannot redirect or block the bounded reader`(_ invalidFile: String) throws {
        let harness = try Harness()
        defer { harness.remove() }
        let slot = harness.directory.appending(path: "collection-1.json")
        try FileManager.default.removeItem(at: slot)
        switch invalidFile {
        case "link":
            let outside = harness.directory.appending(path: "outside.json")
            try Fixture.collection.write(to: outside)
            try FileManager.default.createSymbolicLink(at: slot, withDestinationURL: outside)
        case "directory":
            try FileManager.default.createDirectory(at: slot, withIntermediateDirectories: false)
        default:
            try #require(mkfifo(slot.path, 0o600) == 0)
        }

        #expect(throws: (any Error).self) {
            try harness.reader.readResult()
        }
    }
}

private enum Fixture {
    enum Failure: Error, Equatable { case inaccessible }

    static let collectionText = #"{"formatVersion":1,"items":[{"coverResourceID":null,"isComplete":false,"mangaID":10,"ownedVolumeCount":0,"title":"Alba","totalVolumes":3},{"coverResourceID":null,"isComplete":true,"mangaID":20,"ownedVolumeCount":2,"title":"Bosque","totalVolumes":2}]}"#
    static let collection = Data(collectionText.utf8)
    static let openFence = Data(#"{"formatVersion":1,"publicationGeneration":"11111111-1111-4111-8111-111111111111","fenceRevision":11,"allowedSessionGeneration":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}"#.utf8)
    static let closedFence = Data(#"{"formatVersion":1,"publicationGeneration":"11111111-1111-4111-8111-111111111111","fenceRevision":12,"allowedSessionGeneration":null}"#.utf8)

    static func manifest(
        digest: String = "1e3420df0c0c855b3ce7b9b812d8f3daa18c1ba9aa827c6ff0e75204616e844b",
        byteCount: Int = 250
    ) -> Data {
        let reference = #", "collectionReference":{"slot":1,"digest":"\#(digest)","byteCount":\#(byteCount)}"#
        return Data(manifestText(reference: reference).utf8)
    }

    static func manifestText(reference: String) -> String {
        #"{"formatVersion":1,"publicationGeneration":"11111111-1111-4111-8111-111111111111","revision":7,"sessionGeneration":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","state":"empty","generatedAt":"2026-09-06T00:00:00.000Z","totalEligibleCount":0,"items":[]\#(reference)}"#
    }
}

private extension CollectionWidgetFileReaderTests {
    struct Harness {
        private let root: URL

        var directory: URL { root }
        var reader: CollectionWidgetReader { CollectionWidgetReader(sharedDirectory: directory) }

        func remove() {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

private extension CollectionWidgetFileReaderTests.Harness {
    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Fixture.openFence.write(to: directory.appending(path: "session-fence.json"))
        try Fixture.manifest().write(to: directory.appending(path: "reading-snapshot.json"))
        try Fixture.collection.write(to: directory.appending(path: "collection-1.json"))
    }
}
