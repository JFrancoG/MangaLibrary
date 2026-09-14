//
//  CollectionOutcomeResolutionCoordinatorTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("Collection outcome resolution coordinator", .tags(.fast))
struct CollectionOutcomeResolutionCoordinatorTests {
    @Test("Review uses one fresh individual GET and never trusts the stored baseline")
    func reviewUsesOneFreshIndividualGet() async throws(any Error) {
        let probe = R24CoordinatorProbe(fetchResults: [.success(Self.remoteEntry)])
        let coordinator = Self.coordinator(probe: probe)

        let review = try await coordinator.review(operationID: Self.operationID, expectedAuthority: Self.authority)

        #expect(review.context == Self.context)
        #expect(review.evidence == Self.remoteEvidence)
        #expect(await probe.evidence().fetchTokens == ["access-a"])
        #expect(await probe.evidence().resolvedDecisions.isEmpty)
    }

    @Test("A first 401 refreshes and retries the individual GET once")
    func firstUnauthorizedRefreshesAndRetriesOnce() async throws(any Error) {
        let probe = R24CoordinatorProbe(
            fetchResults: [
                .failure(.network(.statusCode(401))),
                .success(Self.remoteEntry),
            ]
        )
        let coordinator = Self.coordinator(probe: probe)

        _ = try await coordinator.review(operationID: Self.operationID, expectedAuthority: Self.authority)

        let evidence = await probe.evidence()
        #expect(evidence.fetchTokens == ["access-a", "access-b"])
        #expect(evidence.recoveryCount == 1)
    }

    @Test("A second 401 exposes incompatibility without resolving")
    func secondUnauthorizedExposesIncompatibility() async throws(any Error) {
        let probe = R24CoordinatorProbe(
            fetchResults: [
                .failure(.network(.statusCode(401))),
                .failure(.network(.statusCode(401))),
            ]
        )
        let coordinator = Self.coordinator(probe: probe)

        await #expect(throws: CollectionBlockedOutcomeError.authenticationIncompatible(statusCode: 401)) {
            try await coordinator.review(operationID: Self.operationID, expectedAuthority: Self.authority)
        }

