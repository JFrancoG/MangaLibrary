import Darwin
import Foundation

/// Canonical shared files and read/write bounds; the publisher's private recovery ledger is excluded.
enum ReadingSnapshotSharedFile: String {
    case fence = "session-fence.json"
    case snapshot = "reading-snapshot.json"
    case collection0 = "collection-0.json"
    case collection1 = "collection-1.json"

    var byteLimit: Int {
        switch self {
        case .fence: 1_024
        case .snapshot: ReadingSnapshotCodec.maximumByteCount
        case .collection0, .collection1: CollectionWidgetSnapshotCodec.maximumByteCount
        }
    }
}

extension ReadingSnapshotReader {
    /// Opens each canonical file afresh beneath the supplied root, without creating storage.
    ///
    /// Missing files return no bytes. Links, nonregular files, excessive sizes and
    /// other I/O failures throw, so consumers cannot reuse previously readable content.
    init(sharedDirectory: URL) {
        self.init(
            readFence: {
                try ReadingSnapshotFileAccess.read(sharedDirectory, file: .fence)
            },
            readSnapshot: {
                try ReadingSnapshotFileAccess.read(sharedDirectory, file: .snapshot)
            }
        )
    }
}

enum ReadingSnapshotFileAccess {
    static func read(_ directory: URL, file: ReadingSnapshotSharedFile) throws -> Data? {
        try read(directory, name: file.rawValue, limit: file.byteLimit)
    }

    static func read(_ directory: URL, name: String, limit: Int) throws -> Data? {
        guard directory.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        let root = open(directory.standardizedFileURL.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_NONBLOCK)
        guard root >= 0 else { return try missingOrThrow(errno) }
        defer { close(root) }
        let file = openat(root, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard file >= 0 else { return try missingOrThrow(errno) }
        defer { close(file) }

        return try ReadingCoverFileAccess.read(fileDescriptor: file, limit: limit)
    }

    static func missingOrThrow(_ code: Int32) throws -> Data? {
        guard code == ENOENT else { throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO) }
        return nil
    }
}

extension CollectionWidgetReader {
    /// Opens bounded regular files afresh, refusing links and never creating shared storage.
    init(sharedDirectory: URL) {
        self.init(
            readFence: {
                try ReadingSnapshotFileAccess.read(sharedDirectory, file: .fence)
            },
            readSnapshot: {
                try ReadingSnapshotFileAccess.read(sharedDirectory, file: .snapshot)
            },
            readCollection: { slot in
                guard (0...1).contains(slot) else { throw CollectionWidgetSnapshotError.invalidReference }
                return try ReadingSnapshotFileAccess.read(sharedDirectory, file: slot == 0 ? .collection0 : .collection1)
            }
        )
    }
}
