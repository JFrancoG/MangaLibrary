//
//  AccountModel.swift
//  MangaLibrary
//

import Foundation
import Observation

/// Projects the session actor into safe states for the Account feature.
///
/// The model never stores credentials. It normalizes email at the semantic
/// boundary and passes the password only through the current sign-in operation.
    /// Every asynchronous intent carries an identity so a late response cannot
    /// replace the current presentation. Sign-in itself remains single-action.
@Observable @MainActor
final class AccountModel {
    struct Operations: Sendable {
        let currentSnapshot: @Sendable () async -> SessionSnapshot
        let restore: @Sendable () async throws(any Error) -> SessionSnapshot
        let login: @Sendable (String, String) async throws(any Error) -> SessionSnapshot
        let logout: @Sendable () async throws(any Error) -> SessionSnapshot
        let retryLogout: @Sendable () async throws(any Error) -> SessionSnapshot
        let cancelLogout: @Sendable () async throws(any Error) -> SessionSnapshot
        let retryCleanup: @Sendable () async throws(any Error) -> SessionSnapshot

        static func live(controller: SessionController) -> Self {
            Self(
                currentSnapshot: { [controller] in
                    await controller.currentSnapshot()
                },
                restore: { [controller] in
                    try await controller.restore()
                },
                login: { [controller] email, password in
                    try await controller.login(
                        email: email,
                        password: password
                    )
                },
                logout: { [controller] in
                    try await controller.logout()
                },
                retryLogout: { [controller] in
                    try await controller.retryLogout()
                },
                cancelLogout: { [controller] in
                    try await controller.cancelLogout()
                },
                retryCleanup: { [controller] in
                    try await controller.retryCleanup()
                }
            )
        }
    }

    enum Failure: Equatable {
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

        var errorDescriptionResource: LocalizedStringResource {
            switch self {
            case .invalidCredentials:
                "The email or password is incorrect."
            case .authenticationRequired:
                "Sign in again to continue."
            case .temporarilyUnavailable:
                "Protected session data is temporarily unavailable."
            case .persistenceUnavailable:
                "The session could not be saved securely."
            case .transitionInProgress:
                "Another account action is already in progress."
            case .sessionChanged:
                "The session changed while the action was in progress."
            case .notAuthenticated:
                "Sign in to continue."
            case .unavailable:
                "The account service is temporarily unavailable."
            case let .network(error):
                error.errorDescriptionResource
            case .contractDrift:
                "The server response has an unexpected format."
            }
        }
    }

    enum State: Equatable {
        case restoring
        case restorationFailed(failure: Failure)
        case signedOut(failure: Failure?)
        case authenticating
        case authenticated(SessionAccount, notice: Failure?)
        case authenticationRequired(userID: UUID, failure: Failure?)
        case signingOut(SessionAccount)
        case logoutPrepared(SessionAccount, failure: Failure?)
        case resolvingLogout(SessionAccount)
        case cleaning(
            userID: UUID,
            completion: SessionCleanupCompletion,
            failure: Failure?
        )
    }

    private final class OperationIdentity {}

    private(set) var state: State

    @ObservationIgnored private let operations: Operations
    @ObservationIgnored private var activeOperationIdentity: OperationIdentity?

    init(initialState: State = .restoring, operations: Operations) {
        state = initialState
        self.operations = operations
    }

    func restore() async {
        switch state {
        case .restoring, .restorationFailed:
            break
        case .signedOut, .authenticating, .authenticated,
             .authenticationRequired, .signingOut, .logoutPrepared,
             .resolvingLogout, .cleaning:
            return
        }
        guard activeOperationIdentity == nil else {
            return
        }

        let fallback = state
        let identity = beginOperation()
        state = .restoring

        await resolve(
            identity: identity,
            fallback: fallback,
            operation: operations.restore
        )
    }

    func signIn(email: String, password: String) async {
        guard canSubmitSignIn(email: email, password: password) else {
            return
        }

        let fallback: State
        switch state {
        case .signedOut, .authenticationRequired:
            fallback = state
        case .restoring, .restorationFailed, .authenticating, .authenticated,
             .signingOut, .logoutPrepared, .resolvingLogout, .cleaning:
            return
        }

        let normalizedEmail = Self.normalizedEmail(email)
        let identity = beginOperation()
        state = .authenticating

        await resolve(
            identity: identity,
            fallback: fallback,
            operation: {
                try await operations.login(normalizedEmail, password)
            }
        )
    }

    func canSubmitSignIn(email: String, password: String) -> Bool {
        Self.normalizedEmail(email).isEmpty == false
            && password.isEmpty == false
    }

    func signOut() async {
        guard case let .authenticated(account, _) = state else {
            return
        }

        let fallback = state
        let identity = beginOperation()
        state = .signingOut(account)

        await resolve(
            identity: identity,
            fallback: fallback,
            operation: operations.logout
        )
    }

