//
//  CollectionOutboxUpload.swift
//  MangaLibrary
//

import Foundation
import SwiftData

/// The transport-safe value captured from one exact persisted outbox sequence.
struct CollectionOutboxUploadWorkItem: Equatable {
    let operationID: UUID
    let userID: UUID
    let mangaID: Manga.ID
    let sequence: Int64
    let ownedVolumes: [Int64]
    let readingVolume: Int64?
    let isComplete: Bool
}

extension CollectionOutboxUploadWorkItem {
    init(operation: CollectionOutboxOperation) {
        self.init(
            operationID: operation.operationID,
            userID: operation.userID,
            mangaID: operation.mangaID,
            sequence: operation.sequence,
            ownedVolumes: operation.desiredState.ownedVolumes,
            readingVolume: operation.desiredState.readingVolume,
            isComplete: operation.desiredState.isComplete
        )
    }
}

/// Whether the worker may write or must first reconcile an interrupted write.
enum CollectionOutboxUploadClaim: Equatable {
    case send(CollectionOutboxUploadWorkItem)
    case reconcile(CollectionOutboxUploadWorkItem)
}

enum CollectionOutboxUploadError: Error, Equatable {
    case sessionChanged
    case staleOperation
    case persistenceConflict
    case cancelled
}

extension CollectionMutationActor {
    /// Claims one ordered non-tombstone operation for the authorized user.
    ///
    /// A durable `sending` operation is returned for reconciliation and never
    /// changed back to `queued`. Earlier blocked or tombstone work fences later
    /// sequences only within its own user and manga pair.
    func claimNextUpload(
        authorization: SessionCommitAuthorization
    ) throws(CollectionOutboxUploadError) -> CollectionOutboxUploadClaim? {
        do {
            try Task.checkCancellation()
            var claim: CollectionOutboxUploadClaim?
            try authorization.perform {
                try modelContext.transaction {
                    let operations = try fetchUploadOperations(userID: authorization.authority.userID)
                    claim = try nextUploadClaim(from: operations, userID: authorization.authority.userID)
                    try Task.checkCancellation()
                }
            }
            return claim
        } catch let error as CollectionOutboxUploadError {
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

    /// Returns the earliest unfenced `sending` upload without claiming queued work.
    func nextRecoveredUpload(
        authorization: SessionCommitAuthorization
    ) throws(CollectionOutboxUploadError) -> CollectionOutboxUploadWorkItem? {
        do {
            try Task.checkCancellation()
            return try authorization.perform {
                let operations = try fetchUploadOperations(userID: authorization.authority.userID)
                return try recoveredUpload(from: operations, userID: authorization.authority.userID)
            }
        } catch let error as CollectionOutboxUploadError {
            throw error
        } catch is SessionCommitAuthorizationError {
            throw .sessionChanged
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .persistenceConflict
        }
    }

    /// Confirms only the exact operation and sequence represented by the value.
    func confirmUpload(
        _ workItem: CollectionOutboxUploadWorkItem,
        authorization: SessionCommitAuthorization
    ) throws(CollectionOutboxUploadError) {
        try resolveUpload(workItem, authorization: authorization, resolution: .confirmed)
    }

    /// Preserves local and confirmed values while making uncertainty durable.
    func blockUploadOutcome(
        _ workItem: CollectionOutboxUploadWorkItem,
        authorization: SessionCommitAuthorization
    ) throws(CollectionOutboxUploadError) {
        try resolveUpload(workItem, authorization: authorization, resolution: .blockedOutcome)
    }

    /// Reports durable uncertainty so presentation cannot clear its warning accidentally.
    func hasBlockedUploadOutcome(
        authorization: SessionCommitAuthorization
    ) throws(CollectionOutboxUploadError) -> Bool {
        do {
            try Task.checkCancellation()
            return try authorization.perform {
                let operations = try fetchUploadOperations(userID: authorization.authority.userID)
                return operations.contains { $0.state == .blockedOutcome }
            }
        } catch let error as CollectionOutboxUploadError {
            throw error
        } catch is SessionCommitAuthorizationError {
            throw .sessionChanged
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .persistenceConflict
        }
    }

    private enum UploadResolution {
        case confirmed
        case blockedOutcome
    }

    private func nextUploadClaim(
        from operations: [CollectionOutboxOperation],
        userID: UUID
    ) throws(any Error) -> CollectionOutboxUploadClaim? {
        let candidates = try uploadCandidates(from: operations, userID: userID)
        for operation in candidates {
            guard operation.isTombstone == false else { continue }

            let workItem = CollectionOutboxUploadWorkItem(operation: operation)
            switch operation.state {
            case .sending:
                return .reconcile(workItem)
            case .queued:
                guard operation.markSendingIfQueued() else {
                    throw CollectionOutboxUploadError.persistenceConflict
                }
                return .send(workItem)
            case .retry, .blockedAuth, .blockedOutcome, .rejected, .confirmed:
                continue
            }
        }

        return nil
    }

    private func recoveredUpload(
        from operations: [CollectionOutboxOperation],
        userID: UUID
    ) throws(any Error) -> CollectionOutboxUploadWorkItem? {
        let candidates = try uploadCandidates(from: operations, userID: userID)
        guard let operation = candidates.first(where: { $0.isTombstone == false && $0.state == .sending }) else {
            return nil
        }

        return CollectionOutboxUploadWorkItem(operation: operation)
    }

    private func uploadCandidates(
        from operations: [CollectionOutboxOperation],
        userID: UUID
    ) throws(any Error) -> [CollectionOutboxOperation] {
        var operationsByMangaID: [Manga.ID: [CollectionOutboxOperation]] = [:]
        for operation in operations {
            guard
                operation.userID == userID,
                operation.mangaID > 0,
                operation.sequence > 0,
                operation.isTombstone == operation.desiredState.isTombstone,
                isValidUploadState(operation.desiredState)
            else { throw CollectionOutboxUploadError.persistenceConflict }

            operationsByMangaID[operation.mangaID, default: []].append(operation)
        }

        let candidates = operationsByMangaID.values.compactMap { pairOperations -> CollectionOutboxOperation? in
            pairOperations
                .filter { $0.state != .confirmed }
                .min { lhs, rhs in lhs.sequence < rhs.sequence }
        }
        return candidates.sorted(by: uploadOperationOrder)
    }

    private func resolveUpload(
        _ workItem: CollectionOutboxUploadWorkItem,
        authorization: SessionCommitAuthorization,
        resolution: UploadResolution
    ) throws(CollectionOutboxUploadError) {
        guard workItem.userID == authorization.authority.userID else { throw .sessionChanged }

        do {
            try Task.checkCancellation()
            try authorization.perform {
                try modelContext.transaction {
                    let operation = try exactUploadOperation(workItem)
                    switch resolution {
                    case .confirmed:
                        let entry = try exactUploadEntry(workItem)
                        guard operation.markConfirmedIfSending() else {
                            throw CollectionOutboxUploadError.staleOperation
                        }
                        entry.confirmUpload(operation.desiredState)
                        try removeOlderConfirmedUploads(than: operation)
                    case .blockedOutcome:
                        guard operation.markBlockedOutcomeIfSending() else {
                            throw CollectionOutboxUploadError.staleOperation
                        }
                    }
                    try Task.checkCancellation()
                }
            }
        } catch let error as CollectionOutboxUploadError {
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

    private func exactUploadOperation(
        _ workItem: CollectionOutboxUploadWorkItem
    ) throws(any Error) -> CollectionOutboxOperation {
        let operationID = workItem.operationID
        let descriptor = FetchDescriptor<CollectionOutboxOperation>(
            predicate: #Predicate { operation in operation.operationID == operationID }
        )
        let operations = try modelContext.fetch(descriptor)
        guard
            operations.count == 1,
            let operation = operations.first,
            operation.userID == workItem.userID,
            operation.mangaID == workItem.mangaID,
            operation.sequence == workItem.sequence,
            operation.desiredState.ownedVolumes == workItem.ownedVolumes,
            operation.desiredState.readingVolume == workItem.readingVolume,
            operation.desiredState.isComplete == workItem.isComplete,
            operation.desiredState.isTombstone == false,
            operation.isTombstone == false,
            operation.state == .sending
        else { throw CollectionOutboxUploadError.staleOperation }

        return operation
    }

    private func exactUploadEntry(_ workItem: CollectionOutboxUploadWorkItem) throws(any Error) -> CollectionEntry {
        let userID = workItem.userID
        let mangaID = workItem.mangaID
        let descriptor = FetchDescriptor<CollectionEntry>(
            predicate: #Predicate { entry in entry.userID == userID && entry.mangaID == mangaID }
        )
        let entries = try modelContext.fetch(descriptor)
        guard entries.count == 1, let entry = entries.first else {
            throw CollectionOutboxUploadError.persistenceConflict
        }

        return entry
    }

    private func fetchUploadOperations(userID: UUID) throws(any Error) -> [CollectionOutboxOperation] {
        let descriptor = FetchDescriptor<CollectionOutboxOperation>(
            predicate: #Predicate { operation in operation.userID == userID }
        )
        return try modelContext.fetch(descriptor)
    }

    private func removeOlderConfirmedUploads(than confirmedOperation: CollectionOutboxOperation) throws(any Error) {
        let userID = confirmedOperation.userID
        let mangaID = confirmedOperation.mangaID
        let sequence = confirmedOperation.sequence
        let descriptor = FetchDescriptor<CollectionOutboxOperation>(
            predicate: #Predicate { operation in
                operation.userID == userID &&
                    operation.mangaID == mangaID &&
                    operation.sequence < sequence
            }
        )
        for operation in try modelContext.fetch(descriptor) where operation.state == .confirmed {
            modelContext.delete(operation)
        }
    }

    private func uploadOperationOrder(_ lhs: CollectionOutboxOperation, _ rhs: CollectionOutboxOperation) -> Bool {
        if lhs.sequence != rhs.sequence { return lhs.sequence < rhs.sequence }
        if lhs.mangaID != rhs.mangaID { return lhs.mangaID < rhs.mangaID }
        return lhs.operationID.uuidString < rhs.operationID.uuidString
    }

    private func isValidUploadState(_ state: CollectionSnapshot) -> Bool {
        guard state.ownedVolumes.allSatisfy({ $0 > 0 }) else { return false }
        guard state.ownedVolumes == Array(Set(state.ownedVolumes)).sorted() else { return false }
        guard state.readingVolume.map({ $0 > 0 }) ?? true else { return false }

        if let total = state.knownTotalVolumes {
            guard total > 0 else { return false }
            guard state.ownedVolumes.allSatisfy({ $0 <= total }) else { return false }
            guard state.readingVolume.map({ $0 <= total }) ?? true else { return false }
            if state.isComplete {
                guard
                    let count = Int(exactly: total),
                    state.ownedVolumes.count == count,
                    state.ownedVolumes.enumerated().allSatisfy({ index, volume in
                        volume == Int64(index) + 1
                    })
                else { return false }
            }
        } else if state.isComplete {
            return false
        }

        return true
    }
}
