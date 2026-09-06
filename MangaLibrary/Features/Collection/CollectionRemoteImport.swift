//
//  CollectionRemoteImport.swift
//  MangaLibrary
//

import Foundation
import SwiftData

/// Failures that leave the complete Collection snapshot and outbox unchanged.
enum CollectionRemoteImportError: Error, Equatable {
    case invalidIdentity
    case duplicateRemoteID(UUID)
    case duplicateMangaID(Manga.ID)
    case nonPositiveKnownTotal(Int64)
    case knownTotalExceedsMaximum(total: Int64, maximum: Int64)
    case nonPositiveVolume(Int64)
    case volumeExceedsMaximum(volume: Int64, maximum: Int64)
    case volumeExceedsKnownTotal(volume: Int64, total: Int64)
    case completeRequiresKnownTotal
    case incompatibleStoredVolumeState
    case orphanedLocalEntry(Manga.ID)
    case orphanedPendingIntent(Manga.ID)
    case sessionChanged
    case persistenceConflict
    case cancelled
}

extension CollectionRemoteImportError {
    var isUnsupportedRemoteVolumeData: Bool {
        switch self {
        case .nonPositiveKnownTotal,
             .knownTotalExceedsMaximum,
             .nonPositiveVolume,
             .volumeExceedsMaximum,
             .volumeExceedsKnownTotal,
             .completeRequiresKnownTotal:
            true
        case .invalidIdentity,
             .duplicateRemoteID,
             .duplicateMangaID,
             .incompatibleStoredVolumeState,
             .orphanedLocalEntry,
             .orphanedPendingIntent,
             .sessionChanged,
             .persistenceConflict,
             .cancelled:
            false
        }
    }

    var isUnsupportedVolumeData: Bool {
        isUnsupportedRemoteVolumeData || self == .incompatibleStoredVolumeState
    }
}

private struct CollectionValidatedRemoteSnapshot {
    let candidates: [Manga.ID: CollectionRemoteCandidate]
    let opaqueRemotePresenceMangaIDs: Set<Manga.ID>
}

private struct CollectionProcessableDeletionContext {
    let mangaIDs: Set<Manga.ID>
    let supersededSafelyUnsentOperationIDs: Set<UUID>
}

extension CollectionMutationActor {
    typealias RemoteImportCheckpoint = @Sendable (Int) throws(any Error) -> Void

    /// Atomically reconciles one authenticated user's complete remote snapshot.
    ///
    /// Every remote candidate is validated before the transaction mutates the
    /// context. A non-confirmed outbox operation owns the visible local state;
    /// the import advances only its confirmed baseline and presentation data.
    /// An incompatible row may be ignored only for its exact processable local
    /// deletion, without importing it or treating it as remote absence. No
    /// outbox operation is created or changed by this route.
    func importRemote(
        _ remoteEntries: [CollectionRemoteEntry],
        authorization: SessionCommitAuthorization,
        afterMutation: @escaping RemoteImportCheckpoint = { _ in }
    ) throws(CollectionRemoteImportError) {
        do {
            try Task.checkCancellation()
            let userID = authorization.authority.userID

            try authorization.perform {
                try modelContext.transaction {
                    try Task.checkCancellation()
                    try reconcile(remoteEntries, for: userID, afterMutation: afterMutation)
                    try Task.checkCancellation()
                }
                _ = readingEvents?.record(authorization: authorization)
            }
        } catch let error as CollectionRemoteImportError {
            modelContext.rollback()
            throw error
        } catch is SessionCommitAuthorizationError {
            modelContext.rollback()
            throw .sessionChanged
        } catch is CancellationError {
            modelContext.rollback()
            throw .cancelled
        } catch {
            modelContext.rollback()
            throw .persistenceConflict
        }
    }

