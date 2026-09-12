import Foundation
import SwiftData

extension CollectionMutationActor {
    typealias BlockedOutcomeResolutionCheckpoint = @Sendable () throws(any Error) -> Void

    /// Captures only values from one exact durable block for presentation.
    ///
    /// No token or mutable SwiftData model crosses the actor boundary. A later
    /// intent is part of the value fence so a decision cannot silently overtake
    /// an edit made while its screen was open.
    func blockedOutcomeContext(
        operationID: UUID,
        authorization: SessionCommitAuthorization
    ) throws(CollectionBlockedOutcomeError) -> CollectionBlockedOutcomeContext {
        do {
            try Task.checkCancellation()
            return try authorization.perform {
                let operation = try exactBlockedOutcomeOperation(
                    operationID: operationID,
                    userID: authorization.authority.userID
                )
                let entry = try exactBlockedOutcomeEntry(operation)
                let laterIntent = try exactLaterIntent(after: operation)
                let expectedVisibleState = laterIntent?.desiredState ?? operation.desiredState
                guard entry.state == expectedVisibleState else { throw CollectionBlockedOutcomeError.staleOperation }

                return CollectionBlockedOutcomeContext(
                    operation: blockedOutcomeReference(operation, authority: authorization.authority),
                    deviceState: entry.state,
                    mangaSnapshot: entry.mangaSnapshot,
                    laterIntent: laterIntent
                )
            }
        } catch let error as CollectionBlockedOutcomeError {
            throw error
        } catch is SessionCommitAuthorizationError {
            throw .sessionChanged
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .persistenceConflict
        }
    }

    /// Validates one individual GET result without interpreting failure as absence.
    func blockedOutcomeEvidence(
        remoteEntry: CollectionRemoteEntry?,
        mangaID: Manga.ID
    ) throws(CollectionBlockedOutcomeError) -> CollectionBlockedOutcomeEvidence {
        guard let remoteEntry else { return .absent }
        guard remoteEntry.manga.id == mangaID else { throw .incompatibleRemoteState }

        do {
            let candidate = try validatedRemoteCandidate(remoteEntry)
            return .present(state: candidate.state, mangaSnapshot: candidate.mangaSnapshot)
        } catch CollectionRemoteImportError.cancelled {
            throw .cancelled
        } catch {
            throw .incompatibleRemoteState
        }
    }