    func retryLogout() async {
        guard case let .logoutPrepared(account, _) = state else {
            return
        }

        let fallback = state
        let identity = beginOperation()
        state = .signingOut(account)

        await resolve(
            identity: identity,
            fallback: fallback,
            operation: operations.retryLogout
        )
    }

    func cancelLogout() async {
        guard case let .logoutPrepared(account, _) = state else {
            return
        }

        let fallback = state
        let identity = beginOperation()
        state = .resolvingLogout(account)

        await resolve(
            identity: identity,
            fallback: fallback,
            operation: operations.cancelLogout
        )
    }

    func retryCleanup() async {
        guard case let .cleaning(userID, completion, _) = state else {
            return
        }

        let fallback = state
        let identity = beginOperation()
        state = .cleaning(
            userID: userID,
            completion: completion,
            failure: nil
        )

        await resolve(
            identity: identity,
            fallback: fallback,
            operation: operations.retryCleanup
        )
    }

    private func resolve(
        identity: OperationIdentity,
        fallback: State,
        operation: () async throws(any Error) -> SessionSnapshot
    ) async {
        do {
            let snapshot = try await operation()
            try Task.checkCancellation()
            guard isCurrent(identity) else {
                return
            }
            apply(snapshot, failure: nil)
            finish(identity)
        } catch is CancellationError {
            await recoverAfterCancellation(
                identity: identity,
                fallback: fallback
            )
        } catch {
            await recover(
                identity: identity,
                fallback: fallback,
                failure: Self.map(error)
            )
        }
    }

    private func recoverAfterCancellation(identity: OperationIdentity, fallback: State) async {
        let snapshot = await operations.currentSnapshot()
        guard isCurrent(identity) else {
            return
        }

        if snapshot == .notRestored {
            state = fallback
        } else {
            apply(snapshot, failure: nil)
        }
        finish(identity)
    }

    private func recover(identity: OperationIdentity, fallback: State, failure: Failure) async {
        let snapshot = await operations.currentSnapshot()
        guard isCurrent(identity) else {
            return
        }

        if snapshot == .notRestored {
            state = Self.applying(failure, to: fallback)
        } else {
            apply(snapshot, failure: failure)
        }
        finish(identity)
    }

    private func apply(_ snapshot: SessionSnapshot, failure: Failure?) {
        switch snapshot {
        case .notRestored:
            state = .restoring
        case .signedOut:
            state = .signedOut(failure: failure)
        case let .active(account):
            state = .authenticated(account, notice: failure)
        case let .logoutPrepared(account):
            state = .logoutPrepared(account, failure: failure)
        case let .cleaning(userID, completion):
            state = .cleaning(
                userID: userID,
                completion: completion,
                failure: failure
            )
        case let .authenticationRequired(userID):
            state = .authenticationRequired(
                userID: userID,
                failure: failure
            )
        }
    }

    private func beginOperation() -> OperationIdentity {
        let identity = OperationIdentity()
        activeOperationIdentity = identity
        return identity
    }

    private func isCurrent(_ identity: OperationIdentity) -> Bool {
        activeOperationIdentity === identity
    }

    private func finish(_ identity: OperationIdentity) {
        guard activeOperationIdentity === identity else {
            return
        }
        activeOperationIdentity = nil
    }

    private static func applying(_ failure: Failure, to fallback: State) -> State {
        switch fallback {
        case .restoring, .restorationFailed:
            .restorationFailed(failure: failure)
        case .signedOut, .authenticating:
            .signedOut(failure: failure)
        case let .authenticated(account, _), let .signingOut(account):
            .authenticated(account, notice: failure)
        case let .authenticationRequired(userID, _):
            .authenticationRequired(userID: userID, failure: failure)
        case let .logoutPrepared(account, _), let .resolvingLogout(account):
            .logoutPrepared(account, failure: failure)
        case let .cleaning(userID, completion, _):
            .cleaning(
                userID: userID,
                completion: completion,
                failure: failure
            )
        }
    }

    private static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func map(_ error: any Error) -> Failure {
        guard let error = error as? SessionControllerError else {
            return .unavailable
        }

        return switch error {
        case .invalidCredentials:
            .invalidCredentials
        case .authenticationRequired:
            .authenticationRequired
        case .temporarilyUnavailable:
            .temporarilyUnavailable
        case .persistenceUnavailable:
            .persistenceUnavailable
        case .transitionInProgress:
            .transitionInProgress
        case .sessionChanged:
            .sessionChanged
        case .notAuthenticated:
            .notAuthenticated
        case .unavailable:
            .unavailable
        case let .network(error):
            .network(error)
        case .contractDrift:
            .contractDrift
        }
    }
}