    private func validatedRemoteEntries(
        _ remoteEntries: [CollectionRemoteEntry],
        allowingUnsupportedVolumeDataFor processableDeletionMangaIDs: Set<Manga.ID>
    ) throws(CollectionRemoteImportError) -> CollectionValidatedRemoteSnapshot {
        var remoteIDs: Set<UUID> = []
        var remoteMangaIDs: Set<Manga.ID> = []
        var candidates: [Manga.ID: CollectionRemoteCandidate] = [:]
        var opaqueRemotePresenceMangaIDs: Set<Manga.ID> = []
        candidates.reserveCapacity(remoteEntries.count)

        for remoteEntry in remoteEntries {
            guard Task.isCancelled == false else { throw .cancelled }
            guard remoteIDs.insert(remoteEntry.remoteID).inserted else {
                throw .duplicateRemoteID(remoteEntry.remoteID)
            }

            let mangaID = remoteEntry.manga.id
            guard mangaID > 0 else { throw .invalidIdentity }
            guard remoteMangaIDs.insert(mangaID).inserted else { throw .duplicateMangaID(mangaID) }

            do {
                candidates[mangaID] = try validatedRemoteCandidate(remoteEntry)
            } catch let error
                where error.isUnsupportedRemoteVolumeData && processableDeletionMangaIDs.contains(mangaID) {
                opaqueRemotePresenceMangaIDs.insert(mangaID)
            }
        }

        return CollectionValidatedRemoteSnapshot(
            candidates: candidates,
            opaqueRemotePresenceMangaIDs: opaqueRemotePresenceMangaIDs
        )
    }

    /// Validates and canonicalizes one remote entry with the same rules as R1.
    ///
    /// This does not interpret the value as a complete snapshot. R2 uses it only
    /// inside the atomic resolution of an uncertain DELETE.
    func validatedRemoteCandidate(
        _ remoteEntry: CollectionRemoteEntry
    ) throws(CollectionRemoteImportError) -> CollectionRemoteCandidate {
        guard remoteEntry.manga.id > 0 else { throw .invalidIdentity }
        return CollectionRemoteCandidate(
            state: try remoteState(for: remoteEntry),
            mangaSnapshot: CollectionMangaSnapshot(manga: remoteEntry.manga)
        )
    }

    private func remoteState(
        for remoteEntry: CollectionRemoteEntry
    ) throws(CollectionRemoteImportError) -> CollectionSnapshot {
        let knownTotal = remoteEntry.reportedTotalVolumes
        if let knownTotal, knownTotal <= 0 { throw .nonPositiveKnownTotal(knownTotal) }
        if let knownTotal, CollectionVolumePolicy.contains(knownTotal) == false {
            throw .knownTotalExceedsMaximum(total: knownTotal, maximum: CollectionVolumePolicy.maximum)
        }

        for volume in remoteEntry.ownedVolumes {
            try validateRemoteVolume(volume, knownTotal: knownTotal)
        }
        if let readingVolume = remoteEntry.readingVolume {
            try validateRemoteVolume(readingVolume, knownTotal: knownTotal)
        }

        let ownedVolumes: [Int64]
        if remoteEntry.isComplete {
            guard let completeVolumes = CollectionVolumePolicy.completeVolumes(for: knownTotal) else {
                throw .completeRequiresKnownTotal
            }
            ownedVolumes = completeVolumes
        } else {
            ownedVolumes = Array(Set(remoteEntry.ownedVolumes)).sorted()
        }

        return CollectionSnapshot(
            ownedVolumes: ownedVolumes,
            readingVolume: remoteEntry.readingVolume,
            isComplete: remoteEntry.isComplete,
            knownTotalVolumes: knownTotal,
            isTombstone: false
        )
    }

    private func validateRemoteVolume(_ volume: Int64, knownTotal: Int64?) throws(CollectionRemoteImportError) {
        guard volume > 0 else { throw .nonPositiveVolume(volume) }
        guard CollectionVolumePolicy.contains(volume) else {
            throw .volumeExceedsMaximum(volume: volume, maximum: CollectionVolumePolicy.maximum)
        }
        if let knownTotal, volume > knownTotal {
            throw .volumeExceedsKnownTotal(volume: volume, total: knownTotal)
        }
    }

