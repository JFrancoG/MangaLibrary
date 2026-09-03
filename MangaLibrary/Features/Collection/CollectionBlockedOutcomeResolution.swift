//
//  CollectionBlockedOutcomeResolution.swift
//  MangaLibrary
//

import Foundation
import OSLog

/// The complete durable identity reviewed before resolving one uncertain write.
struct CollectionBlockedOutcomeOperationReference: Equatable {
    let authority: SessionAuthority
    let operationID: UUID
    let userID: UUID
    let mangaID: Manga.ID
    let sequence: Int64
    let retryCount: Int
    let desiredState: CollectionSnapshot
}

/// A later safely-unsent intent whose precedence must survive resolution of N.
struct CollectionBlockedOutcomeLaterIntent: Equatable {
    let operationID: UUID
    let sequence: Int64
    let retryCount: Int
    let nextRetryAt: Date?
    let state: CollectionOutboxState
    let desiredState: CollectionSnapshot
}

/// The local values shown by R2.4 and fenced again inside its final transaction.
struct CollectionBlockedOutcomeContext: Equatable {
    let operation: CollectionBlockedOutcomeOperationReference
    let deviceState: CollectionSnapshot
    let mangaSnapshot: CollectionMangaSnapshot?
    let laterIntent: CollectionBlockedOutcomeLaterIntent?

    var hasLaterIntent: Bool { laterIntent != nil }
}

/// A fresh, compatible result from the individual Collection GET.
enum CollectionBlockedOutcomeEvidence: Equatable {
    case absent
    case present(state: CollectionSnapshot, mangaSnapshot: CollectionMangaSnapshot)

    func proves(_ desiredState: CollectionSnapshot) -> Bool {
        switch self {
        case .absent:
            desiredState.isTombstone
        case let .present(state, _):
            desiredState.isTombstone == false && state == desiredState
        }
    }
}

enum CollectionBlockedOutcomeDecision: Equatable {
    case useRemote
    case keepDevice
}

/// The committed effect used to decide whether an unchanged N+1 needs a wake.
enum CollectionBlockedOutcomeStoreResolution: Equatable {
    case adoptedRemote
    case effectAlreadyConfirmed
    case createdIntent(operationID: UUID, sequence: Int64)
    case continuedExistingIntent(operationID: UUID, sequence: Int64)
}

enum CollectionBlockedOutcomeError: Error, Equatable {
    case sessionChanged
    case staleOperation
    case laterIntentRequiresDeviceVersion
    case incompatibleLocalState
    case incompatibleRemoteState
    case authorizationDenied(statusCode: Int)
    case authenticationIncompatible(statusCode: Int)
    case unavailable
    case sequenceExhausted
    case persistenceConflict
    case cancelled
    case remoteChanged(CollectionBlockedOutcomeEvidence)
}

struct CollectionBlockedOutcomeReview: Equatable {
    let context: CollectionBlockedOutcomeContext
    let evidence: CollectionBlockedOutcomeEvidence

    func replacingEvidence(_ evidence: CollectionBlockedOutcomeEvidence) -> Self {
        Self(context: context, evidence: evidence)
    }
}

