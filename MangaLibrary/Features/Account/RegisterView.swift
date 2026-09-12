//
//  RegisterView.swift
//  MangaLibrary
//

import SwiftUI

struct RegisterView: View {
    let onSignIn: () -> Void

    @State private var viewModel: RegisterViewModel
    @FocusState private var focusedField: RegisterViewModel.FocusedField?

    init(model: AccountModel, onSignIn: @escaping () -> Void) {
        self.onSignIn = onSignIn
        _viewModel = State(initialValue: RegisterViewModel(accountModel: model))
    }

    var body: some View {
        Form {
            content
        }
        .scrollContentBackground(.hidden)
        .background(.canvas)
        .navigationTitle("Create account")
        .defaultFocus($focusedField, .email)
        .disabled(viewModel.isBusy)
        .onChange(of: focusedField) { previousField, currentField in
            viewModel.focusChanged(from: previousField, to: currentField)
        }
        .onDisappear {
            focusedField = viewModel.disappear(currentFocus: focusedField)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.registrationState {
        case .idle:
            emailSection
            passwordSection
            submitSection

        case let .failed(failure):
            emailSection
            passwordSection
            Section("Unable to create account") {
                Label(failure.errorDescriptionResource, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.dangerInk)
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

        case .unconfirmed:
            Section {
                Label("Check your account", systemImage: "questionmark.circle")
                    .accessibilityIdentifier("account.register.unconfirmed")

                Text("It may already be created. Try signing in before creating it again.")
            }

            Section {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        unconfirmedActions
                    }
                    .buttonSizing(.flexible)

                    VStack(spacing: 16) {
                        unconfirmedActions
                    }
                    .buttonSizing(.fitted)
                    .frame(maxWidth: .infinity)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

        case .created:
            Section {
                Label("Account created", systemImage: "checkmark.circle")
                    .accessibilityIdentifier("account.register.created")
                Text("Sign in to continue.")
            }

            Section {
                Button {
                    onSignIn()
                } label: {
                    actionLabel("Sign in")
                        .foregroundStyle(.onBrandPrimary)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonSizing(.fitted)
                .tint(Color.brandPrimary)
                .accessibilityIdentifier("account.register.sign-in")
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }

    private var emailSection: some View {
        Section {
            TextField("Email", text: $viewModel.email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .email)
                .onSubmit {
                    focusedField = viewModel.emailSubmitted()
                }
                .accessibilityIdentifier("account.register.email")
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .background(.surface, in: .rect(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.controlBorder, lineWidth: 1)
                }
                .listRowInsets(
                    EdgeInsets(
                        top: 4,
                        leading: 4,
                        bottom: 4,
                        trailing: 4
                    )
                )
                .listRowBackground(Color.canvas)
        } footer: {
            if let emailFailure = viewModel.emailFailure {
                Label(emailFailure.errorDescriptionResource, systemImage: "exclamationmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.dangerInk)
                .accessibilityIdentifier("account.register.email.failure")
            }
        }
    }

    private var passwordSection: some View {
        Section {
            HStack(spacing: 8) {
                Group {
                    if viewModel.isPasswordVisible {
                        TextField("Password", text: $viewModel.password)
                            .focused($focusedField, equals: .revealedPassword)
                    } else {
                        SecureField("Password", text: $viewModel.password)
                            .focused($focusedField, equals: .concealedPassword)
                    }
                }
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit {
                    focusedField = viewModel.submit(currentFocus: focusedField)
                }
                .accessibilityHint("Password must contain at least 8 characters.")
                .accessibilityIdentifier("account.register.password")
                .privacySensitive()

                Button {
                    focusedField = viewModel.togglePasswordVisibility(currentFocus: focusedField)
                } label: {
                    Label {
                        Text(viewModel.passwordVisibilityLabel)
                    } icon: {
                        Image(systemName: viewModel.isPasswordVisible ? "eye.slash" : "eye")
                    }
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
                .tint(Color.brandPrimary)
                .accessibilityIdentifier("account.register.password-visibility")
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(.surface, in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.controlBorder, lineWidth: 1)
            }
            .listRowInsets(
                EdgeInsets(
                    top: 4,
                    leading: 4,
                    bottom: 4,
                    trailing: 4
                )
            )
            .listRowBackground(Color.canvas)
        } footer: {
            if let passwordFailure = viewModel.passwordFailure {
                Label(passwordFailure.errorDescriptionResource, systemImage: "exclamationmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.dangerInk)
                .accessibilityIdentifier("account.register.password.failure")
            } else {
                Text("Password must contain at least 8 characters.")
            }
        }
    }

    private var submitSection: some View {
        Section {
            Button {
                focusedField = viewModel.submit(currentFocus: focusedField)
            } label: {
                actionLabel("Create account")
                    .foregroundStyle(.onBrandPrimary)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonSizing(.fitted)
            .tint(Color.brandPrimary)
            .accessibilityIdentifier("account.register.submit")
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func actionLabel(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .font(.headline)
    }

    @ViewBuilder
    private var unconfirmedActions: some View {
        Button {
            onSignIn()
        } label: {
            actionLabel("Sign in")
                .foregroundStyle(.onBrandPrimary)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.brandPrimary)
        .accessibilityIdentifier("account.register.sign-in")

        Button {
            focusedField = viewModel.prepareRetry()
        } label: {
            actionLabel("Create account again")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(Color.brandPrimary)
        .accessibilityIdentifier("account.register.retry")
    }

}

private extension RegisterView {
    init(
        previewModel model: AccountModel,
        email: String,
        password: String,
        showsValidationErrors: Bool,
        onSignIn: @escaping () -> Void = {}
    ) {
        self.onSignIn = onSignIn
        _viewModel = State(
            initialValue: RegisterViewModel(
                accountModel: model,
                email: email,
                password: password,
                showsValidationErrors: showsValidationErrors
            )
        )
    }
}

#Preview("Register") {
    NavigationStack {
        RegisterView(model: AccountPreviewSupport.model(state: .signedOut(failure: nil)), onSignIn: {})
    }
    .environment(\.locale, Locale(identifier: "en"))
}

#Preview("Register Spanish") {
    NavigationStack {
        RegisterView(model: AccountPreviewSupport.model(state: .signedOut(failure: nil)), onSignIn: {})
    }
    .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Register inline validation") {
    NavigationStack {
        RegisterView(
            previewModel: AccountPreviewSupport.model(state: .signedOut(failure: nil)),
            email: "readerexample.invalid",
            password: "short",
            showsValidationErrors: true
        )
    }
    .environment(\.locale, Locale(identifier: "en"))
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Register submitting") {
    NavigationStack {
        RegisterView(
            model: AccountPreviewSupport.model(state: .signedOut(failure: nil), registrationState: .submitting),
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

#Preview("Register unconfirmed Spanish") {
    NavigationStack {
        RegisterView(
            model: AccountPreviewSupport.model(
                state: .signedOut(failure: nil),
                registrationState: .unconfirmed(.network(.transport(.timedOut)))
            ),
            onSignIn: {}
        )
    }
    .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Register signing in") {
    NavigationStack {
        RegisterView(
            model: AccountPreviewSupport.model(state: .signedOut(failure: nil), registrationState: .signingIn),
            onSignIn: {}
        )
    }
}

#Preview("Register created") {
    NavigationStack {
        RegisterView(
            model: AccountPreviewSupport.model(
                state: .signedOut(failure: nil),
                registrationState: .created(loginFailure: .invalidCredentials)
            ),
            onSignIn: {}
        )
    }
}
