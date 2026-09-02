//
//  CollectionAccess.swift
//  MangaLibrary
//

import Foundation

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
    case user(UUID, restriction: MutationRestriction?)

    var userID: UUID? {
        guard case let .user(userID, _) = self else { return nil }

        return userID
    }

    var canMutate: Bool {
        guard case let .user(_, restriction) = self else { return false }

        return restriction == nil
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
                .user(previousUserID, restriction: .authenticating)
            } else {
                .unavailable(.authenticating)
            }
        case let .authenticated(account, _):
            .user(account.id, restriction: nil)
        case let .authenticationRequired(userID, _):
            .user(userID, restriction: .authenticationRequired)
        case let .signingOut(account):
            .user(account.id, restriction: .signingOut)
        }
    }
}

/// Resolves a generation-scoped commit capability for Collection persistence.
struct CollectionSessionAuthorization {
    typealias Operation = @Sendable (UUID) async -> SessionCommitAuthorization?

    static let denied = Self { _ in nil }
    static let deterministic = Self { userID in
        let authority = SessionAuthority(userID: userID, generation: deterministicGeneration)
        let gate = SessionCommitGate(activeAuthority: authority)
        return gate.authorization(for: authority)
    }

    private static let deterministicGeneration = UUID(
        uuidString: "C011EC71-0000-0000-0000-000000000001"
    )!

    private let operation: Operation

    func callAsFunction(_ userID: UUID) async -> SessionCommitAuthorization? {
        await operation(userID)
    }
}

extension CollectionSessionAuthorization {
    init(sessionController: SessionController) {
        self.init { userID in await sessionController.commitAuthorization(for: userID) }
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
            guard
                await accountModel.authorizesCollectionMutation(userID: command.userID),
                let authorization = await sessionAuthorization(command.userID)
            else {
                throw CollectionMutationError.authenticationRequired
            }

            do {
                return try await actor.apply(command, authorization: authorization)
            } catch let error as CollectionMutationError {
                throw error
            } catch {
                throw CollectionMutationError.persistenceConflict
            }
        }
    }
}

private extension AccountModel {
    func authorizesCollectionMutation(userID: UUID) -> Bool {
        guard case let .authenticated(account, _) = state else { return false }

        return account.id == userID
    }
}
