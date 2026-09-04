//
//  CollectionLogoutTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@Suite("Collection logout", .tags(.integration))
struct CollectionLogoutTests {
    @Test("Every unresolved outbox state blocks logout", arguments: LogoutOutboxScenario.all)
    private func unresolvedStateBlocksLogout(_ scenario: LogoutOutboxScenario) async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        try seed(
            container,
            entries: [Self.entry(state: Self.localState, confirmedState: Self.confirmedState)],
            operations: [
                Self.operation(
                    state: scenario.state,
                    retryCount: scenario.retryCount,
                    nextRetryAt: scenario.nextRetryAt
                )
            ]
        )
        let actor = CollectionMutationActor(modelContainer: container)
        let authorization = try Self.logoutAuthorization()

        let hasPendingChanges = try await actor.hasPendingChangesForLogout(authorization: authorization)

        #expect(hasPendingChanges == scenario.isPending)
    }

    @Test("Discard restores confirmed bases, removes optimistic additions and retains monotonic cursors")
    func discardRestoresEveryPendingPairAtomically() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let otherUserState = Self.state(ownedVolumes: [3], readingVolume: 3)
        try seed(
            container,
            entries: [
                Self.entry(state: Self.localState, confirmedState: Self.confirmedState),
                Self.entry(mangaID: Self.mangaB, state: Self.newLocalState, confirmedState: nil),
                Self.entry(userID: Self.userB, state: otherUserState, confirmedState: otherUserState),
            ],
            operations: [
                Self.operation(sequence: 1, desiredState: Self.confirmedState, state: .confirmed),
                Self.operation(
                    operationID: Self.operationB,
                    sequence: 2,
                    desiredState: Self.localState,
                    state: .blockedOutcome
                ),
                Self.operation(
                    operationID: Self.operationC,
                    mangaID: Self.mangaB,
                    sequence: 7,
                    desiredState: Self.newLocalState,
                    state: .retry,
                    retryCount: 4,
                    nextRetryAt: Self.retryDate
                ),
                Self.operation(
                    operationID: Self.operationD,
                    userID: Self.userB,
                    sequence: 5,
                    desiredState: otherUserState,
                    state: .queued
                ),
            ]
        )
        let actor = CollectionMutationActor(modelContainer: container)
        let gate = SessionCommitGate(activeAuthority: Self.authority)
        let authorization = try #require(gate.suspendForLogout(Self.authority))

        try await actor.discardPendingChangesForLogout(authorization: authorization)

        var persisted = try readStore(container)
        #expect(
            persisted.entries == [
                Self.persistedEntry(state: Self.confirmedState, confirmedState: Self.confirmedState),
                Self.persistedEntry(userID: Self.userB, state: otherUserState, confirmedState: otherUserState),
            ]
        )
        #expect(
            persisted.operations == [
                Self.persistedOperation(
                    operationID: Self.operationB,
                    sequence: 2,
                    desiredState: Self.localState,
                    state: .confirmed
                ),
                Self.persistedOperation(
                    operationID: Self.operationC,
                    mangaID: Self.mangaB,
                    sequence: 7,
                    desiredState: Self.newLocalState,
                    state: .confirmed
                ),
                Self.persistedOperation(
                    operationID: Self.operationD,
                    userID: Self.userB,
                    sequence: 5,
                    desiredState: otherUserState,
                    state: .queued
                ),
            ]
        )

        gate.activate(Self.authority)
        let result = try await actor.apply(
            CollectionMutationCommand(
                authority: Self.authority,
                mangaID: Self.mangaA,
                knownTotalVolumes: 4,
                change: .setReadingVolume(1)
            ),
            authorization: gate.authorization(for: Self.authority),
            newOperationID: Self.operationE
        )

        #expect(result.sequence == 3)
        persisted = try readStore(container)
        #expect(persisted.operations.first { $0.operationID == Self.operationE }?.sequence == 3)
    }

    @Test("A failure after restoring one pair rolls back the complete discard")
    func discardFailureRollsBackEveryPair() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        try seed(
            container,
            entries: [
                Self.entry(state: Self.localState, confirmedState: Self.confirmedState),
                Self.entry(mangaID: Self.mangaB, state: Self.newLocalState, confirmedState: nil),
            ],
            operations: [
                Self.operation(sequence: 1, desiredState: Self.localState, state: .queued),
                Self.operation(
                    operationID: Self.operationB,
                    mangaID: Self.mangaB,
                    sequence: 1,
                    desiredState: Self.newLocalState,
                    state: .blockedAuth
                ),
            ]
        )
        let before = try readStore(container)
        let actor = CollectionMutationActor(modelContainer: container)
        let authorization = try Self.logoutAuthorization()

        await #expect(throws: CollectionLogoutError.persistenceConflict) {
            try await actor.discardPendingChangesForLogout(
                authorization: authorization,
                afterRestoringPair: { restoredCount in
                    if restoredCount == 1 { throw LogoutInjectedFailure.expected }
                }
            )
        }

        #expect(try readStore(container) == before)
    }

    @Test("A stale logout capability cannot inspect or mutate another gate revision")
    func staleLogoutAuthorizationIsRejected() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        try seed(
            container,
            entries: [Self.entry(state: Self.localState, confirmedState: Self.confirmedState)],
            operations: [Self.operation(sequence: 1, desiredState: Self.localState, state: .queued)]
        )
        let before = try readStore(container)
        let actor = CollectionMutationActor(modelContainer: container)
        let gate = SessionCommitGate(activeAuthority: Self.authority)
        let staleAuthorization = try #require(gate.suspendForLogout(Self.authority))
        gate.activate(Self.authority)
        _ = try #require(gate.suspendForLogout(Self.authority))

        await #expect(throws: CollectionLogoutError.sessionChanged) {
            try await actor.hasPendingChangesForLogout(authorization: staleAuthorization)
        }
        await #expect(throws: CollectionLogoutError.sessionChanged) {
            try await actor.discardPendingChangesForLogout(authorization: staleAuthorization)
        }

        #expect(try readStore(container) == before)
    }

    @Test("Cancellation after restoring one pair rolls back the complete discard")
    func discardCancellationRollsBackEveryPair() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        try seed(
            container,
            entries: [
                Self.entry(state: Self.localState, confirmedState: Self.confirmedState),
                Self.entry(mangaID: Self.mangaB, state: Self.newLocalState, confirmedState: nil),
            ],
            operations: [
                Self.operation(sequence: 1, desiredState: Self.localState, state: .queued),
                Self.operation(
                    operationID: Self.operationB,
                    mangaID: Self.mangaB,
                    sequence: 1,
                    desiredState: Self.newLocalState,
                    state: .blockedAuth
                ),
            ]
        )
        let before = try readStore(container)
        let actor = CollectionMutationActor(modelContainer: container)
        let authorization = try Self.logoutAuthorization()

        await #expect(throws: CollectionLogoutError.cancelled) {
            try await actor.discardPendingChangesForLogout(
                authorization: authorization,
                afterRestoringPair: { restoredCount in
                    if restoredCount == 1 { throw CancellationError() }
                }
            )
        }

        #expect(try readStore(container) == before)
    }

    private static func logoutAuthorization() throws(any Error) -> SessionLogoutAuthorization {
        let gate = SessionCommitGate(activeAuthority: authority)
        return try #require(gate.suspendForLogout(authority))
    }

    private static func state(
        ownedVolumes: [Int64],
        readingVolume: Int64? = nil,
        isTombstone: Bool = false
    ) -> CollectionSnapshot {
        CollectionSnapshot(
            ownedVolumes: ownedVolumes,
            readingVolume: readingVolume,
            isComplete: false,
            knownTotalVolumes: 4,
            isTombstone: isTombstone
        )
    }

    private static func entry(
        userID: UUID = userA,
        mangaID: Manga.ID = mangaA,
        state: CollectionSnapshot,
        confirmedState: CollectionSnapshot?
    ) -> CollectionEntry {
        CollectionEntry(
            userID: userID,
            mangaID: mangaID,
            state: state,
            confirmedState: confirmedState
        )
    }

    private static func operation(
        operationID: UUID = operationA,
        userID: UUID = userA,
        mangaID: Manga.ID = mangaA,
        sequence: Int64 = 1,
        desiredState: CollectionSnapshot = localState,
        state: CollectionOutboxState,
        retryCount: Int = 0,
        nextRetryAt: Date? = nil
    ) -> CollectionOutboxOperation {
        CollectionOutboxOperation(
            operationID: operationID,
            userID: userID,
            mangaID: mangaID,
            sequence: sequence,
            desiredState: desiredState,
            state: state,
            retryCount: retryCount,
            nextRetryAt: nextRetryAt
        )
    }

    private static func persistedEntry(
        userID: UUID = userA,
        mangaID: Manga.ID = mangaA,
        state: CollectionSnapshot,
        confirmedState: CollectionSnapshot?
    ) -> LogoutPersistedEntry {
        LogoutPersistedEntry(
            userID: userID,
            mangaID: mangaID,
            state: state,
            confirmedState: confirmedState
        )
    }

    private static func persistedOperation(
        operationID: UUID,
        userID: UUID = userA,
        mangaID: Manga.ID = mangaA,
        sequence: Int64,
        desiredState: CollectionSnapshot,
        state: CollectionOutboxState
    ) -> LogoutPersistedOperation {
        LogoutPersistedOperation(
            operationID: operationID,
            userID: userID,
            mangaID: mangaID,
            sequence: sequence,
            desiredState: desiredState,
            state: state,
            retryCount: 0,
            nextRetryAt: nil
        )
    }

    private static let userA = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let userB = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
    private static let generation = UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!
    private static let authority = SessionAuthority(userID: userA, generation: generation)
    private static let mangaA: Manga.ID = 42
    private static let mangaB: Manga.ID = 84
    private static let operationA = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private static let operationB = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!
    private static let operationC = UUID(uuidString: "CCCCCCCC-DDDD-EEEE-FFFF-AAAAAAAAAAAA")!
    private static let operationD = UUID(uuidString: "DDDDDDDD-EEEE-FFFF-AAAA-BBBBBBBBBBBB")!
    private static let operationE = UUID(uuidString: "EEEEEEEE-FFFF-AAAA-BBBB-CCCCCCCCCCCC")!
    private static let retryDate = Date(timeIntervalSince1970: 1_800_000_030)
    private static let confirmedState = state(ownedVolumes: [1], readingVolume: 1)
    private static let localState = state(ownedVolumes: [1, 2], readingVolume: 2)
    private static let newLocalState = state(ownedVolumes: [4], readingVolume: 4)
}

