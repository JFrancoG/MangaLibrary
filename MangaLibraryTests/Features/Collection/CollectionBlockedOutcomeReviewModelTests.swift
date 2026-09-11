//
//  CollectionBlockedOutcomeReviewModelTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@MainActor
@Suite("Collection blocked outcome review model", .tags(.fast))
struct CollectionBlockedOutcomeReviewModelTests {
    @Test("Opening a pending change publishes the fresh device and cloud comparison")
    func openingPendingChangePublishesFreshComparison() async {
        let probe = ReviewModelProbe(review: Self.review)
        let model = Self.model(probe: probe)

        await model.reviewIfNeeded()

        #expect(model.state == .ready(Self.review))
        #expect(
            await probe.evidence().reviewCalls == [
                ReviewModelCall(operationID: Self.operationID, authority: Self.authority)
            ]
        )
    }

    @Test("A later intent prevents adopting the cloud without invoking resolution")
    func laterIntentPreventsAdoptingRemote() async {
        let probe = ReviewModelProbe(review: Self.laterIntentReview)
        let model = Self.model(probe: probe, initialState: .ready(Self.laterIntentReview))

        let didResolve = await model.resolve(.useRemote)

        #expect(didResolve == false)
        #expect(model.state == .failed(.moreRecentChange, review: Self.laterIntentReview))
        #expect(await probe.evidence().decisions.isEmpty)
    }

    @Test("A confirmed device decision publishes the committed resolution")
    func confirmedDeviceDecisionPublishesResolution() async {
        let expectedResolution = CollectionBlockedOutcomeStoreResolution.createdIntent(
            operationID: Self.newOperationID,
            sequence: 2
        )
        let probe = ReviewModelProbe(review: Self.review, resolveBehavior: .success(expectedResolution))
        let model = Self.model(probe: probe, initialState: .ready(Self.review))

        let didResolve = await model.resolve(.keepDevice)

        #expect(didResolve)
        #expect(model.state == .resolved(expectedResolution))
        #expect(await probe.evidence().decisions == [.keepDevice])
    }

    @Test("A cloud change during confirmation hides decisions until another review")
    func changedCloudVersionRequiresAnotherReview() async throws {
        let probe = ReviewModelProbe(review: Self.review, resolveBehavior: .failure(.remoteChanged(.absent)))
        let model = Self.model(probe: probe, initialState: .ready(Self.review))

        let didResolve = await model.resolve(.useRemote)

        #expect(didResolve == false)
        guard case let .failed(failure, failedReview) = model.state else {
            Issue.record("Expected the changed-cloud review failure")
            return
        }
        let review = try #require(failedReview)
        #expect(failure == .remoteChanged)
        #expect(review.evidence == .absent)
        #expect(review.context == Self.review.context)
        #expect(await model.resolve(.useRemote) == false)
        #expect(await probe.evidence().decisions == [.useRemote])
    }

    @Test("Leaving while review is suspended restores the prior safe state")
    func cancellationRestoresPriorState() async {
        let gate = ReviewModelGate()
        let probe = ReviewModelProbe(review: Self.review, reviewGate: gate)
        let fallback = CollectionBlockedOutcomeReviewModel.State.failed(.unavailable, review: nil)
        let model = Self.model(probe: probe, initialState: fallback)

        let task = Task {
            await model.review()
        }
        await gate.waitUntilArrived()
        task.cancel()
        await gate.open()
        await task.value

        #expect(model.state == fallback)
        #expect(await probe.evidence().decisions.isEmpty)
    }
}

