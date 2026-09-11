//
//  CollectionMutationActorTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@Suite("Collection mutation actor", .tags(.integration))
struct CollectionMutationActorTests {
    @Test("A first mutation requires an offline presentation snapshot")
    func firstMutationWithoutSnapshotLeavesTheStoreEmpty() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionMutationError.mangaSnapshotRequired) {
            try await actor.apply(
                CollectionMutationCommand(
                    authority: Self.authority(for: Self.userA),
                    mangaID: Self.mangaA,
                    knownTotalVolumes: nil,
                    change: .replaceOwnedVolumes([1])
                ),
                newOperationID: Self.operationA
            )
        }

        #expect(try readStore(container) == PersistedCollectionStore(entries: [], operations: []))
    }

    @Test("A presentation snapshot must belong to the mutated manga")
    func mismatchedSnapshotIdentityLeavesTheStoreEmpty() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        let mismatchedSnapshot = CollectionMangaSnapshot(manga: Self.manga(id: Self.mangaB))

        await #expect(
            throws: CollectionMutationError.mangaSnapshotIdentityMismatch(expected: Self.mangaA, actual: Self.mangaB)
        ) {
            try await actor.apply(
                CollectionMutationCommand(
                    authority: Self.authority(for: Self.userA),
                    mangaID: Self.mangaA,
                    mangaSnapshot: mismatchedSnapshot,
                    knownTotalVolumes: nil,
                    change: .replaceOwnedVolumes([1])
                ),
                newOperationID: Self.operationA
            )
        }

        #expect(try readStore(container) == PersistedCollectionStore(entries: [], operations: []))
    }

    @Test("A manga identity must be positive", arguments: [Int64(0), Int64(-1)])
    func invalidMangaIdentityLeavesTheStoreEmpty(mangaID: Manga.ID) async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionMutationError.invalidIdentity) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: mangaID,
                    knownTotalVolumes: nil,
                    change: .replaceOwnedVolumes([1])
                ),
                newOperationID: Self.operationA
            )
        }

        #expect(try readStore(container) == PersistedCollectionStore(entries: [], operations: []))
    }

    @Test("Owned volumes are canonicalized and committed with one queued intent")
    func ownedVolumesAreCanonicalizedAndPersisted() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)

        let result = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: nil,
                change: .replaceOwnedVolumes([3, 1, 3, 2])
            ),
            newOperationID: Self.operationA
        )

        let expectedState = CollectionSnapshot(
            ownedVolumes: [1, 2, 3],
            readingVolume: nil,
            isComplete: false,
            knownTotalVolumes: nil,
            isTombstone: false
        )
        let store = try readStore(container)

        #expect(result.state == expectedState)
        #expect(result.outboxOperationID == Self.operationA)
        #expect(result.sequence == 1)
        #expect(
            store.entries == [
                PersistedCollectionEntry(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    state: expectedState,
                    confirmedState: nil
                )
            ]
        )
        #expect(
            store.operations == [
                PersistedOutboxOperation(
                    operationID: Self.operationA,
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    sequence: 1,
                    desiredState: expectedState,
                    state: .queued,
                    retryCount: 0,
                    nextRetryAt: nil,
                    isTombstone: false
                )
            ]
        )
    }

    @Test("A nonpositive owned volume is rejected without either persisted half")
    func nonpositiveOwnedVolumeLeavesTheStoreEmpty() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionMutationError.nonPositiveVolume(0)) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: nil,
                    change: .replaceOwnedVolumes([0, 1])
                ),
                newOperationID: Self.operationA
            )
        }

        #expect(try readStore(container) == PersistedCollectionStore(entries: [], operations: []))
    }

    @Test("A known total must be positive", arguments: [Int64(0), Int64(-1)])
    func nonpositiveKnownTotalLeavesTheStoreEmpty(total: Int64) async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionMutationError.nonPositiveKnownTotal(total)) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: total,
                    change: .replaceOwnedVolumes([1])
                ),
                newOperationID: Self.operationA
            )
        }

        #expect(try readStore(container) == PersistedCollectionStore(entries: [], operations: []))
    }

    @Test("A known total above 300 preserves the previous atomic state", arguments: [Int64(301), Int64.max])
    func excessiveKnownTotalPreservesCollectionAndOutbox(total: Int64) async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1])
            ),
            newOperationID: Self.operationA
        )
        let priorStore = try readStore(container)

        await #expect(throws: CollectionMutationError.knownTotalExceedsMaximum(total: total, maximum: 300)) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: total,
                    change: .setComplete(true)
                ),
                newOperationID: Self.operationB
            )
        }

        #expect(try readStore(container) == priorStore)
    }

    @Test("An owned volume above 300 is invalid even without a known total", arguments: [Int64(301), Int64.max])
    func excessiveUnknownTotalOwnedVolumePreservesCollectionAndOutbox(volume: Int64) async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: nil,
                change: .replaceOwnedVolumes([1])
            ),
            newOperationID: Self.operationA
        )
        let priorStore = try readStore(container)

        await #expect(throws: CollectionMutationError.volumeExceedsMaximum(volume: volume, maximum: 300)) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: nil,
                    change: .replaceOwnedVolumes([1, volume])
                ),
                newOperationID: Self.operationB
            )
        }

        #expect(try readStore(container) == priorStore)
    }

    @Test("A reading volume above 300 is invalid even without a known total", arguments: [Int64(301), Int64.max])
    func excessiveUnknownTotalReadingVolumePreservesCollectionAndOutbox(volume: Int64) async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: nil,
                change: .setReadingVolume(299)
            ),
            newOperationID: Self.operationA
        )
        let priorStore = try readStore(container)

        await #expect(throws: CollectionMutationError.volumeExceedsMaximum(volume: volume, maximum: 300)) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: nil,
                    change: .setReadingVolume(volume)
                ),
                newOperationID: Self.operationB
            )
        }

        #expect(try readStore(container) == priorStore)
    }

    @Test("An owned volume above the known total is rejected without either persisted half")
    func ownedVolumeAboveKnownTotalLeavesTheStoreEmpty() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionMutationError.volumeExceedsKnownTotal(volume: 4, total: 3)) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: 3,
                    change: .replaceOwnedVolumes([1, 4])
                ),
                newOperationID: Self.operationA
            )
        }

        #expect(try readStore(container) == PersistedCollectionStore(entries: [], operations: []))
    }

    @Test("A reading volume must be positive", arguments: [Int64(0), Int64(-1)])
    func nonpositiveReadingVolumeLeavesTheStoreEmpty(volume: Int64) async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionMutationError.nonPositiveVolume(volume)) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: nil,
                    change: .setReadingVolume(volume)
                ),
                newOperationID: Self.operationA
            )
        }

        #expect(try readStore(container) == PersistedCollectionStore(entries: [], operations: []))
    }

    @Test("Reading progress is independent from ownership and an invalid edit preserves the prior commit")
    func readingProgressHonorsItsOwnInvariant() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1, 3])
            ),
            newOperationID: Self.operationA
        )

        let accepted = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .setReadingVolume(2)
            ),
            newOperationID: Self.operationB
        )
        await #expect(throws: CollectionMutationError.volumeExceedsKnownTotal(volume: 4, total: 3)) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: 3,
                    change: .setReadingVolume(4)
                ),
                newOperationID: Self.operationC
            )
        }

        let expectedState = CollectionSnapshot(
            ownedVolumes: [1, 3],
            readingVolume: 2,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        let store = try readStore(container)

        #expect(accepted.state == expectedState)
        #expect(store.entries.map(\.state) == [expectedState])
        #expect(store.operations.map(\.operationID) == [Self.operationA])
        #expect(store.operations.map(\.sequence) == [2])
        #expect(store.operations.map(\.desiredState) == [expectedState])
    }

    @Test("Whole-editor replacement canonicalizes ownership and an invalid replacement rolls back")
    func replacementStateCanonicalizesAndRollsBackAtomically() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        let accepted = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceState(ownedVolumes: [3, 1, 3, 2], readingVolume: 2, isComplete: false)
            ),
            newOperationID: Self.operationA
        )

        await #expect(throws: CollectionMutationError.volumeExceedsKnownTotal(volume: 4, total: 3)) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: 3,
                    change: .replaceState(ownedVolumes: [1, 3], readingVolume: 4, isComplete: false)
                ),
                newOperationID: Self.operationB
            )
        }

        let expectedState = CollectionSnapshot(
            ownedVolumes: [1, 2, 3],
            readingVolume: 2,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        let store = try readStore(container)
        #expect(accepted.state == expectedState)
        #expect(store.entries.map(\.state) == [expectedState])
        #expect(store.operations.map(\.operationID) == [Self.operationA])
        #expect(store.operations.map(\.sequence) == [1])
        #expect(store.operations.map(\.desiredState) == [expectedState])
    }

    @Test("Deleting and re-adding coalesce one reversible local intent")
    func deleteAndReactivationPreserveTheQueuedIdentity() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1])
            ),
            newOperationID: Self.operationA
        )
        let deleted = try await actor.apply(
            CollectionMutationCommand(
                authority: Self.authority(for: Self.userA),
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .delete
            ),
            newOperationID: Self.operationB
        )

        #expect(deleted.state.isTombstone)
        #expect(deleted.outboxOperationID == Self.operationA)
        #expect(deleted.sequence == 2)

        let reactivated = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([2])
            ),
            newOperationID: Self.operationC
        )
        let store = try readStore(container)

        #expect(reactivated.state.isTombstone == false)
        #expect(reactivated.outboxOperationID == Self.operationA)
        #expect(reactivated.sequence == 3)
        #expect(store.entries.map(\.state.ownedVolumes) == [[2]])
        #expect(store.operations.map(\.operationID) == [Self.operationA])
        #expect(store.operations.map(\.sequence) == [3])
        #expect(store.operations.map(\.isTombstone) == [false])
        #expect(store.operations.map(\.desiredState) == [reactivated.state])
    }

    @Test("Editing during backoff replaces the retry without sending stale state")
    func editingDuringBackoffCoalescesTheRetry() async throws(any Error) {
        let container = try makeContainer()
        let priorState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: 1,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        let seedContext = ModelContext(container)
        seedContext.insert(
            CollectionEntry(
                userID: Self.userA,
                mangaID: Self.mangaA,
                state: priorState,
                confirmedState: nil
            )
        )
        seedContext.insert(
            CollectionOutboxOperation(
                operationID: Self.operationA,
                userID: Self.userA,
                mangaID: Self.mangaA,
                sequence: 1,
                desiredState: priorState,
                state: .retry,
                retryCount: 3,
                nextRetryAt: Date(timeIntervalSince1970: 1_800_000_030)
            )
        )
        try seedContext.save()

        let actor = CollectionMutationActor(modelContainer: container)
        let result = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1, 2])
            ),
            newOperationID: Self.operationB
        )

        let store = try readStore(container)
        #expect(result.outboxOperationID == Self.operationA)
        #expect(result.sequence == 2)
        #expect(store.operations.count == 1)
        #expect(store.operations.first?.operationID == Self.operationA)
        #expect(store.operations.first?.sequence == 2)
        let expectedState = CollectionSnapshot(
            ownedVolumes: [1, 2],
            readingVolume: 1,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        #expect(result.state == expectedState)
        #expect(store.operations.first?.desiredState == expectedState)
        let readContext = ModelContext(container)
        let entries = try readContext.fetch(FetchDescriptor<CollectionEntry>())
        #expect(entries.count == 1)
        #expect(try #require(entries.first).state == expectedState)
        #expect(store.operations.first?.state == .queued)
        #expect(store.operations.first?.retryCount == 0)
        #expect(store.operations.first?.nextRetryAt == nil)
    }

    @Test("Deleting during backoff replaces the retry with one queued tombstone")
    func deletingDuringBackoffCoalescesTheRetry() async throws(any Error) {
        let container = try makeContainer()
        let priorState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: 1,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        let seedContext = ModelContext(container)
        seedContext.insert(
            CollectionEntry(
                userID: Self.userA,
                mangaID: Self.mangaA,
                state: priorState,
                confirmedState: priorState
            )
        )
        seedContext.insert(
            CollectionOutboxOperation(
                operationID: Self.operationA,
                userID: Self.userA,
                mangaID: Self.mangaA,
                sequence: 1,
                desiredState: priorState,
                state: .retry,
                retryCount: 2,
                nextRetryAt: Date(timeIntervalSince1970: 1_800_000_030)
            )
        )
        try seedContext.save()

        let actor = CollectionMutationActor(modelContainer: container)
        let result = try await actor.apply(
            CollectionMutationCommand(
                authority: Self.authority(for: Self.userA),
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .delete
            ),
            newOperationID: Self.operationB
        )

        let store = try readStore(container)
        #expect(result.outboxOperationID == Self.operationA)
        #expect(result.sequence == 2)
        #expect(result.state.isTombstone)
        #expect(store.operations.count == 1)
        #expect(store.operations.first?.operationID == Self.operationA)
        #expect(store.operations.first?.sequence == 2)
        #expect(store.operations.first?.desiredState == result.state)
        #expect(store.operations.first?.state == .queued)
        #expect(store.operations.first?.retryCount == 0)
        #expect(store.operations.first?.nextRetryAt == nil)
        #expect(store.operations.first?.isTombstone == true)
    }

    @Test("Complete state requires a total, preserves volumes when cleared, and falls when one volume is removed")
    func completeStateCanonicalizesAndFallsOnRemoval() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionMutationError.completeRequiresKnownTotal) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: nil,
                    change: .setComplete(true)
                ),
                newOperationID: Self.operationA
            )
        }

        let completed = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .setComplete(true)
            ),
            newOperationID: Self.operationB
        )
        let cleared = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .setComplete(false)
            ),
            newOperationID: Self.operationC
        )
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .setComplete(true)
            ),
            newOperationID: Self.operationD
        )
        let removed = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1, 3])
            ),
            newOperationID: Self.operationE
        )

        #expect(completed.state.ownedVolumes == [1, 2, 3])
        #expect(completed.state.isComplete)
        #expect(cleared.state.ownedVolumes == [1, 2, 3])
        #expect(cleared.state.isComplete == false)
        #expect(removed.state.ownedVolumes == [1, 3])
        #expect(removed.state.isComplete == false)

        let store = try readStore(container)
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.state == removed.state)
        #expect(store.operations.count == 1)
        #expect(store.operations.first?.operationID == Self.operationB)
        #expect(store.operations.first?.sequence == 4)
        #expect(store.operations.first?.desiredState == removed.state)
    }

    @Test("A complete collection at the global maximum materializes exactly 300 volumes")
    func completeStateAcceptsTheGlobalMaximum() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)

        let completed = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 300,
                change: .setComplete(true)
            ),
            newOperationID: Self.operationA
        )

        #expect(completed.state.ownedVolumes.count == 300)
        #expect(Array(completed.state.ownedVolumes.prefix(3)) == [1, 2, 3])
        #expect(Array(completed.state.ownedVolumes.suffix(3)) == [298, 299, 300])
        #expect(completed.state.readingVolume == nil)
        #expect(completed.state.isComplete)
        #expect(completed.state.knownTotalVolumes == 300)

        let store = try readStore(container)
        #expect(store.entries.map(\.state) == [completed.state])
        #expect(store.operations.map(\.desiredState) == [completed.state])
        #expect(store.operations.map(\.state) == [.queued])
    }

    @Test("A newly known total that invalidates current data is rejected atomically")
    func incompatibleKnownTotalPreservesTheUnknownTotalState() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: nil,
                change: .replaceOwnedVolumes([1, 4])
            ),
            newOperationID: Self.operationA
        )

        await #expect(throws: CollectionMutationError.knownTotalInvalidatesCurrentState(3)) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: 3,
                    change: .setReadingVolume(nil)
                ),
                newOperationID: Self.operationB
            )
        }

        let store = try readStore(container)
        #expect(store.entries.first?.state.ownedVolumes == [1, 4])
        #expect(store.entries.first?.state.knownTotalVolumes == nil)
        #expect(store.operations.first?.sequence == 1)
        #expect(store.operations.first?.operationID == Self.operationA)
    }

    @Test("A newly known total cannot silently discard incompatible reading progress")
    func incompatibleKnownTotalPreservesUnknownTotalReadingProgress() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: nil,
                change: .setReadingVolume(4)
            ),
            newOperationID: Self.operationA
        )

        await #expect(throws: CollectionMutationError.knownTotalInvalidatesCurrentState(3)) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: 3,
                    change: .setReadingVolume(nil)
                ),
                newOperationID: Self.operationB
            )
        }

        let store = try readStore(container)
        #expect(store.entries.first?.state.readingVolume == 4)
        #expect(store.entries.first?.state.knownTotalVolumes == nil)
        #expect(store.operations.first?.sequence == 1)
        #expect(store.operations.first?.operationID == Self.operationA)
    }

    @Test("An incompatible historical state is immutable through edits but can become an explicit tombstone")
    func incompatibleHistoricalStateCanOnlyBeTombstoned() async throws(any Error) {
        let container = try makeContainer()
        let historicalState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: 299,
            isComplete: false,
            knownTotalVolumes: 301,
            isTombstone: false
        )
        let seedContext = ModelContext(container)
        seedContext.insert(
            CollectionEntry(
                userID: Self.userA,
                mangaID: Self.mangaA,
                state: historicalState,
                confirmedState: nil,
                mangaSnapshot: CollectionMangaSnapshot(manga: Self.manga(id: Self.mangaA))
            )
        )
        seedContext.insert(
            CollectionOutboxOperation(
                operationID: Self.operationA,
                userID: Self.userA,
                mangaID: Self.mangaA,
                sequence: 1,
                desiredState: historicalState
            )
        )
        try seedContext.save()
        let priorStore = try readStore(container)
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionMutationError.incompatibleStoredVolumeState) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: nil,
                    change: .setReadingVolume(300)
                ),
                newOperationID: Self.operationB
            )
        }
        #expect(try readStore(container) == priorStore)

        let deletion = try await actor.apply(
            CollectionMutationCommand(
                authority: Self.authority(for: Self.userA),
                mangaID: Self.mangaA,
                knownTotalVolumes: nil,
                change: .delete
            ),
            newOperationID: Self.operationC
        )

        #expect(deletion.state.ownedVolumes == historicalState.ownedVolumes)
        #expect(deletion.state.readingVolume == historicalState.readingVolume)
        #expect(deletion.state.knownTotalVolumes == historicalState.knownTotalVolumes)
        #expect(deletion.state.isTombstone)
        #expect(deletion.outboxOperationID == Self.operationA)
        #expect(deletion.sequence == 2)

        let deletedStore = try readStore(container)
        #expect(deletedStore.entries.map(\.state) == [deletion.state])
        #expect(deletedStore.operations.map(\.operationID) == [Self.operationA])
        #expect(deletedStore.operations.map(\.sequence) == [2])
        #expect(deletedStore.operations.map(\.desiredState) == [deletion.state])
    }

    @Test("Repeated upserts stay unique and the same manga remains isolated by user")
    func entriesAndOperationsAreUniquePerUserAndManga() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1])
            ),
            newOperationID: Self.operationA
        )
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1, 2])
            ),
            newOperationID: Self.operationB
        )
        _ = try await actor.apply(
            Self.command(
                userID: Self.userB,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([3])
            ),
            newOperationID: Self.operationC
        )

        let allUsers = try readStore(container)
        let userA = try readStore(container, userID: Self.userA)
        let userB = try readStore(container, userID: Self.userB)

        #expect(allUsers.entries.count == 2)
        #expect(allUsers.operations.count == 2)
        #expect(userA.entries.map(\.state.ownedVolumes) == [[1, 2]])
        #expect(userA.operations.map(\.operationID) == [Self.operationA])
        #expect(userA.operations.map(\.sequence) == [2])
        #expect(userB.entries.map(\.state.ownedVolumes) == [[3]])
        #expect(userB.operations.map(\.operationID) == [Self.operationC])
        #expect(userB.operations.map(\.sequence) == [1])
    }

    @Test("Different mangas of one user keep independent collection and outbox identities")
    func sameUserMangasRemainIndependent() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1])
            ),
            newOperationID: Self.operationA
        )
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaB,
                knownTotalVolumes: 4,
                change: .replaceOwnedVolumes([2, 4])
            ),
            newOperationID: Self.operationB
        )

        let store = try readStore(container, userID: Self.userA)
        #expect(store.entries.map(\.mangaID) == [Self.mangaA, Self.mangaB])
        #expect(store.entries.map(\.state.ownedVolumes) == [[1], [2, 4]])
        #expect(store.operations.map(\.mangaID) == [Self.mangaA, Self.mangaB])
        #expect(store.operations.map(\.sequence) == [1, 1])
        #expect(store.operations.map(\.operationID) == [Self.operationA, Self.operationB])
    }

    @Test("The current schema independently enforces collection identity uniqueness")
    func versionedSchemaEnforcesCollectionIdentityUniqueness() throws(any Error) {
        let container = try makeContainer()
        let initialState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: nil,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        let replacementState = CollectionSnapshot(
            ownedVolumes: [2],
            readingVolume: nil,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        let initialContext = ModelContext(container)
        initialContext.insert(
            CollectionEntry(
                userID: Self.userA,
                mangaID: Self.mangaA,
                state: initialState,
                confirmedState: nil
            )
        )
        try initialContext.save()

        let replacementContext = ModelContext(container)
        replacementContext.insert(
            CollectionEntry(
                userID: Self.userA,
                mangaID: Self.mangaA,
                state: replacementState,
                confirmedState: nil
            )
        )
        try replacementContext.save()

        let store = try readStore(container)
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.userID == Self.userA)
        #expect(store.entries.first?.mangaID == Self.mangaA)
    }

    @Test("An outbox operation identity cannot be reused across collection identities")
    func reusedOperationIdentityRollsBackTheSecondCollection() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1])
            ),
            newOperationID: Self.operationA
        )

        await #expect(throws: CollectionMutationError.persistenceConflict) {
            try await actor.apply(
                Self.command(
                    userID: Self.userB,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: 3,
                    change: .replaceOwnedVolumes([2])
                ),
                newOperationID: Self.operationA
            )
        }

        let store = try readStore(container)
        #expect(store.entries.map(\.userID) == [Self.userA])
        #expect(store.entries.map(\.state.ownedVolumes) == [[1]])
        #expect(store.operations.map(\.operationID) == [Self.operationA])
        #expect(store.operations.map(\.userID) == [Self.userA])
    }

    @Test("A sending operation is preserved while later edits share the next queued intent")
    func sendingOperationKeepsItsIdentityAndLaterEditsCoalesce() async throws(any Error) {
        let container = try makeContainer()
        let priorState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: nil,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        let seedContext = ModelContext(container)
        seedContext.insert(
            CollectionEntry(
                userID: Self.userA,
                mangaID: Self.mangaA,
                state: priorState,
                confirmedState: nil
            )
        )
        seedContext.insert(
            CollectionOutboxOperation(
                operationID: Self.operationA,
                userID: Self.userA,
                mangaID: Self.mangaA,
                sequence: 1,
                desiredState: priorState,
                state: .sending
            )
        )
        try seedContext.save()

        let actor = CollectionMutationActor(modelContainer: container)
        _ = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1, 2])
            ),
            newOperationID: Self.operationB
        )
        let finalResult = try await actor.apply(
            Self.command(
                userID: Self.userA,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .setReadingVolume(2)
            ),
            newOperationID: Self.operationC
        )

        let store = try readStore(container)
        #expect(finalResult.sequence == 3)
        #expect(finalResult.outboxOperationID == Self.operationB)
        #expect(store.operations.map(\.operationID) == [Self.operationA, Self.operationB])
        #expect(store.operations.map(\.sequence) == [1, 3])
        #expect(store.operations.map(\.state) == [.sending, .queued])
        #expect(store.operations.first?.desiredState == priorState)
        #expect(store.operations.last?.desiredState == finalResult.state)
    }

    @Test("Concurrent mutations of one identity serialize into one valid state and intent")
    func concurrentMutationsAreSerialized() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        let ownedCommand = Self.command(
            userID: Self.userA,
            mangaID: Self.mangaA,
            knownTotalVolumes: 3,
            change: .replaceOwnedVolumes([1, 3])
        )
        let readingCommand = Self.command(
            userID: Self.userA,
            mangaID: Self.mangaA,
            knownTotalVolumes: 3,
            change: .setReadingVolume(2)
        )

        async let owned = actor.apply(ownedCommand, newOperationID: Self.operationA)
        async let reading = actor.apply(readingCommand, newOperationID: Self.operationB)
        _ = try await (owned, reading)

        let expectedState = CollectionSnapshot(
            ownedVolumes: [1, 3],
            readingVolume: 2,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        let store = try readStore(container)

        #expect(store.entries.map(\.state) == [expectedState])
        #expect(store.operations.count == 1)
        #expect(store.operations.first?.sequence == 2)
        #expect(store.operations.first?.desiredState == expectedState)
        let operationID = try #require(store.operations.first?.operationID)
        #expect([Self.operationA, Self.operationB].contains(operationID))
    }

    @Test("Sequence exhaustion rolls back both halves and cannot leak into the next commit")
    func sequenceExhaustionRollsBackTheWholeTransaction() async throws(any Error) {
        let container = try makeContainer()
        let priorState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: nil,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        let seedContext = ModelContext(container)
        seedContext.insert(
            CollectionEntry(
                userID: Self.userA,
                mangaID: Self.mangaA,
                state: priorState,
                confirmedState: nil
            )
        )
        seedContext.insert(
            CollectionOutboxOperation(
                operationID: Self.operationA,
                userID: Self.userA,
                mangaID: Self.mangaA,
                sequence: .max,
                desiredState: priorState
            )
        )
        try seedContext.save()

        let actor = CollectionMutationActor(modelContainer: container)
        await #expect(throws: CollectionMutationError.sequenceExhausted) {
            try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: 3,
                    change: .replaceOwnedVolumes([1, 2])
                ),
                newOperationID: Self.operationB
            )
        }
        _ = try await actor.apply(
            Self.command(
                userID: Self.userB,
                mangaID: Self.mangaA,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([2])
            ),
            newOperationID: Self.operationC
        )

        let userA = try readStore(container, userID: Self.userA)
        let userB = try readStore(container, userID: Self.userB)
        #expect(userA.entries.map(\.state) == [priorState])
        #expect(userA.operations.map(\.sequence) == [.max])
        #expect(userA.operations.map(\.desiredState) == [priorState])
        #expect(userB.entries.map(\.state.ownedVolumes) == [[2]])
        #expect(userB.operations.map(\.sequence) == [1])
    }

    @Test("Cancellation observed before commit leaves collection and outbox empty")
    func cancellationBeforeCommitLeavesTheStoreEmpty() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        let task = Task {
            withUnsafeCurrentTask {
                $0?.cancel()
            }
            return try await actor.apply(
                Self.command(
                    userID: Self.userA,
                    mangaID: Self.mangaA,
                    knownTotalVolumes: 3,
                    change: .replaceOwnedVolumes([1])
                ),
                newOperationID: Self.operationA
            )
        }

        await #expect(throws: CollectionMutationError.cancelled) {
            try await task.value
        }
        #expect(try readStore(container) == PersistedCollectionStore(entries: [], operations: []))
    }

    private func makeContainer() throws(any Error) -> ModelContainer {
        try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
    }

    private static func command(
        userID: UUID,
        mangaID: Manga.ID,
        knownTotalVolumes: Int64?,
        change: CollectionMutationCommand.Change
    ) -> CollectionMutationCommand {
        CollectionMutationCommand(
            authority: Self.authority(for: userID),
            mangaID: mangaID,
            mangaSnapshot: CollectionMangaSnapshot(manga: manga(id: mangaID)),
            knownTotalVolumes: knownTotalVolumes,
            change: change
        )
    }

    private static func manga(id: Manga.ID) -> Manga {
        Manga(
            id: id,
            title: "Manga \(id)",
            titleEnglish: nil,
            titleJapanese: nil,
            synopsis: nil,
            score: 8,
            status: .publishing,
            authors: [],
            demographics: [],
            genres: [],
            themes: [],
            coverURL: nil
        )
    }

    private static let userA = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let userB = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!

    private static func authority(for userID: UUID) -> SessionAuthority {
        SessionAuthority(userID: userID, generation: UUID(uuidString: "C011EC71-0000-0000-0000-000000000001")!)
    }
    private static let mangaA: Manga.ID = 42
    private static let mangaB: Manga.ID = 84
    private static let operationA = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private static let operationB = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!
    private static let operationC = UUID(uuidString: "CCCCCCCC-DDDD-EEEE-FFFF-000000000000")!
    private static let operationD = UUID(uuidString: "DDDDDDDD-EEEE-FFFF-0000-111111111111")!
    private static let operationE = UUID(uuidString: "EEEEEEEE-FFFF-0000-1111-222222222222")!
}

