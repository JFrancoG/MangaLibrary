//
//  CollectionRemoteImportTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@Suite("Remote Collection import", .tags(.integration))
struct CollectionRemoteImportTests {
    @Test("A later queued intent stays visible while the confirmed base and offline manga advance")
    func queuedIntentSurvivesNewerRemoteBase() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        try await actor.importRemote(
            [remoteEntry(mangaID: 42, title: "Remote base one", ownedVolumes: [1], readingVolume: 1)],
            authorization: Self.authorization(for: Self.userID)
        )
        let localResult = try await actor.apply(
            CollectionMutationCommand(
                authority: Self.authority(for: Self.userID),
                mangaID: 42,
                knownTotalVolumes: 3,
                change: .replaceState(ownedVolumes: [1, 2], readingVolume: 2, isComplete: false)
            ),
            newOperationID: Self.operationID
        )

        try await actor.importRemote(
            [remoteEntry(mangaID: 42, title: "Remote base two", ownedVolumes: [3], readingVolume: 3)],
            authorization: Self.authorization(for: Self.userID)
        )

        let store = try readRemoteStore(container)
        let entry = try #require(store.entries.first)
        let operation = try #require(store.operations.first)
        let expectedConfirmedState = CollectionSnapshot(
            ownedVolumes: [3],
            readingVolume: 3,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )

        #expect(store.entries.count == 1)
        #expect(entry.state == localResult.state)
        #expect(entry.confirmedState == expectedConfirmedState)
        #expect(entry.mangaTitle == "Remote base two")
        #expect(store.operations.count == 1)
        #expect(operation.operationID == Self.operationID)
        #expect(operation.desiredState == localResult.state)
        #expect(operation.state == .queued)
    }

    @Test("An empty snapshot removes a safe confirmation but preserves a later local intent")
    func emptySnapshotRemovesOnlySafeConfirmedEntries() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        try await actor.importRemote(
            [
                remoteEntry(mangaID: 42, title: "Safe remote", ownedVolumes: [1], readingVolume: nil),
                remoteEntry(mangaID: 84, title: "Pending remote", ownedVolumes: [1], readingVolume: nil)
            ],
            authorization: Self.authorization(for: Self.userID)
        )
        let localResult = try await actor.apply(
            CollectionMutationCommand(
                authority: Self.authority(for: Self.userID),
                mangaID: 84,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1, 2])
            ),
            newOperationID: Self.operationID
        )

        try await actor.importRemote([], authorization: Self.authorization(for: Self.userID))

        let store = try readRemoteStore(container)
        let remainingEntry = try #require(store.entries.first)
        let remainingOperation = try #require(store.operations.first)

        #expect(store.entries.map(\.mangaID) == [84])
        #expect(remainingEntry.state == localResult.state)
        #expect(remainingEntry.confirmedState == nil)
        #expect(store.operations.count == 1)
        #expect(remainingOperation.mangaID == 84)
        #expect(remainingOperation.desiredState == localResult.state)
    }

    @Test("An invalid or duplicate remote batch rolls back every candidate", arguments: RejectedRemoteBatch.allCases)
    func rejectedBatchPreservesThePriorStore(_ rejectedBatch: RejectedRemoteBatch) async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        try await actor.importRemote(
            [remoteEntry(mangaID: 42, title: "Committed base", ownedVolumes: [1], readingVolume: nil)],
            authorization: Self.authorization(for: Self.userID)
        )
        let priorStore = try readRemoteStore(container)

        await #expect(throws: rejectedBatch.expectedError) {
            try await actor.importRemote(rejectedBatch.entries, authorization: Self.authorization(for: Self.userID))
        }

        #expect(try readRemoteStore(container) == priorStore)
    }

    @Test("A failure after the first candidate rolls the complete transaction back")
    func failureAfterPartialMutationRestoresThePriorStore() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        try await actor.importRemote(
            [remoteEntry(mangaID: 42, title: "Committed base", ownedVolumes: [1], readingVolume: nil)],
            authorization: Self.authorization(for: Self.userID)
        )
        let priorStore = try readRemoteStore(container)

        await #expect(throws: CollectionRemoteImportError.persistenceConflict) {
            try await actor.importRemote(
                [
                    remoteEntry(mangaID: 42, title: "Would update", ownedVolumes: [2], readingVolume: 2),
                    remoteEntry(mangaID: 84, title: "Would insert", ownedVolumes: [1], readingVolume: nil),
                ],
                authorization: Self.authorization(for: Self.userID),
                afterMutation: { mutationCount in
                    if mutationCount == 1 { throw InjectedRemoteImportFailure() }
                }
            )
        }

        #expect(try readRemoteStore(container) == priorStore)
    }

    @Test("Cancellation after the first mutation rolls the complete transaction back")
    func cancellationAfterPartialMutationRestoresThePriorStore() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        try await actor.importRemote(
            [remoteEntry(mangaID: 42, title: "Committed base", ownedVolumes: [1], readingVolume: nil)],
            authorization: Self.authorization(for: Self.userID)
        )
        let priorStore = try readRemoteStore(container)
        let operation = Task {
            try await actor.importRemote(
                [remoteEntry(mangaID: 42, title: "Cancelled update", ownedVolumes: [2], readingVolume: 2)],
                authorization: Self.authorization(for: Self.userID),
                afterMutation: { mutationCount in
                    if mutationCount == 1 {
                        withUnsafeCurrentTask { task in task?.cancel() }
                    }
                }
            )
        }

        await #expect(throws: CollectionRemoteImportError.cancelled) {
            try await operation.value
        }
        #expect(try readRemoteStore(container) == priorStore)
    }

    @Test("A local orphan makes the complete snapshot fail closed without partial mutation")
    func orphanedLocalEntryRejectsTheSnapshot() async throws(any Error) {
        let container = try makeContainer()
        let context = ModelContext(container)
        let orphanState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: nil,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        context.insert(
            CollectionEntry(
                userID: Self.userID,
                mangaID: 42,
                state: orphanState,
                confirmedState: nil,
                mangaSnapshot: CollectionMangaSnapshot(
                    manga: Self.remoteEntry(
                        remoteID: UUID(),
                        mangaID: 42,
                        title: "Local orphan",
                        ownedVolumes: [1],
                        readingVolume: nil
                    ).manga
                )
            )
        )
        try context.save()
        let priorStore = try readRemoteStore(container)
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionRemoteImportError.orphanedLocalEntry(42)) {
            try await actor.importRemote(
                [remoteEntry(mangaID: 84, title: "Would be inserted", ownedVolumes: [1], readingVolume: nil)],
                authorization: Self.authorization(for: Self.userID)
            )
        }

        #expect(try readRemoteStore(container) == priorStore)
    }

    @Test("Importing one user never changes another user's collection")
    func importRemainsIsolatedByUser() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        try await actor.importRemote(
            [remoteEntry(mangaID: 42, title: "User A", ownedVolumes: [1], readingVolume: nil)],
            authorization: Self.authorization(for: Self.userID)
        )
        try await actor.importRemote(
            [remoteEntry(mangaID: 84, title: "User B", ownedVolumes: [2], readingVolume: 2)],
            authorization: Self.authorization(for: Self.userB)
        )

        try await actor.importRemote([], authorization: Self.authorization(for: Self.userID))

        let store = try readRemoteStore(container)
        let entry = try #require(store.entries.first)
        #expect(store.entries.count == 1)
        #expect(entry.userID == Self.userB)
        #expect(entry.mangaID == 84)
        #expect(entry.mangaTitle == "User B")
        #expect(store.operations.isEmpty)
    }

    @Test("An authorization from session A cannot mutate the store after session B activates")
    func staleGenerationCannotMutateTheNewSession() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        let authorityA = SessionAuthority(userID: Self.userID, generation: UUID())
        let authorityB = SessionAuthority(userID: Self.userB, generation: UUID())
        let commitGate = SessionCommitGate(activeAuthority: authorityA)
        let authorizationA = commitGate.authorization(for: authorityA)
        commitGate.activate(authorityB)
        try await actor.importRemote(
            [remoteEntry(mangaID: 84, title: "User B", ownedVolumes: [2], readingVolume: 2)],
            authorization: commitGate.authorization(for: authorityB)
        )
        let priorStore = try readRemoteStore(container)

        await #expect(throws: CollectionRemoteImportError.sessionChanged) {
            try await actor.importRemote(
                [remoteEntry(mangaID: 42, title: "Stale user A", ownedVolumes: [1], readingVolume: nil)],
                authorization: authorizationA
            )
        }

        #expect(try readRemoteStore(container) == priorStore)
        #expect(priorStore.entries.map(\.userID) == [Self.userB])
    }

    @Test(
        "Only a confirmed outbox stops owning the optimistic state",
        arguments: [
            CollectionOutboxState.queued,
            .sending,
            .retry,
            .blockedAuth,
            .blockedOutcome,
            .rejected,
            .confirmed,
        ]
    )
    func outboxStateClassifiesPendingIntent(_ outboxState: CollectionOutboxState) async throws(any Error) {
        let container = try makeContainer()
        let context = ModelContext(container)
        let confirmedState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: 1,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        let localState = CollectionSnapshot(
            ownedVolumes: [1, 2],
            readingVolume: 2,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: true
        )
        let localManga = Self.remoteEntry(
            remoteID: UUID(),
            mangaID: 42,
            title: "Local presentation",
            ownedVolumes: [1],
            readingVolume: nil
        ).manga
        context.insert(
            CollectionEntry(
                userID: Self.userID,
                mangaID: 42,
                state: localState,
                confirmedState: confirmedState,
                mangaSnapshot: CollectionMangaSnapshot(manga: localManga)
            )
        )
        context.insert(
            CollectionOutboxOperation(
                operationID: Self.operationID,
                userID: Self.userID,
                mangaID: 42,
                sequence: 7,
                desiredState: localState,
                state: outboxState,
                retryCount: 3,
                nextRetryAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
        try context.save()
        let priorOperation = try #require(readRemoteStore(container).operations.first)
        let actor = CollectionMutationActor(modelContainer: container)

        try await actor.importRemote(
            [remoteEntry(mangaID: 42, title: "New remote presentation", ownedVolumes: [3], readingVolume: 3)],
            authorization: Self.authorization(for: Self.userID)
        )

        let store = try readRemoteStore(container)
        let entry = try #require(store.entries.first)
        let expectedRemoteState = CollectionSnapshot(
            ownedVolumes: [3],
            readingVolume: 3,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        #expect(entry.state == (outboxState == .confirmed ? expectedRemoteState : localState))
        #expect(entry.confirmedState == expectedRemoteState)
        #expect(entry.mangaTitle == "New remote presentation")
        #expect(store.operations == [priorOperation])
    }

    @Test("A complete remote collection canonicalizes the full known range")
    func completeRemoteCollectionUsesTheFullRange() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)

        try await actor.importRemote(
            [
                Self.remoteEntry(
                    remoteID: UUID(),
                    mangaID: 42,
                    title: "Complete remote",
                    ownedVolumes: [3, 1, 3],
                    readingVolume: 2,
                    isComplete: true
                )
            ],
            authorization: Self.authorization(for: Self.userID)
        )

        let entry = try #require(readRemoteStore(container).entries.first)
        #expect(
            entry.state
                == CollectionSnapshot(
                    ownedVolumes: [1, 2, 3],
                    readingVolume: 2,
                    isComplete: true,
                    knownTotalVolumes: 3,
                    isTombstone: false
                )
        )
        #expect(entry.confirmedState == entry.state)
    }

    @Test("A complete remote collection without a known total rejects the whole snapshot")
    func completeRemoteCollectionRequiresKnownTotal() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        let invalid = Self.remoteEntry(
            remoteID: UUID(),
            mangaID: 42,
            title: "Invalid complete remote",
            ownedVolumes: [1],
            readingVolume: nil,
            totalVolumes: nil,
            isComplete: true
        )

        await #expect(throws: CollectionRemoteImportError.completeRequiresKnownTotal) {
            try await actor.importRemote([invalid], authorization: Self.authorization(for: Self.userID))
        }
        #expect(try readRemoteStore(container).entries.isEmpty)
        #expect(try readRemoteStore(container).operations.isEmpty)
    }

    @Test("Cancellation before the transaction preserves the prior remote snapshot")
    func cancellationPreservesThePriorStore() async throws(any Error) {
        let container = try makeContainer()
        let actor = CollectionMutationActor(modelContainer: container)
        try await actor.importRemote(
            [remoteEntry(mangaID: 42, title: "Committed base", ownedVolumes: [1], readingVolume: nil)],
            authorization: Self.authorization(for: Self.userID)
        )
        let priorStore = try readRemoteStore(container)
        let gate = RemoteImportStartGate()
        let operation = Task {
            await gate.suspendUntilOpen()
            try await actor.importRemote(
                [remoteEntry(mangaID: 42, title: "Cancelled update", ownedVolumes: [2], readingVolume: 2)],
                authorization: Self.authorization(for: Self.userID)
            )
        }
        await gate.waitUntilArrived()

        operation.cancel()
        await gate.open()

        await #expect(throws: CollectionRemoteImportError.cancelled) { try await operation.value }
        #expect(try readRemoteStore(container) == priorStore)
    }

    private func makeContainer() throws(any Error) -> ModelContainer {
        try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
    }

    private static func authorization(for userID: UUID) -> SessionCommitAuthorization {
        let authority = authority(for: userID)
        let gate = SessionCommitGate(activeAuthority: authority)
        return gate.authorization(for: authority)
    }

    private static func authority(for userID: UUID) -> SessionAuthority {
        SessionAuthority(userID: userID, generation: UUID(uuidString: "C011EC71-0000-0000-0000-000000000001")!)
    }

    private func remoteEntry(
        mangaID: Manga.ID,
        title: String,
        ownedVolumes: [Int64],
        readingVolume: Int64?
    ) -> CollectionRemoteEntry {
        Self.remoteEntry(
            remoteID: UUID(),
            mangaID: mangaID,
            title: title,
            ownedVolumes: ownedVolumes,
            readingVolume: readingVolume
        )
    }

    fileprivate static func remoteEntry(
        remoteID: UUID,
        mangaID: Manga.ID,
        title: String,
        ownedVolumes: [Int64],
        readingVolume: Int64?,
        totalVolumes: Int64? = 3,
        isComplete: Bool = false
    ) -> CollectionRemoteEntry {
        CollectionRemoteEntry(
            remoteID: remoteID,
            manga: Manga(
                id: mangaID,
                title: title,
                titleEnglish: nil,
                titleJapanese: nil,
                synopsis: "Remote fixture",
                score: 8,
                status: .publishing,
                authors: [],
                demographics: [],
                genres: [],
                themes: [],
                totalVolumes: totalVolumes,
                coverURL: nil
            ),
            ownedVolumes: ownedVolumes,
            readingVolume: readingVolume,
            isComplete: isComplete
        )
    }

    private static let userID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let userB = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
    private static let operationID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
}

