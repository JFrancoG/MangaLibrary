//
//  AccountRootView.swift
//  MangaLibrary
//

import SwiftUI

enum AccountRoute: Hashable {
    case signIn
    case register
}

struct AccountCollectionNotice: Equatable {
    enum Reason: Equatable {
        case authorizationDenied
        case authenticationIncompatible
    }

    let userID: UUID
    let reason: Reason

    var messageResource: LocalizedStringResource {
        switch reason {
        case .authorizationDenied:
            "Your session is still active, but this account does not currently have access to the remote collection."
        case .authenticationIncompatible:
            "Your session is still active, but the collection service could not verify the renewed access. Signing in again is not required."
        }
    }

    var accessibilityIdentifier: String {
        switch reason {
        case .authorizationDenied:
            "account.collection-sync.authorization-denied"
        case .authenticationIncompatible:
            "account.collection-sync.authentication-incompatible"
        }
    }
}

struct AccountRootView: View {
    private enum Action: Hashable {
        case retryRestore
        case signOut
    }

    let model: AccountModel
    let collectionNotice: AccountCollectionNotice?

    @State private var path: [AccountRoute] = []
    @State private var requestedAction: Action?

    init(model: AccountModel, collectionNotice: AccountCollectionNotice? = nil) {
        self.model = model
        self.collectionNotice = collectionNotice
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Account")
                .navigationDestination(for: AccountRoute.self) { route in
                    switch route {
                    case .signIn:
                        SignInView(model: model)
                    case .register:
                        RegisterView(
                            model: model,
                            onSignIn: {
                                path = [.signIn]
                            }
                        )
                    }
                }
        }
        .onChange(of: authenticatedAccountID) {
            guard authenticatedAccountID != nil else { return }
            path.removeAll()
        }
        .task(id: requestedAction) {
            guard let action = requestedAction else { return }

            switch action {
            case .retryRestore:
                await model.restore()
            case .signOut:
                await model.signOut()
            }

            if requestedAction == action {
                requestedAction = nil
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .restoring:
            ProgressView("Restoring session")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("account.restoring")

        case let .restorationFailed(failure):
            restorationFailureContent(failure: failure)

        case let .signedOut(failure):
            signInRequiredContent(
                title: "Sign in to Manga Library",
                description: "Sign in with an existing Manga Library account.",
                failure: failure,
                stateIdentifier: "account.signed-out",
                allowsRegistration: true
            )

        case .authenticating:
            ProgressView("Signing in")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("account.authenticating")

        case let .authenticated(account, notice):
            authenticatedContent(
                account: account,
                notice: notice,
                collectionNotice: collectionNotice?.userID == account.id ? collectionNotice : nil
            )

        case let .authenticationRequired(_, failure):
            signInRequiredContent(
                title: "Sign in again",
                description: "Enter your credentials to continue.",
                failure: failure,
                stateIdentifier: "account.authentication-required",
                allowsRegistration: false
            )

        case let .signingOut(account):
            ProgressView("Signing out")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Signing out")
                .accessibilityValue(account.email ?? "")
                .accessibilityIdentifier("account.signing-out")

        }
    }