    /// Resolves one reviewed block and its freshly rechecked remote evidence atomically.
    ///
    /// Remote adoption never crosses a later local intent. Keeping the device
    /// either proves the original effect, emits a new identity, or removes N's
    /// fence while preserving the exact existing N+1 for the normal worker.
    func resolveBlockedOutcome(
        _ context: CollectionBlockedOutcomeContext,
        evidence: CollectionBlockedOutcomeEvidence,
        decision: CollectionBlockedOutcomeDecision,
        authorization: SessionCommitAuthorization,
        newOperationID: UUID = UUID(),
        afterMutation: @escaping BlockedOutcomeResolutionCheckpoint = {}
    ) throws(CollectionBlockedOutcomeError) -> CollectionBlockedOutcomeStoreResolution {
        guard context.operation.authority == authorization.authority else { throw .sessionChanged }
        try validateBlockedOutcomeEvidence(evidence, mangaID: context.operation.mangaID)

        do {
            try Task.checkCancellation()
            var resolution: CollectionBlockedOutcomeStoreResolution?
            try authorization.perform {
                try modelContext.transaction {
                    let operation = try exactBlockedOutcomeOperation(context.operation)
                    let entry = try exactBlockedOutcomeEntry(operation)
                    let laterIntent = try exactLaterIntent(after: operation)
                    guard
                        entry.state == context.deviceState,
                        laterIntent == context.laterIntent
                    else { throw CollectionBlockedOutcomeError.staleOperation }
                    if decision == .useRemote, laterIntent != nil {
                        throw CollectionBlockedOutcomeError.laterIntentRequiresDeviceVersion
                    }

                    let provesDesiredEffect = evidence.proves(operation.desiredState)
                    switch evidence {
                    case .absent:
                        entry.confirmRemoteAbsence()
                        if decision == .useRemote || (provesDesiredEffect && laterIntent == nil) {
                            modelContext.delete(entry)
                        }
                    case let .present(remoteState, mangaSnapshot):
                        if decision == .useRemote || (provesDesiredEffect && laterIntent == nil) {
                            entry.applyRemote(remoteState, mangaSnapshot: mangaSnapshot)
                        } else {
                            entry.reconcileRemote(remoteState, mangaSnapshot: mangaSnapshot)
                        }
                    }

                    guard operation.markConfirmedIfBlockedOutcome() else {
                        throw CollectionBlockedOutcomeError.staleOperation
                    }
                    try removeOlderConfirmedUploads(than: operation)

                    if let laterIntent {
                        resolution = .continuedExistingIntent(
                            operationID: laterIntent.operationID,
                            sequence: laterIntent.sequence
                        )
                    } else if decision == .useRemote {
                        resolution = .adoptedRemote
                    } else if provesDesiredEffect {
                        resolution = .effectAlreadyConfirmed
                    } else {
                        guard CollectionVolumePolicy.isValid(
                            entry.state,
                            allowingHistoricalTombstone: true
                        ) else { throw CollectionBlockedOutcomeError.incompatibleLocalState }
                        guard try collectionOperation(operationID: newOperationID) == nil else {
                            throw CollectionBlockedOutcomeError.persistenceConflict
                        }
                        let sequence = try nextBlockedOutcomeSequence(after: operation)
                        modelContext.insert(
                            CollectionOutboxOperation(
                                operationID: newOperationID,
                                userID: operation.userID,
                                mangaID: operation.mangaID,
                                sequence: sequence,
                                desiredState: entry.state
                            )
                        )
                        resolution = .createdIntent(operationID: newOperationID, sequence: sequence)
                    }

                    try afterMutation()
                    try Task.checkCancellation()
                }
                _ = readingEvents?.record(authorization: authorization)
            }
            guard let resolution else { throw CollectionBlockedOutcomeError.persistenceConflict }
            return resolution
        } catch let error as CollectionBlockedOutcomeError {
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

    private func exactBlockedOutcomeOperation(
        operationID: UUID,
        userID: UUID
    ) throws(any Error) -> CollectionOutboxOperation {
        let descriptor = FetchDescriptor<CollectionOutboxOperation>(
            predicate: #Predicate { operation in operation.operationID == operationID }
        )
        let operations = try modelContext.fetch(descriptor)
        guard
            operations.count == 1,
            let operation = operations.first,
            operation.userID == userID,
            operation.state == .blockedOutcome
        else { throw CollectionBlockedOutcomeError.staleOperation }
        try validateBlockedOutcomeOperation(operation)
        return operation
    }

    private func exactBlockedOutcomeOperation(
        _ reference: CollectionBlockedOutcomeOperationReference
    ) throws(any Error) -> CollectionOutboxOperation {
        let operation = try exactBlockedOutcomeOperation(operationID: reference.operationID, userID: reference.userID)
        guard
            operation.mangaID == reference.mangaID,
            operation.sequence == reference.sequence,
            operation.retryCount == reference.retryCount,
            operation.desiredState == reference.desiredState
        else { throw CollectionBlockedOutcomeError.staleOperation }
        return operation
    }

    private func exactBlockedOutcomeEntry(_ operation: CollectionOutboxOperation) throws(any Error) -> CollectionEntry {
        let userID = operation.userID
        let mangaID = operation.mangaID
        let descriptor = FetchDescriptor<CollectionEntry>(
            predicate: #Predicate { entry in entry.userID == userID && entry.mangaID == mangaID }
        )
        let entries = try modelContext.fetch(descriptor)
        guard
            entries.count == 1,
            let entry = entries.first,
            entry.mangaSnapshot.map({ $0.mangaID == mangaID }) ?? true
        else { throw CollectionBlockedOutcomeError.persistenceConflict }
        return entry
    }

    private func exactLaterIntent(
        after operation: CollectionOutboxOperation
    ) throws(any Error) -> CollectionBlockedOutcomeLaterIntent? {
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
        guard laterOperations.count <= 1 else { throw CollectionBlockedOutcomeError.persistenceConflict }
        guard let later = laterOperations.first else { return nil }
        try validateBlockedOutcomeOperation(later)
        guard later.state == .queued || later.state == .retry || later.state == .blockedAuth else {
            throw CollectionBlockedOutcomeError.persistenceConflict
        }
        return CollectionBlockedOutcomeLaterIntent(
            operationID: later.operationID,
            sequence: later.sequence,
            retryCount: later.retryCount,
            nextRetryAt: later.nextRetryAt,
            state: later.state,
            desiredState: later.desiredState
        )
    }

    private func blockedOutcomeReference(
        _ operation: CollectionOutboxOperation,
        authority: SessionAuthority
    ) -> CollectionBlockedOutcomeOperationReference {
        CollectionBlockedOutcomeOperationReference(
            authority: authority,
            operationID: operation.operationID,
            userID: operation.userID,
            mangaID: operation.mangaID,
            sequence: operation.sequence,
            retryCount: operation.retryCount,
            desiredState: operation.desiredState
        )
    }

    private func validateBlockedOutcomeOperation(
        _ operation: CollectionOutboxOperation
    ) throws(CollectionBlockedOutcomeError) {
        guard
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
        } else {
            guard operation.nextRetryAt == nil else { throw .persistenceConflict }
        }
        guard CollectionVolumePolicy.isValid(
            operation.desiredState,
            allowingHistoricalTombstone: true
        ) else { throw .incompatibleLocalState }
    }

    private func validateBlockedOutcomeEvidence(
        _ evidence: CollectionBlockedOutcomeEvidence,
        mangaID: Manga.ID
    ) throws(CollectionBlockedOutcomeError) {
        guard mangaID > 0 else { throw .staleOperation }
        guard case let .present(state, mangaSnapshot) = evidence else { return }
        guard
            mangaSnapshot.mangaID == mangaID,
            state.isTombstone == false,
            CollectionVolumePolicy.isValid(state)
        else { throw .incompatibleRemoteState }
    }

    private func collectionOperation(operationID: UUID) throws(any Error) -> CollectionOutboxOperation? {
        let descriptor = FetchDescriptor<CollectionOutboxOperation>(
            predicate: #Predicate { operation in operation.operationID == operationID }
        )
        let operations = try modelContext.fetch(descriptor)
        guard operations.count <= 1 else { throw CollectionBlockedOutcomeError.persistenceConflict }
        return operations.first
    }

    private func nextBlockedOutcomeSequence(after operation: CollectionOutboxOperation) throws(any Error) -> Int64 {
        let userID = operation.userID
        let mangaID = operation.mangaID
        let descriptor = FetchDescriptor<CollectionOutboxOperation>(
            predicate: #Predicate { candidate in candidate.userID == userID && candidate.mangaID == mangaID }
        )
        let operations = try modelContext.fetch(descriptor)
        guard operations.allSatisfy({ $0.sequence > 0 }) else {
            throw CollectionBlockedOutcomeError.persistenceConflict
        }
        guard let maximum = operations.map(\.sequence).max(), maximum < .max else {
            throw CollectionBlockedOutcomeError.sequenceExhausted
        }
        return maximum + 1
    }
}
