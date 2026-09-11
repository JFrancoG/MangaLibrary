//
//  CollectionBlockedOutcomeResolutionTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@Suite("Collection blocked outcome resolution", .tags(.integration))
struct CollectionBlockedOutcomeResolutionTests {
    @Test("Using remote presence resolves a blocked POST without creating work")
    func usingRemotePresenceResolvesBlockedPost() async throws(any Error) {
        let fixture = try Self.makeFixture(localState: Self.localState)
        let remoteState = Self.state(ownedVolumes: [1, 3], readingVolume: 3)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )

        let resolution = try await fixture.actor.resolveBlockedOutcome(
            context,
            evidence: .present(state: remoteState, mangaSnapshot: Self.mangaSnapshot),
            decision: .useRemote,
            authorization: fixture.authorization,
            newOperationID: Self.newOperationID
        )

        #expect(resolution == .adoptedRemote)
        #expect(
            try Self.read(fixture.container) == R24Store(
                entries: [R24Entry(state: remoteState, confirmedState: remoteState)],
                operations: [R24Operation(id: Self.blockedOperationID, sequence: 1, state: .confirmed)]
            )
        )
    }

    @Test("Using remote absence resolves a blocked DELETE and removes its tombstone")
    func usingRemoteAbsenceResolvesBlockedDelete() async throws(any Error) {
        let tombstone = Self.state(ownedVolumes: [1, 2], readingVolume: 2, isTombstone: true)
        let fixture = try Self.makeFixture(localState: tombstone)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )

        let resolution = try await fixture.actor.resolveBlockedOutcome(
            context,
            evidence: .absent,
            decision: .useRemote,
            authorization: fixture.authorization,
            newOperationID: Self.newOperationID
        )

        #expect(resolution == .adoptedRemote)
        #expect(
            try Self.read(fixture.container) == R24Store(
                entries: [],
                operations: [R24Operation(id: Self.blockedOperationID, sequence: 1, state: .confirmed)]
            )
        )
    }

    @Test("Using remote presence restores an uncertain local deletion")
    func usingRemotePresenceRestoresBlockedDelete() async throws(any Error) {
        let tombstone = Self.state(ownedVolumes: [1, 2], readingVolume: 2, isTombstone: true)
        let fixture = try Self.makeFixture(localState: tombstone)
        let remoteState = Self.state(ownedVolumes: [1], readingVolume: 1)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )

        _ = try await fixture.actor.resolveBlockedOutcome(
            context,
            evidence: .present(state: remoteState, mangaSnapshot: Self.mangaSnapshot),
            decision: .useRemote,
            authorization: fixture.authorization,
            newOperationID: Self.newOperationID
        )

        #expect(
            try Self.read(fixture.container).entries == [
                R24Entry(state: remoteState, confirmedState: remoteState)
            ]
        )
    }

    @Test("Keeping a divergent device version creates a fresh queued sequence")
    func keepingDivergentDeviceVersionCreatesFreshIntent() async throws(any Error) {
        let fixture = try Self.makeFixture(localState: Self.localState)
        let remoteState = Self.state(ownedVolumes: [1], readingVolume: 1)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )

        let resolution = try await fixture.actor.resolveBlockedOutcome(
            context,
            evidence: .present(state: remoteState, mangaSnapshot: Self.mangaSnapshot),
            decision: .keepDevice,
            authorization: fixture.authorization,
            newOperationID: Self.newOperationID
        )

        #expect(resolution == .createdIntent(operationID: Self.newOperationID, sequence: 2))
        #expect(
            try Self.read(fixture.container) == R24Store(
                entries: [R24Entry(state: Self.localState, confirmedState: remoteState)],
                operations: [
                    R24Operation(id: Self.blockedOperationID, sequence: 1, state: .confirmed),
                    R24Operation(id: Self.newOperationID, sequence: 2, state: .queued),
                ],
                queuedDesiredState: Self.localState
            )
        )
    }

    @Test("Keeping a device deletion creates a fresh queued tombstone")
    func keepingDeviceDeletionCreatesFreshIntent() async throws(any Error) {
        let tombstone = Self.state(ownedVolumes: [1, 2], readingVolume: 2, isTombstone: true)
        let fixture = try Self.makeFixture(localState: tombstone)
        let remoteState = Self.state(ownedVolumes: [1, 2], readingVolume: 2)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )

        _ = try await fixture.actor.resolveBlockedOutcome(
            context,
            evidence: .present(state: remoteState, mangaSnapshot: Self.mangaSnapshot),
            decision: .keepDevice,
            authorization: fixture.authorization,
            newOperationID: Self.newOperationID
        )

        let store = try Self.read(fixture.container)
        #expect(store.entries == [R24Entry(state: tombstone, confirmedState: remoteState)])
        #expect(store.operations.last == R24Operation(id: Self.newOperationID, sequence: 2, state: .queued))
        #expect(store.queuedDesiredState == tombstone)
    }

    @Test("A fresh read that already proves the device effect creates no operation", arguments: [false, true])
    func matchingEvidenceCreatesNoOperation(isDeletion: Bool) async throws(any Error) {
        let localState = Self.state(ownedVolumes: [1, 2], readingVolume: 2, isTombstone: isDeletion)
        let fixture = try Self.makeFixture(localState: localState)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )
        let evidence: CollectionBlockedOutcomeEvidence = isDeletion
            ? .absent
            : .present(state: localState, mangaSnapshot: Self.mangaSnapshot)

        let resolution = try await fixture.actor.resolveBlockedOutcome(
            context,
            evidence: evidence,
            decision: .keepDevice,
            authorization: fixture.authorization,
            newOperationID: Self.newOperationID
        )

        #expect(resolution == .effectAlreadyConfirmed)
        let store = try Self.read(fixture.container)
        #expect(store.operations == [R24Operation(id: Self.blockedOperationID, sequence: 1, state: .confirmed)])
        #expect(store.entries.isEmpty == isDeletion)
    }

    @Test("Resolving N preserves and unfences an existing N plus one")
    func laterIntentIsPreservedAndUnfenced() async throws(any Error) {
        let laterState = Self.state(ownedVolumes: [1, 2, 3], readingVolume: 3)
        let fixture = try Self.makeFixture(localState: laterState, laterState: laterState)
        let remoteState = Self.state(ownedVolumes: [1], readingVolume: 1)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )

        let resolution = try await fixture.actor.resolveBlockedOutcome(
            context,
            evidence: .present(state: remoteState, mangaSnapshot: Self.mangaSnapshot),
            decision: .keepDevice,
            authorization: fixture.authorization,
            newOperationID: Self.newOperationID
        )

        #expect(resolution == .continuedExistingIntent(operationID: Self.laterOperationID, sequence: 2))
        let store = try Self.read(fixture.container)
        #expect(store.entries == [R24Entry(state: laterState, confirmedState: remoteState)])
        #expect(
            store.operations == [
                R24Operation(id: Self.blockedOperationID, sequence: 1, state: .confirmed),
                R24Operation(id: Self.laterOperationID, sequence: 2, state: .queued),
            ]
        )

        let claim = try #require(try await fixture.actor.claimNextUpload(authorization: fixture.authorization))
        guard case let .send(workItem) = claim else {
            Issue.record("Expected the preserved later intent to become claimable")
            return
        }
        #expect(workItem.operationID == Self.laterOperationID)
        #expect(workItem.sequence == 2)
    }

    @Test("Remote adoption is rejected while a later local intent exists")
    func laterIntentPreventsRemoteAdoption() async throws(any Error) {
        let laterState = Self.state(ownedVolumes: [1, 2, 3], readingVolume: 3)
        let fixture = try Self.makeFixture(localState: laterState, laterState: laterState)
        let priorStore = try Self.read(fixture.container)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )

        await #expect(throws: CollectionBlockedOutcomeError.laterIntentRequiresDeviceVersion) {
            try await fixture.actor.resolveBlockedOutcome(
                context,
                evidence: .absent,
                decision: .useRemote,
                authorization: fixture.authorization,
                newOperationID: Self.newOperationID
            )
        }

        #expect(try Self.read(fixture.container) == priorStore)
    }

    @Test("A changed later intent makes the reviewed context stale")
    func changedLaterIntentCannotBeResolved() async throws(any Error) {
        let laterState = Self.state(ownedVolumes: [1, 2, 3], readingVolume: 3)
        let fixture = try Self.makeFixture(localState: laterState, laterState: laterState)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )
        let changedState = Self.state(ownedVolumes: [2, 3], readingVolume: 2)
        try Self.coalesceLaterOperation(in: fixture.container, to: changedState)
        let priorStore = try Self.read(fixture.container)

        await #expect(throws: CollectionBlockedOutcomeError.staleOperation) {
            try await fixture.actor.resolveBlockedOutcome(
                context,
                evidence: .absent,
                decision: .keepDevice,
                authorization: fixture.authorization,
                newOperationID: Self.newOperationID
            )
        }

        #expect(try Self.read(fixture.container) == priorStore)
    }

    @Test("Every persisted operation fence rejects a stale review", arguments: R24OperationFenceMutation.allCases)
    private func changedOperationFenceCannotBeResolved(mutation: R24OperationFenceMutation) async throws(any Error) {
        let fixture = try Self.makeFixture(localState: Self.localState)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )
        try Self.mutateBlockedOperation(in: fixture.container, mutation: mutation)
        let mutatedFence = try Self.readOperationFence(fixture.container)

        await #expect(throws: CollectionBlockedOutcomeError.staleOperation) {
            try await fixture.actor.resolveBlockedOutcome(
                context,
                evidence: .absent,
                decision: .keepDevice,
                authorization: fixture.authorization,
                newOperationID: Self.newOperationID
            )
        }

        #expect(try Self.readOperationFence(fixture.container) == mutatedFence)
    }

    @Test("A duplicate follow-up UUID rolls the complete resolution back")
    func duplicateFollowUpIdentifierRollsBackEverything() async throws(any Error) {
        let fixture = try Self.makeFixture(localState: Self.localState)
        let priorStore = try Self.read(fixture.container)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )

        await #expect(throws: CollectionBlockedOutcomeError.persistenceConflict) {
            try await fixture.actor.resolveBlockedOutcome(
                context,
                evidence: .absent,
                decision: .keepDevice,
                authorization: fixture.authorization,
                newOperationID: Self.blockedOperationID
            )
        }

        #expect(try Self.read(fixture.container) == priorStore)
    }

    @Test("Sequence exhaustion rolls the complete resolution back")
    func sequenceExhaustionRollsBackEverything() async throws(any Error) {
        let fixture = try Self.makeFixture(localState: Self.localState, blockedSequence: .max)
        let priorFence = try Self.readOperationFence(fixture.container)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )

        await #expect(throws: CollectionBlockedOutcomeError.sequenceExhausted) {
            try await fixture.actor.resolveBlockedOutcome(
                context,
                evidence: .absent,
                decision: .keepDevice,
                authorization: fixture.authorization,
                newOperationID: Self.newOperationID
            )
        }

        #expect(try Self.readOperationFence(fixture.container) == priorFence)
        let readContext = ModelContext(fixture.container)
        let entries = try readContext.fetch(FetchDescriptor<CollectionEntry>())
        let operations = try readContext.fetch(FetchDescriptor<CollectionOutboxOperation>())
        #expect(entries.count == 1)
        #expect(operations.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.userID == Self.userID)
        #expect(entry.mangaID == Self.mangaID)
        #expect(entry.state == Self.localState)
        #expect(entry.confirmedState == Self.confirmedState)
        #expect(entry.mangaSnapshot == Self.mangaSnapshot)
    }

    @Test("Resolution never changes another manga pair or another user")
    func resolutionIsIsolatedToTheReviewedPair() async throws(any Error) {
        let fixture = try Self.makeFixture(localState: Self.localState)
        try Self.seedForeignPairs(in: fixture.container)
        let foreignStore = try Self.readForeignStore(fixture.container)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )

        _ = try await fixture.actor.resolveBlockedOutcome(
            context,
            evidence: .absent,
            decision: .useRemote,
            authorization: fixture.authorization,
            newOperationID: Self.newOperationID
        )

        #expect(try Self.readForeignStore(fixture.container) == foreignStore)
    }

    @Test("The normal worker submits a preserved N plus one exactly once")
    func preservedLaterIntentIsSubmittedExactlyOnce() async throws(any Error) {
        let laterState = Self.state(ownedVolumes: [1, 2, 3], readingVolume: 3)
        let fixture = try Self.makeFixture(localState: laterState, laterState: laterState)
        let remoteState = Self.state(ownedVolumes: [1], readingVolume: 1)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )
        let resolution = try await fixture.actor.resolveBlockedOutcome(
            context,
            evidence: .present(state: remoteState, mangaSnapshot: Self.mangaSnapshot),
            decision: .keepDevice,
            authorization: fixture.authorization,
            newOperationID: Self.newOperationID
        )
        let probe = R24SubmitProbe()
        let coordinator = Self.outboxCoordinator(fixture: fixture, probe: probe)

        try await coordinator.synchronizeAuthenticatedOutbox()
        try await coordinator.synchronizeAuthenticatedOutbox()

        #expect(resolution == .continuedExistingIntent(operationID: Self.laterOperationID, sequence: 2))
        #expect(await probe.submittedOperationIDs() == [Self.laterOperationID])
    }

    @Test("A failure inside the transaction rolls entry and outbox back together")
    func persistenceCheckpointFailureRollsBackEverything() async throws(any Error) {
        let fixture = try Self.makeFixture(localState: Self.localState)
        let priorStore = try Self.read(fixture.container)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )

        await #expect(throws: CollectionBlockedOutcomeError.persistenceConflict) {
            try await fixture.actor.resolveBlockedOutcome(
                context,
                evidence: .absent,
                decision: .keepDevice,
                authorization: fixture.authorization,
                newOperationID: Self.newOperationID,
                afterMutation: {
                    throw R24Failure.injected
                }
            )
        }

        #expect(try Self.read(fixture.container) == priorStore)
    }

    @Test("Cancellation inside the transaction rolls entry and outbox back together")
    func cancellationCheckpointRollsBackEverything() async throws(any Error) {
        let fixture = try Self.makeFixture(localState: Self.localState)
        let priorStore = try Self.read(fixture.container)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )

        await #expect(throws: CollectionBlockedOutcomeError.cancelled) {
            try await fixture.actor.resolveBlockedOutcome(
                context,
                evidence: .absent,
                decision: .keepDevice,
                authorization: fixture.authorization,
                newOperationID: Self.newOperationID,
                afterMutation: {
                    throw CancellationError()
                }
            )
        }

        #expect(try Self.read(fixture.container) == priorStore)
    }

    @Test("A different session generation cannot resolve the durable operation")
    func differentGenerationCannotResolve() async throws(any Error) {
        let fixture = try Self.makeFixture(localState: Self.localState)
        let priorStore = try Self.read(fixture.container)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )
        let replacementAuthority = SessionAuthority(userID: Self.userID, generation: UUID())
        let replacementGate = SessionCommitGate(activeAuthority: replacementAuthority)

        await #expect(throws: CollectionBlockedOutcomeError.sessionChanged) {
            try await fixture.actor.resolveBlockedOutcome(
                context,
                evidence: .absent,
                decision: .keepDevice,
                authorization: replacementGate.authorization(for: replacementAuthority),
                newOperationID: Self.newOperationID
            )
        }

        #expect(try Self.read(fixture.container) == priorStore)
    }

    @Test("Incompatible remote data cannot be adopted as a safe absence")
    func incompatibleRemotePresenceLeavesBlockUntouched() async throws(any Error) {
        let fixture = try Self.makeFixture(localState: Self.localState)
        let priorStore = try Self.read(fixture.container)
        let incompatibleState = CollectionSnapshot(
            ownedVolumes: [301],
            readingVolume: 301,
            isComplete: false,
            knownTotalVolumes: 301,
            isTombstone: false
        )
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: Self.blockedOperationID,
            authorization: fixture.authorization
        )

        await #expect(throws: CollectionBlockedOutcomeError.incompatibleRemoteState) {
            try await fixture.actor.resolveBlockedOutcome(
                context,
                evidence: .present(state: incompatibleState, mangaSnapshot: Self.mangaSnapshot),
                decision: .useRemote,
                authorization: fixture.authorization,
                newOperationID: Self.newOperationID
            )
        }

        #expect(try Self.read(fixture.container) == priorStore)
    }

    @Test("A blocked outcome remains durable when the store is reopened")
    func blockedOutcomeSurvivesReopening() throws(any Error) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "MangaLibrary-R24-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let storeURL = directory.appending(path: "Collection.store")

        do {
            let container = try MangaLibrarySchema.makeContainer(storeURL: storeURL)
            try Self.seedFixture(in: container, localState: Self.localState, laterState: nil)
        }

        let reopened = try MangaLibrarySchema.makeContainer(storeURL: storeURL)
        let context = ModelContext(reopened)
        let operation = try #require(try context.fetch(FetchDescriptor<CollectionOutboxOperation>()).first)
        let entry = try #require(try context.fetch(FetchDescriptor<CollectionEntry>()).first)

        #expect(operation.operationID == Self.blockedOperationID)
        #expect(operation.state == .blockedOutcome)
        #expect(operation.desiredState == Self.localState)
        #expect(entry.state == Self.localState)
    }
}