        let evidence = await probe.evidence()
        #expect(evidence.fetchTokens == ["access-a", "access-b"])
        #expect(evidence.recoveryCount == 1)
        #expect(evidence.resolvedDecisions.isEmpty)
    }

    @Test("A 403 preserves authorization without refresh or retry")
    func forbiddenDoesNotRefreshOrRetry() async throws(any Error) {
        let probe = R24CoordinatorProbe(fetchResults: [.failure(.network(.statusCode(403)))])
        let coordinator = Self.coordinator(probe: probe)

        await #expect(throws: CollectionBlockedOutcomeError.authorizationDenied(statusCode: 403)) {
            try await coordinator.review(operationID: Self.operationID, expectedAuthority: Self.authority)
        }

        let evidence = await probe.evidence()
        #expect(evidence.fetchTokens == ["access-a"])
        #expect(evidence.recoveryCount == 0)
        #expect(evidence.resolvedDecisions.isEmpty)
    }

    @Test("Confirmation rechecks identical evidence and resolves exactly once")
    func confirmationRechecksAndResolvesOnce() async throws(any Error) {
        let probe = R24CoordinatorProbe(
            fetchResults: [.success(Self.remoteEntry), .success(Self.remoteEntry)],
            storeResolution: .createdIntent(operationID: Self.newOperationID, sequence: 2)
        )
        let coordinator = Self.coordinator(probe: probe)
        let review = try await coordinator.review(operationID: Self.operationID, expectedAuthority: Self.authority)

        let resolution = try await coordinator.resolve(review, decision: .keepDevice)

        #expect(resolution == .createdIntent(operationID: Self.newOperationID, sequence: 2))
        let evidence = await probe.evidence()
        #expect(evidence.fetchTokens == ["access-a", "access-a"])
        #expect(evidence.resolvedDecisions == [.keepDevice])
    }

    @Test("A changed remote version requires a new decision and does not mutate")
    func changedRemoteVersionRequiresNewDecision() async throws(any Error) {
        let probe = R24CoordinatorProbe(fetchResults: [.success(Self.remoteEntry), .success(nil)])
        let coordinator = Self.coordinator(probe: probe)
        let review = try await coordinator.review(operationID: Self.operationID, expectedAuthority: Self.authority)

        await #expect(throws: CollectionBlockedOutcomeError.remoteChanged(.absent)) {
            try await coordinator.resolve(review, decision: .useRemote)
        }

        let evidence = await probe.evidence()
        #expect(evidence.resolvedDecisions.isEmpty)
    }

    @Test("The coordinator propagates the store continuation result")
    func existingLaterIntentPropagatesStoreContinuation() async throws(any Error) {
        let probe = R24CoordinatorProbe(
            fetchResults: [.success(Self.remoteEntry), .success(Self.remoteEntry)],
            storeResolution: .continuedExistingIntent(operationID: Self.laterOperationID, sequence: 2)
        )
        let coordinator = Self.coordinator(probe: probe)
        let review = try await coordinator.review(operationID: Self.operationID, expectedAuthority: Self.authority)

        let resolution = try await coordinator.resolve(review, decision: .keepDevice)

        #expect(resolution == .continuedExistingIntent(operationID: Self.laterOperationID, sequence: 2))
        #expect(await probe.evidence().resolvedDecisions == [.keepDevice])
    }

    @Test("Changed manga metadata requires a new decision and does not mutate")
    func changedMangaMetadataRequiresNewDecision() async throws(any Error) {
        let changedManga = Manga(
            id: Self.mangaID,
            title: "Changed Forty-Two",
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
        let changedEntry = CollectionRemoteEntry(
            remoteID: Self.remoteEntry.remoteID,
            manga: changedManga,
            ownedVolumes: Self.remoteState.ownedVolumes,
            readingVolume: Self.remoteState.readingVolume,
            isComplete: Self.remoteState.isComplete
        )
        let changedEvidence = CollectionBlockedOutcomeEvidence.present(
            state: Self.remoteState,
            mangaSnapshot: CollectionMangaSnapshot(manga: changedManga)
        )
        let probe = R24CoordinatorProbe(
            fetchResults: [.success(Self.remoteEntry), .success(changedEntry)],
            evidenceResults: [Self.remoteEvidence, changedEvidence]
        )
        let coordinator = Self.coordinator(probe: probe)
        let review = try await coordinator.review(operationID: Self.operationID, expectedAuthority: Self.authority)

        await #expect(throws: CollectionBlockedOutcomeError.remoteChanged(changedEvidence)) {
            try await coordinator.resolve(review, decision: .useRemote)
        }

        #expect(await probe.evidence().resolvedDecisions.isEmpty)
    }

    @Test("An unavailable individual read offers no decision")
    func unavailableReadOffersNoDecision() async throws(any Error) {
        let probe = R24CoordinatorProbe(fetchResults: [.failure(.unavailable)])
        let coordinator = Self.coordinator(probe: probe)

        await #expect(throws: CollectionBlockedOutcomeError.unavailable) {
            try await coordinator.review(operationID: Self.operationID, expectedAuthority: Self.authority)
        }

        #expect(await probe.evidence().resolvedDecisions.isEmpty)
    }

    @Test("An incompatible individual response offers no decision")
    func incompatibleReadOffersNoDecision() async throws(any Error) {
        let incompatibleManga = Manga(
            id: Self.mangaID + 1,
            title: "Wrong identity",
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
        let incompatibleEntry = CollectionRemoteEntry(
            remoteID: UUID(),
            manga: incompatibleManga,
            ownedVolumes: [1],
            readingVolume: 1,
            isComplete: false
        )
        let probe = R24CoordinatorProbe(fetchResults: [.success(incompatibleEntry)])
        let coordinator = Self.coordinator(probe: probe)

        await #expect(throws: CollectionBlockedOutcomeError.incompatibleRemoteState) {
            try await coordinator.review(operationID: Self.operationID, expectedAuthority: Self.authority)
        }

        #expect(await probe.evidence().resolvedDecisions.isEmpty)
    }

    @Test("Authority invalidated by the confirmation GET prevents the store commit")
    func staleAuthorityAfterGetPreventsCommit() async throws(any Error) {
        let probe = R24CoordinatorProbe(fetchResults: [.success(Self.remoteEntry), .success(Self.remoteEntry)])
        let coordinator = Self.coordinator(probe: probe)
        let review = try await coordinator.review(operationID: Self.operationID, expectedAuthority: Self.authority)
        await probe.invalidateAfterNextFetch()

        await #expect(throws: CollectionBlockedOutcomeError.sessionChanged) {
            try await coordinator.resolve(review, decision: .keepDevice)
        }

        let evidence = await probe.evidence()
        #expect(evidence.fetchTokens.count == 2)
        #expect(evidence.resolvedDecisions.isEmpty)
    }

    @Test(arguments: R24SessionFailureScenario.all, R24SessionFailurePoint.allCases)
    private func `session failure prevents confirmation`(
        _ scenario: R24SessionFailureScenario,
        point: R24SessionFailurePoint
    ) async throws(any Error) {
        let probe = R24CoordinatorProbe(fetchResults: point.fetchResults)
        await probe.failSession(at: point, with: scenario.error)
        let coordinator = Self.coordinator(probe: probe)
        let review = CollectionBlockedOutcomeReview(context: Self.context, evidence: Self.remoteEvidence)

        await #expect(throws: scenario.expectedError) {
            try await coordinator.resolve(review, decision: .keepDevice)
        }

        let evidence = await probe.evidence()
        #expect(evidence.fetchTokens == point.expectedFetchTokens)
        #expect(evidence.recoveryCount == (point == .recover ? 1 : 0))
        #expect(evidence.resolvedDecisions.isEmpty)
    }

    @Test(arguments: R24SessionFailurePoint.allCases)
    private func `session cancellation prevents confirmation`(_ point: R24SessionFailurePoint) async throws(any Error) {
        let probe = R24CoordinatorProbe(fetchResults: point.fetchResults)
        await probe.failSession(at: point, with: CancellationError())
        let coordinator = Self.coordinator(probe: probe)
        let review = CollectionBlockedOutcomeReview(context: Self.context, evidence: Self.remoteEvidence)

        await #expect(throws: CancellationError.self) {
            try await coordinator.resolve(review, decision: .keepDevice)
        }

        let evidence = await probe.evidence()
        #expect(evidence.fetchTokens == point.expectedFetchTokens)
        #expect(evidence.recoveryCount == (point == .recover ? 1 : 0))
        #expect(evidence.resolvedDecisions.isEmpty)
    }
}

