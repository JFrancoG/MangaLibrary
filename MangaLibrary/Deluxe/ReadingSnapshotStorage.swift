import Foundation

enum ReadingSnapshotStorageError: Error {
    case unavailable
    case incompatibleFile
}

/// File effects owned by the single publisher; readers receive only the two public reads.
struct ReadingSnapshotStorage {
    enum File: String {
        case publisherState = "publisher-state.json"
        case fence = "session-fence.json"
        case snapshot = "reading-snapshot.json"

        var byteLimit: Int {
            switch self {
            case .publisherState: 16_384
            case .fence: 1_024
            case .snapshot: 32_768
            }
        }
    }

    let read: @Sendable (File) throws -> Data?
    let replace: @Sendable (File, Data) throws -> Void
}

extension ReadingSnapshotStorage {
    /// Composes two isolated directories, useful before an App Group is provisioned.
    init(directory: URL) throws {
        try self.init(
            sharedDirectory: directory.appending(path: "shared", directoryHint: .isDirectory),
            publisherDirectory: directory.appending(path: "publisher", directoryHint: .isDirectory)
        )
    }

    /// Keeps recovery bookkeeping private to the app; only fence and snapshot use the shared root.
    init(sharedDirectory: URL, publisherDirectory: URL) throws {
        for directory in [sharedDirectory, publisherDirectory] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        }
        self.init(
            read: { file in
                let root = file == .publisherState ? publisherDirectory : sharedDirectory
                return try Self.readFile(root.appending(path: file.rawValue), limit: file.byteLimit)
            },
            replace: { file, data in
                guard data.count <= file.byteLimit else { throw ReadingSnapshotStorageError.incompatibleFile }
                let root = file == .publisherState ? publisherDirectory : sharedDirectory
                do {
                    try data.write(
                        to: root.appending(path: file.rawValue),
                        options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
                    )
                } catch {
                    throw ReadingSnapshotStorageError.unavailable
                }
            }
        )
    }

    private static func readFile(_ url: URL, limit: Int) throws -> Data? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                throw ReadingSnapshotStorageError.incompatibleFile
            }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            var data = Data()
            while data.count <= limit {
                guard let chunk = try file.read(upToCount: limit + 1 - data.count), !chunk.isEmpty else { break }
                data.append(chunk)
            }
            guard data.count <= limit else { throw ReadingSnapshotStorageError.incompatibleFile }
            return data
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return nil
        } catch ReadingSnapshotStorageError.incompatibleFile {
            throw ReadingSnapshotStorageError.incompatibleFile
        } catch {
            throw ReadingSnapshotStorageError.unavailable
        }
    }
}

extension ReadingSnapshotReader {
    init(storage: ReadingSnapshotStorage) {
        self.init(
            readFence: {
                try storage.read(.fence)
            },
            readSnapshot: {
                try storage.read(.snapshot)
            }
        )
    }
}
