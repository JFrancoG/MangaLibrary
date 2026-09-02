//
//  CollectionOutboxPipelineTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@Suite("Collection GET then POST pipeline", .tags(.integration))
struct CollectionOutboxPipelineTests {
    @Test("An empty R1 snapshot preserves a local intent and R2 confirms it through POST")
    func emptyRemoteSnapshotThenPostConfirmsTheLocalIntent() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let mutationActor = CollectionMutationActor(modelContainer: container)
        let authority = SessionAuthority(userID: Self.userID, generation: Self.generation)
        let gate = SessionCommitGate(activeAuthority: authority)
        let commitAuthorization = gate.authorization(for: authority)
        let desiredState = CollectionSnapshot(
            ownedVolumes: [1, 3],
            readingVolume: 2,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        _ = try await mutationActor.apply(
            CollectionMutationCommand(
                authority: authority,
                mangaID: 42,
                mangaSnapshot: CollectionMangaSnapshot(manga: Self.manga),
                knownTotalVolumes: 3,
                change: .replaceState(ownedVolumes: [1, 3], readingVolume: 2, isComplete: false)
            ),
            authorization: commitAuthorization,
            newOperationID: Self.operationID
        )

        let loader = GetThenPostLoader()
        let baseURL = try #require(URL(string: "https://collection.example.test/api"))
        let client = CollectionAPIClient(
            configuration: try APIConfiguration(baseURL: baseURL),
            loadData: { request in try await loader.load(request) }
        )
        let requestAuthorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "synthetic-access",
            commitAuthorization: commitAuthorization
        )
        let importCoordinator = CollectionSyncCoordinator(
            authorize: { requestAuthorization },
            validateAuthorization: { authorization in authorization.authority == authority },
            fetchRemote: { accessToken in try await client.fetch(accessToken: accessToken) },
            importRemote: { entries, authorization in
                try await mutationActor.importRemote(entries, authorization: authorization)
            }
        )
        let outboxCoordinator = CollectionOutboxSyncCoordinator(
            authorize: { requestAuthorization },
            validateAuthorization: { authorization in authorization.authority == authority },
            claimNextUpload: { authorization in
                try await mutationActor.claimNextUpload(authorization: authorization)
            },
            submit: { workItem, accessToken in
                _ = try await client.submit(
                    mangaID: workItem.mangaID,
                    ownedVolumes: workItem.ownedVolumes,
                    readingVolume: workItem.readingVolume,
                    isComplete: workItem.isComplete,
                    accessToken: accessToken
                )
            },
            fetchRemote: { accessToken in try await client.fetch(accessToken: accessToken) },
            importRemote: { entries, authorization in
                try await mutationActor.importRemote(entries, authorization: authorization)
            },
            confirmUpload: { workItem, authorization in
                try await mutationActor.confirmUpload(workItem, authorization: authorization)
            },
            blockUploadOutcome: { workItem, authorization in
                try await mutationActor.blockUploadOutcome(workItem, authorization: authorization)
            },
            hasBlockedOutcome: { authorization in
                try await mutationActor.hasBlockedUploadOutcome(authorization: authorization)
            }
        )
        let synchronization = CollectionSynchronization(
            importCoordinator: importCoordinator,
            outboxCoordinator: outboxCoordinator
        )

