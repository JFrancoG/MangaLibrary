//
//  CollectionBlockedOutcomeReviewModel.swift
//  MangaLibrary
//

import Foundation
import Observation

/// Owns the transient review and resolution workflow for one uncertain Collection write.
///
/// The model retains no credential or SwiftData model. Every attempt crosses the
/// injected semantic capability with stable value identities, and cancellation
/// restores the last safe presentation state without retaining a decision.
@Observable @MainActor
final class CollectionBlockedOutcomeReviewModel {
    enum State: Equatable {
        case idle
        case loading
        case ready(CollectionBlockedOutcomeReview)
        case resolving(CollectionBlockedOutcomeReview, decision: CollectionBlockedOutcomeDecision)
        case failed(Failure, review: CollectionBlockedOutcomeReview?)
        case resolved(CollectionBlockedOutcomeStoreResolution)
    }

    enum Failure: Equatable {
        case sessionChanged
        case operationUnavailable
        case moreRecentChange
        case incompatibleLocalState
        case incompatibleRemoteState
        case authorizationDenied
        case authenticationIncompatible
        case unavailable
        case sequenceExhausted
        case persistenceConflict
        case remoteChanged

        var canRetry: Bool {
            switch self {
            case .sessionChanged, .operationUnavailable, .incompatibleLocalState, .sequenceExhausted:
                false
            case .moreRecentChange, .incompatibleRemoteState, .authorizationDenied,
                 .authenticationIncompatible, .unavailable, .persistenceConflict, .remoteChanged:
                true
            }
        }
    }

    private final class RequestIdentity {}

    let operationID: UUID
    private(set) var state: State

    @ObservationIgnored private let authority: SessionAuthority
    @ObservationIgnored private let resolution: CollectionBlockedOutcomeResolution
    @ObservationIgnored private var activeRequestIdentity: RequestIdentity?

    init(
        operationID: UUID,
        authority: SessionAuthority,
        resolution: CollectionBlockedOutcomeResolution,
        initialState: State = .idle
    ) {
        self.operationID = operationID
        self.authority = authority
        self.resolution = resolution
        state = initialState
    }

    var isBusy: Bool {
        switch state {
        case .loading, .resolving:
            true
        case .idle, .ready, .failed, .resolved:
            false
        }
    }

    func reviewIfNeeded() async {
        guard case .idle = state else { return }

        await review()
    }

    func review() async {
        guard activeRequestIdentity == nil else { return }

        let fallback = state
        let identity = beginRequest()
        state = .loading

        do {
            let review = try await resolution.review(operationID: operationID, expectedAuthority: authority)
            guard Task.isCancelled == false else {
                restore(fallback, for: identity)
                return
            }
            guard finishRequest(identity) else { return }

            state = .ready(review)
        } catch {
            guard Task.isCancelled == false, isCancellation(error) == false else {
                restore(fallback, for: identity)
                return
            }
            guard finishRequest(identity) else { return }

            state = .failed(Self.failure(for: error), review: nil)
        }
    }

    func resolve(_ decision: CollectionBlockedOutcomeDecision) async -> Bool {
        guard activeRequestIdentity == nil, case let .ready(review) = state else { return false }
        guard decision != .useRemote || review.context.hasLaterIntent == false else {
            state = .failed(.moreRecentChange, review: review)
            return false
        }

        let fallback = state
        let identity = beginRequest()
        state = .resolving(review, decision: decision)

        do {
            let result = try await resolution.resolve(review, decision: decision)
            guard Task.isCancelled == false else {
                restore(fallback, for: identity)
                return false
            }
            guard finishRequest(identity) else { return false }

            state = .resolved(result)
            return true
        } catch {
            guard Task.isCancelled == false, isCancellation(error) == false else {
                restore(fallback, for: identity)
                return false
            }
            guard finishRequest(identity) else { return false }

            let failedReview: CollectionBlockedOutcomeReview
            if let error = error as? CollectionBlockedOutcomeError, case let .remoteChanged(evidence) = error {
                failedReview = review.replacingEvidence(evidence)
            } else {
                failedReview = review
            }
            state = .failed(Self.failure(for: error), review: failedReview)
            return false
        }
    }

    private func beginRequest() -> RequestIdentity {
        let identity = RequestIdentity()
        activeRequestIdentity = identity
        return identity
    }

    private func finishRequest(_ identity: RequestIdentity) -> Bool {
        guard activeRequestIdentity === identity else { return false }

        activeRequestIdentity = nil
        return true
    }

    private func restore(_ fallback: State, for identity: RequestIdentity) {
        guard finishRequest(identity) else { return }

        state = fallback
    }

    private func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError {
            return true
        }
        return error as? CollectionBlockedOutcomeError == .cancelled
    }

    private static func failure(for error: any Error) -> Failure {
        guard let error = error as? CollectionBlockedOutcomeError else { return .unavailable }

        return switch error {
        case .sessionChanged:
            .sessionChanged
        case .staleOperation:
            .operationUnavailable
        case .laterIntentRequiresDeviceVersion:
            .moreRecentChange
        case .incompatibleLocalState:
            .incompatibleLocalState
        case .incompatibleRemoteState:
            .incompatibleRemoteState
        case .authorizationDenied:
            .authorizationDenied
        case .authenticationIncompatible:
            .authenticationIncompatible
        case .unavailable:
            .unavailable
        case .sequenceExhausted:
            .sequenceExhausted
        case .persistenceConflict:
            .persistenceConflict
        case .remoteChanged:
            .remoteChanged
        case .cancelled:
            .unavailable
        }
    }
}
