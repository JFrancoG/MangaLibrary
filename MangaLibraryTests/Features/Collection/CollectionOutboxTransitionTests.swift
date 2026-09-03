//
//  CollectionOutboxTransitionTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@Suite("Collection outbox transitions", .tags(.integration))
struct CollectionOutboxTransitionTests {
    @Test("Claiming a queued upload persists sending before exposing the work item")
    func queuedUploadIsClaimedAtomically() async throws(any Error) {
        let container = try makeContainer()
        let desiredState = Self.state(ownedVolumes: [1, 2], readingVolume: 2)
        try seed(
            container,
            entry: Self.entry(state: desiredState, confirmedState: nil),
            operations: [Self.operation(sequence: 1, desiredState: desiredState)]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let claim = try #require(try await actor.claimNextUpload(authorization: Self.authorization(for: Self.userA)))
        let workItem = try requireSendWorkItem(claim)

        #expect(workItem.operationID == Self.operationA)
        #expect(workItem.userID == Self.userA)
        #expect(workItem.mangaID == Self.mangaA)
        #expect(workItem.sequence == 1)
        #expect(workItem.ownedVolumes == [1, 2])
        #expect(workItem.readingVolume == 2)
        #expect(workItem.isComplete == false)
        #expect(workItem.isTombstone == false)

        let persisted = try readStore(container)
        #expect(persisted.entries == [Self.persistedEntry(state: desiredState, confirmedState: nil)])
        #expect(
            persisted.operations == [
                Self.persistedOperation(sequence: 1, desiredState: desiredState, state: .sending)
            ]
        )
    }

    @Test("A queued tombstone is claimed atomically for DELETE")
    func tombstoneIsClaimedAtomically() async throws(any Error) {
        let container = try makeContainer()
        let tombstone = Self.state(ownedVolumes: [1], isTombstone: true)
        try seed(
            container,
            entry: Self.entry(state: tombstone, confirmedState: Self.baseState),
            operations: [Self.operation(sequence: 1, desiredState: tombstone)]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let claim = try #require(try await actor.claimNextUpload(authorization: Self.authorization(for: Self.userA)))
        let workItem = try requireSendWorkItem(claim)

        #expect(workItem.operationID == Self.operationA)
        #expect(workItem.mangaID == Self.mangaA)
        #expect(workItem.sequence == 1)
        #expect(workItem.isTombstone)
        #expect(
            try readStore(container).operations == [
                Self.persistedOperation(sequence: 1, desiredState: tombstone, state: .sending)
            ]
        )
    }