private extension CollectionBlockedOutcomeResolutionTests {
    static let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let generation = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let blockedOperationID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let laterOperationID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let newOperationID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    static let changedOperationID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    static let otherUserID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    static let otherPairOperationID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
    static let otherUserOperationID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
    static let mangaID: Manga.ID = 42
    static let confirmedState = state(ownedVolumes: [1], readingVolume: 1)
    static let localState = state(ownedVolumes: [1, 2], readingVolume: 2)
    static let mangaSnapshot = CollectionMangaSnapshot(
        manga: Manga(
            id: mangaID,
            title: "Forty-Two",
            titleEnglish: nil,
            titleJapanese: nil,
            synopsis: nil,
            score: 8,
            status: .publishing,
            authors: [],
            demographics: [],
            genres: [],
            themes: [],
            totalVolumes: 3,
            coverURL: nil
        )
    )

    static func makeFixture(
        localState: CollectionSnapshot,
        laterState: CollectionSnapshot? = nil,
        blockedSequence: Int64 = 1
    ) throws(any Error) -> R24Fixture {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        try seedFixture(
            in: container,
            localState: localState,
            laterState: laterState,
            blockedSequence: blockedSequence
        )

        let authority = SessionAuthority(userID: userID, generation: generation)
        let gate = SessionCommitGate(activeAuthority: authority)
        let authorization = gate.authorization(for: authority)
        return R24Fixture(
            container: container,
            actor: CollectionMutationActor(modelContainer: container),
            authorization: authorization,
            requestAuthorization: SessionRequestAuthorization(
                authority: authority,
                accessToken: "synthetic-access",
                commitAuthorization: authorization
            )
        )
    }

