#if DEBUG
import Foundation

actor UITestingPendingLogoutSession {
    private let mutationActor: CollectionMutationActor
    private var snapshot = SessionSnapshot.active(AccountPreviewSupport.account)

    init(mutationActor: CollectionMutationActor) {
        self.mutationActor = mutationActor
    }

    nonisolated func operations() -> AccountModel.Operations {
        AccountModel.Operations(
            currentSnapshot: { [self] in
                await currentSnapshot()
            },
            restore: { [self] in
                await currentSnapshot()
            },
            login: { [self] _, _ in
                await currentSnapshot()
            },
            register: { _, _ in .confirmed },
            logout: { [self] discardPendingChanges in
                try await logout(discardPendingChanges: discardPendingChanges)
            }
        )
    }

    private func currentSnapshot() -> SessionSnapshot {
        snapshot
    }

    private func logout(discardPendingChanges: Bool) async throws(any Error) -> SessionSnapshot {
        guard case .active = snapshot else { throw SessionControllerError.notAuthenticated }
        let authority = AccountPreviewSupport.account.authority
        let gate = SessionCommitGate(activeAuthority: authority)
        guard let authorization = gate.suspendForLogout(authority) else { throw SessionControllerError.sessionChanged }

        if discardPendingChanges {
            try await mutationActor.discardPendingChangesForLogout(authorization: authorization)
        } else if try await mutationActor.hasPendingChangesForLogout(authorization: authorization) {
            throw SessionControllerError.pendingCollectionChanges
        }

        snapshot = .signedOut
        return snapshot
    }
}
#endif
