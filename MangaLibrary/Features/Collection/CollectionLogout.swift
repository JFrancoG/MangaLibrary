//
//  CollectionLogout.swift
//  MangaLibrary
//

import Foundation
import SwiftData

enum CollectionLogoutError: Error, Equatable {
    case sessionChanged
    case persistenceConflict
    case cancelled
}

extension CollectionMutationActor {
    typealias LogoutDiscardCheckpoint = @Sendable (Int) throws(any Error) -> Void

    /// Reports whether the authorized user owns any outbox state that still represents local divergence.
    ///
    /// The read consumes the logout-only capability while ordinary Collection commits are suspended.
    /// A `confirmed` cursor is deliberately not pending and remains available to preserve sequence monotonicity.
    func hasPendingChangesForLogout(authorization: SessionLogoutAuthorization) throws(CollectionLogoutError) -> Bool {
        do {
            try Task.checkCancellation()
            return try authorization.perform {
                let operations = try fetchLogoutOperations(userID: authorization.authority.userID)
                try validateLogoutOperations(operations, userID: authorization.authority.userID)
                try Task.checkCancellation()
                return operations.contains { $0.state != .confirmed }
            }
        } catch let error as CollectionLogoutError {
            throw error
        } catch is SessionCommitAuthorizationError {
            throw .sessionChanged
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .persistenceConflict
        }
    }

    /// Discards every unresolved local intent for one user in a single SwiftData transaction.
    ///
    /// Each affected entry returns to its last confirmed baseline, or is removed when the remote
    /// baseline is absent. The highest sequence remains as a `confirmed` cursor so a later edit
    /// cannot reuse a sequence that may already have reached the server.
    func discardPendingChangesForLogout(
        authorization: SessionLogoutAuthorization,
        afterRestoringPair: LogoutDiscardCheckpoint = { _ in }
    ) throws(CollectionLogoutError) {
        do {
            try Task.checkCancellation()
            try authorization.perform {
                try modelContext.transaction {
                    let userID = authorization.authority.userID
                    let operations = try fetchLogoutOperations(userID: userID)
                    try validateLogoutOperations(operations, userID: userID)
                    let operationsByMangaID = Dictionary(grouping: operations, by: \CollectionOutboxOperation.mangaID)
                    let pendingMangaIDs = operationsByMangaID.compactMap { mangaID, pairOperations in
                        pairOperations.contains { $0.state != .confirmed } ? mangaID : nil
                    }.sorted()
                    let entriesByMangaID = try fetchLogoutEntriesByMangaID(userID: userID)

                    for (index, mangaID) in pendingMangaIDs.enumerated() {
                        guard
                            let pairOperations = operationsByMangaID[mangaID],
                            let retainedOperation = pairOperations.max(by: { $0.sequence < $1.sequence }),
                            let entry = entriesByMangaID[mangaID]
                        else { throw CollectionLogoutError.persistenceConflict }

                        if let confirmedState = entry.confirmedState {
                            entry.apply(confirmedState, mangaSnapshot: nil)
                        } else {
                            modelContext.delete(entry)
                        }

                        retainedOperation.resolveForLogoutDiscard()
                        for operation in pairOperations where operation !== retainedOperation {
                            modelContext.delete(operation)
                        }

                        try afterRestoringPair(index + 1)
                        try Task.checkCancellation()
                    }
                }
                readingEvents?.invalidate(authority: authorization.authority)
            }
        } catch let error as CollectionLogoutError {
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

    private func fetchLogoutOperations(userID: UUID) throws(any Error) -> [CollectionOutboxOperation] {
        let descriptor = FetchDescriptor<CollectionOutboxOperation>(
            predicate: #Predicate { operation in operation.userID == userID }
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchLogoutEntriesByMangaID(userID: UUID) throws(any Error) -> [Manga.ID: CollectionEntry] {
        let descriptor = FetchDescriptor<CollectionEntry>(predicate: #Predicate { entry in entry.userID == userID })
        let entries = try modelContext.fetch(descriptor)
        var result: [Manga.ID: CollectionEntry] = [:]
        for entry in entries {
            guard entry.userID == userID, entry.mangaID > 0, result[entry.mangaID] == nil else {
                throw CollectionLogoutError.persistenceConflict
            }
            result[entry.mangaID] = entry
        }
        return result
    }

    private func validateLogoutOperations(
        _ operations: [CollectionOutboxOperation],
        userID: UUID
    ) throws(CollectionLogoutError) {
        var sequencesByMangaID: [Manga.ID: Set<Int64>] = [:]
        for operation in operations {
            guard
                operation.userID == userID,
                operation.mangaID > 0,
                operation.sequence > 0,
                operation.retryCount >= 0,
                operation.isTombstone == operation.desiredState.isTombstone,
                sequencesByMangaID[operation.mangaID, default: []].insert(operation.sequence).inserted
            else { throw .persistenceConflict }

            if operation.state == .retry {
                guard
                    let nextRetryAt = operation.nextRetryAt,
                    nextRetryAt.timeIntervalSinceReferenceDate.isFinite
                else { throw .persistenceConflict }
            } else if operation.state != .confirmed {
                guard operation.nextRetryAt == nil else { throw .persistenceConflict }
            }
        }
    }
}
