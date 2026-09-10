import Darwin
import Foundation

enum WatchReadingSnapshotStorageError: Error {
    case incompatible
    case unavailable
}

/// Owns one watch-local cache, independently of the iPhone's App Group and account storage.
///
/// The complete cache is at most 64 KiB; atomic replacement can temporarily retain another 64 KiB.
/// Reads reject links and nonregular files and stop at the inclusive limit before decoding.
struct WatchReadingSnapshotStorage {
    static let maximumByteCount = 65_536

    let read: @Sendable () throws -> Data?
    let replace: @Sendable (Data) throws -> Void
    let discard: @Sendable () throws -> Void
}

extension WatchReadingSnapshotStorage {
    /// Defers storage creation until the first accepted context is written.
    init(directory: URL) {
        self.init(
            read: { try Self.read(directory) },
            replace: { data in
                guard data.count <= Self.maximumByteCount else { throw WatchReadingSnapshotStorageError.incompatible }
                try Self.validate(directory, creating: true)
                let destination = directory.appending(path: "watch-reading-cache.json")
                try Self.validateFile(destination)
                try data.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            },
            discard: {
                guard try Self.exists(directory) else { return }
                try Self.validate(directory, creating: false)
                let destination = directory.appending(path: "watch-reading-cache.json")
                if try Self.exists(destination) {
                    try FileManager.default.removeItem(at: destination)
                }
                guard try Self.read(directory) == nil else { throw WatchReadingSnapshotStorageError.unavailable }
            }
        )
    }

    private static func read(_ directory: URL) throws -> Data? {
        guard directory.isFileURL else { throw WatchReadingSnapshotStorageError.incompatible }
        let root = open(directory.standardizedFileURL.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_NONBLOCK)
        guard root >= 0 else { return try missingOrThrow(errno) }
        defer { close(root) }
        let descriptor = openat(root, "watch-reading-cache.json", O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { return try missingOrThrow(errno) }
        let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? file.close() }
        var attributes = stat()
        guard fstat(descriptor, &attributes) == 0 else { throw WatchReadingSnapshotStorageError.unavailable }
        guard
            attributes.st_mode & S_IFMT == S_IFREG,
            attributes.st_size >= 0,
            attributes.st_size <= maximumByteCount
        else {
            throw WatchReadingSnapshotStorageError.incompatible
        }
        var data = Data()
        while data.count <= maximumByteCount {
            guard let chunk = try file.read(upToCount: maximumByteCount + 1 - data.count), !chunk.isEmpty else { break }
            data.append(chunk)
        }
        guard data.count <= maximumByteCount else { throw WatchReadingSnapshotStorageError.incompatible }
        return data
    }

    private static func validate(_ directory: URL, creating: Bool) throws {
        guard directory.isFileURL else { throw WatchReadingSnapshotStorageError.incompatible }
        if creating, try !exists(directory) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
            throw WatchReadingSnapshotStorageError.incompatible
        }
    }

    private static func validateFile(_ destination: URL) throws {
        guard try exists(destination) else { return }
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw WatchReadingSnapshotStorageError.incompatible
        }
    }

    private static func exists(_ url: URL) throws -> Bool {
        do {
            _ = try FileManager.default.attributesOfItem(atPath: url.path)
            return true
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return false
        }
    }

    private static func missingOrThrow(_ code: Int32) throws -> Data? {
        guard code != ENOENT else { return nil }
        if code == ELOOP || code == ENOTDIR {
            throw WatchReadingSnapshotStorageError.incompatible
        }
        throw WatchReadingSnapshotStorageError.unavailable
    }
}
