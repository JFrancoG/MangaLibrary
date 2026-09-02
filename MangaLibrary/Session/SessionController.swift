//
//  SessionController.swift
//  MangaLibrary
//

import Foundation

struct SessionAccount: Equatable {
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
    case transitionInProgress
    case sessionChanged
    case notAuthenticated
    case unavailable
    case network(NetworkError)
    case contractDrift
}

/// Owns remote authentication, generation fencing and shared access refresh.
actor SessionController {
    typealias Clock = @Sendable () -> Date
    typealias GenerationFactory = @Sendable () -> UUID

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
        let task: Task<SessionCredential, any Error>
    }

    private struct RejectedRequest {
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
    private let commitGate = SessionCommitGate()

    private var state = State.notRestored
    private var restoreFlight: RestoreFlight?
    private var refreshFlight: RefreshFlight?
    private var activeRefreshIdentity: OperationIdentity?
    private var activeLoginIdentity: OperationIdentity?
    private var committingLoginIdentity: OperationIdentity?
    private var pendingTransition: PendingTransition?
    private var rejectedRequestDuringTransition: RejectedRequest?

    init(
        apiClient: SessionAPIClient,
        persistence: SessionPersistenceActor,
        now: @escaping Clock,
        makeGeneration: @escaping GenerationFactory
    ) {
        self.apiClient = apiClient
        self.persistence = persistence
        self.now = now
        self.makeGeneration = makeGeneration
    }

    func currentSnapshot() -> SessionSnapshot {
        snapshot(for: state)
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

    /// Completes refresh → access → `/me` before writing one complete Keychain record.
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

        do {
            let refresh = try await apiClient.login(email: email, password: password)
            try ensureCurrentLogin(identity)
            let access = try await apiClient.exchangeAccess(refreshToken: refresh.value)
            try ensureCurrentLogin(identity)
            let remoteIdentity = try await apiClient.fetchIdentity(accessToken: access.value)
            try ensureCurrentLogin(identity)
            try Task.checkCancellation()

            committingLoginIdentity = identity
            let persisted = try await persistence.activate(
                userID: remoteIdentity.id,
                generation: makeGeneration(),
                access: access,
                refresh: refresh,
                replacing: replacedAuthority
            )
            try ensureCurrentLogin(identity)

            let account = SessionAccount(
                id: remoteIdentity.id,
                email: remoteIdentity.email,
                isActive: remoteIdentity.isActive,
                isAdmin: remoteIdentity.isAdmin,
                role: remoteIdentity.role
            )
            commitGate.activate(persisted.authority)
            rejectedRequestDuringTransition = nil
            state = .active(AuthenticatedState(session: persisted, account: account))
            clearLogin(identity)
            return .active(account)
        } catch {
            let wasSuperseded = activeLoginIdentity !== identity
            clearLogin(identity)
            if wasSuperseded { throw SessionControllerError.sessionChanged }
            try Task.checkCancellation()
            throw map(error, invalidCredentialsOnUnauthorized: true)
        }
    }

    /// Returns an unexpired access credential, sharing one refresh across callers.
    func accessCredential() async throws(any Error) -> SessionCredential {
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
        guard case let .active(authenticated) = state else {
            if case .authenticationRequired = state {
                throw SessionControllerError.authenticationRequired
            }
            throw SessionControllerError.notAuthenticated
        }

        let currentTime = now()
        if authenticated.session.access.expiresAt > currentTime {
            return authenticated.session.access
        }
        if authenticated.session.refresh.expiresAt <= currentTime {
            try await requireAuthentication(expected: authenticated.session.authority)
            throw SessionControllerError.authenticationRequired
        }
        if let refreshFlight {
            return try await awaitRefresh(flight: refreshFlight)
        }

        let identity = OperationIdentity()
        activeRefreshIdentity = identity
        let task = Task<SessionCredential, any Error> {
            try await self.performRefresh(expected: authenticated, identity: identity)
        }
        let flight = RefreshFlight(identity: identity, task: task)
        refreshFlight = flight
        return try await awaitRefresh(flight: flight)
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
        guard pendingTransition == nil, isActive(authority: expectedAuthority) else {
            throw SessionControllerError.sessionChanged
        }

        return SessionRequestAuthorization(
            authority: expectedAuthority,
            accessToken: credential.value,
            commitAuthorization: commitGate.authorization(for: expectedAuthority)
        )
    }

    /// Revalidates that a suspended request still belongs to the active generation.
    func authorizes(_ authority: SessionAuthority) -> Bool {
        pendingTransition == nil
            && isActive(authority: authority)
            && commitGate.authorizes(authority)
    }

    /// Returns a commit capability only for the currently active local scope.
    func commitAuthorization(for userID: UUID) -> SessionCommitAuthorization? {
        guard
            pendingTransition == nil,
            case let .active(authenticated) = state,
            authenticated.session.userID == userID,
            commitGate.authorizes(authenticated.session.authority)
        else { return nil }

        return commitGate.authorization(for: authenticated.session.authority)
    }

    /// Invalidates only the exact access credential rejected by a protected request.
    func rejectAuthorization(_ authorization: SessionRequestAuthorization) async throws(any Error) {
        guard
            case let .active(authenticated) = state,
            authenticated.session.authority == authorization.authority,
            authenticated.session.access.value == authorization.accessToken
        else { throw SessionControllerError.sessionChanged }

        if pendingTransition != nil {
            rejectedRequestDuringTransition = RejectedRequest(
                authority: authorization.authority,
                accessToken: authorization.accessToken
            )
            commitGate.invalidate(authorization.authority)
            return
        }
        guard activeRefreshIdentity == nil else { throw SessionControllerError.sessionChanged }

        try await requireAuthentication(expected: authorization.authority)
    }

    /// Signs out by deleting the exact current Keychain generation.
    func logout() async throws(any Error) -> SessionSnapshot {
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
        guard case let .active(authenticated) = state else { throw SessionControllerError.notAuthenticated }
        try Task.checkCancellation()

        let transition = PendingTransition.logout(authenticated.session.authority)
        pendingTransition = transition
        commitGate.invalidate(authenticated.session.authority)
        do {
            guard try await persistence.remove(expected: authenticated.session.authority) else {
                throw SessionControllerError.sessionChanged
            }
            guard pendingTransition == transition, isActive(authority: authenticated.session.authority) else {
                clearPendingTransition(transition)
                throw SessionControllerError.sessionChanged
            }

            pendingTransition = nil
            rejectedRequestDuringTransition = nil
            state = .signedOut
            return .signedOut
        } catch {
            clearPendingTransition(transition)
            throw map(error)
        }
    }

    private func performRestore() async throws(any Error) -> SessionSnapshot {
        let restoration = try await persistence.restore()
        apply(restoration)

        guard case let .active(authenticated) = state else { return snapshot(for: state) }

        do {
            let access = try await accessCredential()
            let identity = try await apiClient.fetchIdentity(accessToken: access.value)
            guard isActive(authority: authenticated.session.authority) else { return snapshot(for: state) }
            guard identity.id == authenticated.account.id else {
                try await requireAuthentication(expected: authenticated.session.authority)
                return snapshot(for: state)
            }

            let account = SessionAccount(
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
                 .transitionInProgress, .sessionChanged, .notAuthenticated:
                throw error
            }
        } catch let error as SessionAPIClientError {
            switch error {
            case let .network(.statusCode(code)) where code == 401 || code == 403:
                try await requireAuthentication(expected: authenticated.session.authority)
            case .network, .unavailable, .contractDrift:
                break
            }
        }
        return snapshot(for: state)
    }

    private func performRefresh(
        expected authenticated: AuthenticatedState,
        identity: OperationIdentity
    ) async throws(any Error) -> SessionCredential {
        defer { clearActiveRefresh(identity) }
        let access: SessionCredential
        do {
            access = try await apiClient.exchangeAccess(refreshToken: authenticated.session.refresh.value)
        } catch let error as SessionAPIClientError {
            if case let .network(.statusCode(code)) = error, code == 401 || code == 403 {
                try await requireAuthentication(expected: authenticated.session.authority)
                throw SessionControllerError.authenticationRequired
            }
            throw error
        }

        guard isActive(authority: authenticated.session.authority) else { throw SessionControllerError.sessionChanged }
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
        guard let renewed = try await persistence.replaceAccess(
            access,
            expected: authenticated.session.authority
        ) else {
            throw SessionControllerError.sessionChanged
        }
        guard isActive(authority: authenticated.session.authority) else { throw SessionControllerError.sessionChanged }

        state = .active(AuthenticatedState(session: renewed, account: authenticated.account))
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
        return renewed.access
    }

    private func requireAuthentication(expected authority: SessionAuthority) async throws(SessionControllerError) {
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
        guard isActive(authority: authority) else { throw SessionControllerError.sessionChanged }

        let transition = PendingTransition.authenticationInvalidation(authority)
        pendingTransition = transition
        commitGate.invalidate(authority)
        do {
            guard try await persistence.remove(expected: authority) else {
                throw SessionControllerError.sessionChanged
            }
            guard pendingTransition == transition, isActive(authority: authority) else {
                clearPendingTransition(transition)
                throw SessionControllerError.sessionChanged
            }

            pendingTransition = nil
            rejectedRequestDuringTransition = nil
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
            try Task.checkCancellation()
            throw map(error)
        }
    }

    private func awaitRefresh(flight: RefreshFlight) async throws(any Error) -> SessionCredential {
        do {
            let credential = try await flight.task.value
            clearRefresh(flight.identity)
            try Task.checkCancellation()
            return credential
        } catch {
            clearRefresh(flight.identity)
            try Task.checkCancellation()
            throw map(error)
        }
    }

    private func apply(_ restoration: SessionRestoration) {
        switch restoration {
        case .signedOut:
            commitGate.invalidateAll()
            rejectedRequestDuringTransition = nil
            state = .signedOut
        case let .active(session):
            commitGate.activate(session.authority)
            rejectedRequestDuringTransition = nil
            state = .active(
                AuthenticatedState(
                    session: session,
                    account: SessionAccount(
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

    private func requireAuthenticationInMemory(ifCurrent authority: SessionAuthority) {
        guard isActive(authority: authority) else { return }
        commitGate.invalidate(authority)
        state = .authenticationRequired(authority)
    }

    private func ensureCurrentLogin(_ identity: OperationIdentity) throws(SessionControllerError) {
        guard activeLoginIdentity === identity else { throw SessionControllerError.sessionChanged }
    }

    private func clearLogin(_ identity: OperationIdentity) {
        if activeLoginIdentity === identity { activeLoginIdentity = nil }
        if committingLoginIdentity === identity { committingLoginIdentity = nil }
    }

    private func clearPendingTransition(_ transition: PendingTransition) {
        guard pendingTransition == transition else { return }

        pendingTransition = nil
        if let rejectedRequestDuringTransition {
            self.rejectedRequestDuringTransition = nil
            if case let .active(authenticated) = state,
               authenticated.session.authority == rejectedRequestDuringTransition.authority,
               authenticated.session.access.value == rejectedRequestDuringTransition.accessToken {
                requireAuthenticationInMemory(ifCurrent: rejectedRequestDuringTransition.authority)
                return
            }
        }
        if case let .active(authenticated) = state {
            commitGate.activate(authenticated.session.authority)
        }
    }

    private func clearRestore(_ identity: OperationIdentity) {
        if restoreFlight?.identity === identity { restoreFlight = nil }
    }

    private func clearRefresh(_ identity: OperationIdentity) {
        if refreshFlight?.identity === identity { refreshFlight = nil }
    }

    private func clearActiveRefresh(_ identity: OperationIdentity) {
        if activeRefreshIdentity === identity { activeRefreshIdentity = nil }
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