        try await synchronization()

        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
        let entry = try #require(entries.first)
        let operation = try #require(operations.first)
        #expect(entries.count == 1)
        #expect(entry.state == desiredState)
        #expect(entry.confirmedState == desiredState)
        #expect(operations.count == 1)
        #expect(operation.operationID == Self.operationID)
        #expect(operation.state == .confirmed)
        #expect(await loader.methods() == ["GET", "POST"])
    }

    @Test(
        "Recovered sending reuses the single R1 snapshot and never repeats POST",
        arguments: RecoveredSnapshotScenario.allCases
    )
    private func recoveredSendingReusesTheImportedSnapshot(
        scenario: RecoveredSnapshotScenario
    ) async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let mutationActor = CollectionMutationActor(modelContainer: container)
        let authority = SessionAuthority(userID: Self.userID, generation: Self.generation)
        let gate = SessionCommitGate(activeAuthority: authority)
        let commitAuthorization = gate.authorization(for: authority)
        try await Self.persistSendingUpload(mutationActor: mutationActor, authorization: commitAuthorization)

        let requestAuthorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "synthetic-access",
            commitAuthorization: commitAuthorization
        )
        let remoteEntries: [CollectionRemoteEntry] = switch scenario {
        case .matching:
            [Self.remoteEntry(ownedVolumes: [1, 3])]
        case .missing:
            []
        }
        let probe = RecoveredPipelineProbe(remoteEntries: remoteEntries)
        let synchronization = Self.synchronization(
            mutationActor: mutationActor,
            requestAuthorization: requestAuthorization,
            probe: probe
        )

        switch scenario {
        case .matching:
            try await synchronization()
        case .missing:
            await #expect(throws: CollectionOutboxSyncError.outcomeUnconfirmed) {
                try await synchronization()
            }
        }

        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
        let entry = try #require(entries.first)
        let operation = try #require(operations.first)
        #expect(entries.count == 1)
        #expect(entry.state == Self.desiredState)
        #expect(operations.count == 1)
        #expect(operation.operationID == Self.operationID)
        #expect(operation.state == scenario.expectedOperationState)
        if scenario == .matching { #expect(entry.confirmedState == Self.desiredState) }
        #expect(await probe.evidence() == RecoveredPipelineEvidence(fetchCount: 1, submitCount: 0))
    }

    @Test("A failed R1 snapshot blocks recovered sending without another request")
    func failedR1SnapshotBlocksRecoveredSending() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let mutationActor = CollectionMutationActor(modelContainer: container)
        let authority = SessionAuthority(userID: Self.userID, generation: Self.generation)
        let gate = SessionCommitGate(activeAuthority: authority)
        let commitAuthorization = gate.authorization(for: authority)
        try await Self.persistSendingUpload(mutationActor: mutationActor, authorization: commitAuthorization)

        let requestAuthorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "synthetic-access",
            commitAuthorization: commitAuthorization
        )
        let probe = RecoveredPipelineProbe(remoteEntries: [], fetchFails: true)
        let synchronization = Self.synchronization(
            mutationActor: mutationActor,
            requestAuthorization: requestAuthorization,
            probe: probe
        )

        await #expect(throws: RecoveredPipelineProbe.Failure.readFailed) {
            try await synchronization()
        }

        let context = ModelContext(container)
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
        let operation = try #require(operations.first)
        let notice = AccountCollectionNotice.persistedUploadOutcome(userID: Self.userID, operations: operations)
        #expect(operations.count == 1)
        #expect(operation.state == .blockedOutcome)
        #expect(notice == AccountCollectionNotice(userID: Self.userID, reason: .uploadOutcomeUnconfirmed))
        #expect(await probe.evidence() == RecoveredPipelineEvidence(fetchCount: 1, submitCount: 0))
    }

    @Test(
        "R1 import failures classify recovered uncertainty except cancellation or session change",
        arguments: R1ImportFailureScenario.allCases
    )
    private func r1ImportFailurePreservesTheRequiredRecoveryState(
        scenario: R1ImportFailureScenario
    ) async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let mutationActor = CollectionMutationActor(modelContainer: container)
        let authority = SessionAuthority(userID: Self.userID, generation: Self.generation)
        let gate = SessionCommitGate(activeAuthority: authority)
        let commitAuthorization = gate.authorization(for: authority)
        try await Self.persistSendingUpload(mutationActor: mutationActor, authorization: commitAuthorization)

        let requestAuthorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "synthetic-access",
            commitAuthorization: commitAuthorization
        )
        let probe = RecoveredPipelineProbe(remoteEntries: [Self.remoteEntry(ownedVolumes: [1, 3])])
        let importCoordinator = CollectionSyncCoordinator(
            authorize: { requestAuthorization },
            validateAuthorization: { authorization in authorization.authority == authority },
            fetchRemote: { accessToken in try await probe.fetch(accessToken: accessToken) },
            importRemote: { _, _ in throw scenario.error }
        )
        let synchronization = CollectionSynchronization(
            importCoordinator: importCoordinator,
            outboxCoordinator: Self.outboxCoordinator(
                mutationActor: mutationActor,
                requestAuthorization: requestAuthorization,
                probe: probe
            )
        )

        switch scenario {
        case .persistenceConflict:
            await #expect(throws: CollectionRemoteImportError.persistenceConflict) {
                try await synchronization()
            }
        case .sessionChanged:
            await #expect(throws: CollectionRemoteImportError.sessionChanged) {
                try await synchronization()
            }
        case .cancelled:
            await #expect(throws: CancellationError.self) {
                try await synchronization()
            }
        }

        let context = ModelContext(container)
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
        #expect(operations.count == 1)
        #expect(operations.first?.state == scenario.expectedOperationState)
        #expect(await probe.evidence() == RecoveredPipelineEvidence(fetchCount: 1, submitCount: 0))
    }

    @Test("A snapshot from an earlier generation cannot resolve current sending work")
    func earlierGenerationSnapshotCannotResolveCurrentWork() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let mutationActor = CollectionMutationActor(modelContainer: container)
        let currentAuthority = SessionAuthority(userID: Self.userID, generation: Self.generation)
        let gate = SessionCommitGate(activeAuthority: currentAuthority)
        let commitAuthorization = gate.authorization(for: currentAuthority)
        try await Self.persistSendingUpload(mutationActor: mutationActor, authorization: commitAuthorization)

        let requestAuthorization = SessionRequestAuthorization(
            authority: currentAuthority,
            accessToken: "synthetic-access",
            commitAuthorization: commitAuthorization
        )
        let previousAuthority = SessionAuthority(userID: Self.userID, generation: Self.previousGeneration)
        let importedSnapshot = CollectionImportedSnapshot(
            authority: previousAuthority,
            entries: [Self.remoteEntry(ownedVolumes: [1, 3])]
        )
        let probe = RecoveredPipelineProbe(remoteEntries: [])
        let coordinator = Self.outboxCoordinator(
            mutationActor: mutationActor,
            requestAuthorization: requestAuthorization,
            probe: probe
        )

        await #expect(throws: CollectionOutboxSyncError.sessionChanged) {
            try await coordinator.synchronizeAuthenticatedOutbox(reusing: importedSnapshot)
        }

        let context = ModelContext(container)
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
        #expect(operations.count == 1)
        #expect(operations.first?.state == .sending)
        #expect(await probe.evidence() == RecoveredPipelineEvidence(fetchCount: 0, submitCount: 0))
    }

    @Test("A failed snapshot from an earlier generation cannot block current sending work")
    func earlierGenerationFailureCannotBlockCurrentWork() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let mutationActor = CollectionMutationActor(modelContainer: container)
        let currentAuthority = SessionAuthority(userID: Self.userID, generation: Self.generation)
        let currentGate = SessionCommitGate(activeAuthority: currentAuthority)
        let currentAuthorization = currentGate.authorization(for: currentAuthority)
        try await Self.persistSendingUpload(mutationActor: mutationActor, authorization: currentAuthorization)

        let currentRequestAuthorization = SessionRequestAuthorization(
            authority: currentAuthority,
            accessToken: "synthetic-access",
            commitAuthorization: currentAuthorization
        )
        let previousAuthority = SessionAuthority(userID: Self.userID, generation: Self.previousGeneration)
        let previousGate = SessionCommitGate(activeAuthority: previousAuthority)
        let previousRequestAuthorization = SessionRequestAuthorization(
            authority: previousAuthority,
            accessToken: "previous-access",
            commitAuthorization: previousGate.authorization(for: previousAuthority)
        )
        let probe = RecoveredPipelineProbe(remoteEntries: [])
        let coordinator = Self.outboxCoordinator(
            mutationActor: mutationActor,
            requestAuthorization: currentRequestAuthorization,
            probe: probe
        )

        await #expect(throws: CollectionOutboxSyncError.sessionChanged) {
            try await coordinator.blockRecoveredUploadsAfterUnusableSnapshot(for: previousRequestAuthorization)
        }

        let context = ModelContext(container)
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
        #expect(operations.count == 1)
        #expect(operations.first?.state == .sending)
        #expect(await probe.evidence() == RecoveredPipelineEvidence(fetchCount: 0, submitCount: 0))
    }

    @Test("Rejected request authorization before claim leaves the persisted intent queued")
    func rejectedRequestAuthorizationCannotCreateFalseWriteUncertainty() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let mutationActor = CollectionMutationActor(modelContainer: container)
        let authority = SessionAuthority(userID: Self.userID, generation: Self.generation)
        let gate = SessionCommitGate(activeAuthority: authority)
        let commitAuthorization = gate.authorization(for: authority)
        _ = try await mutationActor.apply(
            CollectionMutationCommand(
                authority: authority,
                mangaID: 42,
                mangaSnapshot: CollectionMangaSnapshot(manga: Self.manga),
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1])
            ),
            authorization: commitAuthorization,
            newOperationID: Self.operationID
        )

        let submissionCounter = SubmissionCounter()
        let requestAuthorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "synthetic-access",
            commitAuthorization: commitAuthorization
        )
        let coordinator = CollectionOutboxSyncCoordinator(
            authorize: { requestAuthorization },
            validateAuthorization: { _ in false },
            claimNextUpload: { authorization in
                try await mutationActor.claimNextUpload(authorization: authorization)
            },
            submit: { _, _ in await submissionCounter.record() },
            fetchRemote: { _ in [] },
            importRemote: { _, _ in },
            confirmUpload: { _, _ in },
            blockUploadOutcome: { _, _ in }
        )

        await #expect(throws: CollectionOutboxSyncError.sessionChanged) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let context = ModelContext(container)
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
        let operation = try #require(operations.first)
        #expect(operations.count == 1)
        #expect(operation.operationID == Self.operationID)
        #expect(operation.state == .queued)
        #expect(await submissionCounter.count() == 0)
    }

    @Test("A persisted uncertain upload remains visible when the earlier R1 read fails")
    func blockedOutcomeNoticeSurvivesR1Failure() async throws(any Error) {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let mutationActor = CollectionMutationActor(modelContainer: container)
        let authority = SessionAuthority(userID: Self.userID, generation: Self.generation)
        let gate = SessionCommitGate(activeAuthority: authority)
        let commitAuthorization = gate.authorization(for: authority)
        _ = try await mutationActor.apply(
            CollectionMutationCommand(
                authority: authority,
                mangaID: 42,
                mangaSnapshot: CollectionMangaSnapshot(manga: Self.manga),
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1])
            ),
            authorization: commitAuthorization,
            newOperationID: Self.operationID
        )
        let claim = try #require(try await mutationActor.claimNextUpload(authorization: commitAuthorization))
        guard case let .send(workItem) = claim else { throw PipelineTestError.unexpectedClaim }
        try await mutationActor.blockUploadOutcome(workItem, authorization: commitAuthorization)

        let requestAuthorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "synthetic-access",
            commitAuthorization: commitAuthorization
        )
        let importCoordinator = CollectionSyncCoordinator(
            authorize: { requestAuthorization },
            validateAuthorization: { _ in true },
            fetchRemote: { _ in throw CollectionAPIClientError.unavailable },
            importRemote: { _, _ in }
        )
        let submissionCounter = SubmissionCounter()
        let outboxCoordinator = CollectionOutboxSyncCoordinator(
            authorize: { requestAuthorization },
            validateAuthorization: { _ in true },
            claimNextUpload: { authorization in
                try await mutationActor.claimNextUpload(authorization: authorization)
            },
            submit: { _, _ in await submissionCounter.record() },
            fetchRemote: { _ in [] },
            importRemote: { entries, authorization in
                try await mutationActor.importRemote(entries, authorization: authorization)
            },
            confirmUpload: { item, authorization in
                try await mutationActor.confirmUpload(item, authorization: authorization)
            },
            blockUploadOutcome: { item, authorization in
                try await mutationActor.blockUploadOutcome(item, authorization: authorization)
            },
            hasBlockedOutcome: { authorization in
                try await mutationActor.hasBlockedUploadOutcome(authorization: authorization)
            }
        )
        let synchronization = CollectionSynchronization(
            importCoordinator: importCoordinator,
            outboxCoordinator: outboxCoordinator
        )

        await #expect(throws: CollectionAPIClientError.unavailable) {
            try await synchronization()
        }

        let context = ModelContext(container)
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
        let notice = AccountCollectionNotice.persistedUploadOutcome(userID: Self.userID, operations: operations)
        #expect(notice == AccountCollectionNotice(userID: Self.userID, reason: .uploadOutcomeUnconfirmed))
        #expect(await submissionCounter.count() == 0)
    }

    private static let userID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let generation = UUID(uuidString: "22222222-3333-4444-5555-666666666666")!
    private static let authority = SessionAuthority(userID: userID, generation: generation)
    private static let previousGeneration = UUID(uuidString: "00000000-1111-2222-3333-444444444444")!
    private static let operationID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private static let desiredState = CollectionSnapshot(
        ownedVolumes: [1, 3],
        readingVolume: 2,
        isComplete: false,
        knownTotalVolumes: 3,
        isTombstone: false
    )
    private static let manga = Manga(
        id: 42,
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

    private static func persistSendingUpload(
        mutationActor: CollectionMutationActor,
        authorization: SessionCommitAuthorization
    ) async throws(any Error) {
        _ = try await mutationActor.apply(
            CollectionMutationCommand(
                authority: authority,
                mangaID: 42,
                mangaSnapshot: CollectionMangaSnapshot(manga: manga),
                knownTotalVolumes: 3,
                change: .replaceState(ownedVolumes: [1, 3], readingVolume: 2, isComplete: false)
            ),
            authorization: authorization,
            newOperationID: operationID
        )
        guard
            let claim = try await mutationActor.claimNextUpload(authorization: authorization),
            case .send = claim
        else {
            throw PipelineTestError.unexpectedClaim
        }
    }

    private static func synchronization(
        mutationActor: CollectionMutationActor,
        requestAuthorization: SessionRequestAuthorization,
        probe: RecoveredPipelineProbe
    ) -> CollectionSynchronization {
        let importCoordinator = CollectionSyncCoordinator(
            authorize: { requestAuthorization },
            validateAuthorization: { authorization in authorization.authority == requestAuthorization.authority },
            fetchRemote: { accessToken in try await probe.fetch(accessToken: accessToken) },
            importRemote: { entries, authorization in
                try await mutationActor.importRemote(entries, authorization: authorization)
            }
        )
        return CollectionSynchronization(
            importCoordinator: importCoordinator,
            outboxCoordinator: outboxCoordinator(
                mutationActor: mutationActor,
                requestAuthorization: requestAuthorization,
                probe: probe
            )
        )
    }

    private static func outboxCoordinator(
        mutationActor: CollectionMutationActor,
        requestAuthorization: SessionRequestAuthorization,
        probe: RecoveredPipelineProbe
    ) -> CollectionOutboxSyncCoordinator {
        CollectionOutboxSyncCoordinator(
            authorize: { requestAuthorization },
            validateAuthorization: { authorization in authorization.authority == requestAuthorization.authority },
            claimNextUpload: { authorization in
                try await mutationActor.claimNextUpload(authorization: authorization)
            },
            nextRecoveredUpload: { authorization in
                try await mutationActor.nextRecoveredUpload(authorization: authorization)
            },
            submit: { workItem, accessToken in
                try await probe.submit(workItem, accessToken: accessToken)
            },
            fetchRemote: { accessToken in try await probe.fetch(accessToken: accessToken) },
            importRemote: { entries, authorization in
                try await mutationActor.importRemote(entries, authorization: authorization)
            },
            confirmUpload: { workItem, authorization in
                try await mutationActor.confirmUpload(workItem, authorization: authorization)
            },
            blockUploadOutcome: { workItem, authorization in
                try await mutationActor.blockUploadOutcome(workItem, authorization: authorization)
            },
            hasBlockedOutcome: { authorization in
                try await mutationActor.hasBlockedUploadOutcome(authorization: authorization)
            }
        )
    }

    private static func remoteEntry(ownedVolumes: [Int64]) -> CollectionRemoteEntry {
        CollectionRemoteEntry(
            remoteID: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
            manga: manga,
            ownedVolumes: ownedVolumes,
            readingVolume: 2,
            isComplete: false
        )
    }
}