private struct LogoutOutboxScenario: CustomTestStringConvertible {
    let testDescription: String
    let state: CollectionOutboxState
    let retryCount: Int
    let nextRetryAt: Date?
    let isPending: Bool

    static let all = [
        Self(testDescription: "queued", state: .queued, retryCount: 0, nextRetryAt: nil, isPending: true),
        Self(testDescription: "sending", state: .sending, retryCount: 0, nextRetryAt: nil, isPending: true),
        Self(
            testDescription: "retry",
            state: .retry,
            retryCount: 2,
            nextRetryAt: Date(timeIntervalSince1970: 1_800_000_030),
            isPending: true
        ),
        Self(testDescription: "blockedAuth", state: .blockedAuth, retryCount: 0, nextRetryAt: nil, isPending: true),
        Self(
            testDescription: "blockedOutcome",
            state: .blockedOutcome,
            retryCount: 0,
            nextRetryAt: nil,
            isPending: true
        ),
        Self(testDescription: "rejected", state: .rejected, retryCount: 0, nextRetryAt: nil, isPending: true),
        Self(testDescription: "confirmed", state: .confirmed, retryCount: 0, nextRetryAt: nil, isPending: false),
    ]
}

private enum LogoutInjectedFailure: Error {
    case expected
}

private struct LogoutPersistedStore: Equatable {
    let entries: [LogoutPersistedEntry]
    let operations: [LogoutPersistedOperation]
}

