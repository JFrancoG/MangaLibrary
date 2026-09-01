//
//  SignInView.swift
//  MangaLibrary
//

import SwiftUI

struct SignInView: View {
    @State private var viewModel: SignInViewModel
    @FocusState private var focusedField: SignInViewModel.FocusedField?

    init(model: AccountModel) {
        _viewModel = State(initialValue: SignInViewModel(accountModel: model))
    }

    var body: some View {
        Form {
            emailSection
            passwordSection

            if let failure = viewModel.failure {
                Section("Unable to sign in") {
                    Label(failure.errorDescriptionResource, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Color(.dangerInk))
                }
                .accessibilityIdentifier("account.sign-in.failure")
            }

            Section {
                VStack(spacing: 22) {
                    Button {
                        focusedField = viewModel.submit(currentFocus: focusedField)
                    } label: {
                        Text("Sign in")
                            .font(.headline)
                            .foregroundStyle(Color(.onBrandPrimary))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .buttonSizing(.fitted)
                    .tint(Color(.brandPrimary))
                    .accessibilityIdentifier("account.sign-in.submit")

                    if viewModel.isAuthenticating {
                        ProgressView("Signing in")
                            .accessibilityIdentifier("account.sign-in.progress")
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.canvas))
        .navigationTitle("Sign in")
        .defaultFocus($focusedField, .email)
        .disabled(viewModel.isAuthenticating)
        .onChange(of: focusedField) { previousField, currentField in
            viewModel.focusChanged(from: previousField, to: currentField)
        }
        .onDisappear {
            focusedField = viewModel.disappear(currentFocus: focusedField)
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
                .accessibilityIdentifier("account.sign-in.email")
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .background(Color(.surface), in: .rect(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(.controlBorder), lineWidth: 1)
                }
                .listRowInsets(
                    EdgeInsets(
                        top: 4,
                        leading: 4,
                        bottom: 4,
                        trailing: 4
                    )
                )
                .listRowBackground(Color(.canvas))
        } footer: {
            if let emailFailure = viewModel.emailFailure {
                Label(emailFailure.errorDescriptionResource, systemImage: "exclamationmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(Color(.dangerInk))
                .accessibilityIdentifier("account.sign-in.email.failure")
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
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit {
                    focusedField = viewModel.submit(currentFocus: focusedField)
                }
                .accessibilityIdentifier("account.sign-in.password")
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
                .tint(Color(.brandPrimary))
                .accessibilityIdentifier("account.sign-in.password-visibility")
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(Color(.surface), in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(.controlBorder), lineWidth: 1)
            }
            .listRowInsets(
                EdgeInsets(
                    top: 4,
                    leading: 4,
                    bottom: 4,
                    trailing: 4
                )
            )
            .listRowBackground(Color(.canvas))
        } footer: {
            if let passwordFailure = viewModel.passwordFailure {
                Label(passwordFailure.errorDescriptionResource, systemImage: "exclamationmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(Color(.dangerInk))
                .accessibilityIdentifier("account.sign-in.password.failure")
            }
        }
    }

}

private extension SignInView {
    init(
        previewModel model: AccountModel,
        email: String,
        password: String,
        showsValidationErrors: Bool
    ) {
        _viewModel = State(
            initialValue: SignInViewModel(
                accountModel: model,
                email: email,
                password: password,
                showsValidationErrors: showsValidationErrors
            )
        )
    }
}

#Preview("Sign in") {
    NavigationStack {
        SignInView(model: AccountPreviewSupport.model(state: .signedOut(failure: nil)))
    }
}

#Preview("Sign in error") {
    NavigationStack {
        SignInView(model: AccountPreviewSupport.model(state: .signedOut(failure: .invalidCredentials)))
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Sign in inline validation Spanish AX5") {
    NavigationStack {
        SignInView(
            previewModel: AccountPreviewSupport.model(state: .signedOut(failure: nil)),
            email: "readerexample.invalid",
            password: "",
            showsValidationErrors: true
        )
    }
    .environment(\.locale, Locale(identifier: "es"))
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Sign in authenticating") {
    NavigationStack {
        SignInView(model: AccountPreviewSupport.model(state: .authenticating))
    }
}
