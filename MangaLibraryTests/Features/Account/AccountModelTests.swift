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
        await session.setRestoreResult(.success(.active(Self.accountA)))
        let model = AccountModel(operations: session.operations())

        await model.restore()

        #expect(model.state == .authenticated(Self.accountA, notice: nil))
    }

    @Test("Deferred restoration never exposes sign-in and remains retryable")
    func unavailableRestoreRemainsRetryable() async {
        let session = ControlledAccountSession()
        await session.setRestoreResult(.failure(.temporarilyUnavailable))
        let model = AccountModel(operations: session.operations())

        await model.restore()

        #expect(model.state == .restorationFailed(failure: .temporarilyUnavailable))

        await session.setRestoreResult(.success(.signedOut))
        await model.restore()

        #expect(model.state == .signedOut(failure: nil))
    }

    @Test("Sign in exposes authenticating until the semantic operation completes")
    func signInHasAStableLoadingState() async {
        let session = ControlledAccountSession()
        let gate = AccountOperationGate()
        await session.setLoginResult(for: "a@example.invalid", result: .success(.active(Self.accountA)), gate: gate)
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        let signIn = Task { @MainActor in
            await model.signIn(email: "a@example.invalid", password: "synthetic-passphrase")
        }
        await gate.waitUntilArrived()
        #expect(model.state == .authenticating(previousUserID: nil))

        await gate.open()
        await signIn.value
        #expect(model.state == .authenticated(Self.accountA, notice: nil))
    }

    @Test("Sign in normalizes email at the semantic boundary")
    func signInNormalizesEmail() async {
        let session = ControlledAccountSession()
        await session.setLoginResult(for: "a@example.invalid", result: .success(.active(Self.accountA)))
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        await model.signIn(email: "  a@example.invalid\n", password: "synthetic-passphrase")

        #expect(model.state == .authenticated(Self.accountA, notice: nil))
    }

    @Test("Invalid sign-in input never starts the remote workflow")
    func invalidSignInInputNeverStartsRemoteWorkflow() async {
        let session = ControlledAccountSession()
        await session.setLoginResult(for: "readerexample.invalid", result: .success(.active(Self.accountA)))
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        #expect(model.canSubmitSignIn(email: "reader@example.invalid", password: "x"))
        #expect(
            model.signInValidation(email: "", password: "")
                == .init(emailFailure: .emailRequired, passwordFailure: .passwordRequired)
        )
        #expect(
            model.signInValidation(email: "readerexample.invalid", password: "synthetic-passphrase").emailFailure
                == .invalidEmail
        )
        #expect(!model.canSubmitSignIn(email: "readerexample.invalid", password: "synthetic-passphrase"))
        #expect(!model.canSubmitSignIn(email: "reader@example.invalid", password: ""))

        await model.signIn(email: "readerexample.invalid", password: "synthetic-passphrase")

        #expect(await session.remoteCalls().isEmpty)
        #expect(model.state == .signedOut(failure: nil))
    }

    @Test("Credential email validation follows the conservative S2.2 grammar", arguments: EmailValidationCase.all)
    fileprivate func validatesCredentialEmail(testCase: EmailValidationCase) {
        let session = ControlledAccountSession()
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        #expect(
            model.signInValidation(email: testCase.email, password: "synthetic-passphrase").emailFailure
                == testCase.expectedFailure
        )
    }

    @Test("Invalid credentials return to signed out with a recoverable reason")
    func invalidCredentialsKeepSignedOutContext() async {
        let session = ControlledAccountSession()
        await session.setLoginResult(for: "a@example.invalid", result: .failure(.invalidCredentials))
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        await model.signIn(email: "a@example.invalid", password: "synthetic-passphrase")

        #expect(model.state == .signedOut(failure: .invalidCredentials))
    }

    @Test("A failed Keychain deletion keeps the authenticated account with a notice")
    func signOutFailureKeepsTheActiveSession() async {
        let session = ControlledAccountSession()
        await session.setLogoutResult(.failure(.temporarilyUnavailable))
        let model = AccountModel(
            initialState: .authenticated(Self.accountA, notice: nil),
            operations: session.operations()
        )

        await model.signOut()
        #expect(model.state == .authenticated(Self.accountA, notice: .temporarilyUnavailable))
    }

    @Test("A repeated sign-in cannot supersede the active attempt")
    func repeatedSignInKeepsTheActiveAttempt() async {
        let session = ControlledAccountSession()
        let gateA = AccountOperationGate()
        await session.setLoginResult(for: "a@example.invalid", result: .success(.active(Self.accountA)), gate: gateA)
        await session.setLoginResult(for: "b@example.invalid", result: .success(.active(Self.accountB)))
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        let signInA = Task { @MainActor in
            await model.signIn(email: "a@example.invalid", password: "synthetic-a")
        }
        await gateA.waitUntilArrived()
        await model.signIn(email: "b@example.invalid", password: "synthetic-b")
        #expect(model.state == .authenticating(previousUserID: nil))
        await gateA.open()
        await signInA.value

        #expect(model.state == .authenticated(Self.accountA, notice: nil))
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
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        let signIn = Task { @MainActor in
            await model.signIn(email: "a@example.invalid", password: "synthetic-passphrase")
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
        await session.setLoginResult(for: "a@example.invalid", result: .success(.active(Self.accountA)), gate: gate)
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        let signIn = Task { @MainActor in
            await model.signIn(email: "a@example.invalid", password: "synthetic-passphrase")
        }
        await gate.waitUntilArrived()

        await model.restore()

        #expect(model.state == .authenticating(previousUserID: nil))
        await gate.open()
        await signIn.value
        #expect(model.state == .authenticated(Self.accountA, notice: nil))
    }

    @Test("Registration cancelled before model entry never starts the workflow")
    func cancelledRegistrationBeforeModelEntryNeverStartsRemoteWorkflow() async {
        let session = ControlledAccountSession()
        let entryGate = AccountOperationGate()
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        let registration = Task { @MainActor in
            await entryGate.suspendUntilOpen()
            await model.register(email: "reader@example.invalid", password: "synthetic-passphrase")
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
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        #expect(model.canSubmitRegistration(email: "reader@example.invalid", password: "12345678"))
        #expect(
            model.registrationValidation(email: "", password: "")
                == .init(emailFailure: .emailRequired, passwordFailure: .passwordRequired)
        )
        #expect(
            model.registrationValidation(email: "reader@example.invalid", password: "1234567").passwordFailure
                == .passwordTooShort
        )
        #expect(!model.canSubmitRegistration(email: "  \n", password: "12345678"))
        #expect(!model.canSubmitRegistration(email: "reader@example", password: "12345678"))
        #expect(!model.canSubmitRegistration(email: "reader..name@example.invalid", password: "12345678"))
        #expect(!model.canSubmitRegistration(email: "reader@example.invalid", password: "1234567"))

        await model.register(email: "  \n", password: "12345678")
        await model.register(email: "reader@example", password: "12345678")
        await model.register(email: "reader..name@example.invalid", password: "12345678")
        await model.register(email: "reader@example.invalid", password: "1234567")

        #expect(await session.remoteCalls().isEmpty)
        #expect(model.registrationState == .idle)
    }

    @Test("Confirmed registration logs in exactly once")
    func confirmedRegistrationLogsInExactlyOnce() async {
        let session = ControlledAccountSession()
        await session.setRegistrationResult(for: "reader@example.invalid", submission: .confirmed)
        await session.setLoginResult(for: "reader@example.invalid", result: .success(.active(Self.accountA)))
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        await model.register(email: "  reader@example.invalid\n", password: "synthetic-passphrase")

        #expect(
            await session.remoteCalls()
                == [
                    .register(email: "reader@example.invalid", password: "synthetic-passphrase"),
                    .login(email: "reader@example.invalid", password: "synthetic-passphrase")
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
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        await model.register(email: "reader@example.invalid", password: "synthetic-passphrase")

        #expect(
            await session.remoteCalls()
                == [
                    .register(email: "reader@example.invalid", password: "synthetic-passphrase")
                ]
        )
        #expect(model.registrationState == .failed(.configurationUnavailable))
        #expect(model.state == .signedOut(failure: nil))
    }

    @Test("Confirmed account remains created when automatic sign in fails")
    func confirmedRegistrationRemainsCreatedWhenLoginFails() async {
        let session = ControlledAccountSession()
        await session.setRegistrationResult(for: "reader@example.invalid", submission: .confirmed)
        await session.setLoginResult(for: "reader@example.invalid", result: .failure(.invalidCredentials))
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        await model.register(email: "reader@example.invalid", password: "synthetic-passphrase")

        #expect(model.registrationState == .created(loginFailure: .invalidCredentials))
        #expect(model.state == .signedOut(failure: nil))
        #expect(await session.remoteCalls().count == 2)
    }

    @Test("Confirmed account remains created when automatic sign in is cancelled")
    func confirmedRegistrationRemainsCreatedWhenLoginIsCancelled() async {
        let session = ControlledAccountSession()
        let loginGate = AccountOperationGate()
        await session.setRegistrationResult(for: "reader@example.invalid", submission: .confirmed)
        await session.setLoginResult(
            for: "reader@example.invalid",
            result: .success(.active(Self.accountA)),
            gate: loginGate,
            commitsSnapshot: false
        )
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        let registration = Task { @MainActor in
            await model.register(email: "reader@example.invalid", password: "synthetic-passphrase")
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
        await session.setRegistrationResult(for: "reader@example.invalid", submission: .confirmed)
        await session.setLoginResult(
            for: "reader@example.invalid",
            result: .success(.active(Self.accountA)),
            gate: loginGate
        )
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        let registration = Task { @MainActor in
            await model.register(email: "reader@example.invalid", password: "synthetic-passphrase")
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
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        await model.register(email: "reader@example.invalid", password: "synthetic-passphrase")

        #expect(model.registrationState == .unconfirmed(.network(.transport(.timedOut))))
        #expect(
            await session.remoteCalls()
                == [
                    .register(email: "reader@example.invalid", password: "synthetic-passphrase")
                ]
        )
    }

    @Test("A late abandoned registration cannot replace a newer session")
    func lateSupersededRegistrationCannotReplaceTheNewerSession() async {
        let session = ControlledAccountSession()
        let registrationGate = AccountOperationGate()
        await session.setRegistrationResult(for: "a@example.invalid", submission: .confirmed, gate: registrationGate)
        await session.setLoginResult(for: "b@example.invalid", result: .success(.active(Self.accountB)))
        let model = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())

        let registrationA = Task { @MainActor in
            await model.register(email: "a@example.invalid", password: "synthetic-a")
        }
        await registrationGate.waitUntilArrived()

        model.abandonRegistration()
        #expect(model.registrationState == .unconfirmed(.cancelled))

        await model.signIn(email: "b@example.invalid", password: "synthetic-b")
        #expect(model.state == .authenticated(Self.accountB, notice: nil))

        await registrationGate.open()
        await registrationA.value

        #expect(model.state == .authenticated(Self.accountB, notice: nil))
        #expect(
            await session.remoteCalls()
                == [
                    .register(email: "a@example.invalid", password: "synthetic-a"),
                    .login(email: "b@example.invalid", password: "synthetic-b")
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

@Suite("Credential form presentation", .tags(.fast))
@MainActor
struct CredentialFormViewModelTests {
    @Test("Invalid sign-in reveals both field errors without remote work")
    func invalidSignInRevealsErrorsWithoutRemoteWork() async {
        let session = ControlledAccountSession()
        let accountModel = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())
        let viewModel = SignInViewModel(accountModel: accountModel)
        viewModel.email = "readerexample.invalid"

        let focus = viewModel.submit(currentFocus: .email)

        #expect(focus == .email)
        #expect(viewModel.emailFailure == .invalidEmail)
        #expect(viewModel.passwordFailure == .passwordRequired)
        #expect(await session.remoteCalls().isEmpty)
    }

    @Test("Sign-in keeps the password and modeled focus when visibility changes")
    func signInVisibilityPreservesPasswordAndFocus() {
        let session = ControlledAccountSession()
        let accountModel = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())
        let viewModel = SignInViewModel(accountModel: accountModel)
        viewModel.email = "invalid"
        viewModel.password = "synthetic-passphrase"

        viewModel.focusChanged(from: .email, to: .concealedPassword)
        let focus = viewModel.togglePasswordVisibility(currentFocus: .concealedPassword)

        #expect(viewModel.emailFailure == .invalidEmail)
        #expect(viewModel.password == "synthetic-passphrase")
        #expect(viewModel.isPasswordVisible)
        #expect(focus == .revealedPassword)
    }

    @Test("Leaving sign-in clears an unsent draft and its validation presentation")
    func leavingSignInClearsUnsentDraft() {
        let session = ControlledAccountSession()
        let accountModel = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())
        let viewModel = SignInViewModel(accountModel: accountModel)
        viewModel.email = "readerexample.invalid"
        viewModel.password = "synthetic-passphrase"

        let visibleFocus = viewModel.togglePasswordVisibility(currentFocus: .concealedPassword)
        let invalidFocus = viewModel.submit(currentFocus: visibleFocus)
        #expect(invalidFocus == .email)
        #expect(viewModel.isPasswordVisible)
        #expect(viewModel.emailFailure == .invalidEmail)

        let clearedFocus = viewModel.disappear(currentFocus: invalidFocus)
        viewModel.focusChanged(from: invalidFocus, to: clearedFocus)

        #expect(clearedFocus == nil)
        #expect(viewModel.password.isEmpty)
        #expect(!viewModel.isPasswordVisible)
        #expect(viewModel.emailFailure == nil)
        #expect(viewModel.passwordFailure == nil)
    }

    @Test("Valid sign-in clears the secret and starts one semantic operation")
    func validSignInClearsSecretAndStartsOneOperation() async {
        let session = ControlledAccountSession()
        let gate = AccountOperationGate()
        await session.setLoginResult(for: "reader@example.invalid", result: .success(.active(Self.account)), gate: gate)
        let accountModel = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())
        let viewModel = SignInViewModel(accountModel: accountModel)
        viewModel.email = "  reader@example.invalid\n"
        viewModel.password = "synthetic-passphrase"

        let focus = viewModel.submit(currentFocus: .concealedPassword)

        #expect(focus == nil)
        #expect(viewModel.password.isEmpty)
        #expect(!viewModel.isPasswordVisible)
        await gate.waitUntilArrived()
        #expect(
            await session.remoteCalls()
                == [.login(email: "reader@example.invalid", password: "synthetic-passphrase")]
        )
        #expect(accountModel.state == .authenticating(previousUserID: nil))

        await gate.open()
        await viewModel.waitForPendingOperation()
        #expect(accountModel.state == .authenticated(Self.account, notice: nil))
    }

    @Test("Leaving sign-in before task entry never starts remote work")
    func leavingSignInBeforeTaskEntryNeverStartsRemoteWork() async {
        let session = ControlledAccountSession()
        await session.setLoginResult(for: "reader@example.invalid", result: .success(.active(Self.account)))
        let accountModel = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())
        let viewModel = SignInViewModel(accountModel: accountModel)
        viewModel.email = "reader@example.invalid"
        viewModel.password = "synthetic-passphrase"

        _ = viewModel.submit(currentFocus: .concealedPassword)
        _ = viewModel.disappear(currentFocus: nil)
        await viewModel.waitForPendingOperation()

        #expect(await session.remoteCalls().isEmpty)
        #expect(accountModel.state == .signedOut(failure: nil))
    }

    @Test("Invalid registration focuses password and never reaches remote work")
    func invalidRegistrationFocusesPasswordWithoutRemoteWork() async {
        let session = ControlledAccountSession()
        let accountModel = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())
        let viewModel = RegisterViewModel(accountModel: accountModel)
        viewModel.email = "reader@example.invalid"
        viewModel.password = "short"

        let focus = viewModel.submit(currentFocus: .email)

        #expect(focus == .concealedPassword)
        #expect(viewModel.emailFailure == nil)
        #expect(viewModel.passwordFailure == .passwordTooShort)
        #expect(await session.remoteCalls().isEmpty)
    }

    @Test("Leaving registration clears an unsent draft and its validation presentation")
    func leavingRegistrationClearsUnsentDraft() {
        let session = ControlledAccountSession()
        let accountModel = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())
        let viewModel = RegisterViewModel(accountModel: accountModel)
        viewModel.email = "readerexample.invalid"
        viewModel.password = "short"

        let visibleFocus = viewModel.togglePasswordVisibility(currentFocus: .concealedPassword)
        let invalidFocus = viewModel.submit(currentFocus: visibleFocus)
        #expect(invalidFocus == .email)
        #expect(viewModel.isPasswordVisible)
        #expect(viewModel.emailFailure == .invalidEmail)
        #expect(viewModel.passwordFailure == .passwordTooShort)

        let clearedFocus = viewModel.disappear(currentFocus: invalidFocus)
        viewModel.focusChanged(from: invalidFocus, to: clearedFocus)

        #expect(clearedFocus == nil)
        #expect(viewModel.password.isEmpty)
        #expect(!viewModel.isPasswordVisible)
        #expect(viewModel.emailFailure == nil)
        #expect(viewModel.passwordFailure == nil)
        #expect(accountModel.registrationState == .idle)
    }

    @Test("Leaving registration clears credentials and invalidates the suspended workflow")
    func leavingRegistrationClearsAndInvalidatesSuspendedWorkflow() async {
        let session = ControlledAccountSession()
        let gate = AccountOperationGate()
        await session.setRegistrationResult(for: "reader@example.invalid", submission: .confirmed, gate: gate)
        let accountModel = AccountModel(initialState: .signedOut(failure: nil), operations: session.operations())
        let viewModel = RegisterViewModel(accountModel: accountModel)
        viewModel.email = "reader@example.invalid"
        viewModel.password = "synthetic-passphrase"

        let submittedFocus = viewModel.submit(currentFocus: .concealedPassword)
        #expect(submittedFocus == nil)
        #expect(viewModel.password.isEmpty)
        await gate.waitUntilArrived()
        #expect(accountModel.registrationState == .submitting)

        let abandonedFocus = viewModel.disappear(currentFocus: .concealedPassword)
        #expect(abandonedFocus == nil)
        #expect(viewModel.password.isEmpty)
        #expect(accountModel.registrationState == .unconfirmed(.cancelled))

        await gate.open()
        await viewModel.waitForPendingOperation()
        #expect(accountModel.registrationState == .unconfirmed(.cancelled))
        #expect(
            await session.remoteCalls()
                == [.register(email: "reader@example.invalid", password: "synthetic-passphrase")]
        )
    }

    private static let account = SessionAccount(
        id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        email: "reader@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
}