    private func signInRequiredContent(
        title: LocalizedStringResource,
        description: LocalizedStringResource,
        failure: AccountModel.Failure?,
        stateIdentifier: String,
        allowsRegistration: Bool
    ) -> some View {
        ScrollView {
            ContentUnavailableView {
                Label(title, systemImage: "person.crop.circle.badge.questionmark")
                    .accessibilityIdentifier(stateIdentifier)
            } description: {
                VStack(spacing: 8) {
                    Text(description)
                    if let failure {
                        Text(failure.errorDescriptionResource)
                            .foregroundStyle(.secondary)
                    }
                }
            } actions: {
                VStack(spacing: 16) {
                    Button {
                        path.append(.signIn)
                    } label: {
                        accountActionLabel("Sign in")
                            .foregroundStyle(.onBrandPrimary)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .buttonSizing(.fitted)
                    .accessibilityIdentifier("account.sign-in.action")
                    .padding(
                        EdgeInsets(
                            top: 0,
                            leading: 0,
                            bottom: 16,
                            trailing: 0
                        )
                    )

                    if allowsRegistration {
                        VStack(spacing: 16) {
                            Text("Don't have an account?")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("account.register.prompt")

                            Button {
                                path.append(.register)
                            } label: {
                                accountActionLabel("Create account")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .buttonSizing(.fitted)
                            .accessibilityIdentifier("account.register.action")
                        }
                    }
                }
            }
            .padding(.vertical, 24)
        }
    }

    private func accountActionLabel(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .font(.headline)
    }

    private func restorationFailureContent(failure: AccountModel.Failure) -> some View {
        ScrollView {
            ContentUnavailableView {
                Label("Session restoration needs attention", systemImage: "lock.trianglebadge.exclamationmark")
                .accessibilityIdentifier("account.restoration-failure")
            } description: {
                VStack(spacing: 8) {
                    Text("Retry restoration before signing in.")
                    Text(failure.errorDescriptionResource)
                        .foregroundStyle(.secondary)
                }
            } actions: {
                Button("Retry restoration") {
                    requestedAction = .retryRestore
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("account.restoration.retry")
            }
            .padding(.vertical, 24)
        }
    }

    private func authenticatedContent(
        account: SessionAccount,
        notice: AccountModel.Failure?,
        collectionNotice: AccountCollectionNotice?
    ) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Label("Signed in", systemImage: "checkmark.circle.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.successInk)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("account.authenticated")

                if let email = account.email {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.textSecondary)

                        Text(email)
                            .font(.body)
                            .foregroundStyle(.textPrimary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .privacySensitive()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.surface, in: .rect(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.separatorDecorative, lineWidth: 1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("account.identity.email")
                }

                if let collectionNotice {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Collection notice")
                            .font(.headline)

                        Label(collectionNotice.messageResource, systemImage: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(.onWarning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.warningFill, in: .rect(cornerRadius: 16, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(collectionNotice.accessibilityIdentifier)
                }

                if let notice {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session notice")
                            .font(.headline)

                        Label(notice.errorDescriptionResource, systemImage: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(.dangerInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.surface, in: .rect(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.dangerInk, lineWidth: 1)
                    }
                }

                Button("Sign out", role: .destructive) {
                    requestedAction = .signOut
                }
                .font(.headline)
                .foregroundStyle(.onDanger)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonSizing(.fitted)
                .tint(Color.dangerFill)
                .accessibilityIdentifier("account.sign-out")
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: 728)
            .frame(maxWidth: .infinity)
        }
        .background(.canvas)
    }

    private var authenticatedAccountID: UUID? {
        guard case let .authenticated(account, _) = model.state else { return nil }
        return account.id
    }
}

#Preview("Account signed out") {
    AccountRootView(model: AccountPreviewSupport.model(state: .signedOut(failure: nil)))
}

#Preview("Account landing after registration uncertainty") {
    AccountRootView(
        model: AccountPreviewSupport.model(
            state: .signedOut(failure: nil),
            registrationState: .unconfirmed(.network(.transport(.timedOut)))
        )
    )
}

#Preview("Account restoring") {
    AccountRootView(model: AccountPreviewSupport.model(state: .restoring))
}

#Preview("Account restoration failure") {
    AccountRootView(model: AccountPreviewSupport.model(state: .restorationFailed(failure: .temporarilyUnavailable)))
}

#Preview("Account authenticated") {
    AccountRootView(
        model: AccountPreviewSupport.model(state: .authenticated(AccountPreviewSupport.account, notice: nil))
    )
}

#Preview("Account authenticated without email") {
    AccountRootView(
        model: AccountPreviewSupport.model(
            state: .authenticated(AccountPreviewSupport.accountWithoutEmail, notice: nil)
        )
    )
}

#Preview("Account authenticated with notice") {
    AccountRootView(
        model: AccountPreviewSupport.model(
            state: .authenticated(AccountPreviewSupport.account, notice: .temporarilyUnavailable)
        )
    )
}

#Preview(
    "Account Collection authentication notice",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Empty>())
) {
    AccountRootView(
        model: AccountPreviewSupport.model(state: .authenticated(AccountPreviewSupport.account, notice: nil)),
        collectionNotice: AccountCollectionNotice(
            userID: AccountPreviewSupport.account.id,
            reason: .authenticationIncompatible
        )
    )
}

#Preview("Account authentication required") {
    AccountRootView(
        model: AccountPreviewSupport.model(
            state: .authenticationRequired(userID: AccountPreviewSupport.account.id, failure: .authenticationRequired)
        )
    )
}

#Preview("Account signing out") {
    AccountRootView(model: AccountPreviewSupport.model(state: .signingOut(AccountPreviewSupport.account)))
}
