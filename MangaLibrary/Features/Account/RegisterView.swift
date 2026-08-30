//
//  RegisterView.swift
//  MangaLibrary
//

import SwiftUI

struct RegisterView: View {
    private enum Field: Hashable {
        case email
        case password
    }

    let model: AccountModel
    let onSignIn: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var registrationTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    var body: some View {
        Form {
            content
        }
        .scrollContentBackground(.hidden)
        .background(Color(.canvas))
        .navigationTitle("Create account")
        .defaultFocus($focusedField, .email)
        .disabled(isBusy)
        .onDisappear {
            registrationTask?.cancel()
            registrationTask = nil
            password = ""
            focusedField = nil
            model.abandonRegistration()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.registrationState {
        case .idle:
            credentialsSection
            submitSection

        case let .failed(failure):
            credentialsSection
            Section("Unable to create account") {
                Label(
                    failure.errorDescriptionResource,
                    systemImage: "exclamationmark.triangle"
                )
            }
            .accessibilityIdentifier("account.register.failure")
            submitSection

        case .submitting:
            Section {
                ProgressView("Creating account")
                    .accessibilityIdentifier("account.register.progress")
            }

        case .signingIn:
            Section {
                Label("Account created", systemImage: "checkmark.circle")
                    .accessibilityIdentifier("account.register.created")
                ProgressView("Signing in")
                    .accessibilityIdentifier("account.register.signing-in")
            }

        case let .unconfirmed(failure):
            Section {
                Label(
                    "Account creation couldn't be confirmed",
                    systemImage: "questionmark.circle"
                )
                .accessibilityIdentifier("account.register.unconfirmed")

                Text(
                    "The request may have created your account. Try signing in before creating it again."
                )
                Text(failure.errorDescriptionResource)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Sign in") {
                    onSignIn()
                }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("account.register.sign-in")

                Button("Try creating account again") {
                    model.prepareRegistrationRetry()
                    focusedField = .email
                }
                .accessibilityIdentifier("account.register.retry")
            }

        case let .created(loginFailure):
            Section {
                Label("Account created", systemImage: "checkmark.circle")
                    .accessibilityIdentifier("account.register.created")
                Text(
                    "Your account was created, but Manga Library couldn't sign you in."
                )
                if let loginFailure {
                    Text(loginFailure.errorDescriptionResource)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Sign in") {
                    onSignIn()
                }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("account.register.sign-in")
            }
        }
    }

    private var credentialsSection: some View {
        Section {
            TextField("Email", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .email)
                .onSubmit {
                    focusedField = .password
                }
                .accessibilityIdentifier("account.register.email")

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .submitLabel(.go)
                .focused($focusedField, equals: .password)
                .onSubmit {
                    startRegistration()
                }
                .accessibilityHint(
                    "Password must contain at least 8 characters."
                )
                .accessibilityIdentifier("account.register.password")
        } header: {
            Text("Credentials")
        } footer: {
            Text("Password must contain at least 8 characters.")
        }
    }

    private var submitSection: some View {
        Section {
            Button("Create account") {
                startRegistration()
            }
            .disabled(canSubmit == false)
            .accessibilityIdentifier("account.register.submit")
        }
    }

    private var canSubmit: Bool {
        switch model.registrationState {
        case .idle, .failed:
            model.canSubmitRegistration(email: email, password: password)
        case .submitting, .signingIn, .created, .unconfirmed:
            false
        }
    }

    private var isBusy: Bool {
        switch model.registrationState {
        case .submitting, .signingIn:
            true
        case .idle, .failed, .created, .unconfirmed:
            false
        }
    }

    private func startRegistration() {
        guard canSubmit else { return }

        let submittedEmail = email
        let submittedPassword = password
        password = ""
        focusedField = nil

        registrationTask?.cancel()
        registrationTask = Task { @MainActor [model] in
            await model.register(
                email: submittedEmail,
                password: submittedPassword
            )
        }
    }
}

#Preview("Register") {
    NavigationStack {
        RegisterView(
            model: AccountPreviewSupport.model(
                state: .signedOut(failure: nil)
            ),
            onSignIn: {}
        )
    }
    .environment(\.locale, Locale(identifier: "en"))
}

#Preview("Register Spanish") {
    NavigationStack {
        RegisterView(
            model: AccountPreviewSupport.model(
                state: .signedOut(failure: nil)
            ),
            onSignIn: {}
        )
    }
    .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Register submitting") {
    NavigationStack {
        RegisterView(
            model: AccountPreviewSupport.model(
                state: .signedOut(failure: nil),
                registrationState: .submitting
            ),
            onSignIn: {}
        )
    }
}

#Preview("Register failure") {
    NavigationStack {
        RegisterView(
            model: AccountPreviewSupport.model(
                state: .signedOut(failure: nil),
                registrationState: .failed(.configurationUnavailable)
            ),
            onSignIn: {}
        )
    }
}

#Preview("Register unconfirmed Spanish AX5") {
    NavigationStack {
        RegisterView(
            model: AccountPreviewSupport.model(
                state: .signedOut(failure: nil),
                registrationState: .unconfirmed(
                    .network(.transport(.timedOut))
                )
            ),
            onSignIn: {}
        )
    }
    .environment(\.locale, Locale(identifier: "es"))
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Register signing in") {
    NavigationStack {
        RegisterView(
            model: AccountPreviewSupport.model(
                state: .signedOut(failure: nil),
                registrationState: .signingIn
            ),
            onSignIn: {}
        )
    }
}

#Preview("Register created") {
    NavigationStack {
        RegisterView(
            model: AccountPreviewSupport.model(
                state: .signedOut(failure: nil),
                registrationState: .created(
                    loginFailure: .invalidCredentials
                )
            ),
            onSignIn: {}
        )
    }
}