fileprivate struct EmailValidationCase: CustomTestStringConvertible {
    let testDescription: String
    let email: String
    let expectedFailure: AccountModel.CredentialValidationFailure?

    static let all = [
        Self(testDescription: "simple address", email: "reader@example.invalid", expectedFailure: nil),
        Self(
            testDescription: "trimmed tagged subdomain address",
            email: "  reader.name+tag@sub.example.invalid\n",
            expectedFailure: nil
        ),
        Self(
            testDescription: "allowed local punctuation",
            email: "reader!#$%&'*+/=?^_{|}~-@example.invalid",
            expectedFailure: nil
        ),
        Self(
            testDescription: "maximum domain label length",
            email: "reader@"
                + String(repeating: "a", count: 63)
                + ".invalid",
            expectedFailure: nil
        ),
        Self(testDescription: "empty address", email: " \n", expectedFailure: .emailRequired),
        Self(testDescription: "missing at sign", email: "readerexample.invalid", expectedFailure: .invalidEmail),
        Self(testDescription: "repeated at sign", email: "reader@@example.invalid", expectedFailure: .invalidEmail),
        Self(
            testDescription: "empty local segment",
            email: "reader..name@example.invalid",
            expectedFailure: .invalidEmail
        ),
        Self(testDescription: "domain without separator", email: "reader@example", expectedFailure: .invalidEmail),
        Self(testDescription: "empty domain segment", email: "reader@example..invalid", expectedFailure: .invalidEmail),
        Self(
            testDescription: "domain label starts with hyphen",
            email: "reader@-example.invalid",
            expectedFailure: .invalidEmail
        ),
        Self(
            testDescription: "domain label ends with hyphen",
            email: "reader@example-.invalid",
            expectedFailure: .invalidEmail
        ),
        Self(
            testDescription: "domain label exceeds maximum length",
            email: "reader@"
                + String(repeating: "a", count: 64)
                + ".invalid",
            expectedFailure: .invalidEmail
        ),
        Self(
            testDescription: "embedded whitespace",
            email: "reader name@example.invalid",
            expectedFailure: .invalidEmail
        ),
        Self(testDescription: "non ASCII local part", email: "lectorañ@example.invalid", expectedFailure: .invalidEmail)
    ]
}