    static func seedFixture(
        in container: ModelContainer,
        localState: CollectionSnapshot,
        laterState: CollectionSnapshot?,
        blockedSequence: Int64 = 1
    ) throws(any Error) {
        let context = ModelContext(container)
        context.insert(
            CollectionEntry(
                userID: userID,
                mangaID: mangaID,
                state: localState,
                confirmedState: confirmedState,
                mangaSnapshot: mangaSnapshot
            )
        )
        context.insert(
            CollectionOutboxOperation(
                operationID: blockedOperationID,
                userID: userID,
                mangaID: mangaID,
                sequence: blockedSequence,
                desiredState: laterState == nil ? localState : Self.localState,
                state: .blockedOutcome
            )
        )
        if let laterState {
            context.insert(
                CollectionOutboxOperation(
                    operationID: laterOperationID,
                    userID: userID,
                    mangaID: mangaID,
                    sequence: blockedSequence + 1,
                    desiredState: laterState
                )
            )
        }
        try context.save()
    }

    static func state(ownedVolumes: [Int64], readingVolume: Int64?, isTombstone: Bool = false) -> CollectionSnapshot {
        CollectionSnapshot(
            ownedVolumes: ownedVolumes,
            readingVolume: readingVolume,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: isTombstone
        )
    }

    static func coalesceLaterOperation(in container: ModelContainer, to state: CollectionSnapshot) throws(any Error) {
        let context = ModelContext(container)
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
        let operation = try #require(operations.first { $0.operationID == laterOperationID })
        operation.coalesce(sequence: 3, desiredState: state)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        try #require(entries.first).apply(state, mangaSnapshot: mangaSnapshot)
        try context.save()
    }

