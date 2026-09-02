//
//  CollectionSyncCoordinator.swift
//  MangaLibrary
//

import Foundation

enum CollectionSyncError: Error, Equatable {
    case sessionChanged
}

/// Fences one authenticated Collection import to an exact session generation.
///
/// A new trigger cancels the previous flight. The current authority is checked
/// after transport for fast rejection; its commit capability is consumed again
/// inside the sole synchronous SwiftData transaction.
actor CollectionSyncCoordinator {
    typealias Authorize = @Sendable () async throws(any Error) -> SessionRequestAuthorization
    typealias ValidateAuthority = @Sendable (SessionAuthority) async -> Bool
    typealias RejectAuthorization = @Sendable (
        SessionRequestAuthorization
    ) async throws(any Error) -> Void
    typealias FetchRemote = @Sendable (String) async throws(any Error) -> [CollectionRemoteEntry]
    typealias ImportRemote = @Sendable (
        [CollectionRemoteEntry],
        SessionCommitAuthorization
    ) async throws(any Error) -> Void

    private final class OperationIdentity {}

    private struct Flight {
        let identity: OperationIdentity
        let task: Task<Void, any Error>
    }

    private let authorize: Authorize
    private let validateAuthority: ValidateAuthority
    private let rejectAuthorization: RejectAuthorization
    private let fetchRemote: FetchRemote
    private let importRemote: ImportRemote
    private var activeFlight: Flight?

    init(
        authorize: @escaping Authorize,
        validateAuthority: @escaping ValidateAuthority,
        rejectAuthorization: @escaping RejectAuthorization = { _ in },
        fetchRemote: @escaping FetchRemote,
        importRemote: @escaping ImportRemote
    ) {
        self.authorize = authorize
        self.validateAuthority = validateAuthority
        self.rejectAuthorization = rejectAuthorization
        self.fetchRemote = fetchRemote
        self.importRemote = importRemote
    }

    func importAuthenticatedCollection() async throws(any Error) {
        try Task.checkCancellation()
        activeFlight?.task.cancel()

        let identity = OperationIdentity()
        let task = Task { [authorize, validateAuthority, rejectAuthorization, fetchRemote, importRemote] in
            try Task.checkCancellation()
            let authorization = try await authorize()
            try Task.checkCancellation()
            let remoteEntries: [CollectionRemoteEntry]
            do {
                remoteEntries = try await fetchRemote(authorization.accessToken)
            } catch let error as CollectionAPIClientError {
                if case let .network(.statusCode(code)) = error, code == 401 || code == 403 {
                    try await rejectAuthorization(authorization)
                    throw SessionControllerError.authenticationRequired
                }
                throw error
            }
            try Task.checkCancellation()

            guard await validateAuthority(authorization.authority) else {
                throw CollectionSyncError.sessionChanged
            }
            try Task.checkCancellation()
            try await importRemote(remoteEntries, authorization.commitAuthorization)
        }
        let flight = Flight(identity: identity, task: task)
        activeFlight = flight

        do {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            clear(flight)
        } catch {
            clear(flight)
            throw error
        }
    }

    private func clear(_ flight: Flight) {
        if activeFlight?.identity === flight.identity { activeFlight = nil }
    }
}

extension CollectionSyncCoordinator {
    init(sessionController: SessionController, client: CollectionAPIClient, mutationActor: CollectionMutationActor) {
        self.init(
            authorize: { try await sessionController.requestAuthorization() },
            validateAuthority: { authority in await sessionController.authorizes(authority) },
            rejectAuthorization: { authorization in
                try await sessionController.rejectAuthorization(authorization)
            },
            fetchRemote: { accessToken in try await client.fetch(accessToken: accessToken) },
            importRemote: { entries, authorization in
                try await mutationActor.importRemote(entries, authorization: authorization)
            }
        )
    }
}

/// The narrow capability injected into the app shell for one reconciliation trigger.
struct CollectionSynchronization {
    typealias Operation = @Sendable () async throws(any Error) -> Void

    static let disabled = Self(operation: {})

    private let operation: Operation

    init(operation: @escaping Operation) {
        self.operation = operation
    }

    func callAsFunction() async throws(any Error) {
        try await operation()
    }
}

extension CollectionSynchronization {
    init(coordinator: CollectionSyncCoordinator) {
        self.init(operation: { try await coordinator.importAuthenticatedCollection() })
    }
}