private actor ControlledAccountSession {
    private struct RegistrationPlan {
        let submission: UserRegistrationSubmission
        let gate: AccountOperationGate?
    }

    private struct LoginPlan {
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
            logout: { [self] in try await logout() }
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
        loginPlans[email] = LoginPlan(result: result, gate: gate, commitsSnapshot: commitsSnapshot)
    }

    func setRegistrationResult(
        for email: String,
        submission: UserRegistrationSubmission,
        gate: AccountOperationGate? = nil
    ) {
        registrationPlans[email] = RegistrationPlan(submission: submission, gate: gate)
    }

    func remoteCalls() -> [AccountRemoteCall] {
        recordedRemoteCalls
    }

    func setLogoutResult(_ result: Result<SessionSnapshot, SessionControllerError>) {
        logoutResult = result
    }

    private func currentSnapshot() -> SessionSnapshot {
        snapshot
    }

    private func restore() throws(any Error) -> SessionSnapshot {
        let result = try restoreResult.get()
        snapshot = result
        return result
    }

    private func register(email: String, password: String) async -> UserRegistrationSubmission {
        recordedRemoteCalls.append(.register(email: email, password: password))
        guard let plan = registrationPlans[email] else { return .notSubmitted(.unavailable) }
        if let gate = plan.gate {
            await gate.suspendUntilOpen()
        }
        return plan.submission
    }

    private func login(email: String, password: String) async throws(any Error) -> SessionSnapshot {
        recordedRemoteCalls.append(.login(email: email, password: password))
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
        let result = try logoutResult.get()
        snapshot = result
        return result
    }
}

private enum AccountRemoteCall: Equatable {
    case register(email: String, password: String)
    case login(email: String, password: String)
}

private actor AccountOperationGate {
    private var didArrive = false
    private var isOpen = false
    private var arrivalContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func waitUntilArrived() async {
        guard didArrive == false else { return }
        await withCheckedContinuation {
            arrivalContinuation = $0
        }
    }

    func suspendUntilOpen() async {
        didArrive = true
        arrivalContinuation?.resume()
        arrivalContinuation = nil
        guard isOpen == false else { return }
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