private enum RecoveredSnapshotScenario: CaseIterable {
    case matching
    case missing

    var expectedOperationState: CollectionOutboxState {
        switch self {
        case .matching: .confirmed
        case .missing: .blockedOutcome
        }
    }
}

private enum R1ImportFailureScenario: CaseIterable {
    case persistenceConflict
    case sessionChanged
    case cancelled

    var error: CollectionRemoteImportError {
        switch self {
        case .persistenceConflict: .persistenceConflict
        case .sessionChanged: .sessionChanged
        case .cancelled: .cancelled
        }
    }

    var expectedOperationState: CollectionOutboxState {
        switch self {
        case .persistenceConflict: .blockedOutcome
        case .sessionChanged, .cancelled: .sending
        }
    }
}

private enum PipelineTestError: Error {
    case unexpectedClaim
}

private actor SubmissionCounter {
    private var submissionCount = 0

    func record() {
        submissionCount += 1
    }

    func count() -> Int {
        submissionCount
    }
}

private struct RecoveredPipelineEvidence: Equatable {
    let fetchCount: Int
    let submitCount: Int
}

private actor RecoveredPipelineProbe {
    enum Failure: Error {
        case readFailed
    }

    private let remoteEntries: [CollectionRemoteEntry]
    private let fetchFails: Bool
    private var fetchCount = 0
    private var submitCount = 0

    init(remoteEntries: [CollectionRemoteEntry], fetchFails: Bool = false) {
        self.remoteEntries = remoteEntries
        self.fetchFails = fetchFails
    }

    func fetch(accessToken: String) throws -> [CollectionRemoteEntry] {
        guard accessToken == "synthetic-access" else { throw Failure.readFailed }
        fetchCount += 1
        if fetchFails { throw Failure.readFailed }
        return remoteEntries
    }

    func submit(_ workItem: CollectionOutboxUploadWorkItem, accessToken: String) throws {
        guard workItem.mangaID == 42, accessToken == "synthetic-access" else {
            throw Failure.readFailed
        }
        submitCount += 1
    }

    func evidence() -> RecoveredPipelineEvidence {
        RecoveredPipelineEvidence(fetchCount: fetchCount, submitCount: submitCount)
    }
}

private actor GetThenPostLoader {
    enum LoaderError: Error {
        case unexpectedRequest
    }

    private var loadedMethods: [String] = []

    func load(_ request: URLRequest) throws -> Data {
        guard
            request.url?.absoluteString == "https://collection.example.test/api/collection/manga",
            request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-access",
            let method = request.httpMethod
        else { throw LoaderError.unexpectedRequest }

        loadedMethods.append(method)
        return switch method {
        case "GET": Data("[]".utf8)
        case "POST": Data("42".utf8)
        default: throw LoaderError.unexpectedRequest
        }
    }

    func methods() -> [String] {
        loadedMethods
    }
}
