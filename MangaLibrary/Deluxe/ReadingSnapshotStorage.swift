import Foundation

enum ReadingSnapshotStorageError: Error {
    case unavailable
    case incompatibleFile
}

/// File effects owned by the single publisher; consumers never receive the private ledger.
struct ReadingSnapshotStorage {
    enum File: String {
        case publisherState = "publisher-state.json"
        case fence = "session-fence.json"
        case snapshot = "reading-snapshot.json"
        case collection0 = "collection-0.json"
        case collection1 = "collection-1.json"

        var byteLimit: Int {
            switch self {
            case .publisherState: 16_384
            case .fence: 1_024
            case .snapshot: 32_768
            case .collection0, .collection1: CollectionWidgetSnapshotCodec.maximumByteCount
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

    /// Keeps recovery bookkeeping private; fence, manifest and bounded collection slots share the group.
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
                if file == .collection0 || file == .collection1 {
                    do {
                        return try ReadingSnapshotFileAccess.read(root, name: file.rawValue, limit: file.byteLimit)
                    } catch let error as CocoaError {
                        switch error.code {
                        case .fileReadTooLarge, .fileReadCorruptFile:
                            throw ReadingSnapshotStorageError.incompatibleFile
                        default:
                            throw ReadingSnapshotStorageError.unavailable
                        }
                    } catch {
                        throw ReadingSnapshotStorageError.unavailable
                    }
                }
                return try Self.readFile(root.appending(path: file.rawValue), limit: file.byteLimit)
            },
            replace: { file, data in
                guard data.count <= file.byteLimit else { throw ReadingSnapshotStorageError.incompatibleFile }
                let root = file == .publisherState ? publisherDirectory : sharedDirectory
                do {
                    if file == .collection0 || file == .collection1 {
                        try Self.validateCollectionDestination(root, file: file)
                    }
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

    private static func validateCollectionDestination(_ directory: URL, file: File) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
            throw ReadingSnapshotStorageError.incompatibleFile
        }
        do {
            let destination = directory.appending(path: file.rawValue)
            let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                throw ReadingSnapshotStorageError.incompatibleFile
            }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return
        }
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
