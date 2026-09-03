//
//  CollectionModels.swift
//  MangaLibrary
//

import Foundation
import SwiftData

extension MangaLibrarySchema.V1 {
    /// A value representation of one local collection state at a specific sequence.
    ///
    /// Product mutations obtain active instances from ``CollectionMutationActor``
    /// with canonical owned volumes that satisfy the current rules. Explicit
    /// deletion may instead retain incompatible legacy values in an opaque
    /// tombstone that is never serialized as a POST.
    struct CollectionSnapshot: Codable, Equatable {
        let ownedVolumes: [Int64]
        let readingVolume: Int64?
        let isComplete: Bool
        let knownTotalVolumes: Int64?
        let isTombstone: Bool
    }

    enum CollectionOutboxState: String, Codable, Equatable {
        case queued
        case sending
        case retry
        case blockedAuth
        case blockedOutcome
        case rejected
        case confirmed
    }

    /// The single persisted collection entry for one user and manga pair.
    ///
    /// Identity is immutable after construction. Product code changes state only
    /// through ``CollectionMutationActor`` so the compound uniqueness constraint is
    /// backed by the same validation and outbox transaction.
    @Model
    final class CollectionEntry {
        #Unique<CollectionEntry>([\.userID, \.mangaID])

        private(set) var userID: UUID
        private(set) var mangaID: Manga.ID
        @Attribute(.codable) private(set) var ownedVolumes: [Int64]
        private(set) var readingVolume: Int64?
        private(set) var isComplete: Bool
        private(set) var knownTotalVolumes: Int64?
        @Attribute(.codable) private(set) var confirmedState: CollectionSnapshot?
        private(set) var isTombstone: Bool

        var state: CollectionSnapshot {
            CollectionSnapshot(
                ownedVolumes: ownedVolumes,
                readingVolume: readingVolume,
                isComplete: isComplete,
                knownTotalVolumes: knownTotalVolumes,
                isTombstone: isTombstone
            )
        }

        init(
            userID: UUID,
            mangaID: Manga.ID,
            state: CollectionSnapshot,
            confirmedState: CollectionSnapshot?
        ) {
            self.userID = userID
            self.mangaID = mangaID
            ownedVolumes = state.ownedVolumes
            readingVolume = state.readingVolume
            isComplete = state.isComplete
            knownTotalVolumes = state.knownTotalVolumes
            self.confirmedState = confirmedState
            isTombstone = state.isTombstone
        }

        func apply(_ state: CollectionSnapshot) {
            ownedVolumes = state.ownedVolumes
            readingVolume = state.readingVolume
            isComplete = state.isComplete
            knownTotalVolumes = state.knownTotalVolumes
            isTombstone = state.isTombstone
        }
    }

    /// One durable synchronization intent ordered within a user and manga pair.
    ///
    /// L1 creates and coalesces only `queued` operations. The UUID remains stable
    /// while a queued intent is replaced, and sequence always advances without wrap.
    @Model
    final class CollectionOutboxOperation {
        #Unique<CollectionOutboxOperation>([\.operationID], [\.userID, \.mangaID, \.sequence])

        private(set) var operationID: UUID
        private(set) var userID: UUID
        private(set) var mangaID: Manga.ID
        private(set) var sequence: Int64
        @Attribute(.codable) private(set) var desiredState: CollectionSnapshot
        private(set) var state: CollectionOutboxState
        private(set) var retryCount: Int
        private(set) var nextRetryAt: Date?
        private(set) var isTombstone: Bool

        init(
            operationID: UUID,
            userID: UUID,
            mangaID: Manga.ID,
            sequence: Int64,
            desiredState: CollectionSnapshot,
            state: CollectionOutboxState = .queued,
            retryCount: Int = 0,
            nextRetryAt: Date? = nil
        ) {
            self.operationID = operationID
            self.userID = userID
            self.mangaID = mangaID
            self.sequence = sequence
            self.desiredState = desiredState
            self.state = state
            self.retryCount = retryCount
            self.nextRetryAt = nextRetryAt
            isTombstone = desiredState.isTombstone
        }

        func coalesce(sequence: Int64, desiredState: CollectionSnapshot) {
            self.sequence = sequence
            self.desiredState = desiredState
            state = .queued
            retryCount = 0
            nextRetryAt = nil
            isTombstone = desiredState.isTombstone
        }
    }
}

typealias CollectionSnapshot = MangaLibrarySchema.V1.CollectionSnapshot
typealias CollectionOutboxState = MangaLibrarySchema.V1.CollectionOutboxState
typealias CollectionEntry = MangaLibrarySchema.V2.CollectionEntry
typealias CollectionOutboxOperation = MangaLibrarySchema.V2.CollectionOutboxOperation
typealias CollectionMangaSnapshot = MangaLibrarySchema.V2.MangaSnapshot

extension CollectionVolumePolicy {
    static func isValid(_ state: CollectionSnapshot, allowingHistoricalTombstone: Bool = false) -> Bool {
        if allowingHistoricalTombstone, state.isTombstone {
            return true
        }

        guard state.ownedVolumes.allSatisfy(contains) else { return false }
        guard state.ownedVolumes == Array(Set(state.ownedVolumes)).sorted() else { return false }
        guard state.readingVolume.map(contains) ?? true else { return false }

        if let total = state.knownTotalVolumes {
            guard contains(total) else { return false }
            guard state.ownedVolumes.allSatisfy({ $0 <= total }) else { return false }
            guard state.readingVolume.map({ $0 <= total }) ?? true else { return false }
        }

        if state.isComplete {
            guard let completeVolumes = completeVolumes(for: state.knownTotalVolumes) else { return false }

            return state.ownedVolumes == completeVolumes
        }

        return true
    }
}

/// A semantic collection edit that can cross into the SwiftData model actor.
///
/// A non-`nil` total replaces the actor's prior knowledge only when it keeps the
/// current state valid. `nil` retains any total already persisted for the pair.
struct CollectionMutationCommand: Equatable {
    enum Change: Equatable {
        case replaceOwnedVolumes([Int64])
        case setReadingVolume(Int64?)
        case setComplete(Bool)
        case replaceState(ownedVolumes: [Int64], readingVolume: Int64?, isComplete: Bool)
        case delete
    }

    let authority: SessionAuthority
    let mangaID: Manga.ID
    private(set) var mangaSnapshot: CollectionMangaSnapshot? = nil
    let knownTotalVolumes: Int64?
    let change: Change

    var userID: UUID { authority.userID }
}

/// The committed collection and outbox identity returned by one mutation.
struct CollectionMutationResult: Equatable {
    let userID: UUID
    let mangaID: Manga.ID
    let state: CollectionSnapshot
    let outboxOperationID: UUID
    let sequence: Int64
}

/// Failures that leave both collection and outbox at their last committed state.
enum CollectionMutationError: Error, Equatable {
    case invalidIdentity
    case nonPositiveKnownTotal(Int64)
    case knownTotalExceedsMaximum(total: Int64, maximum: Int64)
    case nonPositiveVolume(Int64)
    case volumeExceedsMaximum(volume: Int64, maximum: Int64)
    case volumeExceedsKnownTotal(volume: Int64, total: Int64)
    case completeRequiresKnownTotal
    case knownTotalInvalidatesCurrentState(Int64)
    case incompatibleStoredVolumeState
    case mangaSnapshotRequired
    case mangaSnapshotIdentityMismatch(expected: Manga.ID, actual: Manga.ID)
    case collectionEntryNotFound
    case authenticationRequired
    case sequenceExhausted
    case persistenceConflict
    case cancelled
}