/// Performs fresh individual reads and delegates the final commit to the model actor.
///
/// The coordinator never retains a credential in presentation state. A decision
/// resolves a newly authorized request, repeats the safe GET once, and commits
/// only if both local and remote evidence still match the reviewed values.
actor CollectionOutcomeResolutionCoordinator {
    typealias Authorize = @Sendable () async throws(any Error) -> SessionRequestAuthorization
    typealias ValidateAuthorization = @Sendable (SessionRequestAuthorization) async throws(any Error) -> Bool
    typealias RecoverAuthorization = @Sendable (
        SessionRequestAuthorization
    ) async throws(any Error) -> SessionRequestAuthorization
    typealias LoadContext = @Sendable (
        UUID,
        SessionCommitAuthorization
    ) async throws(any Error) -> CollectionBlockedOutcomeContext
    typealias FetchRemoteEntry = @Sendable (Manga.ID, String) async throws(any Error) -> CollectionRemoteEntry?
    typealias ValidateEvidence = @Sendable (
        CollectionRemoteEntry?,
        Manga.ID
    ) async throws(any Error) -> CollectionBlockedOutcomeEvidence
    typealias ResolveStore = @Sendable (
        CollectionBlockedOutcomeContext,
        CollectionBlockedOutcomeEvidence,
        CollectionBlockedOutcomeDecision,
        SessionCommitAuthorization,
        UUID
    ) async throws(any Error) -> CollectionBlockedOutcomeStoreResolution
    typealias OperationIDFactory = @Sendable () -> UUID

    private let authorize: Authorize
    private let validateAuthorization: ValidateAuthorization
    private let recoverAuthorization: RecoverAuthorization
    private let loadContext: LoadContext
    private let fetchRemoteEntry: FetchRemoteEntry
    private let validateEvidence: ValidateEvidence
    private let resolveStore: ResolveStore
    private let makeOperationID: OperationIDFactory

    private static let logger = Logger(
        subsystem: "com.plusprojects.MangaLibrary",
        category: "CollectionOutcomeResolution"
    )

    init(
        authorize: @escaping Authorize,
        validateAuthorization: @escaping ValidateAuthorization,
        recoverAuthorization: @escaping RecoverAuthorization,
        loadContext: @escaping LoadContext,
        fetchRemoteEntry: @escaping FetchRemoteEntry,
        validateEvidence: @escaping ValidateEvidence,
        resolveStore: @escaping ResolveStore,
        makeOperationID: @escaping OperationIDFactory = { UUID() }
    ) {
        self.authorize = authorize
        self.validateAuthorization = validateAuthorization
        self.recoverAuthorization = recoverAuthorization
        self.loadContext = loadContext
        self.fetchRemoteEntry = fetchRemoteEntry
        self.validateEvidence = validateEvidence
        self.resolveStore = resolveStore
        self.makeOperationID = makeOperationID
    }

    func review(
        operationID: UUID,
        expectedAuthority: SessionAuthority
    ) async throws(any Error) -> CollectionBlockedOutcomeReview {
        try Task.checkCancellation()
        let authorization = try await currentAuthorization(expectedAuthority: expectedAuthority)
        let context = try await loadContext(operationID, authorization.commitAuthorization)
        guard context.operation.authority == expectedAuthority else {
            throw CollectionBlockedOutcomeError.sessionChanged
        }
        let (evidence, _) = try await freshEvidence(mangaID: context.operation.mangaID, authorization: authorization)
        return CollectionBlockedOutcomeReview(context: context, evidence: evidence)
    }

    func resolve(
        _ review: CollectionBlockedOutcomeReview,
        decision: CollectionBlockedOutcomeDecision
    ) async throws(any Error) -> CollectionBlockedOutcomeStoreResolution {
        try Task.checkCancellation()
        let expectedAuthority = review.context.operation.authority
        var authorization = try await currentAuthorization(expectedAuthority: expectedAuthority)
        let currentContext = try await loadContext(
            review.context.operation.operationID,
            authorization.commitAuthorization
        )
        guard currentContext == review.context else { throw CollectionBlockedOutcomeError.staleOperation }

        let freshResult = try await freshEvidence(
            mangaID: review.context.operation.mangaID,
            authorization: authorization
        )
        let evidence = freshResult.evidence
        authorization = freshResult.authorization
        guard evidence == review.evidence else { throw CollectionBlockedOutcomeError.remoteChanged(evidence) }

        let resolution: CollectionBlockedOutcomeStoreResolution
        do {
            resolution = try await resolveStore(
                review.context,
                evidence,
                decision,
                authorization.commitAuthorization,
                makeOperationID()
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CollectionBlockedOutcomeError {
            if error == .cancelled {
                throw CancellationError()
            }
            throw error
        } catch {
            throw CollectionBlockedOutcomeError.persistenceConflict
        }

        return resolution
    }

    private func currentAuthorization(
        expectedAuthority: SessionAuthority
    ) async throws(any Error) -> SessionRequestAuthorization {
        do {
            let authorization = try await authorize()
            guard authorization.authority == expectedAuthority else {
                throw CollectionBlockedOutcomeError.sessionChanged
            }
            return authorization
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CollectionBlockedOutcomeError {
            throw error
        } catch let error as SessionAuthorizationRecoveryError {
            switch error {
            case let .identityRejected(statusCode):
                throw CollectionBlockedOutcomeError.authenticationIncompatible(statusCode: statusCode)
            }
        } catch let error as SessionControllerError {
            switch error {
            case .temporarilyUnavailable, .persistenceUnavailable, .unavailable, .network, .contractDrift:
                throw CollectionBlockedOutcomeError.unavailable
            case .invalidCredentials, .authenticationRequired, .transitionInProgress, .sessionChanged,
                 .notAuthenticated:
                throw CollectionBlockedOutcomeError.sessionChanged
            }
        } catch {
            throw CollectionBlockedOutcomeError.unavailable
        }
    }

    private func freshEvidence(
        mangaID: Manga.ID,
        authorization: SessionRequestAuthorization
    ) async throws(any Error) -> (
        evidence: CollectionBlockedOutcomeEvidence,
        authorization: SessionRequestAuthorization
    ) {
        var currentAuthorization = authorization
        let remoteEntry: CollectionRemoteEntry?
        do {
            remoteEntry = try await fetchRemoteEntry(mangaID, currentAuthorization.accessToken)
        } catch let error as CollectionAPIClientError {
            guard case let .network(.statusCode(statusCode)) = error else { throw mapReadError(error) }
            switch statusCode {
            case 401:
                Self.logger.notice("R2.4 access rejected: origin=individualCollection status=401 action=recover")
                currentAuthorization = try await recoveredAuthorization(after: currentAuthorization)
                do {
                    remoteEntry = try await fetchRemoteEntry(mangaID, currentAuthorization.accessToken)
                } catch is CancellationError {
                    throw CancellationError()
                } catch let retryError as CollectionBlockedOutcomeError {
                    throw retryError
                } catch let retryError as CollectionAPIClientError {
                    throw mapRetryError(retryError)
                } catch {
                    throw CollectionBlockedOutcomeError.unavailable
                }
            case 403:
                guard try await isCurrent(currentAuthorization) else {
                    throw CollectionBlockedOutcomeError.sessionChanged
                }
                Self.logger.error("R2.4 authorization denied: origin=individualCollection status=403")
                throw CollectionBlockedOutcomeError.authorizationDenied(statusCode: statusCode)
            default:
                throw CollectionBlockedOutcomeError.unavailable
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CollectionBlockedOutcomeError {
            throw error
        } catch {
            throw CollectionBlockedOutcomeError.unavailable
        }

        try Task.checkCancellation()
        guard try await isCurrent(currentAuthorization) else { throw CollectionBlockedOutcomeError.sessionChanged }
        let evidence: CollectionBlockedOutcomeEvidence
        do {
            evidence = try await validateEvidence(remoteEntry, mangaID)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CollectionBlockedOutcomeError {
            throw error
        } catch {
            throw CollectionBlockedOutcomeError.incompatibleRemoteState
        }
        try Task.checkCancellation()
        guard try await isCurrent(currentAuthorization) else { throw CollectionBlockedOutcomeError.sessionChanged }
        return (evidence, currentAuthorization)
    }

    private func isCurrent(_ authorization: SessionRequestAuthorization) async throws(any Error) -> Bool {
        do {
            return try await validateAuthorization(authorization)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CollectionBlockedOutcomeError {
            throw error
        } catch let error as SessionControllerError {
            switch error {
            case .temporarilyUnavailable, .persistenceUnavailable, .unavailable, .network, .contractDrift:
                throw CollectionBlockedOutcomeError.unavailable
            case .invalidCredentials, .authenticationRequired, .transitionInProgress, .sessionChanged,
                 .notAuthenticated:
                throw CollectionBlockedOutcomeError.sessionChanged
            }
        } catch {
            throw CollectionBlockedOutcomeError.unavailable
        }
    }

    private func recoveredAuthorization(
        after authorization: SessionRequestAuthorization
    ) async throws(any Error) -> SessionRequestAuthorization {
        do {
            let recovered = try await recoverAuthorization(authorization)
            guard recovered.authority == authorization.authority else {
                throw CollectionBlockedOutcomeError.sessionChanged
            }
            return recovered
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CollectionBlockedOutcomeError {
            throw error
        } catch let error as SessionAuthorizationRecoveryError {
            switch error {
            case let .identityRejected(statusCode):
                throw CollectionBlockedOutcomeError.authenticationIncompatible(statusCode: statusCode)
            }
        } catch let error as SessionControllerError {
            switch error {
            case .temporarilyUnavailable, .persistenceUnavailable, .unavailable, .network, .contractDrift:
                throw CollectionBlockedOutcomeError.unavailable
            case .invalidCredentials, .authenticationRequired, .transitionInProgress, .sessionChanged,
                 .notAuthenticated:
                throw CollectionBlockedOutcomeError.sessionChanged
            }
        } catch {
            throw CollectionBlockedOutcomeError.unavailable
        }
    }

    private func mapReadError(_ error: CollectionAPIClientError) -> CollectionBlockedOutcomeError {
        switch error {
        case .contractDrift, .invalidVolumeState, .duplicateRemoteID, .duplicateMangaID:
            .incompatibleRemoteState
        case .unavailable, .network:
            .unavailable
        }
    }

    private func mapRetryError(_ error: CollectionAPIClientError) -> CollectionBlockedOutcomeError {
        if case let .network(.statusCode(statusCode)) = error {
            switch statusCode {
            case 401:
                Self.logger.error("R2.4 authentication incompatible: origin=individualCollection status=401")
                return .authenticationIncompatible(statusCode: statusCode)
            case 403:
                Self.logger.error("R2.4 authorization denied: origin=individualCollection status=403 attempt=2")
                return .authorizationDenied(statusCode: statusCode)
            default:
                return .unavailable
            }
        }
        return mapReadError(error)
    }
}

/// The narrow, credential-free capability injected into R2.4 presentation.
struct CollectionBlockedOutcomeResolution {
    typealias Review = @Sendable (UUID, SessionAuthority) async throws(any Error) -> CollectionBlockedOutcomeReview
    typealias Resolve = @Sendable (
        CollectionBlockedOutcomeReview,
        CollectionBlockedOutcomeDecision
    ) async throws(any Error) -> CollectionBlockedOutcomeStoreResolution

    static let disabled = Self(
        review: { _, _ in
            throw CollectionBlockedOutcomeError.unavailable
        },
        resolve: { _, _ in
            throw CollectionBlockedOutcomeError.unavailable
        }
    )

    private let reviewOperation: Review
    private let resolveOperation: Resolve

    init(review: @escaping Review, resolve: @escaping Resolve) {
        reviewOperation = review
        resolveOperation = resolve
    }

    func review(
        operationID: UUID,
        expectedAuthority: SessionAuthority
    ) async throws(any Error) -> CollectionBlockedOutcomeReview {
        try await reviewOperation(operationID, expectedAuthority)
    }

    func resolve(
        _ review: CollectionBlockedOutcomeReview,
        decision: CollectionBlockedOutcomeDecision
    ) async throws(any Error) -> CollectionBlockedOutcomeStoreResolution {
        try await resolveOperation(review, decision)
    }
}

extension CollectionBlockedOutcomeResolution {
    init(coordinator: CollectionOutcomeResolutionCoordinator) {
        self.init(
            review: { operationID, authority in
                try await coordinator.review(operationID: operationID, expectedAuthority: authority)
            },
            resolve: { review, decision in
                try await coordinator.resolve(review, decision: decision)
            }
        )
    }
}

extension CollectionOutcomeResolutionCoordinator {
    init(sessionController: SessionController, client: CollectionAPIClient, mutationActor: CollectionMutationActor) {
        self.init(
            authorize: {
                try await sessionController.requestAuthorization()
            },
            validateAuthorization: { authorization in
                try await sessionController.authorizes(authorization)
            },
            recoverAuthorization: { authorization in
                try await sessionController.recoverAuthorization(after: authorization)
            },
            loadContext: { operationID, authorization in
                try await mutationActor.blockedOutcomeContext(operationID: operationID, authorization: authorization)
            },
            fetchRemoteEntry: { mangaID, accessToken in
                try await client.fetch(mangaID: mangaID, accessToken: accessToken)
            },
            validateEvidence: { remoteEntry, mangaID in
                try await mutationActor.blockedOutcomeEvidence(remoteEntry: remoteEntry, mangaID: mangaID)
            },
            resolveStore: { context, evidence, decision, authorization, operationID in
                try await mutationActor.resolveBlockedOutcome(
                    context,
                    evidence: evidence,
                    decision: decision,
                    authorization: authorization,
                    newOperationID: operationID
                )
            }
        )
    }
}
