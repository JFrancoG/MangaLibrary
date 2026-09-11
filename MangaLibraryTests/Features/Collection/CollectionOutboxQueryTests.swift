//
//  CollectionOutboxQueryTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@Suite("Collection outbox query", .tags(.integration))
struct CollectionOutboxQueryTests {
    @Test("Changing the query scope fetches only that user's complete outbox")
    func accountChangesScopeTheFetch() throws {
        let container = try makeStore()
        let context = ModelContext(container)

        let userAOperations = try fetch(userID: Self.userA, context: context)
        let userBOperations = try fetch(userID: Self.userB, context: context)
        let signedOutOperations = try fetch(userID: nil, context: context)
        let restoredOperations = try fetch(userID: Self.userA, context: context)

        #expect(userAOperations.map(\.mangaID).sorted() == [42, 84])
        #expect(userAOperations.allSatisfy { $0.userID == Self.userA })
        #expect(userAOperations.contains { $0.state == .confirmed })
        #expect(userAOperations.contains { $0.state == .blockedOutcome })
        #expect(userBOperations.map(\.mangaID).sorted() == [42, 126])
        #expect(userBOperations.allSatisfy { $0.userID == Self.userB })
        #expect(userBOperations.contains { $0.state == .queued })
        #expect(userBOperations.contains { $0.state == .confirmed })
        #expect(signedOutOperations.isEmpty)
        #expect(Set(restoredOperations.map(\.operationID)) == Set(userAOperations.map(\.operationID)))
    }

    @Test("Durable notices and synchronization follow the scoped store and session authority")
    func scopedChangesDriveNoticeAndSynchronization() throws {
        let container = try makeStore()
        let authorityA = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let authorityB = SessionAuthority(userID: Self.userB, generation: Self.generationA)
        let renewedAuthorityA = SessionAuthority(userID: Self.userA, generation: Self.generationB)
        let initialContext = ModelContext(container)
        let initialA = try fetch(userID: Self.userA, context: initialContext)
        let initialB = try fetch(userID: Self.userB, context: initialContext)
        let initialIdentity = CollectionSynchronizationID(authority: authorityA, operations: initialA)

        #expect(AccountCollectionNotice.persistedUploadOutcome(userID: Self.userA, operations: initialA)?.reason
            == .uploadOutcomeUnconfirmed)
        #expect(AccountCollectionNotice.persistedUploadOutcome(userID: Self.userB, operations: initialB) == nil)
        #expect(initialIdentity != CollectionSynchronizationID(authority: authorityB, operations: initialB))
        #expect(initialIdentity != CollectionSynchronizationID(authority: renewedAuthorityA, operations: initialA))
        let signedOut = try fetch(userID: nil, context: initialContext)
        #expect(AccountCollectionNotice.persistedUploadOutcome(userID: nil, operations: signedOut) == nil)
        #expect(initialIdentity != CollectionSynchronizationID(authority: nil, operations: signedOut))

        let writer = ModelContext(container)
        let otherUserOperation = try #require(fetch(userID: Self.userB, context: writer).first { $0.mangaID == 42 })
        try #require(otherUserOperation.markSendingIfQueued())
        try #require(otherUserOperation.markBlockedOutcomeIfSending())
        try writer.save()

        let afterOtherUserChange = try fetch(userID: Self.userA, context: ModelContext(container))
        #expect(CollectionSynchronizationID(authority: authorityA, operations: afterOtherUserChange) == initialIdentity)
        #expect(AccountCollectionNotice.persistedUploadOutcome(
            userID: Self.userA, operations: afterOtherUserChange
        )?.reason == .uploadOutcomeUnconfirmed)

        let blocked = try #require(fetch(userID: Self.userA, context: writer).first { $0.state == .blockedOutcome })
        try #require(blocked.markConfirmedIfBlockedOutcome())
        try writer.save()

        let resolved = try fetch(userID: Self.userA, context: ModelContext(container))
        #expect(resolved.count == 2)
        #expect(resolved.allSatisfy { $0.state == .confirmed })
        #expect(AccountCollectionNotice.persistedUploadOutcome(userID: Self.userA, operations: resolved) == nil)
        #expect(CollectionSynchronizationID(authority: authorityA, operations: resolved) != initialIdentity)
        let unchanged = try fetch(userID: Self.userA, context: ModelContext(container))
        #expect(CollectionSynchronizationID(authority: authorityA, operations: unchanged)
            == CollectionSynchronizationID(authority: authorityA, operations: resolved))
    }

    @Test("Refetching ordinary worker transitions keeps one synchronization task identity")
    func workerTransitionsKeepTheFetchedIdentity() throws {
        let container = try makeStore()
        let authority = SessionAuthority(userID: Self.userB, generation: Self.generationA)
        let initial = try fetch(userID: Self.userB, context: ModelContext(container))
        let identity = CollectionSynchronizationID(authority: authority, operations: initial)
        let writer = ModelContext(container)
        let operation = try #require(fetch(userID: Self.userB, context: writer).first { $0.state == .queued })

        try #require(operation.markSendingIfQueued())
        try writer.save()

        let sending = try fetch(userID: Self.userB, context: ModelContext(container))
        #expect(sending.contains { $0.state == .sending })
        #expect(CollectionSynchronizationID(authority: authority, operations: sending) == identity)

        try #require(operation.markConfirmedIfSending())
        try writer.save()

        let confirmed = try fetch(userID: Self.userB, context: ModelContext(container))
        #expect(confirmed.count == 2)
        #expect(confirmed.allSatisfy { $0.state == .confirmed })
        #expect(CollectionSynchronizationID(authority: authority, operations: confirmed) == identity)
    }
}

private extension CollectionOutboxQueryTests {
    static let userA = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let userB = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let generationA = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let generationB = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    func fetch(userID: UUID?, context: ModelContext) throws -> [CollectionOutboxOperation] {
        try context.fetch(FetchDescriptor(predicate: CollectionOutboxOperation.userPredicate(userID: userID)))
    }

    func makeStore() throws -> ModelContainer {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let snapshot = CollectionSnapshot(
            ownedVolumes: [1], readingVolume: 1, isComplete: false, knownTotalVolumes: 3, isTombstone: false
        )
        let rows: [(UUID, Manga.ID, CollectionOutboxState)] = [
            (Self.userA, 42, .blockedOutcome),
            (Self.userA, 84, .confirmed),
            (Self.userB, 42, .queued),
            (Self.userB, 126, .confirmed)
        ]
        for (index, row) in rows.enumerated() {
            let operationID = UUID(uuidString: "55555555-5555-5555-5555-55555555555\(index)")!
            context.insert(CollectionOutboxOperation(
                operationID: operationID,
                userID: row.0,
                mangaID: row.1,
                sequence: Int64(index + 1),
                desiredState: snapshot,
                state: row.2
            ))
        }
        try context.save()
        return container
    }
}