    static func mutateBlockedOperation(
        in container: ModelContainer,
        mutation: R24OperationFenceMutation
    ) throws(any Error) {
        let context = ModelContext(container)
        let operation = try #require(
            try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
                .first { $0.operationID == blockedOperationID }
        )
        if mutation == .state {
            guard operation.markConfirmedIfBlockedOutcome() else { throw R24Failure.injected }
            try context.save()
            return
        }

        context.delete(operation)
        try context.save()
        context.insert(
            CollectionOutboxOperation(
                operationID: mutation == .operationID ? changedOperationID : blockedOperationID,
                userID: userID,
                mangaID: mangaID,
                sequence: mutation == .sequence ? 2 : 1,
                desiredState: mutation == .payload
                    ? state(ownedVolumes: [2, 3], readingVolume: 3)
                    : localState,
                state: .blockedOutcome,
                retryCount: mutation == .retryCount ? 1 : 0
            )
        )
        try context.save()
    }

    static func readOperationFence(_ container: ModelContainer) throws(any Error) -> R24OperationFence {
        let context = ModelContext(container)
        let operation = try #require(try context.fetch(FetchDescriptor<CollectionOutboxOperation>()).first)
        return R24OperationFence(
            operationID: operation.operationID,
            userID: operation.userID,
            mangaID: operation.mangaID,
            sequence: operation.sequence,
            retryCount: operation.retryCount,
            state: operation.state,
            desiredState: operation.desiredState
        )
    }

    static func seedForeignPairs(in container: ModelContainer) throws(any Error) {
        let context = ModelContext(container)
        let otherPairState = state(ownedVolumes: [1, 3], readingVolume: 3)
        context.insert(
            CollectionEntry(
                userID: userID,
                mangaID: 77,
                state: otherPairState,
                confirmedState: confirmedState,
                mangaSnapshot: nil
            )
        )
        context.insert(
            CollectionOutboxOperation(
                operationID: otherPairOperationID,
                userID: userID,
                mangaID: 77,
                sequence: 1,
                desiredState: otherPairState
            )
        )
        context.insert(
            CollectionEntry(
                userID: otherUserID,
                mangaID: mangaID,
                state: otherPairState,
                confirmedState: confirmedState,
                mangaSnapshot: nil
            )
        )
        context.insert(
            CollectionOutboxOperation(
                operationID: otherUserOperationID,
                userID: otherUserID,
                mangaID: mangaID,
                sequence: 1,
                desiredState: otherPairState,
                state: .blockedOutcome
            )
        )
        try context.save()
    }

    static func readForeignStore(_ container: ModelContainer) throws(any Error) -> R24ForeignStore {
        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
            .filter { $0.userID != userID || $0.mangaID != mangaID }
            .map {
                R24ForeignEntry(
                    userID: $0.userID,
                    mangaID: $0.mangaID,
                    state: $0.state,
                    confirmedState: $0.confirmedState
                )
            }
            .sorted(by: R24ForeignEntry.areInStableOrder)
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
            .filter { $0.userID != userID || $0.mangaID != mangaID }
            .map {
                R24OperationFence(
                    operationID: $0.operationID,
                    userID: $0.userID,
                    mangaID: $0.mangaID,
                    sequence: $0.sequence,
                    retryCount: $0.retryCount,
                    state: $0.state,
                    desiredState: $0.desiredState
                )
            }
            .sorted { $0.operationID.uuidString < $1.operationID.uuidString }
        return R24ForeignStore(entries: entries, operations: operations)
    }

    static func outboxCoordinator(fixture: R24Fixture, probe: R24SubmitProbe) -> CollectionOutboxSyncCoordinator {
        CollectionOutboxSyncCoordinator(
            authorize: { fixture.requestAuthorization },
            validateAuthorization: { authorization in
                authorization.authority == fixture.requestAuthorization.authority
            },
            claimNextUpload: { authorization, now in
                try await fixture.actor.claimNextUpload(authorization: authorization, now: now)
            },
            submit: { item, accessToken in
                await probe.submit(item, accessToken: accessToken)
            },
            fetchRemote: { _ in [] },
            importRemote: { _, _ in },
            confirmUpload: { item, authorization in
                try await fixture.actor.confirmUpload(item, authorization: authorization)
            },
            blockUploadOutcome: { item, authorization in
                try await fixture.actor.blockUploadOutcome(item, authorization: authorization)
            },
            hasBlockedOutcome: { authorization in
                try await fixture.actor.hasBlockedUploadOutcome(authorization: authorization)
            }
        )
    }

    static func read(_ container: ModelContainer) throws(any Error) -> R24Store {
        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>()).map {
            R24Entry(state: $0.state, confirmedState: $0.confirmedState)
        }
        let models = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
            .sorted { $0.sequence < $1.sequence }
        return R24Store(
            entries: entries,
            operations: models.map { R24Operation(id: $0.operationID, sequence: $0.sequence, state: $0.state) },
            queuedDesiredState: models.first(where: { $0.state == .queued })?.desiredState
        )
    }
}

