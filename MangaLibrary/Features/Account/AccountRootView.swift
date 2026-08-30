//
//  AccountRootView.swift
//  MangaLibrary
//

import SwiftUI

enum AccountRoute: Hashable {
    case signIn
}

struct AccountRootView: View {
    private enum Action: Hashable {
        case retryRestore
        case signOut
        case retryLogout
        case cancelLogout
        case retryCleanup
    }

    let model: AccountModel

    @State private var path: [AccountRoute] = []
    @State private var requestedAction: Action?

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Account")
                .navigationDestination(for: AccountRoute.self) { route in
                    switch route {
                    case .signIn:
                        SignInView(model: model)
                    }
                }
        }
        .onChange(of: authenticatedAccountID) {
            guard authenticatedAccountID != nil else {
                return
            }
            path.removeAll()
        }
        .task(id: requestedAction) {
            guard let action = requestedAction else {
                return
            }

            switch action {
            case .retryRestore:
                await model.restore()
            case .signOut:
                await model.signOut()
            case .retryLogout:
                await model.retryLogout()
            case .cancelLogout:
                await model.cancelLogout()
            case .retryCleanup:
                await model.retryCleanup()
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
                stateIdentifier: "account.signed-out"
            )

        case .authenticating:
            ProgressView("Signing in")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("account.authenticating")

        case let .authenticated(account, notice):
            authenticatedContent(account: account, notice: notice)

        case let .authenticationRequired(_, failure):
            signInRequiredContent(
                title: "Sign in again",
                description: "Enter your credentials to continue.",
                failure: failure,
                stateIdentifier: "account.authentication-required"
            )

        case let .signingOut(account):
            ProgressView("Signing out")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Signing out")
                .accessibilityValue(account.email ?? "")
                .accessibilityIdentifier("account.signing-out")

        case let .logoutPrepared(account, failure):
            logoutPreparedContent(account: account, failure: failure)

        case let .resolvingLogout(account):
            ProgressView("Keeping session active")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityValue(account.email ?? "")
                .accessibilityIdentifier("account.logout-resolving")

        case let .cleaning(_, completion, failure):
            cleaningContent(completion: completion, failure: failure)
        }
    }

    private func signInRequiredContent(
        title: LocalizedStringResource,
        description: LocalizedStringResource,
        failure: AccountModel.Failure?,
        stateIdentifier: String
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
                Button("Sign in") {
                    path.append(.signIn)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("account.sign-in.action")
            }
            .padding(.vertical, 24)
        }
    }

    private func restorationFailureContent(failure: AccountModel.Failure) -> some View {
        ScrollView {
            ContentUnavailableView {
                Label(
                    "Session restoration needs attention",
                    systemImage: "lock.trianglebadge.exclamationmark"
                )
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

    private func authenticatedContent(account: SessionAccount, notice: AccountModel.Failure?) -> some View {
        Form {
            Section {
                if let email = account.email {
                    LabeledContent("Email") {
                        Text(email)
                            .accessibilityIdentifier("account.identity.email")
                    }
                } else {
                    Text("Signed in")
                }
            } header: {
                Text("Account")
                    .accessibilityIdentifier("account.authenticated")
            }

            if let notice {
                Section("Session notice") {
                    Label(
                        notice.errorDescriptionResource,
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }

            Section {
                Button("Sign out", role: .destructive) {
                    requestedAction = .signOut
                }
                .accessibilityIdentifier("account.sign-out")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.canvas))
    }

    private func logoutPreparedContent(account _: SessionAccount, failure: AccountModel.Failure?) -> some View {
        ScrollView {
            ContentUnavailableView {
                Label("Sign out needs attention", systemImage: "exclamationmark.triangle")
                    .accessibilityIdentifier("account.logout-prepared")
            } description: {
                VStack(spacing: 8) {
                    Text("The session is still active and can be kept safely.")
                    if let failure {
                        Text(failure.errorDescriptionResource)
                            .foregroundStyle(.secondary)
                    }
                }
            } actions: {
                Button("Retry sign out") {
                    requestedAction = .retryLogout
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("account.logout.retry")

                Button("Keep me signed in") {
                    requestedAction = .cancelLogout
                }
                .accessibilityIdentifier("account.logout.cancel")
            }
            .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private func cleaningContent(completion: SessionCleanupCompletion, failure: AccountModel.Failure?) -> some View {
        if let failure {
            ScrollView {
                ContentUnavailableView {
                    Label("Session cleanup needs attention", systemImage: "lock.trianglebadge.exclamationmark")
                        .accessibilityIdentifier("account.cleaning.failure")
                } description: {
                    VStack(spacing: 8) {
                        Text(cleanupDescription(for: completion))
                        Text(failure.errorDescriptionResource)
                            .foregroundStyle(.secondary)
                    }
                } actions: {
                    Button("Retry cleanup") {
                        requestedAction = .retryCleanup
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("account.cleanup.retry")
                }
                .padding(.vertical, 24)
            }
        } else {
            ProgressView("Finishing secure session cleanup")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("account.cleaning")
        }
    }

    private func cleanupDescription(for completion: SessionCleanupCompletion) -> LocalizedStringResource {
        switch completion {
        case .signedOut:
            "Finish removing the signed-out session from this device."
        case .authenticationRequired:
            "Finish removing expired credentials before signing in again."
        }
    }

    private var authenticatedAccountID: UUID? {
        guard case let .authenticated(account, _) = model.state else {
            return nil
        }
        return account.id
    }
}

#Preview("Account signed out") {
    AccountRootView(
        model: AccountPreviewSupport.model(
            state: .signedOut(failure: nil)
        )
    )
}

#Preview("Account restoring") {
    AccountRootView(
        model: AccountPreviewSupport.model(state: .restoring)
    )
}

#Preview("Account restoration failure") {
    AccountRootView(
        model: AccountPreviewSupport.model(
            state: .restorationFailed(failure: .temporarilyUnavailable)
        )
    )
}

#Preview("Account authenticated") {
    AccountRootView(
        model: AccountPreviewSupport.model(
            state: .authenticated(
                AccountPreviewSupport.account,
                notice: nil
            )
        )
    )
}

#Preview("Account authentication required") {
    AccountRootView(
        model: AccountPreviewSupport.model(
            state: .authenticationRequired(
                userID: AccountPreviewSupport.account.id,
                failure: .authenticationRequired
            )
        )
    )
}

#Preview("Account logout prepared") {
    AccountRootView(
        model: AccountPreviewSupport.model(
            state: .logoutPrepared(
                AccountPreviewSupport.account,
                failure: .temporarilyUnavailable
            )
        )
    )
}

#Preview("Account signing out") {
    AccountRootView(
        model: AccountPreviewSupport.model(
            state: .signingOut(AccountPreviewSupport.account)
        )
    )
}

#Preview("Account keeping session active") {
    AccountRootView(
        model: AccountPreviewSupport.model(
            state: .resolvingLogout(AccountPreviewSupport.account)
        )
    )
}

#Preview("Account cleanup failure") {
    AccountRootView(
        model: AccountPreviewSupport.model(
            state: .cleaning(
                userID: AccountPreviewSupport.account.id,
                completion: .signedOut,
                failure: .temporarilyUnavailable
            )
        )
    )
}

#Preview("Account cleanup in progress") {
    AccountRootView(
        model: AccountPreviewSupport.model(
            state: .cleaning(
                userID: AccountPreviewSupport.account.id,
                completion: .signedOut,
                failure: nil
            )
        )
    )
}