private extension CollectionOutcomeResolutionCoordinatorTests {
    static let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let generation = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let authority = SessionAuthority(userID: userID, generation: generation)
    static let operationID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let laterOperationID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let newOperationID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    static let mangaID: Manga.ID = 42
    static let localState = CollectionSnapshot(
        ownedVolumes: [1, 2],
        readingVolume: 2,
        isComplete: false,
        knownTotalVolumes: 3,
        isTombstone: false
    )
    static let remoteState = CollectionSnapshot(
        ownedVolumes: [1],
        readingVolume: 1,
        isComplete: false,
        knownTotalVolumes: 3,
        isTombstone: false
    )
    static let manga = Manga(
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
    static let remoteEntry = CollectionRemoteEntry(
        remoteID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
        manga: manga,
        ownedVolumes: remoteState.ownedVolumes,
        readingVolume: remoteState.readingVolume,
        isComplete: remoteState.isComplete
    )
    static let remoteEvidence = CollectionBlockedOutcomeEvidence.present(
        state: remoteState,
        mangaSnapshot: CollectionMangaSnapshot(manga: manga)
    )
    static let context = CollectionBlockedOutcomeContext(
        operation: CollectionBlockedOutcomeOperationReference(
            authority: authority,
            operationID: operationID,
            userID: userID,
            mangaID: mangaID,
            sequence: 1,
            retryCount: 0,
            desiredState: localState
        ),
        deviceState: localState,
        mangaSnapshot: CollectionMangaSnapshot(manga: manga),
        laterIntent: nil
    )

    static func coordinator(probe: R24CoordinatorProbe) -> CollectionOutcomeResolutionCoordinator {
        let gate = SessionCommitGate(activeAuthority: authority)
        let authorizationA = SessionRequestAuthorization(
            authority: authority,
            accessToken: "access-a",
            commitAuthorization: gate.authorization(for: authority)
        )
        let authorizationB = SessionRequestAuthorization(
            authority: authority,
            accessToken: "access-b",
            commitAuthorization: gate.authorization(for: authority)
        )

        return CollectionOutcomeResolutionCoordinator(
            authorize: {
                try await probe.authorize(authorizationA)
            },
            validateAuthorization: { candidate in
                try await probe.validate(candidate)
            },
            recoverAuthorization: { candidate in
                try await probe.recordRecovery(candidate)
                return authorizationB
            },
            loadContext: { operationID, _ in
                guard operationID == Self.operationID else { throw CollectionBlockedOutcomeError.staleOperation }
                return Self.context
            },
            fetchRemoteEntry: { mangaID, token in
                try await probe.fetch(mangaID: mangaID, token: token)
            },
            validateEvidence: { remoteEntry, mangaID in
                guard mangaID == Self.mangaID else { throw CollectionBlockedOutcomeError.incompatibleRemoteState }
                guard let remoteEntry else { return .absent }
                guard remoteEntry.manga.id == mangaID else {
                    throw CollectionBlockedOutcomeError.incompatibleRemoteState
                }
                return try await probe.validate(remoteEntry)
            },
            resolveStore: { context, evidence, decision, _, operationID in
                try await probe.resolve(
                    context: context,
                    evidence: evidence,
                    decision: decision,
                    operationID: operationID
                )
            },
            makeOperationID: { Self.newOperationID }
        )
    }
}

private actor R24CoordinatorProbe {
    enum FetchResult {
        case success(CollectionRemoteEntry?)
        case failure(CollectionAPIClientError)
    }

    private var fetchResults: [FetchResult]
    private var invalidatesAfterNextFetch = false
    private var isAuthorized = true
    private var validationResults: [Bool]
    private var evidenceResults: [CollectionBlockedOutcomeEvidence]
    private let storeResolution: CollectionBlockedOutcomeStoreResolution
    private var fetchTokens: [String] = []
    private var recoveryCount = 0
    private var resolvedDecisions: [CollectionBlockedOutcomeDecision] = []
    private var sessionFailure: (point: R24SessionFailurePoint, error: any Error)?

    init(
        fetchResults: [FetchResult],
        validationResults: [Bool] = [],
        evidenceResults: [CollectionBlockedOutcomeEvidence] = [],
        storeResolution: CollectionBlockedOutcomeStoreResolution = .adoptedRemote
    ) {
        self.fetchResults = fetchResults
        self.validationResults = validationResults
        self.evidenceResults = evidenceResults
        self.storeResolution = storeResolution
    }

    func invalidateAfterNextFetch() {
        invalidatesAfterNextFetch = true
    }

    func failSession(at point: R24SessionFailurePoint, with error: any Error) {
        sessionFailure = (point, error)
    }

    func authorize(_ authorization: SessionRequestAuthorization) throws(any Error) -> SessionRequestAuthorization {
        try throwSessionFailure(at: .authorize)
        return authorization
    }

    func validate(_ authorization: SessionRequestAuthorization) throws(any Error) -> Bool {
        try throwSessionFailure(at: .validate)
        guard isAuthorized else { return false }
        guard authorization.authority == CollectionOutcomeResolutionCoordinatorTests.authority else { return false }
        guard validationResults.isEmpty == false else { return true }
        return validationResults.removeFirst()
    }

    func fetch(mangaID: Manga.ID, token: String) throws(any Error) -> CollectionRemoteEntry? {
        guard mangaID == CollectionOutcomeResolutionCoordinatorTests.mangaID else {
            throw CollectionBlockedOutcomeError.incompatibleRemoteState
        }
        fetchTokens.append(token)
        if invalidatesAfterNextFetch {
            isAuthorized = false
            invalidatesAfterNextFetch = false
        }
        guard fetchResults.isEmpty == false else { throw CollectionBlockedOutcomeError.unavailable }

        switch fetchResults.removeFirst() {
        case let .success(entry):
            return entry
        case let .failure(error):
            throw error
        }
    }

    func recordRecovery(_ authorization: SessionRequestAuthorization) throws(any Error) {
        guard authorization.authority == CollectionOutcomeResolutionCoordinatorTests.authority else { return }
        recoveryCount += 1
        try throwSessionFailure(at: .recover)
    }

    func validate(_ remoteEntry: CollectionRemoteEntry) throws(any Error) -> CollectionBlockedOutcomeEvidence {
        guard remoteEntry.manga.id == CollectionOutcomeResolutionCoordinatorTests.mangaID else {
            throw CollectionBlockedOutcomeError.incompatibleRemoteState
        }
        guard evidenceResults.isEmpty == false else {
            return CollectionOutcomeResolutionCoordinatorTests.remoteEvidence
        }
        return evidenceResults.removeFirst()
    }

    func resolve(
        context: CollectionBlockedOutcomeContext,
        evidence: CollectionBlockedOutcomeEvidence,
        decision: CollectionBlockedOutcomeDecision,
        operationID: UUID
    ) throws(any Error) -> CollectionBlockedOutcomeStoreResolution {
        guard
            context == CollectionOutcomeResolutionCoordinatorTests.context,
            evidence == CollectionOutcomeResolutionCoordinatorTests.remoteEvidence,
            operationID == CollectionOutcomeResolutionCoordinatorTests.newOperationID
        else { throw CollectionBlockedOutcomeError.staleOperation }
        resolvedDecisions.append(decision)
        return storeResolution
    }

    func evidence() -> R24CoordinatorEvidence {
        R24CoordinatorEvidence(
            fetchTokens: fetchTokens,
            recoveryCount: recoveryCount,
            resolvedDecisions: resolvedDecisions
        )
    }

    private func throwSessionFailure(at point: R24SessionFailurePoint) throws(any Error) {
        if let sessionFailure, sessionFailure.point == point {
            throw sessionFailure.error
        }
    }
}

private struct R24CoordinatorEvidence: Equatable {
    let fetchTokens: [String]
    let recoveryCount: Int
    let resolvedDecisions: [CollectionBlockedOutcomeDecision]
}

private enum R24SessionFailurePoint: CaseIterable {
    case authorize
    case validate
    case recover

