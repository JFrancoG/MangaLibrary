//
//  SignInViewModel.swift
//  MangaLibrary
//

import Foundation
import Observation

/// Owns the transient presentation and task lifetime of one sign-in screen.
///
/// Session state and remote workflow remain owned by ``AccountModel``. This
/// model keeps credentials only for the current screen presence and clears the
/// password before suspending or when the screen disappears.
@Observable @MainActor
final class SignInViewModel {
    enum FocusedField: Hashable {
        case email
        case concealedPassword
        case revealedPassword
    }

    private enum Field: Hashable {
        case email
        case password
    }

    var email: String
    var password: String
    private(set) var isPasswordVisible = false

    @ObservationIgnored private let accountModel: AccountModel
    @ObservationIgnored private var pendingOperation: Task<Void, Never>?
    @ObservationIgnored private var suppressNextFocusValidation = false
    private var validatedFields: Set<Field>

    init(
        accountModel: AccountModel,
        email: String = "",
        password: String = "",
        showsValidationErrors: Bool = false
    ) {
        self.accountModel = accountModel
        self.email = email
        self.password = password
        validatedFields = showsValidationErrors ? [.email, .password] : []
    }

    var isAuthenticating: Bool {
        if case .authenticating = accountModel.state {
            return true
        }

        return false
    }

    var emailFailure: AccountModel.CredentialValidationFailure? {
        guard validatedFields.contains(.email) else { return nil }
        return validation.emailFailure
    }

    var passwordFailure: AccountModel.CredentialValidationFailure? {
        guard validatedFields.contains(.password) else { return nil }
        return validation.passwordFailure
    }

    var passwordVisibilityLabel: LocalizedStringResource { isPasswordVisible ? "Hide password" : "Show password" }

    var failure: AccountModel.Failure? {
        switch accountModel.state {
        case let .signedOut(failure), let .authenticationRequired(_, failure):
            failure
        case .restoring, .restorationFailed, .authenticating, .authenticated,
             .signingOut:
            nil
        }
    }

    func focusChanged(from previousField: FocusedField?, to currentField: FocusedField?) {
        if suppressNextFocusValidation, currentField == nil {
            suppressNextFocusValidation = false
            return
        }
        guard let previousField else { return }
        let previousValidationField = validationField(for: previousField)
        let currentValidationField = currentField.map(validationField)
        guard previousValidationField != currentValidationField else { return }
        validatedFields.insert(previousValidationField)
    }

    func emailSubmitted() -> FocusedField {
        validatedFields.insert(.email)
        return validation.emailFailure == nil ? passwordFocus : .email
    }

    func submit(currentFocus: FocusedField?) -> FocusedField? {
        validatedFields = [.email, .password]
        let currentValidation = validation
        guard currentValidation.isValid else { return firstInvalidFocus(for: currentValidation) }
        guard isAuthenticating == false else { return currentFocus }

        let submittedEmail = email
        let submittedPassword = password
        prepareForSubmission(currentFocus: currentFocus)

        pendingOperation?.cancel()
        pendingOperation = Task { [accountModel] in
            await accountModel.signIn(email: submittedEmail, password: submittedPassword)
        }
        return nil
    }

    func togglePasswordVisibility(currentFocus: FocusedField?) -> FocusedField? {
        let restoresPasswordFocus = currentFocus == passwordFocus
        isPasswordVisible.toggle()
        return restoresPasswordFocus ? passwordFocus : currentFocus
    }

    func disappear(currentFocus: FocusedField?) -> FocusedField? {
        pendingOperation?.cancel()
        suppressFocusValidationIfNeeded(currentFocus)
        password = ""
        validatedFields.removeAll()
        isPasswordVisible = false
        return nil
    }

    func waitForPendingOperation() async {
        let operation = pendingOperation
        await operation?.value
    }

    private var validation: AccountModel.CredentialValidation {
        accountModel.signInValidation(email: email, password: password)
    }

    private var passwordFocus: FocusedField { isPasswordVisible ? .revealedPassword : .concealedPassword }

    private func validationField(for focusedField: FocusedField) -> Field {
        switch focusedField {
        case .email:
            .email
        case .concealedPassword, .revealedPassword:
            .password
        }
    }

    private func firstInvalidFocus(for validation: AccountModel.CredentialValidation) -> FocusedField? {
        if validation.emailFailure != nil {
            return .email
        }
        if validation.passwordFailure != nil {
            return passwordFocus
        }
        return nil
    }

    private func prepareForSubmission(currentFocus: FocusedField?) {
        suppressFocusValidationIfNeeded(currentFocus)
        password = ""
        validatedFields.removeAll()
        isPasswordVisible = false
    }

    private func suppressFocusValidationIfNeeded(_ currentFocus: FocusedField?) {
        if currentFocus != nil {
            suppressNextFocusValidation = true
        }
    }
}
