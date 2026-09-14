//
//  CollectionSyncCoordinator.swift
//  MangaLibrary
//

import Foundation
import OSLog

enum CollectionSyncFailureOrigin: Equatable {
    case collectionSnapshot(attempt: Int)
    case renewedSessionIdentity
}

enum CollectionSyncError: Error, Equatable {
    case sessionChanged
    case authorizationDenied(origin: CollectionSyncFailureOrigin, statusCode: Int)
    case authenticationIncompatible(origin: CollectionSyncFailureOrigin, statusCode: Int)
    case unsupportedVolumeData
}

/// The authenticated snapshot already imported by R1 and reusable by R2.
///
/// It carries the exact session authority but never retains an access credential.
/// Entries stay raw so R2 can classify an opaque incompatible presence for an
/// exact tombstone without R1 importing or reinterpreting its volume values.
struct CollectionImportedSnapshot {
    let authority: SessionAuthority
    let entries: [CollectionRemoteEntry]
}

/// Fences one authenticated Collection import to an exact session generation.
///
/// A new trigger cancels the previous flight. The current authority is checked
/// after transport for fast rejection; its commit capability is consumed again
/// inside the sole synchronous SwiftData transaction.
actor CollectionSyncCoordinator {
    typealias UnusableSnapshot = @Sendable (SessionRequestAuthorization) async throws(any Error) -> Void
    typealias Authorize = @Sendable () async throws(any Error) -> SessionRequestAuthorization
    typealias ValidateAuthorization = @Sendable (SessionRequestAuthorization) async throws(any Error) -> Bool
    typealias RecoverAuthorization = @Sendable (
        SessionRequestAuthorization
    ) async throws(any Error) -> SessionRequestAuthorization
    typealias FetchRemote = @Sendable (String) async throws(any Error) -> [CollectionRemoteEntry]
    typealias ImportRemote = @Sendable (
        [CollectionRemoteEntry],
        SessionCommitAuthorization
    ) async throws(any Error) -> Void

    private final class OperationIdentity {}

    private struct Flight {
        let identity: OperationIdentity
        let task: Task<CollectionImportedSnapshot, any Error>
    }

    private let authorize: Authorize
    private let validateAuthorization: ValidateAuthorization
    private let recoverAuthorization: RecoverAuthorization
    private let fetchRemote: FetchRemote
    private let importRemote: ImportRemote
    private var activeFlight: Flight?

    private static let logger = Logger(subsystem: "com.plusprojects.MangaLibrary", category: "CollectionSync")

    init(
        authorize: @escaping Authorize,
        validateAuthorization: @escaping ValidateAuthorization,
        recoverAuthorization: @escaping RecoverAuthorization = { _ in
            throw SessionControllerError.unavailable
        },
        fetchRemote: @escaping FetchRemote,
        importRemote: @escaping ImportRemote
    ) {
        self.authorize = authorize
        self.validateAuthorization = validateAuthorization
        self.recoverAuthorization = recoverAuthorization
        self.fetchRemote = fetchRemote
        self.importRemote = importRemote
    }

    func importAuthenticatedCollection() async throws(any Error) {
        _ = try await importAuthenticatedCollection(onUnusableSnapshot: { _ in })
    }

    func importAuthenticatedCollection(
        onUnusableSnapshot: @escaping UnusableSnapshot
    ) async throws(any Error) -> CollectionImportedSnapshot {
        try Task.checkCancellation()
        activeFlight?.task.cancel()

        let identity = OperationIdentity()
        let task = Task { [
            authorize,
            validateAuthorization,
            recoverAuthorization,
            fetchRemote,
            importRemote,
            onUnusableSnapshot,
        ] in
            try Task.checkCancellation()
            var authorization: SessionRequestAuthorization
            do {
                authorization = try await authorize()
            } catch let error as SessionAuthorizationRecoveryError {
                throw Self.authenticationIncompatibility(from: error)
            }
            try Task.checkCancellation()
            let remoteEntries: [CollectionRemoteEntry]
            do {
                do {
                    remoteEntries = try await fetchRemote(authorization.accessToken)
                } catch let error as CollectionAPIClientError {
                    guard case let .network(.statusCode(statusCode)) = error else { throw error }
                    switch statusCode {
                    case 403:
                        guard try await validateAuthorization(authorization) else {
                            throw CollectionSyncError.sessionChanged
                        }
                        Self.logAuthorizationDenied(statusCode: statusCode, attempt: 1)
                        throw CollectionSyncError.authorizationDenied(
                            origin: .collectionSnapshot(attempt: 1),
                            statusCode: statusCode
                        )
                    case 401:
                        Self.logAuthenticationRecovery(statusCode: statusCode)
                        do {
                            authorization = try await recoverAuthorization(authorization)
                        } catch let recoveryError as SessionAuthorizationRecoveryError {
                            throw Self.authenticationIncompatibility(from: recoveryError)
                        }
                        try Task.checkCancellation()
                        do {
                            remoteEntries = try await fetchRemote(authorization.accessToken)
                        } catch let retryError as CollectionAPIClientError {
                            guard case let .network(.statusCode(retryStatusCode)) = retryError else { throw retryError }
                            guard try await validateAuthorization(authorization) else {
                                throw CollectionSyncError.sessionChanged
                            }
                            switch retryStatusCode {
                            case 401:
                                Self.logAuthenticationIncompatible(
                                    origin: .collectionSnapshot(attempt: 2),
                                    statusCode: retryStatusCode
                                )
                                throw CollectionSyncError.authenticationIncompatible(
                                    origin: .collectionSnapshot(attempt: 2),
                                    statusCode: retryStatusCode
                                )
                            case 403:
                                Self.logAuthorizationDenied(statusCode: retryStatusCode, attempt: 2)
                                throw CollectionSyncError.authorizationDenied(
                                    origin: .collectionSnapshot(attempt: 2),
                                    statusCode: retryStatusCode
                                )
                            default:
                                throw retryError
                            }
                        }
                    default:
                        throw error
                    }
                }
                try Task.checkCancellation()
                guard try await validateAuthorization(authorization) else { throw CollectionSyncError.sessionChanged }
                try Task.checkCancellation()
                do {
                    try await importRemote(remoteEntries, authorization.commitAuthorization)
                } catch is CancellationError {
                    throw CancellationError()
                } catch CollectionRemoteImportError.cancelled {
                    throw CancellationError()
                } catch {
                    let importError = error
                    guard try await validateAuthorization(authorization) else {
                        throw CollectionSyncError.sessionChanged
                    }
                    if let importError = importError as? CollectionRemoteImportError,
                       importError.isUnsupportedVolumeData {
                        Self.logUnsupportedVolumeData()
                        throw CollectionSyncError.unsupportedVolumeData
                    }
                    throw importError
                }
                try Task.checkCancellation()
            } catch let error as SessionControllerError
                where error == .temporarilyUnavailable || error == .persistenceUnavailable {
                throw error
            } catch is CancellationError {
                throw CancellationError()
            } catch CollectionSyncError.sessionChanged {
                throw CollectionSyncError.sessionChanged
            } catch CollectionSyncError.unsupportedVolumeData {
                throw CollectionSyncError.unsupportedVolumeData
            } catch CollectionRemoteImportError.cancelled {
                throw CancellationError()
            } catch CollectionRemoteImportError.sessionChanged {
                throw CollectionRemoteImportError.sessionChanged
            } catch {
                let snapshotError = error
                try Task.checkCancellation()
                try await onUnusableSnapshot(authorization)
                try Task.checkCancellation()
                throw snapshotError
            }
            return CollectionImportedSnapshot(authority: authorization.authority, entries: remoteEntries)
        }
        let flight = Flight(identity: identity, task: task)
        activeFlight = flight

        defer {
            clear(flight)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func clear(_ flight: Flight) {
        if activeFlight?.identity === flight.identity {
            activeFlight = nil
        }
    }

    private static func logAuthorizationDenied(statusCode: Int, attempt: Int) {
        logger.error(
            "R1 authorization denied: origin=collectionSnapshot status=\(statusCode, privacy: .public) attempt=\(attempt, privacy: .public)"
        )
    }

    private static func logAuthenticationRecovery(statusCode: Int) {
        logger.notice(
            "R1 access rejected: origin=collectionSnapshot status=\(statusCode, privacy: .public) attempt=1 action=recoverAuthorization"
        )
    }

    private static func logAuthenticationIncompatible(origin: CollectionSyncFailureOrigin, statusCode: Int) {
        switch origin {
        case let .collectionSnapshot(attempt):
            logger.error(
                "R1 authentication incompatible: origin=collectionSnapshot status=\(statusCode, privacy: .public) attempt=\(attempt, privacy: .public)"
            )
        case .renewedSessionIdentity:
            logger.error(
                "R1 authentication incompatible: origin=renewedSessionIdentity status=\(statusCode, privacy: .public)"
            )
        }
    }

    private static func logUnsupportedVolumeData() {
        logger.error("R1 unsupported volume data: action=preserveSessionAndCollection")
    }

    private static func authenticationIncompatibility(
        from error: SessionAuthorizationRecoveryError
    ) -> CollectionSyncError {
        switch error {
        case let .identityRejected(statusCode):
            logAuthenticationIncompatible(origin: .renewedSessionIdentity, statusCode: statusCode)
            return .authenticationIncompatible(origin: .renewedSessionIdentity, statusCode: statusCode)
        }
    }
}

extension CollectionSyncCoordinator {
    init(sessionController: SessionController, client: CollectionAPIClient, mutationActor: CollectionMutationActor) {
        self.init(
            authorize: {
                try await sessionController.requestAuthorization()
            },
            validateAuthorization: { authorization in
                try await sessionController.authorizes(authorization)
            },
            recoverAuthorization: { authorization in
                try await sessionController.recoverAuthorization(after: authorization)
            },
            fetchRemote: { accessToken in
                try await client.fetch(accessToken: accessToken)
            },
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
        self.init(
            operation: {
                try await coordinator.importAuthenticatedCollection()
            }
        )
    }

    init(importCoordinator: CollectionSyncCoordinator, outboxCoordinator: CollectionOutboxSyncCoordinator) {
        self.init(operation: {
            let importedSnapshot = try await importCoordinator.importAuthenticatedCollection { authorization in
                try await outboxCoordinator.blockRecoveredUploadsAfterUnusableSnapshot(for: authorization)
            }
            try await outboxCoordinator.synchronizeAuthenticatedOutbox(reusing: importedSnapshot)
        })
    }
}