private extension CollectionBlockedOutcomeReviewModelTests {
    static let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let generation = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let authority = SessionAuthority(userID: userID, generation: generation)
    static let operationID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let laterOperationID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let newOperationID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    static let deviceState = CollectionSnapshot(
        ownedVolumes: [1, 3],
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
    static let mangaSnapshot = CollectionMangaSnapshot(
        mangaID: 42,
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
        coverURL: nil
    )
    static let operation = CollectionBlockedOutcomeOperationReference(
        authority: authority,
        operationID: operationID,
        userID: userID,
        mangaID: 42,
        sequence: 1,
        retryCount: 0,
        desiredState: deviceState
    )
    static let review = CollectionBlockedOutcomeReview(
        context: CollectionBlockedOutcomeContext(
            operation: operation,
            deviceState: deviceState,
            mangaSnapshot: mangaSnapshot,
            laterIntent: nil
        ),
        evidence: .present(state: remoteState, mangaSnapshot: mangaSnapshot)
    )
    static let laterIntentReview = CollectionBlockedOutcomeReview(
        context: CollectionBlockedOutcomeContext(
            operation: operation,
            deviceState: deviceState,
            mangaSnapshot: mangaSnapshot,
            laterIntent: CollectionBlockedOutcomeLaterIntent(
                operationID: laterOperationID,
                sequence: 2,
                retryCount: 0,
                nextRetryAt: nil,
                state: .queued,
                desiredState: deviceState
            )
        ),
        evidence: review.evidence
    )

    static func model(
        probe: ReviewModelProbe,
        initialState: CollectionBlockedOutcomeReviewModel.State = .idle
    ) -> CollectionBlockedOutcomeReviewModel {
        CollectionBlockedOutcomeReviewModel(
            operationID: operationID,
            authority: authority,
            resolution: CollectionBlockedOutcomeResolution(
                review: { operationID, authority in
                    try await probe.review(operationID: operationID, authority: authority)
                },
                resolve: { review, decision in
                    try await probe.resolve(review: review, decision: decision)
                }
            ),
            initialState: initialState
        )
    }
}

private struct ReviewModelCall: Equatable {
    let operationID: UUID
    let authority: SessionAuthority
}

private struct ReviewModelEvidence: Equatable {
    let reviewCalls: [ReviewModelCall]
    let decisions: [CollectionBlockedOutcomeDecision]
}

private actor ReviewModelProbe {
    enum ResolveBehavior {
        case success(CollectionBlockedOutcomeStoreResolution)
        case failure(CollectionBlockedOutcomeError)
    }

    private let suppliedReview: CollectionBlockedOutcomeReview
    private let resolveBehavior: ResolveBehavior
    private let reviewGate: ReviewModelGate?
    private var reviewCalls: [ReviewModelCall] = []
    private var decisions: [CollectionBlockedOutcomeDecision] = []

    init(
        review: CollectionBlockedOutcomeReview,
        resolveBehavior: ResolveBehavior = .success(.effectAlreadyConfirmed),
        reviewGate: ReviewModelGate? = nil
    ) {
        suppliedReview = review
        self.resolveBehavior = resolveBehavior
        self.reviewGate = reviewGate
    }

    func review(
        operationID: UUID,
        authority: SessionAuthority
    ) async throws(any Error) -> CollectionBlockedOutcomeReview {
        reviewCalls.append(ReviewModelCall(operationID: operationID, authority: authority))
        if let reviewGate {
            await reviewGate.suspend()
        }
        return suppliedReview
    }

    func resolve(
        review: CollectionBlockedOutcomeReview,
        decision: CollectionBlockedOutcomeDecision
    ) throws(any Error) -> CollectionBlockedOutcomeStoreResolution {
        decisions.append(decision)
        switch resolveBehavior {
        case let .success(result):
            return result
        case let .failure(error):
            throw error
        }
    }

    func evidence() -> ReviewModelEvidence {
        ReviewModelEvidence(reviewCalls: reviewCalls, decisions: decisions)
    }
}

private actor ReviewModelGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var hasArrived = false

    func suspend() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            hasArrived = true
        }
    }

    func waitUntilArrived() async {
        while hasArrived == false {
            await Task.yield()
        }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}