enum RejectedRemoteBatch: CaseIterable, CustomTestStringConvertible {
    case invalidIdentity
    case nonPositiveVolume
    case nonPositiveReadingVolume
    case invalidVolume
    case duplicateManga

    var entries: [CollectionRemoteEntry] {
        switch self {
        case .invalidIdentity:
            [
                CollectionRemoteImportTests.remoteEntry(
                    remoteID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    mangaID: 0,
                    title: "Invalid identity",
                    ownedVolumes: [1],
                    readingVolume: nil
                )
            ]
        case .nonPositiveVolume:
            [
                CollectionRemoteImportTests.remoteEntry(
                    remoteID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    mangaID: 84,
                    title: "Invalid nonpositive volume",
                    ownedVolumes: [0],
                    readingVolume: nil
                )
            ]
        case .nonPositiveReadingVolume:
            [
                CollectionRemoteImportTests.remoteEntry(
                    remoteID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                    mangaID: 84,
                    title: "Invalid nonpositive reading volume",
                    ownedVolumes: [1],
                    readingVolume: 0
                )
            ]
        case .invalidVolume:
            [
                CollectionRemoteImportTests.remoteEntry(
                    remoteID: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                    mangaID: 42,
                    title: "Would update",
                    ownedVolumes: [2],
                    readingVolume: nil
                ),
                CollectionRemoteImportTests.remoteEntry(
                    remoteID: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                    mangaID: 84,
                    title: "Invalid candidate",
                    ownedVolumes: [4],
                    readingVolume: nil
                )
            ]
        case .duplicateManga:
            [
                CollectionRemoteImportTests.remoteEntry(
                    remoteID: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
                    mangaID: 42,
                    title: "Duplicate one",
                    ownedVolumes: [1],
                    readingVolume: nil
                ),
                CollectionRemoteImportTests.remoteEntry(
                    remoteID: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
                    mangaID: 42,
                    title: "Duplicate two",
                    ownedVolumes: [2],
                    readingVolume: nil
                )
            ]
        }
    }

