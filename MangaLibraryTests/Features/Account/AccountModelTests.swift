//
//  AccountModelTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("Account presentation model", .tags(.fast))
@MainActor
struct AccountModelTests {
    @Test("Restore maps the safe session snapshot into account presentation")
    func restorePublishesAuthenticatedAccount() async {
        let session = ControlledAccountSession()
        await session.setRestoreResult(
            .success(.active(Self.accountA))
        )
        let model = AccountModel(operations: session.operations())

        await model.restore()

        #expect(
            model.state
                == .authenticated(Self.accountA, notice: nil)
        )
    }

    @Test("Deferred restoration never exposes sign-in and remains retryable")
    func unavailableRestoreRemainsRetryable() async {
        let session = ControlledAccountSession()
        await session.setRestoreResult(
            .failure(.temporarilyUnavailable)
        )
        let model = AccountModel(operations: session.operations())

        await model.restore()

        #expect(
            model.state
                == .restorationFailed(failure: .temporarilyUnavailable)
        )

        await session.setRestoreResult(.success(.signedOut))
        await model.restore()

        #expect(model.state == .signedOut(failure: nil))
    }

    @Test("Sign in exposes authenticating until the semantic operation completes")
    func signInHasAStableLoadingState() async {
        let session = ControlledAccountSession()
        let gate = AccountOperationGate()
        await session.setLoginResult(
            for: "a@example.invalid",
            result: .success(.active(Self.accountA)),
            gate: gate
        )
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        let signIn = Task { @MainActor in
            await model.signIn(
                email: "a@example.invalid",
                password: "synthetic-passphrase"
            )
        }
        await gate.waitUntilArrived()
        #expect(model.state == .authenticating)

        await gate.open()
        await signIn.value
        #expect(
            model.state
                == .authenticated(Self.accountA, notice: nil)
        )
    }

    @Test("Sign in normalizes email at the semantic boundary")
    func signInNormalizesEmail() async {
        let session = ControlledAccountSession()
        await session.setLoginResult(
            for: "a@example.invalid",
            result: .success(.active(Self.accountA))
        )
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        await model.signIn(
            email: "  a@example.invalid\n",
            password: "synthetic-passphrase"
        )

        #expect(
            model.state
                == .authenticated(Self.accountA, notice: nil)
        )
    }

    @Test("Invalid credentials return to signed out with a recoverable reason")
    func invalidCredentialsKeepSignedOutContext() async {
        let session = ControlledAccountSession()
        await session.setLoginResult(
            for: "a@example.invalid",
            result: .failure(.invalidCredentials)
        )
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        await model.signIn(
            email: "a@example.invalid",
            password: "synthetic-passphrase"
        )

        #expect(
            model.state
                == .signedOut(failure: .invalidCredentials)
        )
    }

    @Test("Post-invalidation failure remains cleaning until retry succeeds")
    func signOutCleanupCanBeRetried() async {
        let session = ControlledAccountSession()
        await session.setLogoutResult(
            .failure(.temporarilyUnavailable),
            failureSnapshot: .cleaning(
                userID: Self.accountA.id,
                completion: .signedOut
            )
        )
        await session.setRetryCleanupResult(.success(.signedOut))
        let model = AccountModel(
            initialState: .authenticated(Self.accountA, notice: nil),
            operations: session.operations()
        )

        await model.signOut()
        #expect(
            model.state
                == .cleaning(
                    userID: Self.accountA.id,
                    completion: .signedOut,
                    failure: .temporarilyUnavailable
                )
        )

        await model.retryCleanup()
        #expect(model.state == .signedOut(failure: nil))
    }

    @Test("Resolving prepared logout admits only one decision")
    func preparedLogoutDecisionCannotCompete() async {
        let session = ControlledAccountSession()
        let gate = AccountOperationGate()
        await session.setCancelLogoutResult(
            .success(.active(Self.accountA)),
            gate: gate
        )
        let model = AccountModel(
            initialState: .logoutPrepared(Self.accountA, failure: nil),
            operations: session.operations()
        )

        let cancel = Task { @MainActor in
            await model.cancelLogout()
        }
        await gate.waitUntilArrived()

        #expect(model.state == .resolvingLogout(Self.accountA))
        await model.retryLogout()
        #expect(model.state == .resolvingLogout(Self.accountA))

        await gate.open()
        await cancel.value
        #expect(
            model.state
                == .authenticated(Self.accountA, notice: nil)
        )
    }

    @Test("A repeated sign-in cannot supersede the active attempt")
    func repeatedSignInKeepsTheActiveAttempt() async {
        let session = ControlledAccountSession()
        let gateA = AccountOperationGate()
        await session.setLoginResult(
            for: "a@example.invalid",
            result: .success(.active(Self.accountA)),
            gate: gateA
        )
        await session.setLoginResult(
            for: "b@example.invalid",
            result: .success(.active(Self.accountB))
        )
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        let signInA = Task { @MainActor in
            await model.signIn(
                email: "a@example.invalid",
                password: "synthetic-a"
            )
        }
        await gateA.waitUntilArrived()
        await model.signIn(
            email: "b@example.invalid",
            password: "synthetic-b"
        )
        #expect(model.state == .authenticating)
        await gateA.open()
        await signInA.value

        #expect(
            model.state
                == .authenticated(Self.accountA, notice: nil)
        )
    }

    @Test("A cancelled sign-in reconciles with current session authority")
    func cancelledSignInUsesCurrentSnapshot() async {
        let session = ControlledAccountSession()
        let gate = AccountOperationGate()
        await session.setLoginResult(
            for: "a@example.invalid",
            result: .success(.active(Self.accountA)),
            gate: gate,
            commitsSnapshot: false
        )
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        let signIn = Task { @MainActor in
            await model.signIn(
                email: "a@example.invalid",
                password: "synthetic-passphrase"
            )
        }
        await gate.waitUntilArrived()
        signIn.cancel()
        await gate.open()
        await signIn.value

        #expect(model.state == .signedOut(failure: nil))
    }

    @Test("A repeated bootstrap cannot supersede an active sign-in")
    func restoreDuringSignInDoesNotReplaceItsOperation() async {
        let session = ControlledAccountSession()
        let gate = AccountOperationGate()
        await session.setLoginResult(
            for: "a@example.invalid",
            result: .success(.active(Self.accountA)),
            gate: gate
        )
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        let signIn = Task { @MainActor in
            await model.signIn(
                email: "a@example.invalid",
                password: "synthetic-passphrase"
            )
        }
        await gate.waitUntilArrived()

        await model.restore()

        #expect(model.state == .authenticating)
        await gate.open()
        await signIn.value
        #expect(
            model.state
                == .authenticated(Self.accountA, notice: nil)
        )
    }

    @Test("Registration cancelled before model entry never starts the workflow")
    func cancelledRegistrationBeforeModelEntryNeverStartsRemoteWorkflow() async {
        let session = ControlledAccountSession()
        let entryGate = AccountOperationGate()
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        let registration = Task { @MainActor in
            await entryGate.suspendUntilOpen()
            await model.register(
                email: "reader@example.invalid",
                password: "synthetic-passphrase"
            )
        }
        await entryGate.waitUntilArrived()
        registration.cancel()
        await entryGate.open()
        await registration.value

        #expect(await session.remoteCalls().isEmpty)
        #expect(model.state == .signedOut(failure: nil))
        #expect(model.registrationState == .idle)
    }

    @Test("Invalid registration input never starts the remote workflow")
    func invalidRegistrationInputNeverStartsRemoteWorkflow() async {
        let session = ControlledAccountSession()
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        #expect(
            model.canSubmitRegistration(
                email: "reader@example.invalid",
                password: "12345678"
            )
        )
        #expect(
            !model.canSubmitRegistration(
                email: "  \n",
                password: "12345678"
            )
        )
        #expect(
            !model.canSubmitRegistration(
                email: "reader@example.invalid",
                password: "1234567"
            )
        )

        await model.register(email: "  \n", password: "12345678")
        await model.register(
            email: "reader@example.invalid",
            password: "1234567"
        )

        #expect(await session.remoteCalls().isEmpty)
        #expect(model.registrationState == .idle)
    }

    @Test("Confirmed registration logs in exactly once")
    func confirmedRegistrationLogsInExactlyOnce() async {
        let session = ControlledAccountSession()
        await session.setRegistrationResult(
            for: "reader@example.invalid",
            submission: .confirmed
        )
        await session.setLoginResult(
            for: "reader@example.invalid",
            result: .success(.active(Self.accountA))
        )
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        await model.register(
            email: "  reader@example.invalid\n",
            password: "synthetic-passphrase"
        )

        #expect(
            await session.remoteCalls()
                == [
                    .register(
                        email: "reader@example.invalid",
                        password: "synthetic-passphrase"
                    ),
                    .login(
                        email: "reader@example.invalid",
                        password: "synthetic-passphrase"
                    )
                ]
        )
        #expect(model.state == .authenticated(Self.accountA, notice: nil))
        #expect(model.registrationState == .idle)
    }

    @Test("A local registration failure never attempts sign in")
    func notSubmittedRegistrationStopsBeforeSignIn() async {
        let session = ControlledAccountSession()
        await session.setRegistrationResult(
            for: "reader@example.invalid",
            submission: .notSubmitted(.configurationUnavailable)
        )
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        await model.register(
            email: "reader@example.invalid",
            password: "synthetic-passphrase"
        )

        #expect(
            await session.remoteCalls()
                == [
                    .register(
                        email: "reader@example.invalid",
                        password: "synthetic-passphrase"
                    )
                ]
        )
        #expect(
            model.registrationState
                == .failed(.configurationUnavailable)
        )
        #expect(model.state == .signedOut(failure: nil))
    }

    @Test("Confirmed account remains created when automatic sign in fails")
    func confirmedRegistrationRemainsCreatedWhenLoginFails() async {
        let session = ControlledAccountSession()
        await session.setRegistrationResult(
            for: "reader@example.invalid",
            submission: .confirmed
        )
        await session.setLoginResult(
            for: "reader@example.invalid",
            result: .failure(.invalidCredentials)
        )
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        await model.register(
            email: "reader@example.invalid",
            password: "synthetic-passphrase"
        )

        #expect(
            model.registrationState
                == .created(loginFailure: .invalidCredentials)
        )
        #expect(model.state == .signedOut(failure: nil))
        #expect(await session.remoteCalls().count == 2)
    }

    @Test("Confirmed account remains created when automatic sign in is cancelled")
    func confirmedRegistrationRemainsCreatedWhenLoginIsCancelled() async {
        let session = ControlledAccountSession()
        let loginGate = AccountOperationGate()
        await session.setRegistrationResult(
            for: "reader@example.invalid",
            submission: .confirmed
        )
        await session.setLoginResult(
            for: "reader@example.invalid",
            result: .success(.active(Self.accountA)),
            gate: loginGate,
            commitsSnapshot: false
        )
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        let registration = Task { @MainActor in
            await model.register(
                email: "reader@example.invalid",
                password: "synthetic-passphrase"
            )
        }
        await loginGate.waitUntilArrived()
        registration.cancel()
        model.abandonRegistration()
        #expect(model.registrationState == .signingIn)
        await loginGate.open()
        await registration.value

        #expect(model.registrationState == .created(loginFailure: nil))
        #expect(model.state == .signedOut(failure: nil))
        #expect(await session.remoteCalls().count == 2)
    }

    @Test("Cancelled automatic sign in publishes a session already committed")
    func cancelledRegistrationLoginReconcilesCommittedSession() async {
        let session = ControlledAccountSession()
        let loginGate = AccountOperationGate()
        await session.setRegistrationResult(
            for: "reader@example.invalid",
            submission: .confirmed
        )
        await session.setLoginResult(
            for: "reader@example.invalid",
            result: .success(.active(Self.accountA)),
            gate: loginGate
        )
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        let registration = Task { @MainActor in
            await model.register(
                email: "reader@example.invalid",
                password: "synthetic-passphrase"
            )
        }
        await loginGate.waitUntilArrived()
        registration.cancel()
        model.abandonRegistration()
        await loginGate.open()
        await registration.value

        #expect(model.state == .authenticated(Self.accountA, notice: nil))
        #expect(model.registrationState == .idle)
        #expect(await session.remoteCalls().count == 2)
    }

    @Test("A timed out registration remains unconfirmed without sign in")
    func timedOutRegistrationBecomesUncertainWithoutRetryOrLogin() async {
        let session = ControlledAccountSession()
        await session.setRegistrationResult(
            for: "reader@example.invalid",
            submission: .unconfirmed(.network(.transport(.timedOut)))
        )
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        await model.register(
            email: "reader@example.invalid",
            password: "synthetic-passphrase"
        )

        #expect(
            model.registrationState
                == .unconfirmed(.network(.transport(.timedOut)))
        )
        #expect(
            await session.remoteCalls()
                == [
                    .register(
                        email: "reader@example.invalid",
                        password: "synthetic-passphrase"
                    )
                ]
        )
    }

    @Test("A late abandoned registration cannot replace a newer session")
    func lateSupersededRegistrationCannotReplaceTheNewerSession() async {
        let session = ControlledAccountSession()
        let registrationGate = AccountOperationGate()
        await session.setRegistrationResult(
            for: "a@example.invalid",
            submission: .confirmed,
            gate: registrationGate
        )
        await session.setLoginResult(
            for: "b@example.invalid",
            result: .success(.active(Self.accountB))
        )
        let model = AccountModel(
            initialState: .signedOut(failure: nil),
            operations: session.operations()
        )

        let registrationA = Task { @MainActor in
            await model.register(
                email: "a@example.invalid",
                password: "synthetic-a"
            )
        }
        await registrationGate.waitUntilArrived()

        model.abandonRegistration()
        #expect(model.registrationState == .unconfirmed(.cancelled))

        await model.signIn(
            email: "b@example.invalid",
            password: "synthetic-b"
        )
        #expect(model.state == .authenticated(Self.accountB, notice: nil))

        await registrationGate.open()
        await registrationA.value

        #expect(model.state == .authenticated(Self.accountB, notice: nil))
        #expect(
            await session.remoteCalls()
                == [
                    .register(
                        email: "a@example.invalid",
                        password: "synthetic-a"
                    ),
                    .login(
                        email: "b@example.invalid",
                        password: "synthetic-b"
                    )
                ]
        )
    }

    private static let accountA = SessionAccount(
        id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        email: "a@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
    private static let accountB = SessionAccount(
        id: UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!,
        email: "b@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
}

private actor ControlledAccountSession {
    private struct RegistrationPlan: Sendable {
        let submission: UserRegistrationSubmission
        let gate: AccountOperationGate?
    }

    private struct LoginPlan: Sendable {
        let result: Result<SessionSnapshot, SessionControllerError>
        let gate: AccountOperationGate?
        let commitsSnapshot: Bool
    }

    private var snapshot = SessionSnapshot.notRestored
    private var restoreResult: Result<SessionSnapshot, SessionControllerError> = .success(.signedOut)
    private var registrationPlans: [String: RegistrationPlan] = [:]
    private var loginPlans: [String: LoginPlan] = [:]
    private var recordedRemoteCalls: [AccountRemoteCall] = []
    private var logoutResult: Result<SessionSnapshot, SessionControllerError> = .success(.signedOut)
    private var logoutFailureSnapshot: SessionSnapshot?
    private var cancelLogoutResult: Result<SessionSnapshot, SessionControllerError> = .success(.signedOut)
    private var cancelLogoutGate: AccountOperationGate?
    private var retryCleanupResult: Result<SessionSnapshot, SessionControllerError> = .success(.signedOut)

    nonisolated func operations() -> AccountModel.Operations {
        AccountModel.Operations(
            currentSnapshot: { [self] in await currentSnapshot() },
            restore: { [self] in try await restore() },
            login: { [self] email, password in
                try await login(email: email, password: password)
            },
            register: { [self] email, password in
                await register(email: email, password: password)
            },
            logout: { [self] in try await logout() },
            retryLogout: { [self] in try await retryLogout() },
            cancelLogout: { [self] in try await cancelLogout() },
            retryCleanup: { [self] in try await retryCleanup() }
        )
    }

    func setRestoreResult(_ result: Result<SessionSnapshot, SessionControllerError>) {
        restoreResult = result
    }

    func setLoginResult(
        for email: String,
        result: Result<SessionSnapshot, SessionControllerError>,
        gate: AccountOperationGate? = nil,
        commitsSnapshot: Bool = true
    ) {
        loginPlans[email] = LoginPlan(
            result: result,
            gate: gate,
            commitsSnapshot: commitsSnapshot
        )
    }

    func setRegistrationResult(
        for email: String,
        submission: UserRegistrationSubmission,
        gate: AccountOperationGate? = nil
    ) {
        registrationPlans[email] = RegistrationPlan(
            submission: submission,
            gate: gate
        )
    }

    func remoteCalls() -> [AccountRemoteCall] {
        recordedRemoteCalls
    }

    func setLogoutResult(
        _ result: Result<SessionSnapshot, SessionControllerError>,
        failureSnapshot: SessionSnapshot? = nil
    ) {
        logoutResult = result
        logoutFailureSnapshot = failureSnapshot
    }

    func setRetryCleanupResult(_ result: Result<SessionSnapshot, SessionControllerError>) {
        retryCleanupResult = result
    }

    func setCancelLogoutResult(
        _ result: Result<SessionSnapshot, SessionControllerError>,
        gate: AccountOperationGate? = nil
    ) {
        cancelLogoutResult = result
        cancelLogoutGate = gate
    }

    private func currentSnapshot() -> SessionSnapshot {
        snapshot
    }

    private func restore() throws(any Error) -> SessionSnapshot {
        let result = try restoreResult.get()
        snapshot = result
        return result
    }

    private func register(
        email: String,
        password: String
    ) async -> UserRegistrationSubmission {
        recordedRemoteCalls.append(
            .register(email: email, password: password)
        )
        guard let plan = registrationPlans[email] else {
            return .notSubmitted(.unavailable)
        }
        if let gate = plan.gate {
            await gate.suspendUntilOpen()
        }
        return plan.submission
    }

    private func login(
        email: String,
        password: String
    ) async throws(any Error) -> SessionSnapshot {
        recordedRemoteCalls.append(
            .login(email: email, password: password)
        )
        let plan = try #require(loginPlans[email])
        if let gate = plan.gate {
            await gate.suspendUntilOpen()
        }
        let result = try plan.result.get()
        if plan.commitsSnapshot {
            snapshot = result
        }
        return result
    }

    private func logout() throws(any Error) -> SessionSnapshot {
        do {
            let result = try logoutResult.get()
            snapshot = result
            return result
        } catch {
            if let logoutFailureSnapshot {
                snapshot = logoutFailureSnapshot
            }
            throw error
        }
    }

    private func retryLogout() throws(any Error) -> SessionSnapshot {
        try logout()
    }

    private func cancelLogout() async throws(any Error) -> SessionSnapshot {
        if let cancelLogoutGate {
            await cancelLogoutGate.suspendUntilOpen()
        }
        let result = try cancelLogoutResult.get()
        snapshot = result
        return result
    }

    private func retryCleanup() throws(any Error) -> SessionSnapshot {
        let result = try retryCleanupResult.get()
        snapshot = result
        return result
    }
}

private enum AccountRemoteCall: Equatable, Sendable {
    case register(email: String, password: String)
    case login(email: String, password: String)
}

private actor AccountOperationGate {
    private var didArrive = false
    private var isOpen = false
    private var arrivalContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func waitUntilArrived() async {
        guard didArrive == false else {
            return
        }
        await withCheckedContinuation {
            arrivalContinuation = $0
        }
    }

    func suspendUntilOpen() async {
        didArrive = true
        arrivalContinuation?.resume()
        arrivalContinuation = nil
        guard isOpen == false else {
            return
        }
        await withCheckedContinuation {
            releaseContinuation = $0
        }
    }

    func open() {
        isOpen = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
