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
    let retryCount: Int
    let ownedVolumes: [Int64]
    let readingVolume: Int64?
    let isComplete: Bool
    let isTombstone: Bool
}

extension CollectionOutboxUploadWorkItem {
    init(operation: CollectionOutboxOperation) {
        self.init(
            operationID: operation.operationID,
            userID: operation.userID,
            mangaID: operation.mangaID,
            sequence: operation.sequence,
            retryCount: operation.retryCount,
            ownedVolumes: operation.desiredState.ownedVolumes,
            readingVolume: operation.desiredState.readingVolume,
            isComplete: operation.desiredState.isComplete,
            isTombstone: operation.desiredState.isTombstone
        )
    }
}

/// Whether the worker may write or must first reconcile an interrupted write.
enum CollectionOutboxUploadClaim: Equatable {
    case send(CollectionOutboxUploadWorkItem)
    case reconcile(CollectionOutboxUploadWorkItem)
    case waitUntil(Date)
}

enum CollectionOutboxUploadError: Error, Equatable {
    case sessionChanged
    case staleOperation
    case invalidVolumeState
    case persistenceConflict
    case cancelled
}

/// Remote evidence used to finish one exact DELETE attempt without replaying it.
enum CollectionDeletionEvidence: Equatable {
    case absent
    case present(CollectionRemoteEntry)
}

/// The durable outcome written while resolving an exact tombstone sequence.
enum CollectionOutboxResolution: Equatable {
    case confirmed
    case blockedOutcome
}

/// The durable local resolution of one positively classified pre-send failure.
enum CollectionOutboxRetryResolution: Equatable, Sendable {
    case scheduled
    case superseded
}

extension CollectionMutationActor {
    typealias PermanentRejectionCheckpoint = @Sendable () throws(any Error) -> Void