private struct PersistedCollectionStore: Equatable {
    let entries: [PersistedCollectionEntry]
    let operations: [PersistedOutboxOperation]
}

private struct PersistedCollectionEntry: Equatable {
    let userID: UUID
    let mangaID: Manga.ID
    let state: CollectionSnapshot
    let confirmedState: CollectionSnapshot?
}

private struct PersistedOutboxOperation: Equatable {
    let operationID: UUID
    let userID: UUID
    let mangaID: Manga.ID
    let sequence: Int64
    let desiredState: CollectionSnapshot
    let state: CollectionOutboxState
    let retryCount: Int
    let nextRetryAt: Date?
    let isTombstone: Bool
}

private func readStore(_ container: ModelContainer, userID: UUID? = nil) throws(any Error) -> PersistedCollectionStore {
    let context = ModelContext(container)
    let entries: [CollectionEntry]
    let operations: [CollectionOutboxOperation]

    if let userID {
        entries = try context.fetch(
            FetchDescriptor<CollectionEntry>(
                predicate: #Predicate { $0.userID == userID }
            )
        )
        operations = try context.fetch(
            FetchDescriptor<CollectionOutboxOperation>(
                predicate: #Predicate { $0.userID == userID }
            )
        )
    } else {
        entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
    }

    return PersistedCollectionStore(
        entries: entries
            .map {
                PersistedCollectionEntry(
                    userID: $0.userID,
                    mangaID: $0.mangaID,
                    state: $0.state,
                    confirmedState: $0.confirmedState
                )
            }
            .sorted(by: collectionEntryOrder),
        operations: operations
            .map {
                PersistedOutboxOperation(
                    operationID: $0.operationID,
                    userID: $0.userID,
                    mangaID: $0.mangaID,
                    sequence: $0.sequence,
                    desiredState: $0.desiredState,
                    state: $0.state,
                    retryCount: $0.retryCount,
                    nextRetryAt: $0.nextRetryAt,
                    isTombstone: $0.isTombstone
                )
            }
            .sorted(by: outboxOperationOrder)
    )
}

private func collectionEntryOrder(_ lhs: PersistedCollectionEntry, _ rhs: PersistedCollectionEntry) -> Bool {
    if lhs.userID != rhs.userID {
        return lhs.userID.uuidString < rhs.userID.uuidString
    }
    return lhs.mangaID < rhs.mangaID
}

private func outboxOperationOrder(_ lhs: PersistedOutboxOperation, _ rhs: PersistedOutboxOperation) -> Bool {
    if lhs.userID != rhs.userID {
        return lhs.userID.uuidString < rhs.userID.uuidString
    }
    if lhs.mangaID != rhs.mangaID {
        return lhs.mangaID < rhs.mangaID
    }
    return lhs.sequence < rhs.sequence
}