    var fetchResults: [R24CoordinatorProbe.FetchResult] {
        switch self {
        case .authorize:
            []
        case .validate:
            [.success(CollectionOutcomeResolutionCoordinatorTests.remoteEntry)]
        case .recover:
            [.failure(.network(.statusCode(401)))]
        }
    }

    var expectedFetchTokens: [String] {
        self == .authorize ? [] : ["access-a"]
    }
}

private struct R24SessionFailureScenario {
    let error: SessionControllerError
    let expectedError: CollectionBlockedOutcomeError

    static let all: [Self] = [
        Self(error: .temporarilyUnavailable, expectedError: .unavailable),
        Self(error: .persistenceUnavailable, expectedError: .unavailable),
        Self(error: .pendingCollectionPersistenceUnavailable, expectedError: .unavailable),
        Self(error: .unavailable, expectedError: .unavailable),
        Self(error: .network(.transport(.notConnectedToInternet)), expectedError: .unavailable),
        Self(error: .contractDrift, expectedError: .unavailable),
        Self(error: .invalidCredentials, expectedError: .sessionChanged),
        Self(error: .authenticationRequired, expectedError: .sessionChanged),
        Self(error: .pendingCollectionChanges, expectedError: .sessionChanged),
        Self(error: .transitionInProgress, expectedError: .sessionChanged),
        Self(error: .sessionChanged, expectedError: .sessionChanged),
        Self(error: .notAuthenticated, expectedError: .sessionChanged),
    ]
}
