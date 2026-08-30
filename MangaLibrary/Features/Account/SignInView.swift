//
//  SignInView.swift
//  MangaLibrary
//

import SwiftUI

struct SignInView: View {
    private enum Field: Hashable {
        case email
        case password
    }

    let model: AccountModel

    @State private var email = ""
    @State private var password = ""
    @State private var signInTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    var body: some View {
        Form {
            Section("Credentials") {
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
                    .accessibilityIdentifier("account.sign-in.email")

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        startSignIn()
                    }
                    .accessibilityIdentifier("account.sign-in.password")
            }

            if let failure {
                Section("Unable to sign in") {
                    Label(
                        failure.errorDescriptionResource,
                        systemImage: "exclamationmark.triangle"
                    )
                }
                .accessibilityIdentifier("account.sign-in.failure")
            }

            Section {
                Button("Sign in") {
                    startSignIn()
                }
                .disabled(canSubmit == false)
                .accessibilityIdentifier("account.sign-in.submit")

                if isAuthenticating {
                    ProgressView("Signing in")
                        .accessibilityIdentifier("account.sign-in.progress")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.canvas))
        .navigationTitle("Sign in")
        .defaultFocus($focusedField, .email)
        .disabled(isAuthenticating)
        .onDisappear {
            signInTask?.cancel()
            signInTask = nil
            password = ""
        }
    }

    private var isAuthenticating: Bool {
        model.state == .authenticating
    }

    private var canSubmit: Bool {
        model.canSubmitSignIn(email: email, password: password)
            && isAuthenticating == false
    }

    private var failure: AccountModel.Failure? {
        switch model.state {
        case let .signedOut(failure),
             let .authenticationRequired(_, failure):
            failure
        case .restoring, .restorationFailed, .authenticating,
             .authenticated, .signingOut, .logoutPrepared,
             .resolvingLogout, .cleaning:
            nil
        }
    }

    private func startSignIn() {
        guard canSubmit else {
            return
        }

        let submittedEmail = email
        let submittedPassword = password
        password = ""
        focusedField = nil

        signInTask?.cancel()
        signInTask = Task { @MainActor [model] in
            await model.signIn(
                email: submittedEmail,
                password: submittedPassword
            )
        }
    }
}

#Preview("Sign in") {
    NavigationStack {
        SignInView(
            model: AccountPreviewSupport.model(
                state: .signedOut(failure: nil)
            )
        )
    }
}

#Preview("Sign in error") {
    NavigationStack {
        SignInView(
            model: AccountPreviewSupport.model(
                state: .signedOut(failure: .invalidCredentials)
            )
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Sign in authenticating") {
    NavigationStack {
        SignInView(
            model: AccountPreviewSupport.model(
                state: .authenticating
            )
        )
    }
}
