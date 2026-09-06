//
//  CollectionMutationActor.swift
//  MangaLibrary
//

import Foundation
import SwiftData

/// Serializes every local Collection mutation and its matching outbox intent.
///
/// The actor owns its `ModelContext`; callers cross the boundary only with
/// `Sendable` values. A successful call commits both models in one transaction.
/// Validation, cancellation, sequence exhaustion and persistence failures roll
/// the context back to its last committed state.
/// Authorized visible commits invalidate earlier Deluxe preparations and signal
/// the new persisted state before releasing the same session critical section.
@ModelActor
actor CollectionMutationActor {
    private(set) var readingEvents: ReadingPublicationEvents? = nil

    init(modelContainer: ModelContainer, readingEvents: ReadingPublicationEvents) {
        let context = ModelContext(modelContainer)
        self.modelContainer = modelContainer
        modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.readingEvents = readingEvents
    }

    /// Applies a local intent while its exact session generation remains valid.
    ///
    /// Authority validation and the complete SwiftData transaction share one
    /// synchronous critical section, closing the session-check-to-commit race.
    func apply(
        _ command: CollectionMutationCommand,
        authorization: SessionCommitAuthorization,
        newOperationID: UUID = UUID()
    ) throws(CollectionMutationError) -> CollectionMutationResult {
        guard authorization.authority == command.authority else { throw .authenticationRequired }

        do {
            return try authorization.perform {
                let result = try apply(command, newOperationID: newOperationID)
                _ = readingEvents?.record(authorization: authorization)
                return result
            }
        } catch let error as CollectionMutationError {
            throw error
        } catch is SessionCommitAuthorizationError {
            modelContext.rollback()
            throw .authenticationRequired
        } catch {
            modelContext.rollback()
            throw .persistenceConflict
        }
    }

    /// Applies one semantic edit to a user and manga pair.
    ///
    /// A safely unsent `queued` or `retry` operation for the same pair keeps its
    /// UUID, receives a higher sequence and clears any obsolete backoff. Work
    /// whose remote outcome may exist remains untouched; a later queued intent
    /// is created when necessary. An explicit deletion supersedes a recovered
    /// pre-policy `sending` POST whose volume state is no longer valid.
    ///
    /// - Parameters:
    ///   - command: Identity, optional total knowledge and the semantic edit.
    ///   - newOperationID: UUID to use only when the transaction creates an outbox operation.
    /// - Returns: The committed value state and its current outbox identity.
    /// - Throws: ``CollectionMutationError`` when identity or collection values
    ///   are invalid, a total would invalidate the current state, sequence would
    ///   wrap, cancellation is observed before commit, or persistence fails.
    func apply(
        _ command: CollectionMutationCommand,
        newOperationID: UUID = UUID()
    ) throws(CollectionMutationError) -> CollectionMutationResult {
        do {
            try Task.checkCancellation()
            var result: CollectionMutationResult?
            try modelContext.transaction {
                try Task.checkCancellation()
                result = try performMutation(command, newOperationID: newOperationID)
                try Task.checkCancellation()
            }
            guard let result else { throw CollectionMutationError.persistenceConflict }
            return result
        } catch let error as CollectionMutationError {
            modelContext.rollback()
            throw error
        } catch is CancellationError {
            modelContext.rollback()
            throw .cancelled
        } catch {
            modelContext.rollback()
            throw .persistenceConflict
        }
    }

    private func performMutation(
        _ command: CollectionMutationCommand,
        newOperationID: UUID
    ) throws(any Error) -> CollectionMutationResult {
        guard command.mangaID > 0 else { throw CollectionMutationError.invalidIdentity }
        if let mangaSnapshot = command.mangaSnapshot, mangaSnapshot.mangaID != command.mangaID {
            throw CollectionMutationError.mangaSnapshotIdentityMismatch(
                expected: command.mangaID,
                actual: mangaSnapshot.mangaID
            )
        }

        let entry = try fetchEntry(userID: command.userID, mangaID: command.mangaID)
        if entry == nil {
            if case .delete = command.change {
                throw CollectionMutationError.collectionEntryNotFound
            }
            guard command.mangaSnapshot != nil else { throw CollectionMutationError.mangaSnapshotRequired }
        }
        let currentState = entry?.state ?? CollectionSnapshot(
            ownedVolumes: [],
            readingVolume: nil,
            isComplete: false,
            knownTotalVolumes: nil,
            isTombstone: false
        )
        if CollectionVolumePolicy.isValid(currentState) == false {
            guard case .delete = command.change else { throw CollectionMutationError.incompatibleStoredVolumeState }
        }

        let desiredState = try applying(command, to: currentState)
        if let entry {
            entry.apply(desiredState, mangaSnapshot: command.mangaSnapshot)
        } else {
            modelContext.insert(
                CollectionEntry(
                    userID: command.userID,
                    mangaID: command.mangaID,
                    state: desiredState,
                    confirmedState: nil,
                    mangaSnapshot: command.mangaSnapshot
                )
            )
        }

        let outbox = try fetchOutbox(userID: command.userID, mangaID: command.mangaID)
        let sequence = try nextSequence(after: outbox)
        if case .delete = command.change {
            supersedeInvalidHistoricalSendingUploads(in: outbox)
        }
        let safelyUnsent = outbox.filter { $0.state == .queued || $0.state == .retry }
        guard safelyUnsent.count <= 1 else { throw CollectionMutationError.persistenceConflict }

        let operation: CollectionOutboxOperation
        if let existingOperation = safelyUnsent.first {
            existingOperation.coalesce(sequence: sequence, desiredState: desiredState)
            operation = existingOperation
        } else {
            guard try fetchOperation(operationID: newOperationID) == nil else {
                throw CollectionMutationError.persistenceConflict
            }
            let newOperation = CollectionOutboxOperation(
                operationID: newOperationID,
                userID: command.userID,
                mangaID: command.mangaID,
                sequence: sequence,
                desiredState: desiredState
            )
            modelContext.insert(newOperation)
            operation = newOperation
        }

        return CollectionMutationResult(
            userID: command.userID,
            mangaID: command.mangaID,
            state: desiredState,
            outboxOperationID: operation.operationID,
            sequence: sequence
        )
    }

    /// Drops only a recovered, incompatible POST that an explicit DELETE supersedes.
    ///
    /// Its sequence has already contributed to the next monotonic value. The
    /// operation is not marked confirmed because its remote result is unknown;
    /// the following bodyless DELETE is correct whether that POST applied or not.
    private func supersedeInvalidHistoricalSendingUploads(in operations: [CollectionOutboxOperation]) {
        for operation in operations where
            operation.state == .sending &&
            operation.isTombstone == false &&
            operation.desiredState.isTombstone == false &&
            CollectionVolumePolicy.isValid(operation.desiredState) == false {
            modelContext.delete(operation)
        }
    }

    private func fetchEntry(userID: UUID, mangaID: Manga.ID) throws(any Error) -> CollectionEntry? {
        let descriptor = FetchDescriptor<CollectionEntry>(
            predicate: #Predicate { entry in
                entry.userID == userID && entry.mangaID == mangaID
            }
        )
        let entries = try modelContext.fetch(descriptor)
        guard entries.count <= 1 else { throw CollectionMutationError.persistenceConflict }
        return entries.first
    }

    private func fetchOutbox(userID: UUID, mangaID: Manga.ID) throws(any Error) -> [CollectionOutboxOperation] {
        let descriptor = FetchDescriptor<CollectionOutboxOperation>(
            predicate: #Predicate { operation in
                operation.userID == userID && operation.mangaID == mangaID
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchOperation(operationID: UUID) throws(any Error) -> CollectionOutboxOperation? {
        let descriptor = FetchDescriptor<CollectionOutboxOperation>(
            predicate: #Predicate { operation in
                operation.operationID == operationID
            }
        )
        let operations = try modelContext.fetch(descriptor)
        guard operations.count <= 1 else { throw CollectionMutationError.persistenceConflict }
        return operations.first
    }

    private func nextSequence(after operations: [CollectionOutboxOperation]) throws(CollectionMutationError) -> Int64 {
        guard operations.allSatisfy({ $0.sequence > 0 }) else { throw .persistenceConflict }
        guard let maximum = operations.map(\.sequence).max() else { return 1 }
        guard maximum < .max else { throw .sequenceExhausted }
        return maximum + 1
    }

    private func applying(
        _ command: CollectionMutationCommand,
        to currentState: CollectionSnapshot
    ) throws(CollectionMutationError) -> CollectionSnapshot {
        if case .delete = command.change {
            return CollectionSnapshot(
                ownedVolumes: currentState.ownedVolumes,
                readingVolume: currentState.readingVolume,
                isComplete: currentState.isComplete,
                knownTotalVolumes: currentState.knownTotalVolumes,
                isTombstone: true
            )
        }

        if let newTotal = command.knownTotalVolumes {
            guard newTotal > 0 else { throw .nonPositiveKnownTotal(newTotal) }
            guard CollectionVolumePolicy.contains(newTotal) else {
                throw .knownTotalExceedsMaximum(total: newTotal, maximum: CollectionVolumePolicy.maximum)
            }
            if newTotal != currentState.knownTotalVolumes {
                try validateKnownTotalChange(newTotal, currentState: currentState)
            }
        }

        let knownTotal = command.knownTotalVolumes ?? currentState.knownTotalVolumes
        var ownedVolumes = currentState.ownedVolumes
        var readingVolume = currentState.readingVolume
        var isComplete = currentState.isComplete

        switch command.change {
        case let .replaceOwnedVolumes(volumes):
            ownedVolumes = try canonicalOwnedVolumes(volumes, knownTotal: knownTotal)
            if isComplete && matchesCompleteRange(ownedVolumes, total: knownTotal) == false {
                isComplete = false
            }
        case let .setReadingVolume(volume):
            try validate(volume: volume, knownTotal: knownTotal)
            readingVolume = volume
        case let .setComplete(complete):
            if complete {
                guard let completeVolumes = CollectionVolumePolicy.completeVolumes(for: knownTotal) else {
                    throw .completeRequiresKnownTotal
                }
                ownedVolumes = completeVolumes
            }
            isComplete = complete
        case let .replaceState(volumes, volume, complete):
            try validate(volume: volume, knownTotal: knownTotal)
            readingVolume = volume
            if complete {
                guard let completeVolumes = CollectionVolumePolicy.completeVolumes(for: knownTotal) else {
                    throw .completeRequiresKnownTotal
                }
                ownedVolumes = completeVolumes
            } else {
                ownedVolumes = try canonicalOwnedVolumes(volumes, knownTotal: knownTotal)
            }
            isComplete = complete
        case .delete:
            throw .persistenceConflict
        }

        let candidate = CollectionSnapshot(
            ownedVolumes: ownedVolumes,
            readingVolume: readingVolume,
            isComplete: isComplete,
            knownTotalVolumes: knownTotal,
            isTombstone: false
        )
        guard CollectionVolumePolicy.isValid(candidate) else { throw .persistenceConflict }
        return candidate
    }

    private func canonicalOwnedVolumes(
        _ volumes: [Int64],
        knownTotal: Int64?
    ) throws(CollectionMutationError) -> [Int64] {
        for volume in volumes {
            try validate(volume: volume, knownTotal: knownTotal)
        }
        return Array(Set(volumes)).sorted()
    }

    private func validate(volume: Int64?, knownTotal: Int64?) throws(CollectionMutationError) {
        guard let volume else { return }
        guard volume > 0 else { throw .nonPositiveVolume(volume) }
        guard CollectionVolumePolicy.contains(volume) else {
            throw .volumeExceedsMaximum(volume: volume, maximum: CollectionVolumePolicy.maximum)
        }
        if let knownTotal, volume > knownTotal {
            throw .volumeExceedsKnownTotal(volume: volume, total: knownTotal)
        }
    }

    private func validateKnownTotalChange(
        _ newTotal: Int64,
        currentState: CollectionSnapshot
    ) throws(CollectionMutationError) {
        let invalidatesOwnedVolumes = currentState.ownedVolumes.contains { $0 > newTotal }
        let invalidatesReadingVolume = currentState.readingVolume.map { $0 > newTotal } ?? false
        if currentState.isComplete || invalidatesOwnedVolumes || invalidatesReadingVolume {
            throw .knownTotalInvalidatesCurrentState(newTotal)
        }
    }

    private func matchesCompleteRange(_ ownedVolumes: [Int64], total: Int64?) -> Bool {
        guard let completeVolumes = CollectionVolumePolicy.completeVolumes(for: total) else { return false }

        return ownedVolumes == completeVolumes
    }
}
