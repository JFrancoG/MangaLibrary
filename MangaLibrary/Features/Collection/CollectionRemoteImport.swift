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
    case nonPositiveVolume(Int64)
    case volumeExceedsKnownTotal(volume: Int64, total: Int64)
    case completeRequiresKnownTotal
    case orphanedLocalEntry(Manga.ID)
    case orphanedPendingIntent(Manga.ID)
    case sessionChanged
    case persistenceConflict
    case cancelled
}

extension CollectionMutationActor {
    typealias RemoteImportCheckpoint = @Sendable (Int) throws(any Error) -> Void

    /// Atomically reconciles one authenticated user's complete remote snapshot.
    ///
    /// Every remote candidate is validated before the transaction mutates the
    /// context. A non-confirmed outbox operation owns the visible local state;
    /// the import advances only its confirmed baseline and presentation data.
    /// No outbox operation is created or changed by this route.
    func importRemote(
        _ remoteEntries: [CollectionRemoteEntry],
        authorization: SessionCommitAuthorization,
        afterMutation: @escaping RemoteImportCheckpoint = { _ in }
    ) throws(CollectionRemoteImportError) {
        do {
            try Task.checkCancellation()
            let remoteByMangaID = try validatedRemoteEntries(remoteEntries)
            let userID = authorization.authority.userID

            try authorization.perform {
                try modelContext.transaction {
                    try Task.checkCancellation()
                    try reconcile(remoteByMangaID, for: userID, afterMutation: afterMutation)
                    try Task.checkCancellation()
                }
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
        _ remoteEntries: [CollectionRemoteEntry]
    ) throws(CollectionRemoteImportError) -> [Manga.ID: CollectionRemoteCandidate] {
        var remoteIDs: Set<UUID> = []
        var candidates: [Manga.ID: CollectionRemoteCandidate] = [:]
        candidates.reserveCapacity(remoteEntries.count)

        for remoteEntry in remoteEntries {
            guard Task.isCancelled == false else { throw .cancelled }
            guard remoteIDs.insert(remoteEntry.remoteID).inserted else {
                throw .duplicateRemoteID(remoteEntry.remoteID)
            }

            let candidate = try validatedRemoteCandidate(remoteEntry)
            let mangaID = candidate.mangaSnapshot.mangaID
            guard candidates[mangaID] == nil else { throw .duplicateMangaID(mangaID) }
            candidates[mangaID] = candidate
        }

        return candidates
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

        for volume in remoteEntry.ownedVolumes {
            try validateRemoteVolume(volume, knownTotal: knownTotal)
        }
        if let readingVolume = remoteEntry.readingVolume {
            try validateRemoteVolume(readingVolume, knownTotal: knownTotal)
        }

        let ownedVolumes: [Int64]
        if remoteEntry.isComplete {
            guard let knownTotal, knownTotal > 0 else { throw .completeRequiresKnownTotal }
            ownedVolumes = Array(1...knownTotal)
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
        if let knownTotal, volume > knownTotal {
            throw .volumeExceedsKnownTotal(volume: volume, total: knownTotal)
        }
    }

    private func reconcile(
        _ remoteByMangaID: [Manga.ID: CollectionRemoteCandidate],
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
                isValidRemotePersistedState(entry.state),
                entry.confirmedState.map(isValidRemotePersistedState) ?? true,
                entry.mangaSnapshot.map({ $0.mangaID == entry.mangaID }) ?? true,
                entriesByMangaID[entry.mangaID] == nil
            else { throw CollectionRemoteImportError.persistenceConflict }

            entriesByMangaID[entry.mangaID] = entry
        }

        for operation in operations {
            guard
                operation.userID == userID,
                operation.mangaID > 0,
                operation.sequence > 0,
                isValidRemotePersistedState(operation.desiredState),
                operation.isTombstone == operation.desiredState.isTombstone
            else { throw CollectionRemoteImportError.persistenceConflict }

            operationsByMangaID[operation.mangaID, default: []].append(operation)
        }

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

    private func isValidRemotePersistedState(_ state: CollectionSnapshot) -> Bool {
        guard state.ownedVolumes.allSatisfy({ $0 > 0 }) else { return false }
        guard state.ownedVolumes == Array(Set(state.ownedVolumes)).sorted() else { return false }
        guard state.readingVolume.map({ $0 > 0 }) ?? true else { return false }

        if let total = state.knownTotalVolumes {
            guard total > 0 else { return false }
            guard state.ownedVolumes.allSatisfy({ $0 <= total }) else { return false }
            guard state.readingVolume.map({ $0 <= total }) ?? true else { return false }
        }

        if state.isComplete {
            guard
                let total = state.knownTotalVolumes,
                total > 0,
                let count = Int(exactly: total),
                state.ownedVolumes.count == count
            else { return false }
            guard state.ownedVolumes.enumerated().allSatisfy({ index, volume in
                volume == Int64(index) + 1
            }) else { return false }
        }

        return true
    }
}

struct CollectionRemoteCandidate {
    let state: CollectionSnapshot
    let mangaSnapshot: CollectionMangaSnapshot
}
