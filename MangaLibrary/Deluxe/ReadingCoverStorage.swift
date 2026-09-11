import CryptoKit
import Darwin
import Foundation

enum ReadingCoverStorageError: Error, Equatable {
    case unavailable
    case incompatibleStorage
    case unresolvedAdmission
    case quotaExceeded
    case conflictingResource
}

/// Cover effects are serialized by ReadingSnapshotPublisher, never by another writer.
///
/// Admission includes JPEGs, retained receipts, the journal and staging. Receipts
/// are permanent and precede every manifest that can expose a resource. Recovery
/// removes only files proven to belong to an uncommitted attempt without a receipt;
/// absent or incompatible recovery metadata never authorizes deletion.
struct ReadingCoverStorage {
    struct Effects {
        let read: @Sendable (URL, Int) throws -> Data?
        let writeExclusive: @Sendable (URL, Data) throws -> Void
        let promoteExclusive: @Sendable (URL, URL) throws -> Void
        let remove: @Sendable (URL) throws -> Void
        let inventory: @Sendable ([URL]) throws -> Int

        static let live = Self(
            read: { url, limit in
                let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
                guard descriptor >= 0 else {
                    if errno == ENOENT {
                        return nil
                    }
                    throw ReadingCoverStorageError.unavailable
                }
                defer { close(descriptor) }
                return try ReadingCoverFileAccess.read(fileDescriptor: descriptor, limit: limit)
            },
            writeExclusive: { url, data in
                try data.write(
                    to: url,
                    options: [.withoutOverwriting, .completeFileProtectionUntilFirstUserAuthentication]
                )
            },
            promoteExclusive: { source, destination in
                guard renamex_np(source.path, destination.path, UInt32(RENAME_EXCL)) == 0 else {
                    throw ReadingCoverStorageError.unavailable
                }
            },
            remove: { url in
                do {
                    try FileManager.default.removeItem(at: url)
                } catch let error as CocoaError where error.code == .fileNoSuchFile {
                    return
                }
            },
            inventory: { roots in
                var directories = roots
                var total = 0
                while let directory = directories.popLast() {
                    try requireDirectory(directory)
                    for url in try FileManager.default.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: nil
                    ) {
                        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                        switch attributes[.type] as? FileAttributeType {
                        case .typeDirectory:
                            directories.append(url)
                        case .typeRegular:
                            guard let size = attributes[.size] as? NSNumber, size.int64Value >= 0 else {
                                throw ReadingCoverStorageError.incompatibleStorage
                            }
                            let (next, overflow) = total.addingReportingOverflow(size.intValue)
                            guard !overflow else { throw ReadingCoverStorageError.quotaExceeded }
                            total = next
                        default:
                            throw ReadingCoverStorageError.incompatibleStorage
                        }
                    }
                }
                return total
            }
        )
    }

    private struct Journal: Codable {
        let formatVersion: Int
        let attemptID: UUID
        let previousManifestDigest: Data?
        let expectedManifestDigest: Data
        let createdResourceIDs: [String]

        func validate() throws {
            guard
                formatVersion == 1,
                previousManifestDigest.map({ $0.count == 32 }) ?? true,
                expectedManifestDigest.count == 32,
                createdResourceIDs.allSatisfy(ReadingCoverResource.isValidIdentifier),
                Set(createdResourceIDs).count == createdResourceIDs.count
            else { throw ReadingCoverStorageError.incompatibleStorage }
        }
    }

    private static let quota = 8_388_608
    private static let journalLimit = 16_384
    private static let receipt = Data(#"{"formatVersion":1}"#.utf8)
    private static let sizingAttempt = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))

    private let sharedDirectory: URL
    private let publisherDirectory: URL
    private let coversDirectory: URL
    private let admissionDirectory: URL
    private let receiptsDirectory: URL
    private let stagingDirectory: URL
    private let journalURL: URL
    private let effects: Effects

    /// Plans ordered, deduplicated resources without writing or consuming admission.
    ///
    /// A committed journal may remain while finalization is retried. Supplying
    /// that exact valid manifest permits a read-only plan; its retained receipts
    /// and empty staging must remain coherent. The next changed commit must
    /// recover the journal before starting another durable admission.
    func admissibleResources(
        _ candidates: [ReadingCoverResource],
        currentManifest: Data? = nil
    ) throws -> [ReadingCoverResource] {
        try validateAdmissionState(currentManifest: currentManifest)
        let used = try effects.inventory([coversDirectory, admissionDirectory])
        var selected: [ReadingCoverResource] = []
        var created: [String] = []
        var extraBytes = 0
        var identities = Set<String>()
        for resource in candidates {
            try Task.checkCancellation()
            guard identities.insert(resource.identifier).inserted else { continue }
            let existing = try existingResource(resource.identifier)
            let retained = try hasReceipt(resource.identifier)
            if let existing, existing != resource {
                continue
            }
            if existing != nil, retained {
                selected.append(resource)
                continue
            }
            var nextCreated = created
            var nextExtra = extraBytes
            if existing == nil {
                nextCreated.append(resource.identifier)
                nextExtra += resource.data.count
            }
            if !retained {
                nextExtra += Self.receipt.count
            }
            let sizingJournal = Journal(
                formatVersion: 1,
                attemptID: Self.sizingAttempt,
                previousManifestDigest: Data(repeating: 0, count: 32),
                expectedManifestDigest: Data(repeating: 0, count: 32),
                createdResourceIDs: nextCreated
            )
            let journalBytes: Int
            do {
                journalBytes = try encodedJournal(sizingJournal).count
            } catch ReadingCoverStorageError.quotaExceeded {
                continue
            }
            guard used <= Self.quota - nextExtra - journalBytes else { continue }
            selected.append(resource)
            created = nextCreated
            extraBytes = nextExtra
        }
        return selected
    }

    /// Writes an attempt descriptor before resources and durable retention before the manifest.
    ///
    /// The caller replaces its manifest only after this succeeds. Failure leaves
    /// the prior manifest intact and enough metadata to recover conservatively.
    func prepare(
        _ resources: [ReadingCoverResource],
        attemptID: UUID,
        previousManifest: Data?,
        expectedManifest: Data
    ) throws {
        guard !resources.isEmpty else { return }
        try Task.checkCancellation()
        let admitted = try admissibleResources(resources)
        let requested = Set(resources.map(\.identifier))
        guard Set(admitted.map(\.identifier)) == requested else { throw ReadingCoverStorageError.quotaExceeded }
        var created: [String] = []
        for resource in admitted where try existingResource(resource.identifier) == nil {
            created.append(resource.identifier)
        }
        if created.isEmpty {
            return
        }
        let journal = Journal(
            formatVersion: 1,
            attemptID: attemptID,
            previousManifestDigest: previousManifest.map(Self.digest),
            expectedManifestDigest: Self.digest(expectedManifest),
            createdResourceIDs: created
        )
        let bytes = try encodedJournal(journal)
        try write(journalURL, data: bytes)
        guard try effects.read(journalURL, Self.journalLimit) == bytes else {
            throw ReadingCoverStorageError.incompatibleStorage
        }

        for resource in admitted where created.contains(resource.identifier) {
            try Task.checkCancellation()
            let staging = stagedURL(resource.identifier, attemptID: attemptID)
            try write(staging, data: resource.data)
            guard try effects.read(staging, 65_536) == resource.data else {
                throw ReadingCoverStorageError.conflictingResource
            }
            try requireOwnedDirectories()
            try effects.promoteExclusive(staging, coverURL(resource.identifier))
            guard try existingResource(resource.identifier) == resource else {
                throw ReadingCoverStorageError.conflictingResource
            }
        }
        for resource in admitted {
            try Task.checkCancellation()
            if try !hasReceipt(resource.identifier) {
                try write(receiptURL(resource.identifier), data: Self.receipt)
            }
            guard try hasReceipt(resource.identifier) else { throw ReadingCoverStorageError.incompatibleStorage }
        }
    }

    /// Reconciles only this writer's descriptor; retained or ambiguous bytes are never collected.
    func recover(currentManifest: Data?) throws {
        try requireOwnedDirectories()
        guard let bytes = try effects.read(journalURL, Self.journalLimit) else {
            try validateAdmissionState()
            return
        }
        let journal = try decodedJournal(bytes)
        let current = currentManifest.map(Self.digest)
        let committed = current == journal.expectedManifestDigest
        guard committed || current == journal.previousManifestDigest else {
            throw ReadingCoverStorageError.unresolvedAdmission
        }
        let referencedResources: Set<String>
        if let currentManifest {
            do {
                let snapshot = try ReadingSnapshotCodec.decode(currentManifest)
                referencedResources = Set(snapshot.items.compactMap(\.coverResourceID))
            } catch {
                throw ReadingCoverStorageError.incompatibleStorage
            }
        } else {
            referencedResources = []
        }
        _ = try effects.inventory([coversDirectory, admissionDirectory])
        var removals: [URL] = []
        for identifier in journal.createdResourceIDs {
            let retained = try hasReceipt(identifier)
            guard !committed || retained else { throw ReadingCoverStorageError.incompatibleStorage }
            let staging = stagedURL(identifier, attemptID: journal.attemptID)
            if try effects.read(staging, 65_536) != nil {
                removals.append(staging)
            }
            if
                !committed,
                !retained,
                !referencedResources.contains(identifier),
                try effects.read(coverURL(identifier), 65_536) != nil
            {
                removals.append(coverURL(identifier))
            }
        }
        for url in removals {
            try effects.remove(url)
        }
        try effects.remove(journalURL)
    }

    private func validateAdmissionState(currentManifest: Data? = nil) throws {
        try requireOwnedDirectories()
        if let bytes = try effects.read(journalURL, Self.journalLimit) {
            let journal = try decodedJournal(bytes)
            guard let currentManifest, Self.digest(currentManifest) == journal.expectedManifestDigest else {
                throw ReadingCoverStorageError.unresolvedAdmission
            }
            do {
                _ = try ReadingSnapshotCodec.decode(currentManifest)
            } catch {
                throw ReadingCoverStorageError.incompatibleStorage
            }
            for identifier in journal.createdResourceIDs {
                guard try hasReceipt(identifier) else { throw ReadingCoverStorageError.incompatibleStorage }
            }
        }
        guard try FileManager.default.contentsOfDirectory(atPath: stagingDirectory.path).isEmpty else {
            throw ReadingCoverStorageError.unresolvedAdmission
        }
        for url in try FileManager.default.contentsOfDirectory(at: receiptsDirectory, includingPropertiesForKeys: nil) {
            let identifier = url.deletingPathExtension().lastPathComponent
            guard
                url.pathExtension == "json",
                ReadingCoverResource.isValidIdentifier(identifier),
                try hasReceipt(identifier)
            else { throw ReadingCoverStorageError.incompatibleStorage }
        }
        for url in try FileManager.default.contentsOfDirectory(at: coversDirectory, includingPropertiesForKeys: nil) {
            let identifier = url.deletingPathExtension().lastPathComponent
            guard
                url.pathExtension == "jpg",
                ReadingCoverResource.isValidIdentifier(identifier),
                try hasReceipt(identifier)
            else { throw ReadingCoverStorageError.unresolvedAdmission }
        }
    }

    private func existingResource(_ identifier: String) throws -> ReadingCoverResource? {
        guard let bytes = try effects.read(coverURL(identifier), 65_536) else { return nil }
        guard let resource = ReadingCoverResource(jpegData: bytes), resource.identifier == identifier else {
            throw ReadingCoverStorageError.conflictingResource
        }
        return resource
    }

    private func hasReceipt(_ identifier: String) throws -> Bool {
        guard let bytes = try effects.read(receiptURL(identifier), 64) else { return false }
        guard bytes == Self.receipt else { throw ReadingCoverStorageError.incompatibleStorage }
        return true
    }

    private func decodedJournal(_ bytes: Data) throws -> Journal {
        do {
            let journal = try JSONDecoder().decode(Journal.self, from: bytes)
            try journal.validate()
            return journal
        } catch {
            throw ReadingCoverStorageError.incompatibleStorage
        }
    }

    private func encodedJournal(_ journal: Journal) throws -> Data {
        try journal.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(journal)
        guard data.count <= Self.journalLimit else { throw ReadingCoverStorageError.quotaExceeded }
        return data
    }

    private func write(_ url: URL, data: Data) throws {
        try requireOwnedDirectories()
        let used = try effects.inventory([coversDirectory, admissionDirectory])
        guard used <= Self.quota - data.count else { throw ReadingCoverStorageError.quotaExceeded }
        try effects.writeExclusive(url, data)
    }

    private func requireOwnedDirectories() throws {
        for directory in [
            sharedDirectory,
            publisherDirectory,
            coversDirectory,
            admissionDirectory,
            receiptsDirectory,
            stagingDirectory
        ] {
            try Self.requireDirectory(directory)
        }
    }

    private static func requireDirectory(_ url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
            throw ReadingCoverStorageError.incompatibleStorage
        }
    }

    private func coverURL(_ identifier: String) -> URL {
        coversDirectory.appending(path: identifier + ".jpg")
    }

    private func receiptURL(_ identifier: String) -> URL {
        receiptsDirectory.appending(path: identifier + ".json")
    }

    private func stagedURL(_ identifier: String, attemptID: UUID) -> URL {
        stagingDirectory.appending(path: attemptID.uuidString + "-" + identifier + ".jpg")
    }

    private static func digest(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }
}

extension ReadingCoverStorage {
    init(sharedDirectory: URL, publisherDirectory: URL, effects: Effects = .live) throws {
        guard sharedDirectory.isFileURL, publisherDirectory.isFileURL else {
            throw ReadingCoverStorageError.incompatibleStorage
        }
        self.sharedDirectory = sharedDirectory
        self.publisherDirectory = publisherDirectory
        coversDirectory = sharedDirectory.appending(path: "covers", directoryHint: .isDirectory)
        admissionDirectory = publisherDirectory.appending(path: "cover-admission", directoryHint: .isDirectory)
        receiptsDirectory = admissionDirectory.appending(path: "receipts", directoryHint: .isDirectory)
        stagingDirectory = admissionDirectory.appending(path: "staging", directoryHint: .isDirectory)
        journalURL = admissionDirectory.appending(path: "journal.json")
        self.effects = effects
        for directory in [
            sharedDirectory,
            publisherDirectory,
            coversDirectory,
            admissionDirectory,
            receiptsDirectory,
            stagingDirectory
        ] {
            if FileManager.default.fileExists(atPath: directory.path) {
                try Self.requireDirectory(directory)
            } else {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
                )
                try Self.requireDirectory(directory)
            }
        }
    }
}
