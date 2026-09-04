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
    /// Sendable capabilities used to bridge the session actor and deterministic doubles.
    ///
    /// Registration remains separate so its App-Token never enters the session boundary.
    /// The struct's sendability is inferred from its stored `@Sendable` closures.
    struct Operations {
        typealias SnapshotOperation = @Sendable () async throws(any Error) -> SessionSnapshot
        typealias LogoutOperation = @Sendable (Bool) async throws(any Error) -> SessionSnapshot

        let currentSnapshot: @Sendable () async -> SessionSnapshot
        let restore: SnapshotOperation
        let login: @Sendable (String, String) async throws(any Error) -> SessionSnapshot
        let register: UserRegistrationClient.Operation
        let logout: LogoutOperation

        static func live(controller: SessionController, register: @escaping UserRegistrationClient.Operation) -> Self {
            Self(
                currentSnapshot: { await controller.currentSnapshot() },
                restore: { try await controller.restore() },
                login: { email, password in try await controller.login(email: email, password: password) },
                register: register,
                logout: { discardPendingChanges in
                    try await controller.logout(discardPendingChanges: discardPendingChanges)
                }
            )
        }
    }

    enum Failure: Equatable {
        case invalidCredentials
        case authenticationRequired
        case temporarilyUnavailable
        case persistenceUnavailable
        case pendingCollectionPersistenceUnavailable
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
            case .pendingCollectionPersistenceUnavailable:
                "Pending Collection changes could not be checked or discarded. Your local changes remain. Try again."
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

    enum CredentialValidationFailure: Equatable {
        case emailRequired
        case invalidEmail
        case passwordRequired
        case passwordTooShort

        var errorDescriptionResource: LocalizedStringResource {
            switch self {
            case .emailRequired:
                "Enter an email address."
            case .invalidEmail:
                "Enter a valid email address."
            case .passwordRequired:
                "Enter your password."
            case .passwordTooShort:
                "Password must contain at least 8 characters."
            }
        }
    }

    struct CredentialValidation: Equatable {
        let emailFailure: CredentialValidationFailure?
        let passwordFailure: CredentialValidationFailure?

        var isValid: Bool { emailFailure == nil && passwordFailure == nil }
    }

    enum State: Equatable {
        case restoring
        case restorationFailed(failure: Failure)
        case signedOut(failure: Failure?)
        case authenticating(previousUserID: UUID?)
        case authenticated(SessionAccount, notice: Failure?)
        case authenticationRequired(userID: UUID, failure: Failure?)
        case signingOut(SessionAccount)
    }

    enum RegistrationState: Equatable {
        case idle
        case submitting
        case signingIn
        case failed(UserRegistrationFailure)
        case created(loginFailure: Failure?)
        case unconfirmed(UserRegistrationFailure)
    }

    private final class OperationIdentity {}

    private final class ReconciliationContext {
        let identity: OperationIdentity
        let authority: SessionAuthority
        var failure: Failure?

        init(identity: OperationIdentity, authority: SessionAuthority, failure: Failure?) {
            self.identity = identity
            self.authority = authority
            self.failure = failure
        }
    }

    private(set) var state: State
    private(set) var registrationState: RegistrationState
    private(set) var showsPendingLogoutConfirmation: Bool

    @ObservationIgnored private let operations: Operations
    @ObservationIgnored private var activeOperationIdentity: OperationIdentity?
    @ObservationIgnored private var activeReconciliation: ReconciliationContext?
    @ObservationIgnored private var sessionAuthority: SessionAuthority?

    init(initialState: State = .restoring, registrationState: RegistrationState = .idle, operations: Operations) {
        state = initialState
        self.registrationState = registrationState
        showsPendingLogoutConfirmation = false
        self.operations = operations
        sessionAuthority = switch initialState {
        case let .authenticated(account, _), let .signingOut(account): account.authority
        case .restoring, .restorationFailed, .signedOut, .authenticating,
             .authenticationRequired: nil
        }
    }

    func register(email: String, password: String) async {
        guard
            Task.isCancelled == false,
            activeOperationIdentity == nil,
            canSubmitRegistration(email: email, password: password),
            case .signedOut = state
        else { return }

        switch registrationState {
        case .idle, .failed:
            break
        case .submitting, .signingIn, .created, .unconfirmed:
            return
        }

        let normalizedEmail = Self.normalizedEmail(email)
        let identity = beginOperation()
        registrationState = .submitting

        let submission = await operations.register(normalizedEmail, password)
        guard isCurrent(identity) else { return }

        switch submission {
        case let .notSubmitted(failure):
            registrationState = .failed(failure)
            finish(identity)
        case let .unconfirmed(failure):
            registrationState = .unconfirmed(failure)
            finish(identity)
        case .confirmed:
            registrationState = .signingIn

            guard Task.isCancelled == false else {
                registrationState = .created(loginFailure: nil)
                finish(identity)
                return
            }

            await signInAfterRegistration(identity: identity, email: normalizedEmail, password: password)
        }
    }

    func canSubmitRegistration(email: String, password: String) -> Bool {
        registrationValidation(email: email, password: password).isValid
    }

    func registrationValidation(email: String, password: String) -> CredentialValidation {
        Self.credentialValidation(email: email, password: password, minimumPasswordLength: 8)
    }

    func prepareRegistrationRetry() {
        guard case .unconfirmed = registrationState else { return }

        registrationState = .idle
    }

    /// Invalidates a registration workflow whose caller no longer owns its UI.
    ///
    /// A request suspended in transport becomes uncertain. Once the account was
    /// confirmed, cancellation remains owned by the automatic sign-in task so
    /// it can reconcile any durable session commit before presenting a result.
    func abandonRegistration() {
        switch registrationState {
        case .submitting:
            activeOperationIdentity = nil
            registrationState = .unconfirmed(.cancelled)
        case .idle, .failed, .signingIn, .created, .unconfirmed:
            break
        }
    }

    func restore() async {
        switch state {
        case .restoring, .restorationFailed:
            break
        case .signedOut, .authenticating, .authenticated,
             .authenticationRequired, .signingOut:
            return
        }
        guard activeOperationIdentity == nil else { return }

        let fallback = state
        let identity = beginOperation()
        state = .restoring

        await resolve(identity: identity, fallback: fallback, operation: operations.restore)
    }

    func signIn(email: String, password: String) async {
        guard
            Task.isCancelled == false,
            activeOperationIdentity == nil,
            canSubmitSignIn(email: email, password: password)
        else { return }

        let fallback: State
        let previousUserID: UUID?
        switch state {
        case .signedOut:
            fallback = state
            previousUserID = nil
        case let .authenticationRequired(userID, _):
            fallback = state
            previousUserID = userID
        case .restoring, .restorationFailed, .authenticating, .authenticated,
             .signingOut:
            return
        }

        let normalizedEmail = Self.normalizedEmail(email)
        let identity = beginOperation()
        state = .authenticating(previousUserID: previousUserID)

        await resolve(identity: identity, fallback: fallback) {
            try await operations.login(normalizedEmail, password)
        }
    }

    func canSubmitSignIn(email: String, password: String) -> Bool {
        signInValidation(email: email, password: password).isValid
    }

    func signInValidation(email: String, password: String) -> CredentialValidation {
        Self.credentialValidation(email: email, password: password, minimumPasswordLength: nil)
    }

    func signOut() async {
        guard case let .authenticated(account, _) = state else { return }

        let fallback = state
        let identity = beginOperation()
        showsPendingLogoutConfirmation = false
        state = .signingOut(account)

        do {
            let snapshot = try await operations.logout(false)
            try Task.checkCancellation()
            guard isCurrent(identity) else { return }
            apply(snapshot, failure: nil)
            finish(identity)
        } catch let error as SessionControllerError where error == .pendingCollectionChanges {
            await presentPendingLogoutDecision(identity: identity, fallback: fallback, account: account)
        } catch is CancellationError {
            await recoverAfterCancellation(identity: identity, fallback: fallback)
        } catch {
            await recover(identity: identity, fallback: fallback, failure: Self.map(error))
        }
    }

    /// Keeps the authenticated session active so the normal Collection worker can finish its work.
    func staySignedInWithPendingChanges() {
        showsPendingLogoutConfirmation = false
    }

    /// Reauthorizes and atomically discards unresolved Collection work before signing out.
    func discardPendingChangesAndSignOut() async {
        guard case let .authenticated(account, _) = state else { return }

        let fallback = state
        let identity = beginOperation()
        showsPendingLogoutConfirmation = false
        state = .signingOut(account)

        await resolve(identity: identity, fallback: fallback) {
            try await operations.logout(true)
        }
    }

    /// Reconciles a session transition discovered by Collection infrastructure.
    ///
    /// Transport and contract failures remain invisible to this local-first
    /// feature. Only an authoritative loss or replacement of the expected
    /// session changes Account presentation.
    func reconcileSession(expectedAuthority: SessionAuthority, cause: (any Error)? = nil) async {
        let incomingFailure = Self.reconciliationFailure(from: cause)
        if let activeReconciliation,
           activeOperationIdentity === activeReconciliation.identity,
           activeReconciliation.authority == expectedAuthority {
            activeReconciliation.failure = Self.mergingReconciliationFailure(
                incomingFailure,
                with: activeReconciliation.failure
            )
            return
        }
        if Self.isPersistenceFailure(incomingFailure),
           sessionAuthority == expectedAuthority,
           case let .authenticationRequired(userID, existingFailure) = state,
           userID == expectedAuthority.userID {
            state = .authenticationRequired(
                userID: userID,
                failure: Self.preferredReconciliationFailure(
                    incomingFailure,
                    over: existingFailure,
                    fallback: .authenticationRequired
                )
            )
            return
        }
        guard
            Task.isCancelled == false,
            activeOperationIdentity == nil,
            sessionAuthority == expectedAuthority,
            state.reconciliationUserID == expectedAuthority.userID
        else { return }

        let identity = beginOperation()
        let reconciliation = ReconciliationContext(
            identity: identity,
            authority: expectedAuthority,
            failure: incomingFailure
        )
        activeReconciliation = reconciliation
        defer {
            if activeReconciliation === reconciliation {
                activeReconciliation = nil
            }
            finish(identity)
        }
        let snapshot = await operations.currentSnapshot()
        guard
            Task.isCancelled == false || Self.isPersistenceFailure(reconciliation.failure),
            isCurrent(identity),
            sessionAuthority == expectedAuthority,
            state.reconciliationUserID == expectedAuthority.userID
        else { return }

        let existingFailure = state.reconciliationFailure
        let reconciledFailure = reconciliation.failure
        switch snapshot {
        case .notRestored:
            break
        case .signedOut:
            apply(snapshot, failure: reconciledFailure ?? .notAuthenticated)
        case let .active(activeAccount) where activeAccount.authority == expectedAuthority:
            if Self.isPersistenceFailure(reconciledFailure) {
                apply(
                    snapshot,
                    failure: Self.preferredReconciliationFailure(
                        reconciledFailure,
                        over: existingFailure,
                        fallback: .persistenceUnavailable
                    )
                )
            }
        case .active:
            apply(snapshot, failure: .sessionChanged)
        case .authenticationRequired:
            apply(
                snapshot,
                failure: Self.preferredReconciliationFailure(
                    reconciledFailure,
                    over: existingFailure,
                    fallback: .authenticationRequired
                )
            )
        }
    }

    private func resolve(
        identity: OperationIdentity,
        fallback: State,
        operation: () async throws(any Error) -> SessionSnapshot
    ) async {
        do {
            let snapshot = try await operation()
            try Task.checkCancellation()
            guard isCurrent(identity) else { return }
            apply(snapshot, failure: nil)
            finish(identity)
        } catch is CancellationError {
            await recoverAfterCancellation(identity: identity, fallback: fallback)
        } catch {
            await recover(identity: identity, fallback: fallback, failure: Self.map(error))
        }
    }

    private func presentPendingLogoutDecision(
        identity: OperationIdentity,
        fallback: State,
        account: SessionAccount
    ) async {
        let snapshot = await operations.currentSnapshot()
        guard Task.isCancelled == false else {
            await recoverAfterCancellation(identity: identity, fallback: fallback)
            return
        }
        guard isCurrent(identity) else { return }

        switch snapshot {
        case let .active(currentAccount) where currentAccount.authority == account.authority:
            apply(snapshot, failure: nil)
            showsPendingLogoutConfirmation = true
        case .notRestored:
            state = fallback
        case .signedOut:
            apply(snapshot, failure: nil)
        case .active:
            apply(snapshot, failure: .sessionChanged)
        case .authenticationRequired:
            apply(snapshot, failure: .authenticationRequired)
        }
        finish(identity)
    }

    private func signInAfterRegistration(identity: OperationIdentity, email: String, password: String) async {
        do {
            let snapshot = try await operations.login(email, password)
            try Task.checkCancellation()
            guard isCurrent(identity) else { return }

            guard case .active = snapshot else {
                registrationState = .created(loginFailure: .unavailable)
                finish(identity)
                return
            }

            apply(snapshot, failure: nil)
            finish(identity)
        } catch is CancellationError {
            await reconcileRegistrationLogin(identity: identity, failure: nil)
        } catch {
            await reconcileRegistrationLogin(identity: identity, failure: Self.map(error))
        }
    }

    private func reconcileRegistrationLogin(identity: OperationIdentity, failure: Failure?) async {
        let snapshot = await operations.currentSnapshot()
        guard isCurrent(identity) else { return }

        if case .active = snapshot {
            apply(snapshot, failure: nil)
        } else {
            registrationState = .created(loginFailure: failure)
        }
        finish(identity)
    }

    private func recoverAfterCancellation(identity: OperationIdentity, fallback: State) async {
        let snapshot = await operations.currentSnapshot()
        guard isCurrent(identity) else { return }

        if snapshot == .notRestored {
            state = fallback
        } else {
            apply(snapshot, failure: nil)
        }
        finish(identity)
    }

    private func recover(identity: OperationIdentity, fallback: State, failure: Failure) async {
        let snapshot = await operations.currentSnapshot()
        guard isCurrent(identity) else { return }

        if snapshot == .notRestored {
            state = Self.applying(failure, to: fallback)
        } else {
            apply(snapshot, failure: failure)
        }
        finish(identity)
    }

    private func apply(_ snapshot: SessionSnapshot, failure: Failure?) {
        showsPendingLogoutConfirmation = false
        switch snapshot {
        case .notRestored:
            state = .restoring
        case .signedOut:
            sessionAuthority = nil
            state = .signedOut(failure: failure)
        case let .active(account):
            sessionAuthority = account.authority
            state = .authenticated(account, notice: failure)
            registrationState = .idle
        case let .authenticationRequired(userID):
            if sessionAuthority?.userID != userID {
                sessionAuthority = nil
            }
            state = .authenticationRequired(userID: userID, failure: failure)
        }
    }

    private func beginOperation() -> OperationIdentity {
        let identity = OperationIdentity()
        activeOperationIdentity = identity
        activeReconciliation = nil
        return identity
    }

    private func isCurrent(_ identity: OperationIdentity) -> Bool {
        activeOperationIdentity === identity
    }

    private func finish(_ identity: OperationIdentity) {
        guard activeOperationIdentity === identity else { return }
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
        }
    }

    private static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func credentialValidation(
        email: String,
        password: String,
        minimumPasswordLength: Int?
    ) -> CredentialValidation {
        let normalizedEmail = normalizedEmail(email)
        let emailFailure: CredentialValidationFailure?
        if normalizedEmail.isEmpty {
            emailFailure = .emailRequired
        } else if normalizedEmail.wholeMatch(of: emailPattern) == nil {
            emailFailure = .invalidEmail
        } else {
            emailFailure = nil
        }

        let passwordFailure: CredentialValidationFailure?
        if password.isEmpty {
            passwordFailure = .passwordRequired
        } else if let minimumPasswordLength, password.count < minimumPasswordLength {
            passwordFailure = .passwordTooShort
        } else {
            passwordFailure = nil
        }

        return CredentialValidation(emailFailure: emailFailure, passwordFailure: passwordFailure)
    }

    private static let emailPattern = #/^[A-Za-z0-9!#$%&'*+\/=?^_{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+\/=?^_{|}~-]+)*@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$/#

    private static func map(_ error: any Error) -> Failure {
        guard let error = error as? SessionControllerError else { return .unavailable }

        return switch error {
        case .invalidCredentials:
            .invalidCredentials
        case .authenticationRequired:
            .authenticationRequired
        case .temporarilyUnavailable:
            .temporarilyUnavailable
        case .persistenceUnavailable:
            .persistenceUnavailable
        case .pendingCollectionPersistenceUnavailable:
            .pendingCollectionPersistenceUnavailable
        case .pendingCollectionChanges:
            .unavailable
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

    private static func reconciliationFailure(from cause: (any Error)?) -> Failure? {
        guard let cause = cause as? SessionControllerError else { return nil }

        return map(cause)
    }

    private static func preferredReconciliationFailure(
        _ failure: Failure?,
        over existingFailure: Failure?,
        fallback: Failure
    ) -> Failure {
        mergingReconciliationFailure(failure, with: existingFailure) ?? fallback
    }

    private static func mergingReconciliationFailure(_ failure: Failure?, with existingFailure: Failure?) -> Failure? {
        switch (failure, existingFailure) {
        case (.temporarilyUnavailable?, _), (.persistenceUnavailable?, _):
            failure
        case (_, .temporarilyUnavailable?), (_, .persistenceUnavailable?):
            existingFailure
        default:
            failure ?? existingFailure
        }
    }

    private static func isPersistenceFailure(_ failure: Failure?) -> Bool {
        failure == .temporarilyUnavailable || failure == .persistenceUnavailable
    }
}

private extension AccountModel.State {
    var reconciliationUserID: UUID? {
        switch self {
        case let .authenticated(account, _):
            account.id
        case let .authenticationRequired(userID, _):
            userID
        case .restoring, .restorationFailed, .signedOut, .authenticating, .signingOut:
            nil
        }
    }

    var reconciliationFailure: AccountModel.Failure? {
        switch self {
        case let .authenticated(_, notice):
            notice
        case let .authenticationRequired(_, failure):
            failure
        case .restoring, .restorationFailed, .signedOut, .authenticating, .signingOut:
            nil
        }
    }
}
