//
//  CollectionOutboxDeletePipelineTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@Suite("Collection DELETE persistence pipeline", .tags(.integration))
struct CollectionOutboxDeletePipelineTests {
    @Test("A confirmed DELETE removes only its manga through the real persistence actor")
    func confirmedDeleteRetiresOnlyItsEntry() async throws(any Error) {
        let fixture = try await Self.makeFixture()
        let probe = DeletePipelineProbe(outcome: .confirmed)
        let coordinator = Self.coordinator(
            mutationActor: fixture.mutationActor,
            authorization: fixture.authorization,
            probe: probe
        )

        try await coordinator.synchronizeAuthenticatedOutbox()

        let store = try Self.readStore(fixture.container)
        #expect(await probe.events() == [.delete(Self.mangaID)])
        #expect(store.entries == [Self.otherEntryEvidence])
        #expect(
            store.operations == [
                DeletePipelineOperationEvidence(
                    mangaID: Self.mangaID,
                    sequence: 2,
                    state: .confirmed,
                    desiredState: Self.tombstoneState
                ),
                Self.otherOperationEvidence,
            ]
        )
    }

    @Test("A lost DELETE response plus individual absence preserves and uploads N plus one")
    func uncertainDeleteWithAbsencePreservesLaterIntent() async throws(any Error) {
        let fixture = try await Self.makeFixture()
        let probe = DeletePipelineProbe(outcome: .uncertain(remoteEntry: nil))
        let coordinator = Self.coordinator(
            mutationActor: fixture.mutationActor,
            authorization: fixture.authorization,
            probe: probe
        )

        try await coordinator.synchronizeAuthenticatedOutbox()

        let store = try Self.readStore(fixture.container)
        #expect(
            await probe.events() == [
                .delete(Self.mangaID),
                .get(Self.mangaID),
                .post(Self.mangaID),
            ]
        )
        #expect(
            store.entries == [
                DeletePipelineEntryEvidence(
                    mangaID: Self.mangaID,
                    state: Self.laterState,
                    confirmedState: Self.laterState,
                    title: Self.manga.title
                ),
                Self.otherEntryEvidence,
            ]
        )
        #expect(
            store.operations == [
                DeletePipelineOperationEvidence(
                    mangaID: Self.mangaID,
                    sequence: 3,
                    state: .confirmed,
                    desiredState: Self.laterState
                ),
                Self.otherOperationEvidence,
            ]
        )
    }

    @Test("A lost DELETE response plus individual presence blocks N and preserves N plus one")
    func uncertainDeleteWithPresenceBlocksWithoutLosingLaterIntent() async throws(any Error) {
        let fixture = try await Self.makeFixture()
        let remoteEntry = Self.remoteEntry(state: Self.remoteState)
        let probe = DeletePipelineProbe(outcome: .uncertain(remoteEntry: remoteEntry))
        let coordinator = Self.coordinator(
            mutationActor: fixture.mutationActor,
            authorization: fixture.authorization,
            probe: probe
        )

        await #expect(throws: CollectionOutboxSyncError.outcomeUnconfirmed) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let store = try Self.readStore(fixture.container)
        let noticeContext = ModelContext(fixture.container)
        let notice = AccountCollectionNotice.persistedUploadOutcome(
            userID: Self.userID,
            operations: try noticeContext.fetch(FetchDescriptor<CollectionOutboxOperation>())
        )
        #expect(await probe.events() == [.delete(Self.mangaID), .get(Self.mangaID)])
        #expect(notice == AccountCollectionNotice(userID: Self.userID, reason: .uploadOutcomeUnconfirmed))
        #expect(
            store.entries == [
                DeletePipelineEntryEvidence(
                    mangaID: Self.mangaID,
                    state: Self.laterState,
                    confirmedState: Self.remoteState,
                    title: remoteEntry.manga.title
                ),
                Self.otherEntryEvidence,
            ]
        )
        #expect(
            store.operations == [
                DeletePipelineOperationEvidence(
                    mangaID: Self.mangaID,
                    sequence: 1,
                    state: .confirmed,
                    desiredState: Self.initialState
                ),
                DeletePipelineOperationEvidence(
                    mangaID: Self.mangaID,
                    sequence: 2,
                    state: .blockedOutcome,
                    desiredState: Self.tombstoneState
                ),
                DeletePipelineOperationEvidence(
                    mangaID: Self.mangaID,
                    sequence: 3,
                    state: .queued,
                    desiredState: Self.laterState
                ),
                Self.otherOperationEvidence,
            ]
        )
    }

    private static func makeFixture() async throws(any Error) -> DeletePipelineFixture {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let mutationActor = CollectionMutationActor(modelContainer: container)
        let gate = SessionCommitGate(activeAuthority: authority)
        let authorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "synthetic-access",
            commitAuthorization: gate.authorization(for: authority)
        )

        try await persistConfirmed(
            manga,
            state: initialState,
            operationID: initialOperationID,
            mutationActor: mutationActor,
            authorization: authorization.commitAuthorization
        )
        try await persistConfirmed(
            otherManga,
            state: otherState,
            operationID: otherOperationID,
            mutationActor: mutationActor,
            authorization: authorization.commitAuthorization
        )
        _ = try await mutationActor.apply(
            CollectionMutationCommand(
                authority: authority,
                mangaID: mangaID,
                knownTotalVolumes: initialState.knownTotalVolumes,
                change: .delete
            ),
            authorization: authorization.commitAuthorization,
            newOperationID: deleteOperationID
        )

        return DeletePipelineFixture(container: container, mutationActor: mutationActor, authorization: authorization)
    }

    private static func persistConfirmed(
        _ manga: Manga,
        state: CollectionSnapshot,
        operationID: UUID,
        mutationActor: CollectionMutationActor,
        authorization: SessionCommitAuthorization
    ) async throws(any Error) {
        _ = try await mutationActor.apply(
            CollectionMutationCommand(
                authority: authority,
                mangaID: manga.id,
                mangaSnapshot: CollectionMangaSnapshot(manga: manga),
                knownTotalVolumes: state.knownTotalVolumes,
                change: .replaceState(
                    ownedVolumes: state.ownedVolumes,
                    readingVolume: state.readingVolume,
                    isComplete: state.isComplete
                )
            ),
            authorization: authorization,
            newOperationID: operationID
        )
        let claim = try #require(try await mutationActor.claimNextUpload(authorization: authorization))
        guard case let .send(workItem) = claim else {
            Issue.record("Expected a new upload while preparing the DELETE pipeline")
            throw DeletePipelineProbe.Failure.unexpectedRequest
        }
        try await mutationActor.confirmUpload(workItem, authorization: authorization)
    }

    private static func coordinator(
        mutationActor: CollectionMutationActor,
        authorization: SessionRequestAuthorization,
        probe: DeletePipelineProbe
    ) -> CollectionOutboxSyncCoordinator {
        CollectionOutboxSyncCoordinator(
            authorize: { authorization },
            validateAuthorization: { candidate in candidate.authority == authorization.authority },
            claimNextUpload: { commitAuthorization, now in
                try await mutationActor.claimNextUpload(authorization: commitAuthorization, now: now)
            },
            submit: { workItem, accessToken in
                let createsLaterIntent = try await probe.submit(workItem, accessToken: accessToken)
                if createsLaterIntent {
                    _ = try await mutationActor.apply(
                        CollectionMutationCommand(
                            authority: authority,
                            mangaID: mangaID,
                            mangaSnapshot: CollectionMangaSnapshot(manga: manga),
                            knownTotalVolumes: laterState.knownTotalVolumes,
                            change: .replaceState(
                                ownedVolumes: laterState.ownedVolumes,
                                readingVolume: laterState.readingVolume,
                                isComplete: laterState.isComplete
                            )
                        ),
                        authorization: authorization.commitAuthorization,
                        newOperationID: laterOperationID
                    )
                    throw DeletePipelineProbe.Failure.lostDeleteResponse
                }
            },
            fetchRemote: { accessToken in
                try await probe.fetchFull(accessToken: accessToken)
            },
            fetchRemoteEntry: { requestedMangaID, accessToken in
                try await probe.fetchIndividual(mangaID: requestedMangaID, accessToken: accessToken)
            },
            importRemote: { _, _ in
                Issue.record("An individual DELETE reconciliation must not import a full snapshot")
            },
            confirmUpload: { workItem, commitAuthorization in
                try await mutationActor.confirmUpload(workItem, authorization: commitAuthorization)
            },
            resolveDeletion: { workItem, evidence, commitAuthorization in
                try await mutationActor.resolveDeletion(
                    workItem,
                    evidence: evidence,
                    authorization: commitAuthorization
                )
            },
            blockUploadOutcome: { workItem, commitAuthorization in
                try await mutationActor.blockUploadOutcome(workItem, authorization: commitAuthorization)
            },
            hasBlockedOutcome: { commitAuthorization in
                try await mutationActor.hasBlockedUploadOutcome(authorization: commitAuthorization)
            }
        )
    }

    private static func readStore(_ container: ModelContainer) throws(any Error) -> DeletePipelineStoreEvidence {
        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
            .map {
                DeletePipelineEntryEvidence(
                    mangaID: $0.mangaID,
                    state: $0.state,
                    confirmedState: $0.confirmedState,
                    title: $0.mangaSnapshot?.title
                )
            }
            .sorted { $0.mangaID < $1.mangaID }
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
            .map {
                DeletePipelineOperationEvidence(
                    mangaID: $0.mangaID,
                    sequence: $0.sequence,
                    state: $0.state,
                    desiredState: $0.desiredState
                )
            }
            .sorted {
                ($0.mangaID, $0.sequence) < ($1.mangaID, $1.sequence)
            }
        return DeletePipelineStoreEvidence(entries: entries, operations: operations)
    }

    private static func remoteEntry(state: CollectionSnapshot) -> CollectionRemoteEntry {
        CollectionRemoteEntry(
            remoteID: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
            manga: Manga(
                id: mangaID,
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

    private static let userID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let generation = UUID(uuidString: "22222222-3333-4444-5555-666666666666")!
    private static let authority = SessionAuthority(userID: userID, generation: generation)
    private static let mangaID: Manga.ID = 42
    private static let otherMangaID: Manga.ID = 84
    private static let initialOperationID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    private static let otherOperationID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002")!
    private static let deleteOperationID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000003")!
    private static let laterOperationID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000004")!
    private static let initialState = CollectionSnapshot(
        ownedVolumes: [1],
        readingVolume: 1,
        isComplete: false,
        knownTotalVolumes: 3,
        isTombstone: false
    )
    private static let tombstoneState = CollectionSnapshot(
        ownedVolumes: initialState.ownedVolumes,
        readingVolume: initialState.readingVolume,
        isComplete: initialState.isComplete,
        knownTotalVolumes: initialState.knownTotalVolumes,
        isTombstone: true
    )
    private static let laterState = CollectionSnapshot(
        ownedVolumes: [2, 3],
        readingVolume: 3,
        isComplete: false,
        knownTotalVolumes: 3,
        isTombstone: false
    )
    private static let remoteState = CollectionSnapshot(
        ownedVolumes: [1, 2],
        readingVolume: 2,
        isComplete: false,
        knownTotalVolumes: 3,
        isTombstone: false
    )
    private static let otherState = CollectionSnapshot(
        ownedVolumes: [2],
        readingVolume: 2,
        isComplete: false,
        knownTotalVolumes: 4,
        isTombstone: false
    )
    private static let manga = Manga(
        id: mangaID,
        title: "Local Forty-Two",
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
    private static let otherManga = Manga(
        id: otherMangaID,
        title: "Other Manga",
        titleEnglish: nil,
        titleJapanese: nil,
        synopsis: nil,
        score: 7,
        status: .finished,
        authors: [],
        demographics: [],
        genres: [],
        themes: [],
        totalVolumes: 4,
        coverURL: nil
    )
    private static let otherEntryEvidence = DeletePipelineEntryEvidence(
        mangaID: otherMangaID,
        state: otherState,
        confirmedState: otherState,
        title: otherManga.title
    )
    private static let otherOperationEvidence = DeletePipelineOperationEvidence(
        mangaID: otherMangaID,
        sequence: 1,
        state: .confirmed,
        desiredState: otherState
    )
}

private struct DeletePipelineFixture {
    let container: ModelContainer
    let mutationActor: CollectionMutationActor
    let authorization: SessionRequestAuthorization
}

private struct DeletePipelineStoreEvidence: Equatable {
    let entries: [DeletePipelineEntryEvidence]
    let operations: [DeletePipelineOperationEvidence]
}

private struct DeletePipelineEntryEvidence: Equatable {
    let mangaID: Manga.ID
    let state: CollectionSnapshot
    let confirmedState: CollectionSnapshot?
    let title: String?
}

private struct DeletePipelineOperationEvidence: Equatable {
    let mangaID: Manga.ID
    let sequence: Int64
    let state: CollectionOutboxState
    let desiredState: CollectionSnapshot
}

private actor DeletePipelineProbe {
    enum Outcome {
        case confirmed
        case uncertain(remoteEntry: CollectionRemoteEntry?)
    }

    enum Failure: Error {
        case lostDeleteResponse
        case unexpectedRequest
    }

    enum Event: Equatable {
        case delete(Manga.ID)
        case get(Manga.ID)
        case post(Manga.ID)
    }

    private let outcome: Outcome
    private var recordedEvents: [Event] = []

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func submit(_ workItem: CollectionOutboxUploadWorkItem, accessToken: String) throws -> Bool {
        guard accessToken == "synthetic-access" else { throw Failure.unexpectedRequest }
        if workItem.isTombstone {
            recordedEvents.append(.delete(workItem.mangaID))
            if case .uncertain = outcome {
                return true
            }
            return false
        }

        recordedEvents.append(.post(workItem.mangaID))
        return false
    }

    func fetchIndividual(mangaID: Manga.ID, accessToken: String) throws -> CollectionRemoteEntry? {
        guard accessToken == "synthetic-access" else { throw Failure.unexpectedRequest }
        recordedEvents.append(.get(mangaID))
        guard case let .uncertain(remoteEntry) = outcome else { throw Failure.unexpectedRequest }
        return remoteEntry
    }

    func fetchFull(accessToken: String) throws -> [CollectionRemoteEntry] {
        guard accessToken == "synthetic-access" else { throw Failure.unexpectedRequest }
        throw Failure.unexpectedRequest
    }

    func events() -> [Event] { recordedEvents }
}
