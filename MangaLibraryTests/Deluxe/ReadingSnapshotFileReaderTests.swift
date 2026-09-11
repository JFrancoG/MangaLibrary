import Darwin
import Foundation
import Testing
@testable import MangaLibrary

@Suite("Shared snapshot file reader", .tags(.integration))
struct ReadingSnapshotFileReaderTests {
    @Test
    func `the shared directory delivers the independently specified DX1 content`() throws {
        let harness = try Harness()
        defer { harness.remove() }

        let snapshot = try #require(try harness.reader.read())

        #expect(snapshot.items.map(\.mangaID) == [20, 10, 30])
        #expect(snapshot.items.map(\.readingVolume) == [3, 2, 300])
        #expect(snapshot.revision == 7)
    }

    @Test(arguments: ["root", "session-fence.json", "reading-snapshot.json"])
    func `missing storage is unavailable and is not recreated`(_ missing: String) throws {
        let harness = try Harness()
        defer { harness.remove() }
        let missingURL = missing == "root" ? harness.shared : harness.shared.appending(path: missing)
        try FileManager.default.removeItem(at: missingURL)

        #expect(try harness.reader.read() == nil)
        #expect(!FileManager.default.fileExists(atPath: missingURL.path))
    }

    @Test(arguments: [("session-fence.json", 1_024), ("reading-snapshot.json", 32_768)])
    func `each file accepts its inclusive byte limit`(name: String, limit: Int) throws {
        let harness = try Harness()
        defer { harness.remove() }
        let bytes = Data(repeating: 32, count: limit)
        try bytes.write(to: harness.shared.appending(path: name))

        #expect(try read(name, from: harness.reader) == bytes)
    }

    @Test(arguments: [("session-fence.json", 1_025), ("reading-snapshot.json", 32_769)])
    func `each file rejects bytes above its own limit`(name: String, byteCount: Int) throws {
        let harness = try Harness()
        defer { harness.remove() }
        try Data(repeating: 32, count: byteCount).write(to: harness.shared.appending(path: name))

        #expect(throws: (any Error).self) {
            try read(name, from: harness.reader)
        }
    }

    @Test(arguments: ["session-fence.json", "reading-snapshot.json"], InvalidFile.allCases)
    fileprivate func `only regular files under the shared root are read`(name: String, invalid: InvalidFile) throws {
        let harness = try Harness()
        defer { harness.remove() }
        let destination = harness.shared.appending(path: name)
        try FileManager.default.removeItem(at: destination)
        switch invalid {
        case .symbolicLink:
            let outside = harness.directory.appending(path: "outside.json")
            try Self.fixture("content").write(to: outside)
            try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: outside)
        case .directory:
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        case .namedPipe:
            try #require(mkfifo(destination.path, 0o600) == 0)
        }

        #expect(throws: (any Error).self) {
            try read(name, from: harness.reader)
        }
    }

    @Test(arguments: [false, true])
    func `a replaced root cannot redirect the reader or masquerade as a directory`(_ symbolicLink: Bool) throws {
        let harness = try Harness()
        defer { harness.remove() }
        let outside = harness.directory.appending(path: "outside", directoryHint: .isDirectory)
        try FileManager.default.moveItem(at: harness.shared, to: outside)
        if symbolicLink {
            try FileManager.default.createSymbolicLink(at: harness.shared, withDestinationURL: outside)
        } else {
            try Self.fixture("content").write(to: harness.shared)
        }

        #expect(throws: (any Error).self) {
            try harness.reader.read()
        }
    }

    @Test
    func `a nonfile URL is rejected without creating a network reader`() throws {
        let remote = try #require(URL(string: "https://example.invalid/Reading"))
        let reader = ReadingSnapshotReader(sharedDirectory: remote)

        #expect(throws: (any Error).self) {
            try reader.read()
        }
    }

    @Test(arguments: ["fence-closed", "fence-open-b"])
    func `an actual atomic fence replacement invalidates an in-flight observation`(_ replacement: String) throws {
        let harness = try Harness()
        defer { harness.remove() }
        let disk = harness.reader
        let replacement = try Self.fixture(replacement)
        let fenceURL = harness.shared.appending(path: "session-fence.json")
        let reader = ReadingSnapshotReader(
            readFence: disk.readFence,
            readSnapshot: {
                let bytes = try disk.readSnapshot()
                try replacement.write(to: fenceURL, options: .atomic)
                return bytes
            }
        )

        #expect(try reader.read() == nil)
        #expect(try disk.readFence() == replacement)
        #expect(try disk.read() == nil)
    }
}

private extension ReadingSnapshotFileReaderTests {
    enum InvalidFile: CaseIterable { case symbolicLink, directory, namedPipe }

    func read(_ name: String, from reader: ReadingSnapshotReader) throws -> Data? {
        try name == "session-fence.json" ? reader.readFence() : reader.readSnapshot()
    }

    static func fixture(_ name: String) throws -> Data {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try Data(contentsOf: repository.appending(path: "Contracts/Deluxe/\(name).json"))
    }

    struct Harness {
        let directory: URL
        let shared: URL

        var reader: ReadingSnapshotReader { ReadingSnapshotReader(sharedDirectory: shared) }

        func remove() {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

private extension ReadingSnapshotFileReaderTests.Harness {
    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        shared = directory.appending(path: "shared", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        try ReadingSnapshotFileReaderTests.fixture("fence-open-a")
            .write(to: shared.appending(path: "session-fence.json"))
        try ReadingSnapshotFileReaderTests.fixture("content")
            .write(to: shared.appending(path: "reading-snapshot.json"))
    }
}