    private func reconcile(
        _ remoteEntries: [CollectionRemoteEntry],
        for userID: UUID,
        afterMutation: RemoteImportCheckpoint
    ) throws(any Error) {
        let entries = try fetchEntries(for: userID)
        let operations = try fetchOperations(for: userID)
        var entriesByMangaID: [Manga.ID: CollectionEntry] = [:]
        var operationsByMangaID: [Manga.ID: [CollectionOutboxOperation]] = [:]

        for entry in entries {
            guard
                entry.userID == userID,
                entry.mangaID > 0,
                entry.mangaSnapshot.map({ $0.mangaID == entry.mangaID }) ?? true,
                entriesByMangaID[entry.mangaID] == nil
            else { throw CollectionRemoteImportError.persistenceConflict }
            guard CollectionVolumePolicy.isValid(entry.state, allowingHistoricalTombstone: true) else {
                throw CollectionRemoteImportError.incompatibleStoredVolumeState
            }
            if entry.isTombstone == false,
               let confirmedState = entry.confirmedState,
               CollectionVolumePolicy.isValid(confirmedState) == false {
                throw CollectionRemoteImportError.incompatibleStoredVolumeState
            }

            entriesByMangaID[entry.mangaID] = entry
        }

        for operation in operations {
            guard
                operation.userID == userID,
                operation.mangaID > 0,
                operation.sequence > 0,
                operation.retryCount >= 0,
                operation.isTombstone == operation.desiredState.isTombstone
            else { throw CollectionRemoteImportError.persistenceConflict }
            if operation.state == .retry {
                guard
                    let nextRetryAt = operation.nextRetryAt,
                    nextRetryAt.timeIntervalSinceReferenceDate.isFinite
                else { throw CollectionRemoteImportError.persistenceConflict }
            } else if operation.state != .confirmed {
                guard operation.nextRetryAt == nil else { throw CollectionRemoteImportError.persistenceConflict }
            }

            operationsByMangaID[operation.mangaID, default: []].append(operation)
        }

        let processableDeletions = processableDeletionContext(
            entriesByMangaID: entriesByMangaID,
            operationsByMangaID: operationsByMangaID
        )
        for operation in operations where operation.state != .confirmed {
            guard
                CollectionVolumePolicy.isValid(
                    operation.desiredState,
                    allowingHistoricalTombstone: true
                ) || processableDeletions.supersededSafelyUnsentOperationIDs.contains(operation.operationID)
            else { throw CollectionRemoteImportError.incompatibleStoredVolumeState }
        }
        let validatedRemoteSnapshot = try validatedRemoteEntries(
            remoteEntries,
            allowingUnsupportedVolumeDataFor: processableDeletions.mangaIDs
        )
        let remoteByMangaID = validatedRemoteSnapshot.candidates
        let opaqueRemotePresenceMangaIDs = validatedRemoteSnapshot.opaqueRemotePresenceMangaIDs

        for (mangaID, pairOperations) in operationsByMangaID where entriesByMangaID[mangaID] == nil {
            if pairOperations.contains(where: { $0.state != .confirmed }) {
                throw CollectionRemoteImportError.orphanedPendingIntent(mangaID)
            }
        }

        for (mangaID, entry) in entriesByMangaID where remoteByMangaID[mangaID] == nil {
            let pairOperations = operationsByMangaID[mangaID, default: []]
            let hasPendingIntent = pairOperations.contains { $0.state != .confirmed }
            if hasPendingIntent == false, entry.confirmedState == nil {
                throw CollectionRemoteImportError.orphanedLocalEntry(mangaID)
            }
        }

        var mutationCount = 0
        for (mangaID, candidate) in remoteByMangaID {
            try Task.checkCancellation()
            let pairOperations = operationsByMangaID[mangaID, default: []]
            let hasPendingIntent = pairOperations.contains { $0.state != .confirmed }

            if let entry = entriesByMangaID.removeValue(forKey: mangaID) {
                if hasPendingIntent {
                    entry.reconcileRemote(candidate.state, mangaSnapshot: candidate.mangaSnapshot)
                } else {
                    entry.applyRemote(candidate.state, mangaSnapshot: candidate.mangaSnapshot)
                }
            } else {
                modelContext.insert(
                    CollectionEntry(
                        userID: userID,
                        mangaID: mangaID,
                        state: candidate.state,
                        confirmedState: candidate.state,
                        mangaSnapshot: candidate.mangaSnapshot
                    )
                )
            }
            mutationCount += 1
            try afterMutation(mutationCount)
        }

        for (mangaID, entry) in entriesByMangaID {
            try Task.checkCancellation()
            if opaqueRemotePresenceMangaIDs.contains(mangaID) {
                continue
            }
            let pairOperations = operationsByMangaID[mangaID, default: []]
            let hasPendingIntent = pairOperations.contains { $0.state != .confirmed }

            if hasPendingIntent {
                entry.confirmRemoteAbsence()
            } else if entry.confirmedState != nil {
                modelContext.delete(entry)
            }
            mutationCount += 1
            try afterMutation(mutationCount)
        }
    }

