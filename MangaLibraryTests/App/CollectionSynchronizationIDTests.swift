//
//  CollectionSynchronizationIDTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("Collection synchronization identity", .tags(.fast))
struct CollectionSynchronizationIDTests {
    @Test("Resolving a durable block changes the shell synchronization identity")
    func resolvingBlockedOutcomeChangesIdentity() {
        let blocked = CollectionSynchronizationID(
            authority: Self.authority,
            operations: [Self.operation(state: .blockedOutcome), Self.laterOperation()]
        )
        let resolved = CollectionSynchronizationID(
            authority: Self.authority,
            operations: [Self.operation(state: .confirmed), Self.laterOperation()]
        )

        #expect(blocked != resolved)
    }

    @Test("Ordinary worker transitions do not restart shell synchronization")
    func ordinaryWorkerTransitionsKeepIdentity() {
        let queued = CollectionSynchronizationID(
            authority: Self.authority,
            operations: [Self.operation(state: .queued)]
        )
        let sending = CollectionSynchronizationID(
            authority: Self.authority,
            operations: [Self.operation(state: .sending)]
        )
        let confirmed = CollectionSynchronizationID(
            authority: Self.authority,
            operations: [Self.operation(state: .confirmed)]
        )

        #expect(queued == sending)
        #expect(sending == confirmed)
    }

    @Test("Repeated observation of the same durable block keeps one identity")
    func unchangedBlockedOutcomeKeepsIdentity() {
        let first = CollectionSynchronizationID(
            authority: Self.authority,
            operations: [Self.operation(state: .blockedOutcome)]
        )
        let second = CollectionSynchronizationID(
            authority: Self.authority,
            operations: [Self.operation(state: .blockedOutcome)]
        )

        #expect(first == second)
    }
}

private extension CollectionSynchronizationIDTests {
    static let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let authority = SessionAuthority(
        userID: userID,
        generation: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    )
    static let operationID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let laterOperationID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let state = CollectionSnapshot(
        ownedVolumes: [1],
        readingVolume: 1,
        isComplete: false,
        knownTotalVolumes: 3,
        isTombstone: false
    )

    static func operation(state operationState: CollectionOutboxState) -> CollectionOutboxOperation {
        CollectionOutboxOperation(
            operationID: operationID,
            userID: userID,
            mangaID: 42,
            sequence: 1,
            desiredState: state,
            state: operationState
        )
    }

    static func laterOperation() -> CollectionOutboxOperation {
        CollectionOutboxOperation(
            operationID: laterOperationID,
            userID: userID,
            mangaID: 42,
            sequence: 2,
            desiredState: state
        )
    }
}