    var expectedError: CollectionRemoteImportError {
        switch self {
        case .invalidIdentity:
            .invalidIdentity
        case .nonPositiveVolume:
            .nonPositiveVolume(0)
        case .nonPositiveReadingVolume:
            .nonPositiveVolume(0)
        case .invalidVolume:
            .volumeExceedsKnownTotal(volume: 4, total: 3)
        case .duplicateManga:
            .duplicateMangaID(42)
        }
    }

    var testDescription: String {
        switch self {
        case .invalidIdentity: "invalid identity"
        case .nonPositiveVolume: "nonpositive volume"
        case .nonPositiveReadingVolume: "nonpositive reading volume"
        case .invalidVolume: "invalid volume"
        case .duplicateManga: "duplicate manga"
        }
    }
}

private struct InjectedRemoteImportFailure: Error {}

private struct RemotePersistedStore: Equatable {
    let entries: [RemotePersistedEntry]
    let operations: [RemotePersistedOperation]
}

private struct RemotePersistedEntry: Equatable {
    let userID: UUID
    let mangaID: Manga.ID
    let state: CollectionSnapshot
    let confirmedState: CollectionSnapshot?
    let mangaTitle: String?
}

private struct RemotePersistedOperation: Equatable {
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

private func readRemoteStore(_ container: ModelContainer) throws(any Error) -> RemotePersistedStore {
    let context = ModelContext(container)
    let entries = try context.fetch(FetchDescriptor<CollectionEntry>(sortBy: [SortDescriptor(\.mangaID)]))
    let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>(sortBy: [SortDescriptor(\.mangaID)]))

    return RemotePersistedStore(
        entries: entries.map {
            RemotePersistedEntry(
                userID: $0.userID,
                mangaID: $0.mangaID,
                state: $0.state,
                confirmedState: $0.confirmedState,
                mangaTitle: $0.mangaSnapshot?.title
            )
        },
        operations: operations.map {
            RemotePersistedOperation(
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
    )
}

private actor RemoteImportStartGate {
    private var arrived = false
    private var isOpen = false
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
    private var openWaiters: [CheckedContinuation<Void, Never>] = []

    func suspendUntilOpen() async {
        arrived = true
        arrivalWaiters.forEach { $0.resume() }
        arrivalWaiters.removeAll()
        guard isOpen == false else { return }

        await withCheckedContinuation { openWaiters.append($0) }
    }

    func waitUntilArrived() async {
        guard arrived == false else { return }

        await withCheckedContinuation { arrivalWaiters.append($0) }
    }

    func open() {
        isOpen = true
        openWaiters.forEach { $0.resume() }
        openWaiters.removeAll()
    }
}