    /// Claims one ordered upsert or tombstone operation for the authorized user.
    ///
    /// A durable `sending` operation is returned for reconciliation and never
    /// changed back to `queued`. Earlier blocked work fences later
    /// sequences only within its own user and manga pair.
    func claimNextUpload(
        authorization: SessionCommitAuthorization,
        now: Date = Date()
    ) throws(CollectionOutboxUploadError) -> CollectionOutboxUploadClaim? {
        do {
            try Task.checkCancellation()
            var claim: CollectionOutboxUploadClaim?
            try authorization.perform {
                try modelContext.transaction {
                    let operations = try fetchUploadOperations(userID: authorization.authority.userID)
                    claim = try nextUploadClaim(from: operations, userID: authorization.authority.userID, now: now)
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
        guard workItem.isTombstone == false else { throw .staleOperation }
        try resolveUpload(workItem, authorization: authorization, resolution: .confirmed)
    }

    /// Preserves local and confirmed values while making uncertainty durable.
    func blockUploadOutcome(
        _ workItem: CollectionOutboxUploadWorkItem,
        authorization: SessionCommitAuthorization
    ) throws(CollectionOutboxUploadError) {
        try resolveUpload(workItem, authorization: authorization, resolution: .blockedOutcome)
    }

    /// Persists one positively classified pre-send failure for a later attempt.
    ///
    /// If a newer intent already exists for the same pair, the proven-unsent
    /// attempt is retired instead of scheduling its obsolete payload. Once the
    /// transport supplies that evidence, caller cancellation cannot skip this
    /// local resolution; the coordinator propagates it before any later effect.
    @discardableResult
    func scheduleUploadRetry(
        _ workItem: CollectionOutboxUploadWorkItem,
        nextRetryAt: Date,
        authorization: SessionCommitAuthorization
    ) throws(CollectionOutboxUploadError) -> CollectionOutboxRetryResolution {
        guard workItem.userID == authorization.authority.userID else { throw .sessionChanged }
        guard nextRetryAt.timeIntervalSinceReferenceDate.isFinite else { throw .persistenceConflict }

        do {
            var resolution = CollectionOutboxRetryResolution.scheduled
            try authorization.perform {
                try modelContext.transaction {
                    let operation = try exactUploadOperation(workItem, expectedState: .sending)
                    if try hasLaterUpload(than: operation) {
                        modelContext.delete(operation)
                        resolution = .superseded
                    } else {
                        guard operation.markRetryIfSending(nextRetryAt: nextRetryAt) else {
                            throw CollectionOutboxUploadError.staleOperation
                        }
                    }
                }
            }
            return resolution
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

    /// Makes unsent work durable before the session owner removes its authority.
    ///
    /// A `sending` operation is deliberately preserved because its remote result
    /// still requires reconciliation. The exceptional capability is valid only
    /// while the exact session gate is suspended for authentication invalidation.
    func blockUploadsForAuthentication(
        authorization: SessionInvalidationAuthorization
    ) throws(CollectionOutboxUploadError) {
        do {
            try authorization.perform {
                try modelContext.transaction {
                    let operations = try fetchUploadOperations(userID: authorization.authority.userID)
                    for operation in operations {
                        try validateUploadOperation(operation, userID: authorization.authority.userID)
                        _ = operation.markBlockedAuthIfUnsent()
                    }
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

    /// Reactivates only the authenticated user's safely blocked work.
    ///
    /// Coalescence includes a newer queued or retryable intent created while
    /// authentication recovery was still completing, so stale blocked work can
    /// never regain precedence.
    func reactivateBlockedUploads(authorization: SessionCommitAuthorization) throws(CollectionOutboxUploadError) {
        do {
            try Task.checkCancellation()
            try authorization.perform {
                try modelContext.transaction {
                    let operations = try fetchUploadOperations(userID: authorization.authority.userID)
                    for operation in operations {
                        try validateUploadOperationStructure(operation, userID: authorization.authority.userID)
                    }
                    let retainedOperations = try reactivateBlockedUploads(in: operations)
                    for operation in retainedOperations {
                        try validateUploadOperation(operation, userID: authorization.authority.userID)
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

    /// Resolves a positively classified permanent rejection and restores its base.
    ///
    /// The temporary `rejected` state and the restored collection value are part
    /// of one SwiftData transaction, so observers see either the prior optimistic
    /// state or the fully resolved `confirmed` cursor. A later intent keeps owning
    /// presentation and is never overwritten by rollback of its predecessor.
    func resolvePermanentRejection(
        _ workItem: CollectionOutboxUploadWorkItem,
        authorization: SessionCommitAuthorization,
        afterMutation: @escaping PermanentRejectionCheckpoint = {}
    ) throws(CollectionOutboxUploadError) {
        guard workItem.userID == authorization.authority.userID else { throw .sessionChanged }

        do {
            try Task.checkCancellation()
            try authorization.perform {
                try modelContext.transaction {
                    let operation = try exactUploadOperation(workItem, expectedState: .sending)
                    let entry = try exactUploadEntry(workItem)
                    guard operation.markRejectedIfSending() else { throw CollectionOutboxUploadError.staleOperation }

                    if try hasLaterPendingUpload(than: operation) == false {
                        if let confirmedState = entry.confirmedState {
                            entry.apply(confirmedState, mangaSnapshot: nil)
                        } else {
                            modelContext.delete(entry)
                        }
                    }

                    try afterMutation()

                    guard operation.markConfirmedIfRejected() else {
                        throw CollectionOutboxUploadError.persistenceConflict
                    }
                    try removeOlderConfirmedUploads(than: operation)
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

    /// Resolves one exact tombstone and its remote evidence in a single commit.
    ///
    /// Compatible presence advances the confirmed baseline and presentation
    /// snapshot, then persists uncertainty. Incompatible volume data is not
    /// adopted because presence alone proves that deletion is unconfirmed.
    /// Absence confirms the sequence and retires the tombstone entry only when
    /// no later local intent owns its visible state.
    func resolveDeletion(
        _ workItem: CollectionOutboxUploadWorkItem,
        evidence: CollectionDeletionEvidence,
        authorization: SessionCommitAuthorization
    ) throws(CollectionOutboxUploadError) -> CollectionOutboxResolution {
        guard workItem.userID == authorization.authority.userID else { throw .sessionChanged }
        guard workItem.isTombstone else { throw .staleOperation }
        do {
            try Task.checkCancellation()
        } catch {
            throw .cancelled
        }

        let candidate: CollectionRemoteCandidate?
        switch evidence {
        case .absent:
            candidate = nil
        case let .present(remoteEntry):
            guard remoteEntry.manga.id == workItem.mangaID else { throw .staleOperation }
            do {
                candidate = try validatedRemoteCandidate(remoteEntry)
            } catch CollectionRemoteImportError.cancelled {
                throw .cancelled
            } catch let error where error.isUnsupportedRemoteVolumeData {
                candidate = nil
            } catch {
                throw .persistenceConflict
            }
        }

        do {
            try Task.checkCancellation()
            var persistedResolution: CollectionOutboxResolution?
            try authorization.perform {
                try modelContext.transaction {
                    let operation = try exactUploadOperation(workItem)
                    let entry = try exactUploadEntry(workItem)

                    switch evidence {
                    case .present:
                        if let candidate {
                            entry.reconcileRemote(candidate.state, mangaSnapshot: candidate.mangaSnapshot)
                        }
                        guard operation.markBlockedOutcomeIfSending() else {
                            throw CollectionOutboxUploadError.staleOperation
                        }
                        persistedResolution = .blockedOutcome
                    case .absent:
                        guard operation.markConfirmedIfSending() else {
                            throw CollectionOutboxUploadError.staleOperation
                        }
                        entry.confirmRemoteAbsence()
                        try removeOlderConfirmedUploads(than: operation)

                        if try hasLaterPendingUpload(than: operation) == false {
                            guard entry.state == operation.desiredState, entry.isTombstone else {
                                throw CollectionOutboxUploadError.persistenceConflict
                            }
                            modelContext.delete(entry)
                        }
                        persistedResolution = .confirmed
                    }
                    try Task.checkCancellation()
                }
            }
            guard let persistedResolution else { throw CollectionOutboxUploadError.persistenceConflict }
            return persistedResolution
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
        userID: UUID,
        now: Date
    ) throws(any Error) -> CollectionOutboxUploadClaim? {
        let candidates = try uploadCandidates(from: operations, userID: userID)
        var earliestRetryDate: Date?

        for operation in candidates {
            let workItem = CollectionOutboxUploadWorkItem(operation: operation)
            switch operation.state {
            case .sending:
                return .reconcile(workItem)
            case .queued:
                guard operation.markSendingIfQueued() else { throw CollectionOutboxUploadError.persistenceConflict }
                return .send(CollectionOutboxUploadWorkItem(operation: operation))
            case .retry:
                guard let nextRetryAt = operation.nextRetryAt else {
                    throw CollectionOutboxUploadError.persistenceConflict
                }
                if nextRetryAt <= now {
                    guard operation.markSendingIfRetryIsDue(at: now) else {
                        throw CollectionOutboxUploadError.persistenceConflict
                    }
                    return .send(CollectionOutboxUploadWorkItem(operation: operation))
                }
                if earliestRetryDate.map({ nextRetryAt < $0 }) ?? true {
                    earliestRetryDate = nextRetryAt
                }
            case .blockedAuth, .blockedOutcome, .rejected, .confirmed:
                continue
            }
        }

        return earliestRetryDate.map(CollectionOutboxUploadClaim.waitUntil)
    }

    private func recoveredUpload(
        from operations: [CollectionOutboxOperation],
        userID: UUID
    ) throws(any Error) -> CollectionOutboxUploadWorkItem? {
        let candidates = try uploadCandidates(from: operations, userID: userID)
        guard let operation = candidates.first(where: { $0.state == .sending }) else {
            return nil
        }

        return CollectionOutboxUploadWorkItem(operation: operation)
    }

    private func reactivateBlockedUploads(
        in operations: [CollectionOutboxOperation]
    ) throws(CollectionOutboxUploadError) -> [CollectionOutboxOperation] {
        let safelyUnsentByMangaID = Dictionary(
            grouping: operations.filter { operation in
                operation.state == .queued || operation.state == .retry || operation.state == .blockedAuth
            },
            by: \.mangaID
        )
        var supersededOperationIDs: Set<UUID> = []
        for safelyUnsentOperations in safelyUnsentByMangaID.values {
            let ordered = safelyUnsentOperations.sorted { $0.sequence < $1.sequence }
            guard
                Set(ordered.map(\.sequence)).count == ordered.count,
                let latest = ordered.last
            else { throw .persistenceConflict }

            for superseded in ordered.dropLast() {
                supersededOperationIDs.insert(superseded.operationID)
                modelContext.delete(superseded)
            }
            if latest.state == .blockedAuth {
                guard latest.markQueuedIfBlockedAuth() else { throw .persistenceConflict }
            }
        }

        return operations.filter { supersededOperationIDs.contains($0.operationID) == false }
    }

    private func uploadCandidates(
        from operations: [CollectionOutboxOperation],
        userID: UUID
    ) throws(any Error) -> [CollectionOutboxOperation] {
        var operationsByMangaID: [Manga.ID: [CollectionOutboxOperation]] = [:]
        for operation in operations {
            try validateUploadOperation(operation, userID: userID)

            operationsByMangaID[operation.mangaID, default: []].append(operation)
        }

        let candidates = operationsByMangaID.values.compactMap { pairOperations -> CollectionOutboxOperation? in
            pairOperations
                .filter { $0.state != .confirmed }
                .min { lhs, rhs in lhs.sequence < rhs.sequence }
        }
        return candidates.sorted(by: uploadOperationOrder)
    }

    private func validateUploadOperation(
        _ operation: CollectionOutboxOperation,
        userID: UUID
    ) throws(CollectionOutboxUploadError) {
        try validateUploadOperationStructure(operation, userID: userID)
        if operation.state != .confirmed {
            guard CollectionVolumePolicy.isValid(
                operation.desiredState,
                allowingHistoricalTombstone: true
            ) else { throw .invalidVolumeState }
        }
    }

    private func validateUploadOperationStructure(
        _ operation: CollectionOutboxOperation,
        userID: UUID
    ) throws(CollectionOutboxUploadError) {
        guard
            operation.userID == userID,
            operation.mangaID > 0,
            operation.sequence > 0,
            operation.retryCount >= 0,
            operation.isTombstone == operation.desiredState.isTombstone
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
        _ workItem: CollectionOutboxUploadWorkItem,
        expectedState: CollectionOutboxState = .sending
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
            operation.retryCount == workItem.retryCount,
            operation.desiredState.ownedVolumes == workItem.ownedVolumes,
            operation.desiredState.readingVolume == workItem.readingVolume,
            operation.desiredState.isComplete == workItem.isComplete,
            operation.desiredState.isTombstone == workItem.isTombstone,
            operation.isTombstone == workItem.isTombstone,
            operation.state == expectedState
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

    private func hasLaterPendingUpload(than operation: CollectionOutboxOperation) throws(any Error) -> Bool {
        let userID = operation.userID
        let mangaID = operation.mangaID
        let sequence = operation.sequence
        let descriptor = FetchDescriptor<CollectionOutboxOperation>(
            predicate: #Predicate { candidate in
                candidate.userID == userID &&
                    candidate.mangaID == mangaID &&
                    candidate.sequence > sequence
            }
        )
        let laterOperations = try modelContext.fetch(descriptor)
        for laterOperation in laterOperations {
            guard
                laterOperation.sequence > sequence,
                laterOperation.isTombstone == laterOperation.desiredState.isTombstone
            else { throw CollectionOutboxUploadError.persistenceConflict }
            if laterOperation.state != .confirmed {
                guard CollectionVolumePolicy.isValid(
                    laterOperation.desiredState,
                    allowingHistoricalTombstone: true
                ) else {
                    throw CollectionOutboxUploadError.invalidVolumeState
                }
            }
        }
        return laterOperations.contains { $0.state != .confirmed }
    }

    private func hasLaterUpload(than operation: CollectionOutboxOperation) throws(any Error) -> Bool {
        let userID = operation.userID
        let mangaID = operation.mangaID
        let sequence = operation.sequence
        let descriptor = FetchDescriptor<CollectionOutboxOperation>(
            predicate: #Predicate { candidate in
                candidate.userID == userID &&
                    candidate.mangaID == mangaID &&
                    candidate.sequence > sequence
            }
        )
        let laterOperations = try modelContext.fetch(descriptor)
        for laterOperation in laterOperations {
            try validateUploadOperation(laterOperation, userID: userID)
        }
        return laterOperations.isEmpty == false
    }

    private func uploadOperationOrder(_ lhs: CollectionOutboxOperation, _ rhs: CollectionOutboxOperation) -> Bool {
        if lhs.sequence != rhs.sequence {
            return lhs.sequence < rhs.sequence
        }
        if lhs.mangaID != rhs.mangaID {
            return lhs.mangaID < rhs.mangaID
        }
        return lhs.operationID.uuidString < rhs.operationID.uuidString
    }

}
