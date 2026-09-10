import Foundation
import Testing
@testable import MangaLibrary

@Suite("Watch local snapshot cache files", .tags(.integration))
struct WatchReadingSnapshotStorageTests {
    @Test
    func `an atomic replacement survives recreation and a discard removes it`() throws {
        let directory = Self.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = WatchReadingSnapshotStorage(directory: directory)
        let previous = Data("previous context".utf8)
        let replacement = Data("replacement context".utf8)

        try storage.replace(previous)
        try storage.replace(replacement)
        let relaunched = WatchReadingSnapshotStorage(directory: directory)

        #expect(try relaunched.read() == replacement)
        try relaunched.discard()
        #expect(try storage.read() == nil)
    }

    @Test
    func `oversized writes leave the previous complete cache intact`() throws {
        let directory = Self.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = WatchReadingSnapshotStorage(directory: directory)
        let previous = Data("previous context".utf8)
        try storage.replace(previous)

        #expect(throws: (any Error).self) {
            try storage.replace(Data(repeating: 0, count: 65_537))
        }
        #expect(try storage.read() == previous)
    }

    @Test
    func `a cache root link is rejected instead of reading another directory`() throws {
        let directory = Self.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let actual = directory.appending(path: "actual", directoryHint: .isDirectory)
        let link = directory.appending(path: "link", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: actual, withIntermediateDirectories: true)
        let storage = WatchReadingSnapshotStorage(directory: actual)
        try storage.replace(Data("private context".utf8))
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: actual)
        let redirected = WatchReadingSnapshotStorage(directory: link)

        #expect(throws: (any Error).self) { try redirected.read() }
        #expect(throws: (any Error).self) { try redirected.replace(Data("replacement".utf8)) }
    }
}

private extension WatchReadingSnapshotStorageTests {
    static func directory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }
}