private struct R24Fixture {
    let container: ModelContainer
    let actor: CollectionMutationActor
    let authorization: SessionCommitAuthorization
    let requestAuthorization: SessionRequestAuthorization
}

private struct R24Store: Equatable {
    let entries: [R24Entry]
    let operations: [R24Operation]
    private(set) var queuedDesiredState: CollectionSnapshot? = nil
}

private struct R24Entry: Equatable {
    let state: CollectionSnapshot
    let confirmedState: CollectionSnapshot?
}

private struct R24Operation: Equatable {
    let id: UUID
    let sequence: Int64
    let state: CollectionOutboxState
}

private enum R24OperationFenceMutation: CaseIterable, Sendable {
    case operationID
    case sequence
    case retryCount
    case payload
    case state
}

private struct R24OperationFence: Equatable {
    let operationID: UUID
    let userID: UUID
    let mangaID: Manga.ID
    let sequence: Int64
    let retryCount: Int
    let state: CollectionOutboxState
    let desiredState: CollectionSnapshot
}

private struct R24ForeignStore: Equatable {
    let entries: [R24ForeignEntry]
    let operations: [R24OperationFence]
}

private struct R24ForeignEntry: Equatable {
    let userID: UUID
    let mangaID: Manga.ID
    let state: CollectionSnapshot
    let confirmedState: CollectionSnapshot?

    static func areInStableOrder(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.userID != rhs.userID {
            return lhs.userID.uuidString < rhs.userID.uuidString
        }
        return lhs.mangaID < rhs.mangaID
    }
}

private actor R24SubmitProbe {
    private var operationIDs: [UUID] = []

    func submit(_ item: CollectionOutboxUploadWorkItem, accessToken: String) {
        guard accessToken == "synthetic-access" else { return }
        operationIDs.append(item.operationID)
    }

    func submittedOperationIDs() -> [UUID] {
        operationIDs
    }
}

private enum R24Failure: Error {
    case injected
}
