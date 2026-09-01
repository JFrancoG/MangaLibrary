//
//  SessionController.swift
//  MangaLibrary
//

import Foundation

struct SessionAccount: Equatable, Sendable {
    let id: UUID
    let email: String?
    let isActive: Bool?
    let isAdmin: Bool?
    let role: String?
}

enum SessionSnapshot: Equatable, Sendable {
    case notRestored
    case signedOut
    case active(SessionAccount)
    case authenticationRequired(UUID)
}

enum SessionControllerError: Error, Equatable, Sendable {
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

    private enum PendingTransition: Equatable {
        case logout(SessionAuthority)
        case authenticationInvalidation(SessionAuthority)
    }

    private let apiClient: SessionAPIClient
    private let persistence: SessionPersistenceActor
    private let now: Clock
    private let makeGeneration: GenerationFactory

    private var state = State.notRestored
    private var restoreFlight: RestoreFlight?
    private var refreshFlight: RefreshFlight?
    private var activeLoginIdentity: OperationIdentity?
    private var committingLoginIdentity: OperationIdentity?
    private var pendingTransition: PendingTransition?

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
        let task = Task<SessionCredential, any Error> {
            try await self.performRefresh(expected: authenticated)
        }
        let flight = RefreshFlight(identity: identity, task: task)
        refreshFlight = flight
        return try await awaitRefresh(flight: flight)
    }

    /// Signs out by deleting the exact current Keychain generation.
    func logout() async throws(any Error) -> SessionSnapshot {
        guard pendingTransition == nil else { throw SessionControllerError.transitionInProgress }
        guard case let .active(authenticated) = state else { throw SessionControllerError.notAuthenticated }
        try Task.checkCancellation()

        let transition = PendingTransition.logout(authenticated.session.authority)
        pendingTransition = transition
        do {
            guard try await persistence.remove(expected: authenticated.session.authority) else {
                throw SessionControllerError.sessionChanged
            }
            guard pendingTransition == transition, isActive(authority: authenticated.session.authority) else {
                clearPendingTransition(transition)
                throw SessionControllerError.sessionChanged
            }

            pendingTransition = nil
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
        expected authenticated: AuthenticatedState
    ) async throws(any Error) -> SessionCredential {
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
        do {
            guard try await persistence.remove(expected: authority) else {
                throw SessionControllerError.sessionChanged
            }
            guard pendingTransition == transition, isActive(authority: authority) else {
                clearPendingTransition(transition)
                throw SessionControllerError.sessionChanged
            }

            pendingTransition = nil
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
            state = .signedOut
        case let .active(session):
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
        if pendingTransition == transition { pendingTransition = nil }
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
