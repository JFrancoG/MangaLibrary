//
//  SessionController.swift
//  MangaLibrary
//

import Foundation
import OSLog

struct SessionAccount: Equatable {
    let authority: SessionAuthority
    let id: UUID
    let email: String?
    let isActive: Bool?
    let isAdmin: Bool?
    let role: String?
}

enum SessionSnapshot: Equatable {
    case notRestored
    case signedOut
    case active(SessionAccount)
    case authenticationRequired(UUID)
}

enum SessionControllerError: Error, Equatable {
    case invalidCredentials
    case authenticationRequired
    case temporarilyUnavailable
    case persistenceUnavailable
    case pendingCollectionPersistenceUnavailable
    case pendingCollectionChanges
    case transitionInProgress
    case sessionChanged
    case notAuthenticated
    case unavailable
    case network(NetworkError)
    case contractDrift
}

/// A renewed JWT was issued but could not validate the same session identity.
///
/// The status is safe diagnostic metadata. No credential, request or response payload
/// crosses this boundary, and this error does not by itself invalidate the previous JWT.
enum SessionAuthorizationRecoveryError: Error, Equatable {
    case identityRejected(statusCode: Int)
}

/// Owns remote authentication, generation fencing and shared JWT refresh.
actor SessionController {
    typealias Clock = @Sendable () -> Date
    typealias GenerationFactory = @Sendable () -> UUID
    typealias SynchronizationObserver = @Sendable (SynchronizationPoint) async -> Void
    typealias AuthenticationInvalidationObserver = @Sendable (
        SessionInvalidationAuthorization
    ) async throws(any Error) -> Void
    typealias LogoutPendingChangesObserver = @Sendable (SessionLogoutAuthorization) async throws(any Error) -> Bool
    typealias LogoutPendingChangesDiscarder = @Sendable (SessionLogoutAuthorization) async throws(any Error) -> Void

    enum SynchronizationPoint: Hashable {
        case accessCredentialAwaitingRefresh
        case accessCredentialResolvedRefresh
        case authorizationRecoveryResolvedRefresh
        case authorizationRecoveryAwaitingRefresh
        case localAuthorizationAwaitingRefresh
        case restorationAwaitingRefresh
    }

    private struct AuthenticatedState {
        let session: SessionPersistedSession
        let account: SessionAccount
    }

    private enum State {
        case notRestored
        case signedOut
        case active(AuthenticatedState)
        case authenticationRequired(SessionAuthority)
    }

    private final class OperationIdentity {}

    private struct RestoreFlight {
        let identity: OperationIdentity
        let task: Task<SessionSnapshot, any Error>
    }

    private struct RefreshFlight {
        let identity: OperationIdentity
        let replacing: RejectedRequest
        let task: Task<SessionCredential, any Error>
    }

    private struct AccessCredentialResolution {
        let credential: SessionCredential
        let validatedIdentity: Bool
    }

    private struct RejectedRequest: Equatable {
        let authority: SessionAuthority
        let accessToken: String
    }

    private enum PendingTransition: Equatable {
        case logout(SessionAuthority)
        case authenticationInvalidation(SessionAuthority)
    }

    private let apiClient: SessionAPIClient
    private let persistence: SessionPersistenceActor
    private let now: Clock
    private let makeGeneration: GenerationFactory
    private let renewalWindow: TimeInterval
    private let commitGate: SessionCommitGate
    private let synchronizationObserver: SynchronizationObserver
    private let authenticationInvalidationObserver: AuthenticationInvalidationObserver
    private let logoutPendingChangesObserver: LogoutPendingChangesObserver
    private let logoutPendingChangesDiscarder: LogoutPendingChangesDiscarder

    private static let logger = Logger(subsystem: "com.plusprojects.MangaLibrary", category: "Session")

    private var state = State.notRestored
    private var restoreFlight: RestoreFlight?
    private var refreshFlight: RefreshFlight?
    private var activeLoginIdentity: OperationIdentity?
    private var committingLoginIdentity: OperationIdentity?
    private var committingRefreshIdentity: OperationIdentity?
    private var pendingTransition: PendingTransition?
    private var rejectedRequest: RejectedRequest?
    private var rejectedRequestDuringTransition: RejectedRequest?

    init(
        apiClient: SessionAPIClient,
        persistence: SessionPersistenceActor,
        now: @escaping Clock,
        makeGeneration: @escaping GenerationFactory,
        renewalWindow: TimeInterval = 5 * 60,
        synchronizationObserver: @escaping SynchronizationObserver = { _ in },
        logoutPendingChangesObserver: @escaping LogoutPendingChangesObserver,
        logoutPendingChangesDiscarder: @escaping LogoutPendingChangesDiscarder,
        authenticationInvalidationObserver: @escaping AuthenticationInvalidationObserver
    ) {
        self.apiClient = apiClient
        self.persistence = persistence
        self.now = now
        self.makeGeneration = makeGeneration
        self.renewalWindow = renewalWindow
        self.synchronizationObserver = synchronizationObserver
        self.logoutPendingChangesObserver = logoutPendingChangesObserver
        self.logoutPendingChangesDiscarder = logoutPendingChangesDiscarder
        self.authenticationInvalidationObserver = authenticationInvalidationObserver
        commitGate = SessionCommitGate(now: now)
    }

    func currentSnapshot() -> SessionSnapshot {
        if case let .authenticationInvalidation(authority) = pendingTransition {
            return .authenticationRequired(authority.userID)
        }

        return snapshot(for: state)
    }

    /// Restores durable authority once and opportunistically refreshes account details.
    ///
    /// Multiple callers await one session-level task. Cancelling one waiter does
    /// not cancel restoration needed by the rest of the app.
    func restore() async throws(any Error) -> SessionSnapshot {
        if let restoreFlight {
            return try await awaitRestore(flight: restoreFlight)
        }
        guard case .notRestored = state else { return snapshot(for: state) }

        let identity = OperationIdentity()
        let task = Task<SessionSnapshot, any Error> { try await self.performRestore() }
        let flight = RestoreFlight(identity: identity, task: task)
        restoreFlight = flight
        return try await awaitRestore(flight: flight)
    }

    /// Completes JWT login → `/me` before writing one complete Keychain record.
    func login(email: String, password: String) async throws(any Error) -> SessionSnapshot {
        guard committingLoginIdentity == nil else { throw SessionControllerError.transitionInProgress }
        let replacedAuthority: SessionAuthority?
        switch state {
        case .signedOut:
            replacedAuthority = nil
        case let .authenticationRequired(authority):
            replacedAuthority = authority
        case .notRestored, .active:
            throw SessionControllerError.transitionInProgress
        }

        let identity = OperationIdentity()
        activeLoginIdentity = identity
        var expiredCredentialCleanupError: SessionControllerError?

        do {
            let access = try await apiClient.login(email: email, password: password)
            try ensureCurrentLogin(identity)
            guard access.expiresAt > now() else { throw SessionControllerError.contractDrift }
            let remoteIdentity = try await apiClient.fetchIdentity(accessToken: access.value)
            try ensureCurrentLogin(identity)
            guard access.expiresAt > now() else { throw SessionControllerError.contractDrift }
            try Task.checkCancellation()
            committingLoginIdentity = identity
            let persisted = try await persistence.activate(
                userID: remoteIdentity.id,
                generation: makeGeneration(),
                access: access,
                replacing: replacedAuthority
            )
            try ensureCurrentLogin(identity)
            guard persisted.access.expiresAt > now() else {
                let removed: Bool
                do {
                    removed = try await persistence.remove(expected: persisted.authority)
                } catch {
                    publishAuthenticationRequired(for: persisted.authority)
                    let mappedError = map(error)
                    expiredCredentialCleanupError = mappedError
                    throw mappedError
                }
                guard removed else { throw SessionControllerError.sessionChanged }
                throw SessionControllerError.contractDrift
            }

            let account = SessionAccount(
                authority: persisted.authority,
                id: remoteIdentity.id,
                email: remoteIdentity.email,
                isActive: remoteIdentity.isActive,
                isAdmin: remoteIdentity.isAdmin,
                role: remoteIdentity.role
            )
            activateCommitGate(for: persisted)
            rejectedRequest = nil
            rejectedRequestDuringTransition = nil
            state = .active(AuthenticatedState(session: persisted, account: account))
            clearLogin(identity)
            return .active(account)
        } catch {
            let wasSuperseded = activeLoginIdentity !== identity
            clearLogin(identity)
            if wasSuperseded { throw SessionControllerError.sessionChanged }
            if let expiredCredentialCleanupError {
                throw expiredCredentialCleanupError
            }
            try Task.checkCancellation()
            throw map(error, invalidCredentialsOnUnauthorized: true)
        }
    }

    /// Returns an unexpired JWT, sharing one preventive refresh across callers.
    func accessCredential() async throws(any Error) -> SessionCredential {
        let expectedAuthority: SessionAuthority?
        if case let .active(authenticated) = state {
            expectedAuthority = authenticated.session.authority
        } else {
            expectedAuthority = nil
        }
        let resolution = try await resolveAccessCredential()
        guard let expectedAuthority else { throw SessionControllerError.sessionChanged }
        let resolvedCommitAuthorization = commitGate.authorization(for: expectedAuthority)
        if resolution.validatedIdentity {
            await synchronizationObserver(.accessCredentialResolvedRefresh)
        }
        let resolvedRequest = RejectedRequest(authority: expectedAuthority, accessToken: resolution.credential.value)
        guard
            pendingTransition == nil,
            case let .active(current) = state,
            current.session.authority == expectedAuthority,
            current.session.access == resolution.credential,
            rejectedRequest != resolvedRequest,
            refreshFlight?.replacing != resolvedRequest,
            commitGate.authorizes(resolvedCommitAuthorization)
        else { throw SessionControllerError.sessionChanged }
        guard resolution.credential.expiresAt > now() else {
            try await requireAuthentication(expected: expectedAuthority)
            throw SessionControllerError.authenticationRequired
        }

        return resolution.credential
    }

    private func resolveAccessCredential() async throws(any Error) -> AccessCredentialResolution {
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
        guard case let .active(authenticated) = state else {
            if case .authenticationRequired = state {
                throw SessionControllerError.authenticationRequired
            }
            throw SessionControllerError.notAuthenticated
        }

        let currentRequest = rejectedRequest(for: authenticated)
        if let refreshFlight, refreshFlight.replacing == currentRequest {
            await synchronizationObserver(.accessCredentialAwaitingRefresh)
            let credential = try await awaitRefresh(flight: refreshFlight)
            return AccessCredentialResolution(credential: credential, validatedIdentity: true)
        }
        if let rejectedRequest, rejectedRequest != currentRequest {
            self.rejectedRequest = nil
        }
        if rejectedRequest == currentRequest {
            let credential = try await refreshCredential(for: authenticated)
            return AccessCredentialResolution(credential: credential, validatedIdentity: true)
        }

        let currentTime = now()
        if authenticated.session.access.expiresAt <= currentTime {
            try await requireAuthentication(expected: authenticated.session.authority)
            throw SessionControllerError.authenticationRequired
        }
        if authenticated.session.access.expiresAt.timeIntervalSince(currentTime) > renewalWindow {
            return AccessCredentialResolution(credential: authenticated.session.access, validatedIdentity: false)
        }
        let credential = try await refreshCredential(for: authenticated)
        return AccessCredentialResolution(credential: credential, validatedIdentity: true)
    }

    /// Authorizes one remote request and captures the exact session generation.
    ///
    /// A caller can use ``authorizes(_:)`` as a fast rejection after suspension;
    /// the returned commit capability is the authoritative persistence fence.
    func requestAuthorization() async throws(any Error) -> SessionRequestAuthorization {
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
        guard case let .active(authenticated) = state else {
            if case .authenticationRequired = state { throw SessionControllerError.authenticationRequired }

            throw SessionControllerError.notAuthenticated
        }
        let expectedAuthority = authenticated.session.authority
        let credential = try await accessCredential()
        if let authorization = try makeRequestAuthorization(
            credential: credential,
            expectedAuthority: expectedAuthority
        ) {
            return authorization
        }
        try await requireAuthentication(expected: expectedAuthority)
        throw SessionControllerError.authenticationRequired
    }

    /// Revalidates that a suspended request still owns the exact active JWT.
    func authorizes(_ authorization: SessionRequestAuthorization) async throws(SessionControllerError) -> Bool {
        guard
            pendingTransition == nil,
            case let .active(authenticated) = state,
            authenticated.session.authority == authorization.authority,
            authenticated.session.access.value == authorization.accessToken
        else { return false }

        let request = rejectedRequest(for: authorization)
        if refreshFlight?.replacing == request {
            return false
        }
        guard authenticated.session.access.expiresAt > now() else {
            try await requireAuthentication(expected: authorization.authority)
            return false
        }
        return rejectedRequest != request
            && commitGate.authorizes(authorization.commitAuthorization)
    }

    /// Returns a commit capability only for the currently active local scope.
    func commitAuthorization(
        for expectedAuthority: SessionAuthority
    ) async throws(any Error) -> SessionCommitAuthorization? {
        guard
            pendingTransition == nil,
            case let .active(authenticated) = state,
            authenticated.session.authority == expectedAuthority
        else { return nil }

        let request = rejectedRequest(for: authenticated)
        if let refreshFlight, refreshFlight.replacing == request {
            await synchronizationObserver(.localAuthorizationAwaitingRefresh)
            do {
                _ = try await awaitRefresh(flight: refreshFlight)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard
                    pendingTransition == nil,
                    case let .active(current) = state,
                    current.session.authority == expectedAuthority,
                    current.session.access.expiresAt > now(),
                    commitGate.authorizes(expectedAuthority)
                else { throw error }
            }
        }

        guard
            pendingTransition == nil,
            case let .active(current) = state,
            current.session.authority == expectedAuthority
        else { throw SessionControllerError.sessionChanged }
        guard current.session.access.expiresAt > now() else {
            try await requireAuthentication(expected: expectedAuthority)
            return nil
        }
        guard commitGate.authorizes(expectedAuthority) else { return nil }

        return commitGate.authorization(for: expectedAuthority)
    }

    /// Replaces the exact JWT rejected by a protected request.
    ///
    /// The refresh remains single-flight even when the rejected JWT has not
    /// expired. The renewed credential must resolve the same `/me` identity before
    /// it can replace the Keychain envelope or authorize a retry.
    func recoverAuthorization(
        after authorization: SessionRequestAuthorization
    ) async throws(any Error) -> SessionRequestAuthorization {
        guard
            case let .active(authenticated) = state,
            authenticated.session.authority == authorization.authority,
            authenticated.session.access.value == authorization.accessToken
        else { throw SessionControllerError.sessionChanged }

        let rejectedRequest = rejectedRequest(for: authorization)
        if pendingTransition != nil {
            guard commitGate.matches(authorization.commitAuthorization) else {
                throw SessionControllerError.sessionChanged
            }
            rejectedRequestDuringTransition = rejectedRequest
            throw SessionControllerError.transitionInProgress
        }
        guard commitGate.authorizes(authorization.commitAuthorization) else {
            throw SessionControllerError.sessionChanged
        }
        self.rejectedRequest = rejectedRequest

        var credential: SessionCredential
        if let refreshFlight, refreshFlight.replacing == rejectedRequest {
            credential = try await awaitRefresh(flight: refreshFlight)
        } else {
            credential = try await refreshCredential(for: authenticated)
        }
        await synchronizationObserver(.authorizationRecoveryResolvedRefresh)
        while let refreshFlight {
            let currentRequest = RejectedRequest(authority: authorization.authority, accessToken: credential.value)
            guard refreshFlight.replacing == currentRequest else { break }
            await synchronizationObserver(.authorizationRecoveryAwaitingRefresh)
            credential = try await awaitRefresh(flight: refreshFlight)
        }

        if let authorization = try makeRequestAuthorization(
            credential: credential,
            expectedAuthority: authorization.authority
        ) {
            return authorization
        }
        try await requireAuthentication(expected: authorization.authority)
        throw SessionControllerError.authenticationRequired
    }

    /// Signs out after resolving the exact user's pending Collection work.
    ///
    /// The first attempt inspects the outbox while normal commits are suspended. If work remains,
    /// the session is reactivated and presentation must obtain an explicit discard decision. A
    /// confirmed discard uses a fresh logout capability before deleting the exact Keychain generation.
    func logout(discardPendingChanges: Bool = false) async throws(any Error) -> SessionSnapshot {
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
        guard committingRefreshIdentity == nil else { throw SessionControllerError.transitionInProgress }
        guard case let .active(authenticated) = state else { throw SessionControllerError.notAuthenticated }
        try Task.checkCancellation()

        let transition = PendingTransition.logout(authenticated.session.authority)
        pendingTransition = transition
        do {
            guard let logoutAuthorization = commitGate.suspendForLogout(authenticated.session.authority) else {
                throw SessionControllerError.sessionChanged
            }
            if discardPendingChanges {
                try await logoutPendingChangesDiscarder(logoutAuthorization)
            } else {
                let hasPendingChanges = try await logoutPendingChangesObserver(logoutAuthorization)
                try Task.checkCancellation()
                if hasPendingChanges { throw SessionControllerError.pendingCollectionChanges }
            }

            guard try await persistence.remove(expected: authenticated.session.authority) else {
                throw SessionControllerError.sessionChanged
            }
            guard pendingTransition == transition, isActive(authority: authenticated.session.authority) else {
                clearPendingTransition(transition)
                throw SessionControllerError.sessionChanged
            }

            pendingTransition = nil
            rejectedRequest = nil
            rejectedRequestDuringTransition = nil
            commitGate.invalidate(authenticated.session.authority)
            state = .signedOut
            return .signedOut
        } catch {
            if
                pendingTransition == transition,
                isActive(authority: authenticated.session.authority),
                authenticated.session.access.expiresAt <= now()
            {
                pendingTransition = nil
                requireAuthenticationInMemory(ifCurrent: authenticated.session.authority)
            } else {
                clearPendingTransition(transition)
            }
            if error is CancellationError { throw CancellationError() }
            throw map(error)
        }
    }

    private func performRestore() async throws(any Error) -> SessionSnapshot {
        let restoration = try await persistence.restore()
        apply(restoration)

        guard case let .active(authenticated) = state else { return snapshot(for: state) }
        var identityAuthorization: SessionRequestAuthorization?

        do {
            let resolution = try await resolveAccessCredential()
            let request = RejectedRequest(
                authority: authenticated.session.authority,
                accessToken: resolution.credential.value
            )
            try await awaitCoincidentRefresh(replacing: request)
            guard isActive(request: request) else { return snapshot(for: state) }
            guard resolution.credential.expiresAt > now() else {
                try await requireAuthentication(expected: request.authority)
                return snapshot(for: state)
            }
            if resolution.validatedIdentity {
                return snapshot(for: state)
            }

            guard let authorization = try makeRequestAuthorization(
                credential: resolution.credential,
                expectedAuthority: request.authority
            ) else {
                try await requireAuthentication(expected: request.authority)
                return snapshot(for: state)
            }
            identityAuthorization = authorization
            let identity = try await apiClient.fetchIdentity(accessToken: resolution.credential.value)
            try await awaitCoincidentRefresh(replacing: request)
            guard isActive(authorization: authorization) else { return snapshot(for: state) }
            guard resolution.credential.expiresAt > now() else {
                try await requireAuthentication(expected: request.authority)
                return snapshot(for: state)
            }
            guard identity.id == authenticated.account.id else {
                try await requireAuthentication(expected: authenticated.session.authority)
                return snapshot(for: state)
            }

            let account = SessionAccount(
                authority: request.authority,
                id: identity.id,
                email: identity.email,
                isActive: identity.isActive,
                isAdmin: identity.isAdmin,
                role: identity.role
            )
            guard case let .active(current) = state else { return snapshot(for: state) }
            state = .active(AuthenticatedState(session: current.session, account: account))
        } catch let error as SessionControllerError {
            switch error {
            case .authenticationRequired:
                break
            case .network, .unavailable, .contractDrift:
                break
            case .invalidCredentials, .temporarilyUnavailable, .persistenceUnavailable,
                 .pendingCollectionPersistenceUnavailable,
                 .pendingCollectionChanges,
                 .transitionInProgress, .sessionChanged, .notAuthenticated:
                throw error
            }
        } catch let error as SessionAPIClientError {
            if let identityAuthorization {
                let identityRequest = rejectedRequest(for: identityAuthorization)
                try await awaitCoincidentRefresh(replacing: identityRequest)
                guard isActive(authorization: identityAuthorization) else { return snapshot(for: state) }
                guard case let .active(current) = state else { return snapshot(for: state) }
                guard current.session.access.expiresAt > now() else {
                    try await requireAuthentication(expected: identityRequest.authority)
                    return snapshot(for: state)
                }
            }
            switch error {
            case let .network(.statusCode(code)) where code == 401 || code == 403:
                try await requireAuthentication(expected: authenticated.session.authority)
            case .network, .unavailable, .contractDrift:
                break
            }
        }
        return snapshot(for: state)
    }

    private func awaitCoincidentRefresh(replacing request: RejectedRequest) async throws(any Error) {
        guard let refreshFlight, refreshFlight.replacing == request else { return }

        await synchronizationObserver(.restorationAwaitingRefresh)
        do {
            _ = try await awaitRefresh(flight: refreshFlight)
        } catch let error as SessionControllerError
            where error == .temporarilyUnavailable || error == .persistenceUnavailable {
            throw error
        } catch {
            try Task.checkCancellation()
        }
    }

    private func refreshCredential(for authenticated: AuthenticatedState) async throws(any Error) -> SessionCredential {
        if authenticated.session.access.expiresAt <= now() {
            try await requireAuthentication(expected: authenticated.session.authority)
            throw SessionControllerError.authenticationRequired
        }

        let identity = OperationIdentity()
        let replacing = rejectedRequest(for: authenticated)
        let task = Task<SessionCredential, any Error> {
            try await self.performRefresh(expected: authenticated)
        }
        let flight = RefreshFlight(identity: identity, replacing: replacing, task: task)
        refreshFlight = flight
        return try await awaitRefresh(flight: flight)
    }

    private func performRefresh(
        expected authenticated: AuthenticatedState
    ) async throws(any Error) -> SessionCredential {
        let request = rejectedRequest(for: authenticated)
        try ensureCurrentRefresh(request)
        guard authenticated.session.access.expiresAt > now() else {
            try await requireAuthentication(expected: authenticated.session.authority)
            throw SessionControllerError.authenticationRequired
        }

        let access: SessionCredential
        do {
            access = try await apiClient.refresh(token: authenticated.session.access.value)
        } catch let error as SessionAPIClientError {
            try ensureCurrentRefresh(request)
            if case let .network(.statusCode(code)) = error, code == 401 || code == 403 {
                Self.logger.error(
                    "Session authorization rejected: origin=jwtRefresh status=\(code, privacy: .public) action=authenticationRequired"
                )
                try await requireAuthentication(expected: authenticated.session.authority)
                throw SessionControllerError.authenticationRequired
            }
            try await requireAuthenticationIfExpired(authenticated)
            throw error
        }

        try ensureCurrentRefresh(request)
        guard access.expiresAt > now() else {
            try await requireAuthenticationIfExpired(authenticated)
            throw SessionControllerError.contractDrift
        }
        let account: SessionAccount
        do {
            account = try await validatedAccount(
                accessToken: access.value,
                expectedAuthority: authenticated.session.authority
            )
        } catch let error as SessionControllerError {
            throw error
        } catch {
            try ensureCurrentRefresh(request)
            try await requireAuthenticationIfExpired(authenticated)
            throw error
        }
        try ensureCurrentRefresh(request)
        guard access.expiresAt > now() else {
            try await requireAuthenticationIfExpired(authenticated)
            throw SessionControllerError.contractDrift
        }
        let commitIdentity = OperationIdentity()
        guard committingRefreshIdentity == nil else { throw SessionControllerError.transitionInProgress }
        committingRefreshIdentity = commitIdentity
        let replacement: SessionPersistedSession?
        do {
            replacement = try await persistence.replaceAccess(access, expected: authenticated.session.authority)
            clearRefreshCommit(commitIdentity)
        } catch {
            clearRefreshCommit(commitIdentity)
            try ensureCurrentRefresh(request)
            try await requireAuthenticationIfExpired(authenticated)
            throw error
        }
        guard let renewed = replacement else { throw SessionControllerError.sessionChanged }
        try ensureCurrentRefresh(request)
        guard renewed.access.expiresAt > now() else {
            try await requireAuthentication(expected: renewed.authority)
            throw SessionControllerError.authenticationRequired
        }

        activateCommitGate(for: renewed)
        state = .active(AuthenticatedState(session: renewed, account: account))
        rejectedRequest = nil
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
        return renewed.access
    }

    private func validatedAccount(
        accessToken: String,
        expectedAuthority: SessionAuthority
    ) async throws(any Error) -> SessionAccount {
        let identity: SessionIdentity
        do {
            identity = try await apiClient.fetchIdentity(accessToken: accessToken)
        } catch let error as SessionAPIClientError {
            if case let .network(.statusCode(statusCode)) = error,
               statusCode == 401 || statusCode == 403 {
                throw SessionAuthorizationRecoveryError.identityRejected(statusCode: statusCode)
            }
            throw error
        }

        guard isActive(authority: expectedAuthority) else { throw SessionControllerError.sessionChanged }
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
        guard identity.id == expectedAuthority.userID else {
            try await requireAuthentication(expected: expectedAuthority)
            throw SessionControllerError.authenticationRequired
        }

        return SessionAccount(
            authority: expectedAuthority,
            id: identity.id,
            email: identity.email,
            isActive: identity.isActive,
            isAdmin: identity.isAdmin,
            role: identity.role
        )
    }

    private func requireAuthenticationIfExpired(
        _ authenticated: AuthenticatedState
    ) async throws(SessionControllerError) {
        guard authenticated.session.access.expiresAt <= now() else { return }

        try await requireAuthentication(expected: authenticated.session.authority)
        throw SessionControllerError.authenticationRequired
    }

    private func requireAuthentication(expected authority: SessionAuthority) async throws(SessionControllerError) {
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
        guard committingRefreshIdentity == nil else { throw SessionControllerError.transitionInProgress }
        guard isActive(authority: authority) else { throw SessionControllerError.sessionChanged }

        let transition = PendingTransition.authenticationInvalidation(authority)
        pendingTransition = transition
        do {
            guard let invalidationAuthorization = commitGate.suspendForAuthenticationInvalidation(authority) else {
                throw SessionControllerError.sessionChanged
            }
            do {
                try await authenticationInvalidationObserver(invalidationAuthorization)
            } catch {
                Self.logger.error("Session invalidation observer failed; authentication cleanup continues")
            }
            guard try await persistence.remove(expected: authority) else {
                throw SessionControllerError.sessionChanged
            }
            guard pendingTransition == transition, isActive(authority: authority) else {
                clearPendingTransition(transition)
                throw SessionControllerError.sessionChanged
            }

            pendingTransition = nil
            rejectedRequest = nil
            rejectedRequestDuringTransition = nil
            commitGate.invalidate(authority)
            state = .authenticationRequired(authority)
        } catch {
            requireAuthenticationInMemory(ifCurrent: authority)
            clearPendingTransition(transition)
            throw map(error)
        }
    }

    private func awaitRestore(flight: RestoreFlight) async throws(any Error) -> SessionSnapshot {
        do {
            let result = try await flight.task.value
            clearRestore(flight.identity)
            try Task.checkCancellation()
            return result
        } catch {
            clearRestore(flight.identity)
            let mappedError = map(error)
            if mappedError == .temporarilyUnavailable || mappedError == .persistenceUnavailable {
                throw mappedError
            }
            try Task.checkCancellation()
            throw mappedError
        }
    }

    private func awaitRefresh(flight: RefreshFlight) async throws(any Error) -> SessionCredential {
        do {
            let credential = try await flight.task.value
            clearRefresh(flight.identity)
            try Task.checkCancellation()
            return credential
        } catch let error as SessionAuthorizationRecoveryError {
            clearRefresh(flight.identity)
            try Task.checkCancellation()
            throw error
        } catch {
            clearRefresh(flight.identity)
            let mappedError = map(error)
            if mappedError == .temporarilyUnavailable || mappedError == .persistenceUnavailable {
                throw mappedError
            }
            try Task.checkCancellation()
            throw mappedError
        }
    }

    private func apply(_ restoration: SessionRestoration) {
        switch restoration {
        case .signedOut:
            commitGate.invalidateAll()
            rejectedRequest = nil
            rejectedRequestDuringTransition = nil
            state = .signedOut
        case let .active(session):
            activateCommitGate(for: session)
            rejectedRequest = nil
            rejectedRequestDuringTransition = nil
            state = .active(
                AuthenticatedState(
                    session: session,
                    account: SessionAccount(
                        authority: session.authority,
                        id: session.userID,
                        email: nil,
                        isActive: nil,
                        isAdmin: nil,
                        role: nil
                    )
                )
            )
        }
    }

    private func snapshot(for state: State) -> SessionSnapshot {
        switch state {
        case .notRestored:
            .notRestored
        case .signedOut:
            .signedOut
        case let .active(authenticated):
            .active(authenticated.account)
        case let .authenticationRequired(authority):
            .authenticationRequired(authority.userID)
        }
    }

    private func isActive(authority: SessionAuthority) -> Bool {
        guard case let .active(authenticated) = state else { return false }
        return authenticated.session.authority == authority
    }

    private func isActive(request: RejectedRequest) -> Bool {
        guard case let .active(authenticated) = state else { return false }
        return authenticated.session.authority == request.authority
            && authenticated.session.access.value == request.accessToken
    }

    private func isActive(authorization: SessionRequestAuthorization) -> Bool {
        isActive(request: rejectedRequest(for: authorization))
            && commitGate.authorizes(authorization.commitAuthorization)
    }

    private func ensureCurrentRefresh(_ request: RejectedRequest) throws(SessionControllerError) {
        guard isActive(request: request) else { throw SessionControllerError.sessionChanged }
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
    }

    private func makeRequestAuthorization(
        credential: SessionCredential,
        expectedAuthority: SessionAuthority
    ) throws(SessionControllerError) -> SessionRequestAuthorization? {
        let request = RejectedRequest(authority: expectedAuthority, accessToken: credential.value)
        guard
            case let .active(authenticated) = state,
            authenticated.session.authority == expectedAuthority,
            authenticated.session.access == credential
        else { throw SessionControllerError.sessionChanged }
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
        guard rejectedRequest != request else { throw SessionControllerError.sessionChanged }
        guard refreshFlight?.replacing != request else { throw SessionControllerError.sessionChanged }
        guard credential.expiresAt > now() else { return nil }
        guard commitGate.authorizes(expectedAuthority) else { throw SessionControllerError.sessionChanged }

        return SessionRequestAuthorization(
            authority: expectedAuthority,
            accessToken: credential.value,
            commitAuthorization: commitGate.authorization(for: expectedAuthority)
        )
    }

    private func rejectedRequest(for authenticated: AuthenticatedState) -> RejectedRequest {
        RejectedRequest(authority: authenticated.session.authority, accessToken: authenticated.session.access.value)
    }

    private func rejectedRequest(for authorization: SessionRequestAuthorization) -> RejectedRequest {
        RejectedRequest(authority: authorization.authority, accessToken: authorization.accessToken)
    }

    private func requireAuthenticationInMemory(ifCurrent authority: SessionAuthority) {
        guard isActive(authority: authority) else { return }
        commitGate.invalidate(authority)
        rejectedRequest = nil
        rejectedRequestDuringTransition = nil
        state = .authenticationRequired(authority)
    }

    private func publishAuthenticationRequired(for authority: SessionAuthority) {
        commitGate.invalidateAll()
        rejectedRequest = nil
        rejectedRequestDuringTransition = nil
        state = .authenticationRequired(authority)
    }

    private func ensureCurrentLogin(_ identity: OperationIdentity) throws(SessionControllerError) {
        guard activeLoginIdentity === identity else { throw SessionControllerError.sessionChanged }
    }

    private func clearLogin(_ identity: OperationIdentity) {
        if activeLoginIdentity === identity { activeLoginIdentity = nil }
        if committingLoginIdentity === identity { committingLoginIdentity = nil }
    }

    private func clearRefreshCommit(_ identity: OperationIdentity) {
        if committingRefreshIdentity === identity {
            committingRefreshIdentity = nil
        }
    }

    private func clearPendingTransition(_ transition: PendingTransition) {
        guard pendingTransition == transition else { return }

        pendingTransition = nil
        if let rejectedRequestDuringTransition {
            self.rejectedRequestDuringTransition = nil
            if case let .active(authenticated) = state,
               authenticated.session.authority == rejectedRequestDuringTransition.authority,
               authenticated.session.access.value == rejectedRequestDuringTransition.accessToken {
                rejectedRequest = rejectedRequestDuringTransition
            }
        }
        if case let .active(authenticated) = state {
            activateCommitGate(for: authenticated.session)
        }
    }

    private func activateCommitGate(for session: SessionPersistedSession) {
        commitGate.activate(session.authority, expiresAt: session.access.expiresAt)
    }

    private func clearRestore(_ identity: OperationIdentity) {
        if restoreFlight?.identity === identity { restoreFlight = nil }
    }

    private func clearRefresh(_ identity: OperationIdentity) {
        if refreshFlight?.identity === identity { refreshFlight = nil }
    }

    private func map(_ error: any Error, invalidCredentialsOnUnauthorized: Bool = false) -> SessionControllerError {
        if let error = error as? SessionControllerError { return error }
        if let error = error as? SessionAPIClientError {
            switch error {
            case .unavailable:
                return .unavailable
            case let .network(.statusCode(code))
                where invalidCredentialsOnUnauthorized && (code == 401 || code == 403):
                return .invalidCredentials
            case let .network(error):
                return .network(error)
            case .contractDrift:
                return .contractDrift
            }
        }
        if let error = error as? SessionStorageError {
            return error == .temporarilyUnavailable ? .temporarilyUnavailable : .persistenceUnavailable
        }
        if let error = error as? SessionPersistenceError, error == .transitionBlocked {
            return .transitionInProgress
        }
        return .unavailable
    }
}