private struct LogoutPersistedEntry: Equatable {
    let userID: UUID
    let mangaID: Manga.ID
    let state: CollectionSnapshot
    let confirmedState: CollectionSnapshot?
}

private struct LogoutPersistedOperation: Equatable {
    let operationID: UUID
    let userID: UUID
    let mangaID: Manga.ID
    let sequence: Int64
    let desiredState: CollectionSnapshot
    let state: CollectionOutboxState
    let retryCount: Int
    let nextRetryAt: Date?
}

private func seed(
    _ container: ModelContainer,
    entries: [CollectionEntry],
    operations: [CollectionOutboxOperation]
) throws(any Error) {
    let context = ModelContext(container)
    for entry in entries {
        context.insert(entry)
    }
    for operation in operations {
        context.insert(operation)
    }
    try context.save()
}

private func readStore(_ container: ModelContainer) throws(any Error) -> LogoutPersistedStore {
    let context = ModelContext(container)
    let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
    let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())

    return LogoutPersistedStore(
        entries: entries
            .map {
                LogoutPersistedEntry(
                    userID: $0.userID,
                    mangaID: $0.mangaID,
                    state: $0.state,
                    confirmedState: $0.confirmedState
                )
            }
            .sorted { ($0.userID.uuidString, $0.mangaID) < ($1.userID.uuidString, $1.mangaID) },
        operations: operations
            .map {
                LogoutPersistedOperation(
                    operationID: $0.operationID,
                    userID: $0.userID,
                    mangaID: $0.mangaID,
                    sequence: $0.sequence,
                    desiredState: $0.desiredState,
                    state: $0.state,
                    retryCount: $0.retryCount,
                    nextRetryAt: $0.nextRetryAt
                )
            }
            .sorted { lhs, rhs in
                (lhs.userID.uuidString, lhs.mangaID, lhs.sequence)
                    < (rhs.userID.uuidString, rhs.mangaID, rhs.sequence)
            }
    )
}
