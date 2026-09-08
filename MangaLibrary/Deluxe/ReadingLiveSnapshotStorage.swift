import Foundation

extension ReadingSnapshotStorage {
    /// Resolves the authorized group for each effect so temporary unavailability can be retried.
    /// An absent group denies even private bookkeeping; it never substitutes another directory.
    init(
        resolvingSharedDirectory: @escaping @Sendable () -> URL?,
        publisherDirectory: URL
    ) {
        self.init(
            read: { file in
                guard let sharedDirectory = resolvingSharedDirectory() else {
                    throw ReadingSnapshotStorageError.unavailable
                }
                let storage = try ReadingSnapshotStorage(
                    sharedDirectory: sharedDirectory,
                    publisherDirectory: publisherDirectory
                )
                return try storage.read(file)
            },
            replace: { file, data in
                guard let sharedDirectory = resolvingSharedDirectory() else {
                    throw ReadingSnapshotStorageError.unavailable
                }
                let storage = try ReadingSnapshotStorage(
                    sharedDirectory: sharedDirectory,
                    publisherDirectory: publisherDirectory
                )
                try storage.replace(file, data)
            }
        )
    }
}
