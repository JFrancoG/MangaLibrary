//
//  CollectionAccess.swift
//  MangaLibrary
//

import Foundation

struct CollectionUserScope: Equatable {
    let userID: UUID
    let authority: SessionAuthority?
}

/// The collection scope projected from the current session presentation.
///
/// A known identity can remain readable while reauthentication or logout is in
/// progress, but only an unrestricted authenticated scope authorizes a submit.
enum CollectionAccess: Equatable {
    enum UnavailableReason: Equatable {
        case restoring
        case restorationFailed
        case signedOut
        case authenticating
    }

    enum MutationRestriction: Equatable {
        case authenticationRequired
        case authenticating
        case signingOut
    }

    case unavailable(UnavailableReason)
    case user(CollectionUserScope, restriction: MutationRestriction?)

    var userID: UUID? {
        guard case let .user(scope, _) = self else { return nil }

        return scope.userID
    }

    var authority: SessionAuthority? {
        guard case let .user(scope, _) = self else { return nil }

        return scope.authority
    }

    var canMutate: Bool {
        guard case let .user(scope, restriction) = self else { return false }

        return restriction == nil && scope.authority != nil
    }
}

extension AccountModel.State {
    var collectionAccess: CollectionAccess {
        switch self {
        case .restoring:
            .unavailable(.restoring)
        case .restorationFailed:
            .unavailable(.restorationFailed)
        case .signedOut:
            .unavailable(.signedOut)
        case let .authenticating(previousUserID):
            if let previousUserID {
                .user(CollectionUserScope(userID: previousUserID, authority: nil), restriction: .authenticating)
            } else {
                .unavailable(.authenticating)
            }
        case let .authenticated(account, _):
            .user(CollectionUserScope(userID: account.id, authority: account.authority), restriction: nil)
        case let .authenticationRequired(userID, _):
            .user(CollectionUserScope(userID: userID, authority: nil), restriction: .authenticationRequired)
        case let .signingOut(account):
            .user(CollectionUserScope(userID: account.id, authority: account.authority), restriction: .signingOut)
        }
    }
}

/// Resolves a generation-scoped commit capability for Collection persistence.
struct CollectionSessionAuthorization {
    typealias Operation = @Sendable (SessionAuthority) async throws(any Error) -> SessionCommitAuthorization?

    static let denied = Self { _ in nil }
    static let deterministic = Self { authority in
        let gate = SessionCommitGate(activeAuthority: authority)
        return gate.authorization(for: authority)
    }

    private let operation: Operation

    init(operation: @escaping Operation) {
        self.operation = operation
    }

    func callAsFunction(_ authority: SessionAuthority) async throws(any Error) -> SessionCommitAuthorization? {
        try await operation(authority)
    }
}

extension CollectionSessionAuthorization {
    init(sessionController: SessionController) {
        self.init { authority in
            try await sessionController.commitAuthorization(for: authority)
        }
    }
}

/// Revalidates session authority before delegating to the sole model actor.
///
/// The capability stores no session snapshot. A sheet that outlives an account
/// transition therefore cannot enqueue work for a stale or unauthorized user.
struct CollectionMutation {
    typealias Operation = @Sendable (
        CollectionMutationCommand
    ) async throws(CollectionMutationError) -> CollectionMutationResult

    private let operation: Operation

    func callAsFunction(
        _ command: CollectionMutationCommand
    ) async throws(CollectionMutationError) -> CollectionMutationResult {
        try await operation(command)
    }
}

extension CollectionMutation {
    init(
        actor: CollectionMutationActor,
        accountModel: AccountModel,
        sessionAuthorization: CollectionSessionAuthorization
    ) {
        operation = {
            (command: CollectionMutationCommand) async throws(CollectionMutationError) -> CollectionMutationResult in
            guard await accountModel.authorizesCollectionMutation(command.authority) else {
                throw CollectionMutationError.authenticationRequired
            }
            let expectedAuthority = command.authority
            let authorization: SessionCommitAuthorization?
            do {
                authorization = try await sessionAuthorization(expectedAuthority)
            } catch is CancellationError {
                throw CollectionMutationError.cancelled
            } catch {
                await accountModel.reconcileSession(expectedAuthority: expectedAuthority, cause: error)
                throw CollectionMutationError.authenticationRequired
            }
            guard let authorization else {
                await accountModel.reconcileSession(expectedAuthority: expectedAuthority)
                throw CollectionMutationError.authenticationRequired
            }

            do {
                return try await actor.apply(command, authorization: authorization)
            } catch CollectionMutationError.authenticationRequired {
                let replacement: SessionCommitAuthorization?
                do {
                    replacement = try await sessionAuthorization(expectedAuthority)
                } catch is CancellationError {
                    throw CollectionMutationError.cancelled
                } catch {
                    await accountModel.reconcileSession(expectedAuthority: expectedAuthority, cause: error)
                    throw CollectionMutationError.authenticationRequired
                }
                guard let replacement else {
                    await accountModel.reconcileSession(expectedAuthority: expectedAuthority)
                    throw CollectionMutationError.authenticationRequired
                }
                guard replacement.authority == authorization.authority else {
                    throw CollectionMutationError.persistenceConflict
                }

                do {
                    return try await actor.apply(command, authorization: replacement)
                } catch CollectionMutationError.authenticationRequired {
                    let current: SessionCommitAuthorization?
                    do {
                        current = try await sessionAuthorization(expectedAuthority)
                    } catch is CancellationError {
                        throw CollectionMutationError.cancelled
                    } catch {
                        await accountModel.reconcileSession(expectedAuthority: expectedAuthority, cause: error)
                        throw CollectionMutationError.authenticationRequired
                    }
                    guard current != nil else {
                        await accountModel.reconcileSession(expectedAuthority: expectedAuthority)
                        throw CollectionMutationError.authenticationRequired
                    }
                    throw CollectionMutationError.persistenceConflict
                } catch let error as CollectionMutationError {
                    throw error
                } catch {
                    throw CollectionMutationError.persistenceConflict
                }
            } catch let error as CollectionMutationError {
                throw error
            } catch {
                throw CollectionMutationError.persistenceConflict
            }
        }
    }
}

private extension AccountModel {
    func authorizesCollectionMutation(_ authority: SessionAuthority) -> Bool {
        guard case let .authenticated(account, _) = state else { return false }

        return account.authority == authority
    }
}
