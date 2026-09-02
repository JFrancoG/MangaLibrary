//
//  AccountPreviewSupport.swift
//  MangaLibrary
//

import Foundation

enum AccountPreviewSupport {
    private static let userID = UUID(uuidString: "A11CE000-0000-4000-8000-000000000001")!
    private static let userWithoutEmailID = UUID(uuidString: "A11CE000-0000-4000-8000-000000000002")!
    private static let generation = UUID(uuidString: "C011EC71-0000-4000-8000-000000000001")!

    static let account = SessionAccount(
        authority: SessionAuthority(userID: userID, generation: generation),
        id: userID,
        email: "reader@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )

    static let accountWithoutEmail = SessionAccount(
        authority: SessionAuthority(userID: userWithoutEmailID, generation: generation),
        id: userWithoutEmailID,
        email: nil,
        isActive: true,
        isAdmin: false,
        role: "user"
    )

    @MainActor
    static func model(
        state: AccountModel.State,
        registrationState: AccountModel.RegistrationState = .idle
    ) -> AccountModel {
        let session = AccountPreviewSession(snapshot: snapshot(for: state), fallbackAccount: account)
        return AccountModel(initialState: state, registrationState: registrationState, operations: session.operations())
    }

    private static func snapshot(for state: AccountModel.State) -> SessionSnapshot {
        switch state {
        case .restoring, .restorationFailed:
            .notRestored
        case .signedOut:
            .signedOut
        case let .authenticating(previousUserID):
            previousUserID.map(SessionSnapshot.authenticationRequired) ?? .signedOut
        case let .authenticated(account, _), let .signingOut(account):
            .active(account)
        case let .authenticationRequired(userID, _):
            .authenticationRequired(userID)
        }
    }
}

private actor AccountPreviewSession {
    private var snapshot: SessionSnapshot
    private let fallbackAccount: SessionAccount

    init(snapshot: SessionSnapshot, fallbackAccount: SessionAccount) {
        self.snapshot = snapshot
        self.fallbackAccount = fallbackAccount
    }

    nonisolated func operations() -> AccountModel.Operations {
        AccountModel.Operations(
            currentSnapshot: { [self] in await currentSnapshot() },
            restore: { [self] in await restore() },
            login: { [self] email, _ in await login(email: email) },
            register: { _, _ in .confirmed },
            logout: { [self] in try await logout() }
        )
    }

    private func currentSnapshot() -> SessionSnapshot {
        snapshot
    }

    private func restore() -> SessionSnapshot {
        if snapshot == .notRestored {
            snapshot = .signedOut
        }
        return snapshot
    }

    private func login(email _: String) -> SessionSnapshot {
        snapshot = .active(fallbackAccount)
        return snapshot
    }

    private func logout() throws(SessionControllerError) -> SessionSnapshot {
        guard case .active = snapshot else { throw SessionControllerError.notAuthenticated }
        snapshot = .signedOut
        return snapshot
    }

}