    /// Identifies exact deletions that can progress without reading volume values.
    ///
    /// Only the earliest non-confirmed operation for a pair can authorize the
    /// exception. A retryable or authentication-blocked deletion can recover;
    /// uncertain, rejected, or superseded work continues to fence later intent.
    private func processableDeletionContext(
        entriesByMangaID: [Manga.ID: CollectionEntry],
        operationsByMangaID: [Manga.ID: [CollectionOutboxOperation]]
    ) -> CollectionProcessableDeletionContext {
        var mangaIDs: Set<Manga.ID> = []
        var supersededSafelyUnsentOperationIDs: Set<UUID> = []

        for (mangaID, entry) in entriesByMangaID where entry.isTombstone {
            let pendingOperations = operationsByMangaID[mangaID, default: []].filter { $0.state != .confirmed }
            let orderedOperations = pendingOperations.sorted { $0.sequence < $1.sequence }
            guard
                Set(orderedOperations.map(\.sequence)).count == orderedOperations.count,
                let firstPendingOperation = orderedOperations.first
            else { continue }
            let processableDeletion: CollectionOutboxOperation?
            if isProcessableDeletion(firstPendingOperation, matching: entry) {
                processableDeletion = firstPendingOperation
            } else if
                orderedOperations.allSatisfy(isSafelyUnsent),
                let latestSafelyUnsentOperation = orderedOperations.last,
                isProcessableDeletion(latestSafelyUnsentOperation, matching: entry)
            {
                processableDeletion = latestSafelyUnsentOperation
                supersededSafelyUnsentOperationIDs.formUnion(orderedOperations.dropLast().map(\.operationID))
            } else {
                processableDeletion = nil
            }
            guard processableDeletion != nil else { continue }

            mangaIDs.insert(mangaID)
        }

        return CollectionProcessableDeletionContext(
            mangaIDs: mangaIDs,
            supersededSafelyUnsentOperationIDs: supersededSafelyUnsentOperationIDs
        )
    }

    private func isSafelyUnsent(_ operation: CollectionOutboxOperation) -> Bool {
        switch operation.state {
        case .queued, .retry, .blockedAuth:
            true
        case .sending, .blockedOutcome, .rejected, .confirmed:
            false
        }
    }

    private func isProcessableDeletion(
        _ operation: CollectionOutboxOperation,
        matching entry: CollectionEntry
    ) -> Bool {
        let isProcessable = switch operation.state {
        case .queued, .sending, .retry, .blockedAuth:
            true
        case .blockedOutcome, .rejected, .confirmed:
            false
        }
        return isProcessable && operation.isTombstone && operation.desiredState == entry.state
    }

    private func fetchEntries(for userID: UUID) throws(any Error) -> [CollectionEntry] {
        let descriptor = FetchDescriptor<CollectionEntry>(predicate: #Predicate { entry in entry.userID == userID })
        return try modelContext.fetch(descriptor)
    }

    private func fetchOperations(for userID: UUID) throws(any Error) -> [CollectionOutboxOperation] {
        let descriptor = FetchDescriptor<CollectionOutboxOperation>(
            predicate: #Predicate { operation in operation.userID == userID }
        )
        return try modelContext.fetch(descriptor)
    }

}

struct CollectionRemoteCandidate {
    let state: CollectionSnapshot
    let mangaSnapshot: CollectionMangaSnapshot
}
