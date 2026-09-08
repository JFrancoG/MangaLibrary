import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("App Group availability for the existing snapshot writer", .tags(.integration))
struct ReadingLiveSnapshotStorageTests {
    @Test(arguments: [ReadingSnapshotStorage.File.fence, .snapshot, .publisherState, .collection0, .collection1])
    func `an unavailable group denies every effect without creating a private substitute`(
        _ file: ReadingSnapshotStorage.File
    ) throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = ReadingSnapshotStorage(
            resolvingSharedDirectory: { nil },
            publisherDirectory: directory.appending(path: "publisher")
        )

        #expect(FileManager.default.fileExists(atPath: directory.path) == false)
        #expect(throws: ReadingSnapshotStorageError.unavailable) {
            try storage.read(file)
        }
        #expect(throws: ReadingSnapshotStorageError.unavailable) {
            try storage.replace(file, Data("must not be written".utf8))
        }
        #expect(FileManager.default.fileExists(atPath: directory.path) == false)
    }

    @Test
    func `the same storage retries group availability while keeping publisher state private`() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let shared = directory.appending(path: "authorized-group")
        let publisher = directory.appending(path: "publisher")
        let resolved = Mutex<URL?>(nil)
        let storage = ReadingSnapshotStorage(
            resolvingSharedDirectory: { resolved.withLock { $0 } },
            publisherDirectory: publisher
        )
        let fence = try Self.closedFence()
        let privateState = Data(#"{"storageFixture":"private publisher bookkeeping"}"#.utf8)

        #expect(throws: ReadingSnapshotStorageError.unavailable) {
            try storage.read(.fence)
        }
        resolved.withLock { $0 = shared }
        #expect(try storage.read(.fence) == nil)
        try storage.replace(.fence, fence)
        try storage.replace(.publisherState, privateState)

        #expect(try Data(contentsOf: shared.appending(path: "session-fence.json")) == fence)
        #expect(try Data(contentsOf: publisher.appending(path: "publisher-state.json")) == privateState)
        #expect(FileManager.default.fileExists(atPath: shared.appending(path: "publisher-state.json").path) == false)
        #expect(FileManager.default.fileExists(atPath: publisher.appending(path: "session-fence.json").path) == false)

        resolved.withLock { $0 = nil }
        #expect(throws: ReadingSnapshotStorageError.unavailable) {
            try storage.read(.publisherState)
        }
        #expect(throws: ReadingSnapshotStorageError.unavailable) {
            try storage.replace(.fence, Data("must not replace the authorized fence".utf8))
        }
        #expect(try Data(contentsOf: shared.appending(path: "session-fence.json")) == fence)
        #expect(try Data(contentsOf: publisher.appending(path: "publisher-state.json")) == privateState)

        resolved.withLock { $0 = shared }
        #expect(try storage.read(.fence) == fence)
        #expect(try storage.read(.publisherState) == privateState)
    }
}

private extension ReadingLiveSnapshotStorageTests {
    static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "ReadingLiveStorage-\(UUID())")
    }

    static func closedFence() throws -> Data {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try Data(contentsOf: repository.appending(path: "Contracts/Deluxe/fence-closed.json"))
    }
}