    @Test("A historical out-of-range tombstone remains claimable for bodyless DELETE")
    func historicalOutOfRangeTombstoneCanBeClaimed() async throws(any Error) {
        let container = try makeContainer()
        let tombstone = Self.state(
            ownedVolumes: [1],
            readingVolume: 299,
            knownTotalVolumes: 301,
            isTombstone: true
        )
        try seed(
            container,
            entry: Self.entry(state: tombstone, confirmedState: Self.baseState),
            operations: [Self.operation(sequence: 1, desiredState: tombstone)]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let claim = try #require(try await actor.claimNextUpload(authorization: Self.authorization(for: Self.userA)))
        let workItem = try requireSendWorkItem(claim)

        #expect(workItem.ownedVolumes == [1])
        #expect(workItem.readingVolume == 299)
        #expect(workItem.isTombstone)
        #expect(try readStore(container).operations.map(\.state) == [.sending])
    }

    @Test("An incompatible confirmed cursor cannot block a later historical tombstone")
    func historicalConfirmedCursorDoesNotBlockDeleteClaim() async throws(any Error) {
        let container = try makeContainer()
        let historicalState = Self.state(ownedVolumes: [1], readingVolume: 299, knownTotalVolumes: 301)
        let tombstone = Self.state(
            ownedVolumes: historicalState.ownedVolumes,
            readingVolume: historicalState.readingVolume,
            knownTotalVolumes: historicalState.knownTotalVolumes,
            isTombstone: true
        )
        try seed(
            container,
            entry: Self.entry(state: tombstone, confirmedState: historicalState),
            operations: [
                Self.operation(sequence: 1, desiredState: historicalState, state: .confirmed),
                Self.operation(operationID: Self.operationB, sequence: 2, desiredState: tombstone),
            ]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let claim = try #require(try await actor.claimNextUpload(authorization: Self.authorization(for: Self.userA)))
        let workItem = try requireSendWorkItem(claim)

        #expect(workItem.operationID == Self.operationB)
        #expect(workItem.sequence == 2)
        #expect(workItem.isTombstone)
        #expect(try readStore(container).operations.map(\.state) == [.confirmed, .sending])
    }

    @Test("A queued POST at the global boundary remains claimable")
    func maximumUnknownTotalUploadCanBeClaimed() async throws(any Error) {
        let container = try makeContainer()
        let desiredState = Self.state(ownedVolumes: [299, 300], readingVolume: 300, knownTotalVolumes: nil)
        try seed(
            container,
            entry: Self.entry(state: desiredState, confirmedState: nil),
            operations: [Self.operation(sequence: 1, desiredState: desiredState)]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let claim = try #require(try await actor.claimNextUpload(authorization: Self.authorization(for: Self.userA)))
        let workItem = try requireSendWorkItem(claim)

        #expect(workItem.ownedVolumes == [299, 300])
        #expect(workItem.readingVolume == 300)
        #expect(workItem.isComplete == false)
        #expect(workItem.isTombstone == false)
        #expect(try readStore(container).operations.map(\.state) == [.sending])
    }

    @Test(
        "An invalid queued POST cannot be claimed or alter a later intent",
        arguments: InvalidUploadVolumeScenario.allCases
    )
    private func invalidVolumeStateFailsBeforeClaim(_ scenario: InvalidUploadVolumeScenario) async throws(any Error) {
        let container = try makeContainer()
        let validLaterState = Self.state(ownedVolumes: [1], readingVolume: 1)
        try seed(
            container,
            entry: Self.entry(state: scenario.state, confirmedState: nil),
            operations: [
                Self.operation(sequence: 1, desiredState: scenario.state),
                Self.operation(operationID: Self.operationB, sequence: 2, desiredState: validLaterState),
            ]
        )
        let priorStore = try readStore(container)
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionOutboxUploadError.invalidVolumeState) {
            try await actor.claimNextUpload(authorization: Self.authorization(for: Self.userA))
        }

        #expect(try readStore(container) == priorStore)
    }

    @Test("A session can only claim its own user's uploads")
    func authorizationDoesNotCrossUserIdentity() async throws(any Error) {
        let container = try makeContainer()
        let desiredState = Self.state(ownedVolumes: [2])
        try seed(
            container,
            entry: Self.entry(userID: Self.userB, state: desiredState, confirmedState: nil),
            operations: [
                Self.operation(
                    operationID: Self.operationB,
                    userID: Self.userB,
                    sequence: 1,
                    desiredState: desiredState
                )
            ]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let claim = try await actor.claimNextUpload(authorization: Self.authorization(for: Self.userA))

        #expect(claim == nil)
        #expect(
            try readStore(container).operations == [
                Self.persistedOperation(
                    operationID: Self.operationB,
                    userID: Self.userB,
                    sequence: 1,
                    desiredState: desiredState,
                    state: .queued
                )
            ]
        )
    }

    @Test("A blocked outcome prevents skipping to a later upload for the same pair")
    func blockedOutcomeFencesLaterSequence() async throws(any Error) {
        let container = try makeContainer()
        let blockedState = Self.state(ownedVolumes: [1])
        let laterState = Self.state(ownedVolumes: [1, 2])
        try seed(
            container,
            entry: Self.entry(state: laterState, confirmedState: Self.baseState),
            operations: [
                Self.operation(sequence: 1, desiredState: blockedState, state: .blockedOutcome),
                Self.operation(operationID: Self.operationB, sequence: 2, desiredState: laterState)
            ]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let claim = try await actor.claimNextUpload(authorization: Self.authorization(for: Self.userA))

        #expect(claim == nil)
        #expect(try readStore(container).operations.map(\.state) == [.blockedOutcome, .queued])
    }

    @Test("A recovered sending upload is reconciled before a later queued sequence")
    func sendingUploadFencesLaterSequence() async throws(any Error) {
        let container = try makeContainer()
        let sendingState = Self.state(ownedVolumes: [1])
        let laterState = Self.state(ownedVolumes: [1, 2])
        try seed(
            container,
            entry: Self.entry(state: laterState, confirmedState: Self.baseState),
            operations: [
                Self.operation(sequence: 1, desiredState: sendingState, state: .sending),
                Self.operation(operationID: Self.operationB, sequence: 2, desiredState: laterState)
            ]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let claim = try #require(try await actor.claimNextUpload(authorization: Self.authorization(for: Self.userA)))
        let workItem = try requireReconcileWorkItem(claim)

        #expect(workItem.operationID == Self.operationA)
        #expect(workItem.sequence == 1)
        #expect(workItem.ownedVolumes == [1])
        #expect(try readStore(container).operations.map(\.state) == [.sending, .queued])
    }

    @Test("Confirming sequence N advances only the baseline when N plus one is visible")
    func confirmationPreservesLaterOptimisticState() async throws(any Error) {
        let container = try makeContainer()
        let confirmedByServer = Self.state(ownedVolumes: [1, 2], readingVolume: 2)
        let laterVisibleState = Self.state(ownedVolumes: [1, 2, 3], readingVolume: 3)
        try seed(
            container,
            entry: Self.entry(state: laterVisibleState, confirmedState: Self.baseState),
            operations: [
                Self.operation(sequence: 1, desiredState: confirmedByServer, state: .sending),
                Self.operation(operationID: Self.operationB, sequence: 2, desiredState: laterVisibleState)
            ]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let authorization = Self.authorization(for: Self.userA)
        let claim = try #require(try await actor.claimNextUpload(authorization: authorization))
        let workItem = try requireReconcileWorkItem(claim)

        try await actor.confirmUpload(workItem, authorization: authorization)

        let persisted = try readStore(container)
        #expect(
            persisted.entries == [
                Self.persistedEntry(state: laterVisibleState, confirmedState: confirmedByServer)
            ]
        )
        #expect(persisted.operations.map(\.operationID) == [Self.operationA, Self.operationB])
        #expect(persisted.operations.map(\.state) == [.confirmed, .queued])
        #expect(persisted.operations.map(\.desiredState) == [confirmedByServer, laterVisibleState])
    }

    @Test("Confirming a tombstone removes its entry and retains the monotonic sequence cursor")
    func tombstoneConfirmationRetiresTheEntry() async throws(any Error) {
        let container = try makeContainer()
        let tombstone = Self.state(ownedVolumes: [1], isTombstone: true)
        try seed(
            container,
            entry: Self.entry(state: tombstone, confirmedState: Self.baseState),
            operations: [Self.operation(sequence: 4, desiredState: tombstone, state: .sending)]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let authorization = Self.authorization(for: Self.userA)
        let claim = try #require(try await actor.claimNextUpload(authorization: authorization))
        let workItem = try requireReconcileWorkItem(claim)

        let resolution = try await actor.resolveDeletion(workItem, evidence: .absent, authorization: authorization)

        let persisted = try readStore(container)
        #expect(resolution == .confirmed)
        #expect(persisted.entries.isEmpty)
        #expect(
            persisted.operations == [
                Self.persistedOperation(sequence: 4, desiredState: tombstone, state: .confirmed)
            ]
        )
    }

    @Test("Confirming delete N preserves a later visible N plus one and records remote absence")
    func tombstoneConfirmationPreservesLaterIntent() async throws(any Error) {
        let container = try makeContainer()
        let tombstone = Self.state(ownedVolumes: [1], isTombstone: true)
        let laterVisibleState = Self.state(ownedVolumes: [1, 2], readingVolume: 2)
        try seed(
            container,
            entry: Self.entry(state: laterVisibleState, confirmedState: Self.baseState),
            operations: [
                Self.operation(sequence: 4, desiredState: tombstone, state: .sending),
                Self.operation(operationID: Self.operationB, sequence: 5, desiredState: laterVisibleState)
            ]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let authorization = Self.authorization(for: Self.userA)
        let claim = try #require(try await actor.claimNextUpload(authorization: authorization))
        let workItem = try requireReconcileWorkItem(claim)

        let resolution = try await actor.resolveDeletion(workItem, evidence: .absent, authorization: authorization)

        let persisted = try readStore(container)
        #expect(resolution == .confirmed)
        #expect(persisted.entries == [Self.persistedEntry(state: laterVisibleState, confirmedState: nil)])
        #expect(persisted.operations.map(\.sequence) == [4, 5])
        #expect(persisted.operations.map(\.state) == [.confirmed, .queued])
    }

    @Test("Remote presence updates the deletion baseline and presentation before blocking")
    func tombstonePresenceIsPersistedAtomically() async throws(any Error) {
        let container = try makeContainer()
        let tombstone = Self.state(ownedVolumes: [1], isTombstone: true)
        let remoteState = Self.state(ownedVolumes: [2], readingVolume: 2)
        try seed(
            container,
            entry: Self.entry(state: tombstone, confirmedState: Self.baseState),
            operations: [Self.operation(sequence: 4, desiredState: tombstone, state: .sending)]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let authorization = Self.authorization(for: Self.userA)
        let claim = try #require(try await actor.claimNextUpload(authorization: authorization))
        let workItem = try requireReconcileWorkItem(claim)
        let evidence = CollectionDeletionEvidence.present(Self.remoteEntry(state: remoteState))

        let resolution = try await actor.resolveDeletion(workItem, evidence: evidence, authorization: authorization)

        let persisted = try readStore(container)
        #expect(resolution == .blockedOutcome)
        #expect(persisted.entries == [Self.persistedEntry(state: tombstone, confirmedState: remoteState)])
        #expect(persisted.operations.map(\.state) == [.blockedOutcome])

        let context = ModelContext(container)
        let entry = try #require(try context.fetch(FetchDescriptor<CollectionEntry>()).first)
        #expect(entry.mangaSnapshot?.title == "Remote Forty-Two")
    }

    @Test("Incompatible remote presence blocks a tombstone without adopting its values")
    func incompatibleTombstonePresenceIsNotAdopted() async throws(any Error) {
        let container = try makeContainer()
        let historicalState = Self.state(ownedVolumes: [1], readingVolume: 299, knownTotalVolumes: 301)
        let tombstone = Self.state(
            ownedVolumes: historicalState.ownedVolumes,
            readingVolume: historicalState.readingVolume,
            knownTotalVolumes: historicalState.knownTotalVolumes,
            isTombstone: true
        )
        try seed(
            container,
            entry: Self.entry(state: tombstone, confirmedState: Self.baseState),
            operations: [Self.operation(sequence: 4, desiredState: tombstone, state: .sending)]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let authorization = Self.authorization(for: Self.userA)
        let claim = try #require(try await actor.claimNextUpload(authorization: authorization))
        let workItem = try requireReconcileWorkItem(claim)
        let evidence = CollectionDeletionEvidence.present(Self.remoteEntry(state: historicalState))

        let resolution = try await actor.resolveDeletion(workItem, evidence: evidence, authorization: authorization)

        let persisted = try readStore(container)
        #expect(resolution == .blockedOutcome)
        #expect(persisted.entries == [Self.persistedEntry(state: tombstone, confirmedState: Self.baseState)])
        #expect(persisted.operations.map(\.state) == [.blockedOutcome])

        let context = ModelContext(container)
        let entry = try #require(try context.fetch(FetchDescriptor<CollectionEntry>()).first)
        #expect(entry.mangaSnapshot == nil)
    }

    @Test("Confirmation requires the exact operation UUID and sequence", arguments: StaleConfirmationIdentity.allCases)
    private func staleIdentityCannotConfirmPersistedWork(identity: StaleConfirmationIdentity) async throws(any Error) {
        let container = try makeContainer()
        let desiredState = Self.state(ownedVolumes: [1, 2], readingVolume: 2)
        try seed(
            container,
            entry: Self.entry(state: desiredState, confirmedState: Self.baseState),
            operations: [Self.operation(sequence: 1, desiredState: desiredState, state: .sending)]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let authorization = Self.authorization(for: Self.userA)
        let claim = try #require(try await actor.claimNextUpload(authorization: authorization))
        let currentWorkItem = try requireReconcileWorkItem(claim)
        let staleWorkItem = CollectionOutboxUploadWorkItem(
            operationID: identity == .operationID ? Self.operationB : currentWorkItem.operationID,
            userID: currentWorkItem.userID,
            mangaID: currentWorkItem.mangaID,
            sequence: identity == .sequence ? currentWorkItem.sequence + 1 : currentWorkItem.sequence,
            ownedVolumes: currentWorkItem.ownedVolumes,
            readingVolume: currentWorkItem.readingVolume,
            isComplete: currentWorkItem.isComplete,
            isTombstone: currentWorkItem.isTombstone
        )
        let before = try readStore(container)

        await #expect(throws: CollectionOutboxUploadError.staleOperation) {
            try await actor.confirmUpload(staleWorkItem, authorization: authorization)
        }

        #expect(try readStore(container) == before)
    }

    @Test("Blocking an uncertain upload preserves both visible and confirmed states")
    func blockedOutcomePreservesCollectionValues() async throws(any Error) {
        let container = try makeContainer()
        let visibleState = Self.state(ownedVolumes: [1, 2], readingVolume: 2)
        try seed(
            container,
            entry: Self.entry(state: visibleState, confirmedState: Self.baseState),
            operations: [Self.operation(sequence: 1, desiredState: visibleState, state: .sending)]
        )

        let actor = CollectionMutationActor(modelContainer: container)
        let authorization = Self.authorization(for: Self.userA)
        let claim = try #require(try await actor.claimNextUpload(authorization: authorization))
        let workItem = try requireReconcileWorkItem(claim)

        try await actor.blockUploadOutcome(workItem, authorization: authorization)
        #expect(try await actor.hasBlockedUploadOutcome(authorization: authorization))

        let persisted = try readStore(container)
        #expect(persisted.entries == [Self.persistedEntry(state: visibleState, confirmedState: Self.baseState)])
        #expect(
            persisted.operations == [
                Self.persistedOperation(sequence: 1, desiredState: visibleState, state: .blockedOutcome)
            ]
        )
    }

    private func makeContainer() throws(any Error) -> ModelContainer {
        try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
    }

    private func requireSendWorkItem(
        _ claim: CollectionOutboxUploadClaim
    ) throws(any Error) -> CollectionOutboxUploadWorkItem {
        guard case let .send(workItem) = claim else {
            Issue.record("Expected a newly claimed upload, but received reconciliation work")
            throw UnexpectedClaimError()
        }
        return workItem
    }

    private func requireReconcileWorkItem(
        _ claim: CollectionOutboxUploadClaim
    ) throws(any Error) -> CollectionOutboxUploadWorkItem {
        guard case let .reconcile(workItem) = claim else {
            Issue.record("Expected reconciliation work, but received a newly claimed upload")
            throw UnexpectedClaimError()
        }
        return workItem
    }

    private static func authorization(for userID: UUID) -> SessionCommitAuthorization {
        let authority = SessionAuthority(userID: userID, generation: generation)
        let gate = SessionCommitGate(activeAuthority: authority)
        return gate.authorization(for: authority)
    }

    private static func state(
        ownedVolumes: [Int64],
        readingVolume: Int64? = nil,
        isComplete: Bool = false,
        knownTotalVolumes: Int64? = 3,
        isTombstone: Bool = false
    ) -> CollectionSnapshot {
        CollectionSnapshot(
            ownedVolumes: ownedVolumes,
            readingVolume: readingVolume,
            isComplete: isComplete,
            knownTotalVolumes: knownTotalVolumes,
            isTombstone: isTombstone
        )
    }

    private static func entry(
        userID: UUID = userA,
        state: CollectionSnapshot,
        confirmedState: CollectionSnapshot?
    ) -> CollectionEntry {
        CollectionEntry(
            userID: userID,
            mangaID: mangaA,
            state: state,
            confirmedState: confirmedState
        )
    }

    private static func operation(
        operationID: UUID = operationA,
        userID: UUID = userA,
        sequence: Int64,
        desiredState: CollectionSnapshot,
        state: CollectionOutboxState = .queued
    ) -> CollectionOutboxOperation {
        CollectionOutboxOperation(
            operationID: operationID,
            userID: userID,
            mangaID: mangaA,
            sequence: sequence,
            desiredState: desiredState,
            state: state
        )
    }

    private static func remoteEntry(state: CollectionSnapshot) -> CollectionRemoteEntry {
        CollectionRemoteEntry(
            remoteID: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
            manga: Manga(
                id: mangaA,
                title: "Remote Forty-Two",
                titleEnglish: nil,
                titleJapanese: nil,
                synopsis: nil,
                score: 8,
                status: .publishing,
                authors: [],
                demographics: [],
                genres: [],
                themes: [],
                totalVolumes: state.knownTotalVolumes,
                coverURL: nil
            ),
            ownedVolumes: state.ownedVolumes,
            readingVolume: state.readingVolume,
            isComplete: state.isComplete
        )
    }

    private static func persistedEntry(
        userID: UUID = userA,
        state: CollectionSnapshot,
        confirmedState: CollectionSnapshot?
    ) -> PersistedEntry {
        PersistedEntry(
            userID: userID,
            mangaID: mangaA,
            state: state,
            confirmedState: confirmedState
        )
    }

    private static func persistedOperation(
        operationID: UUID = operationA,
        userID: UUID = userA,
        sequence: Int64,
        desiredState: CollectionSnapshot,
        state: CollectionOutboxState
    ) -> PersistedOperation {
        PersistedOperation(
            operationID: operationID,
            userID: userID,
            mangaID: mangaA,
            sequence: sequence,
            desiredState: desiredState,
            state: state
        )
    }

    private static let baseState = state(ownedVolumes: [])
    private static let userA = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let userB = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
    private static let generation = UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!
    private static let mangaA: Manga.ID = 42
    private static let operationA = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private static let operationB = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!
}

private enum InvalidUploadVolumeScenario: CaseIterable, CustomTestStringConvertible {
    case excessiveKnownTotal
    case extremeKnownTotal
    case excessiveUnknownTotalOwnedVolume
    case extremeUnknownTotalOwnedVolume
    case excessiveUnknownTotalReadingVolume
    case extremeUnknownTotalReadingVolume

    var state: CollectionSnapshot {
        switch self {
        case .excessiveKnownTotal:
            makeState(knownTotalVolumes: 301)
        case .extremeKnownTotal:
            makeState(knownTotalVolumes: .max)
        case .excessiveUnknownTotalOwnedVolume:
            makeState(ownedVolumes: [301], knownTotalVolumes: nil)
        case .extremeUnknownTotalOwnedVolume:
            makeState(ownedVolumes: [.max], knownTotalVolumes: nil)
        case .excessiveUnknownTotalReadingVolume:
            makeState(readingVolume: 301, knownTotalVolumes: nil)
        case .extremeUnknownTotalReadingVolume:
            makeState(readingVolume: .max, knownTotalVolumes: nil)
        }
    }

    var testDescription: String {
        switch self {
        case .excessiveKnownTotal: "known total 301"
        case .extremeKnownTotal: "known total Int64.max"
        case .excessiveUnknownTotalOwnedVolume: "owned volume 301 without total"
        case .extremeUnknownTotalOwnedVolume: "owned volume Int64.max without total"
        case .excessiveUnknownTotalReadingVolume: "reading volume 301 without total"
        case .extremeUnknownTotalReadingVolume: "reading volume Int64.max without total"
        }
    }

    private func makeState(
        ownedVolumes: [Int64] = [1],
        readingVolume: Int64? = nil,
        knownTotalVolumes: Int64?
    ) -> CollectionSnapshot {
        CollectionSnapshot(
            ownedVolumes: ownedVolumes,
            readingVolume: readingVolume,
            isComplete: false,
            knownTotalVolumes: knownTotalVolumes,
            isTombstone: false
        )
    }
}

private enum StaleConfirmationIdentity: CaseIterable {
    case operationID
    case sequence
}

private struct UnexpectedClaimError: Error {}

private struct PersistedStore: Equatable {
    let entries: [PersistedEntry]
    let operations: [PersistedOperation]
}

private struct PersistedEntry: Equatable {
    let userID: UUID
    let mangaID: Manga.ID
    let state: CollectionSnapshot
    let confirmedState: CollectionSnapshot?
}

private struct PersistedOperation: Equatable {
    let operationID: UUID
    let userID: UUID
    let mangaID: Manga.ID
    let sequence: Int64
    let desiredState: CollectionSnapshot
    let state: CollectionOutboxState
}

private func seed(
    _ container: ModelContainer,
    entry: CollectionEntry,
    operations: [CollectionOutboxOperation]
) throws(any Error) {
    let context = ModelContext(container)
    context.insert(entry)
    for operation in operations {
        context.insert(operation)
    }
    try context.save()
}

private func readStore(_ container: ModelContainer) throws(any Error) -> PersistedStore {
    let context = ModelContext(container)
    let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
    let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())

    return PersistedStore(
        entries: entries
            .map {
                PersistedEntry(
                    userID: $0.userID,
                    mangaID: $0.mangaID,
                    state: $0.state,
                    confirmedState: $0.confirmedState
                )
            }
            .sorted(by: persistedEntryOrder),
        operations: operations
            .map {
                PersistedOperation(
                    operationID: $0.operationID,
                    userID: $0.userID,
                    mangaID: $0.mangaID,
                    sequence: $0.sequence,
                    desiredState: $0.desiredState,
                    state: $0.state
                )
            }
            .sorted(by: persistedOperationOrder)
    )
}

private func persistedEntryOrder(_ lhs: PersistedEntry, _ rhs: PersistedEntry) -> Bool {
    if lhs.userID != rhs.userID {
        return lhs.userID.uuidString < rhs.userID.uuidString
    }
    return lhs.mangaID < rhs.mangaID
}

private func persistedOperationOrder(_ lhs: PersistedOperation, _ rhs: PersistedOperation) -> Bool {
    if lhs.userID != rhs.userID {
        return lhs.userID.uuidString < rhs.userID.uuidString
    }
    if lhs.mangaID != rhs.mangaID {
        return lhs.mangaID < rhs.mangaID
    }
    return lhs.sequence < rhs.sequence
}
