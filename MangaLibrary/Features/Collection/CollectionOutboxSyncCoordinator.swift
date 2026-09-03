//
//  CollectionOutboxSyncCoordinator.swift
//  MangaLibrary
//

import Foundation
import OSLog

enum CollectionOutboxSyncError: Error, Equatable {
    case sessionChanged
    case outcomeUnconfirmed
}

/// Serializes Collection outbox writes and fences every effect to one session generation.
actor CollectionOutboxSyncCoordinator {
    typealias Authorize = @Sendable () async throws(any Error) -> SessionRequestAuthorization
    typealias ValidateAuthorization = @Sendable (SessionRequestAuthorization) async throws(any Error) -> Bool
    typealias ClaimNextUpload = @Sendable (
        SessionCommitAuthorization
    ) async throws(any Error) -> CollectionOutboxUploadClaim?
    typealias NextRecoveredUpload = @Sendable (
        SessionCommitAuthorization
    ) async throws(any Error) -> CollectionOutboxUploadWorkItem?
    typealias Submit = @Sendable (CollectionOutboxUploadWorkItem, String) async throws(any Error) -> Void
    typealias FetchRemote = @Sendable (String) async throws(any Error) -> [CollectionRemoteEntry]
    typealias FetchRemoteEntry = @Sendable (Manga.ID, String) async throws(any Error) -> CollectionRemoteEntry?
    typealias ImportRemote = @Sendable (
        [CollectionRemoteEntry],
        SessionCommitAuthorization
    ) async throws(any Error) -> Void
    typealias ResolveUpload = @Sendable (
        CollectionOutboxUploadWorkItem,
        SessionCommitAuthorization
    ) async throws(any Error) -> Void
    typealias ResolveDeletion = @Sendable (
        CollectionOutboxUploadWorkItem,
        CollectionDeletionEvidence,
        SessionCommitAuthorization
    ) async throws(any Error) -> CollectionOutboxResolution
    typealias HasBlockedOutcome = @Sendable (SessionCommitAuthorization) async throws(any Error) -> Bool

    private final class OperationIdentity {}

    private struct Flight {
        let identity: OperationIdentity
        let task: Task<Void, any Error>
    }

    private let authorize: Authorize
    private let validateAuthorization: ValidateAuthorization
    private let claimNextUpload: ClaimNextUpload
    private let nextRecoveredUpload: NextRecoveredUpload
    private let submit: Submit
    private let fetchRemote: FetchRemote
    private let fetchRemoteEntry: FetchRemoteEntry
    private let importRemote: ImportRemote
    private let confirmUpload: ResolveUpload
    private let resolveDeletion: ResolveDeletion
    private let blockUploadOutcome: ResolveUpload
    private let hasBlockedOutcome: HasBlockedOutcome
    private var activeFlight: Flight?
    private var pendingReplacement: OperationIdentity?

    private static let logger = Logger(subsystem: "com.plusprojects.MangaLibrary", category: "CollectionOutbox")

    init(
        authorize: @escaping Authorize,
        validateAuthorization: @escaping ValidateAuthorization,
        claimNextUpload: @escaping ClaimNextUpload,
        nextRecoveredUpload: @escaping NextRecoveredUpload = { _ in nil },
        submit: @escaping Submit,
        fetchRemote: @escaping FetchRemote,
        fetchRemoteEntry: @escaping FetchRemoteEntry = { _, _ in
            throw CollectionAPIClientError.unavailable
        },
        importRemote: @escaping ImportRemote,
        confirmUpload: @escaping ResolveUpload,
        resolveDeletion: @escaping ResolveDeletion = { _, _, _ in
            throw CollectionOutboxUploadError.persistenceConflict
        },
        blockUploadOutcome: @escaping ResolveUpload,
        hasBlockedOutcome: @escaping HasBlockedOutcome = { _ in false }
    ) {
        self.authorize = authorize
        self.validateAuthorization = validateAuthorization
        self.claimNextUpload = claimNextUpload
        self.nextRecoveredUpload = nextRecoveredUpload
        self.submit = submit
        self.fetchRemote = fetchRemote
        self.fetchRemoteEntry = fetchRemoteEntry
        self.importRemote = importRemote
        self.confirmUpload = confirmUpload
        self.resolveDeletion = resolveDeletion
        self.blockUploadOutcome = blockUploadOutcome
        self.hasBlockedOutcome = hasBlockedOutcome
    }

    func synchronizeAuthenticatedOutbox(
        reusing importedSnapshot: CollectionImportedSnapshot? = nil
    ) async throws(any Error) {
        try Task.checkCancellation()
        let authorization = try await authorize()
        try Task.checkCancellation()
        if let importedSnapshot, importedSnapshot.authority != authorization.authority {
            throw CollectionOutboxSyncError.sessionChanged
        }
        guard try await validateAuthorization(authorization) else {
            throw CollectionOutboxSyncError.sessionChanged
        }
        try Task.checkCancellation()
        try requireCurrentCommitAuthorization(authorization)
        let identity = try await reserveReplacement(for: authorization)
        try consumeReplacement(identity)

        let task = Task {
            try await Self.run(
                importedSnapshot: importedSnapshot,
                authorization: authorization,
                validateAuthorization: validateAuthorization,
                claimNextUpload: claimNextUpload,
                submit: submit,
                fetchRemote: fetchRemote,
                fetchRemoteEntry: fetchRemoteEntry,
                importRemote: importRemote,
                confirmUpload: confirmUpload,
                resolveDeletion: resolveDeletion,
                blockUploadOutcome: blockUploadOutcome,
                hasBlockedOutcome: hasBlockedOutcome
            )
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

    /// Classifies only durable `sending` work after R1 could not use its snapshot.
    ///
    /// The failed R1 attempt's exact authority is revalidated. Queued operations are
    /// never claimed, and no remote request is made from this recovery path.
    func blockRecoveredUploadsAfterUnusableSnapshot(
        for authorization: SessionRequestAuthorization
    ) async throws(any Error) {
        try Task.checkCancellation()
        guard try await validateAuthorization(authorization) else {
            throw CollectionOutboxSyncError.sessionChanged
        }
        try Task.checkCancellation()
        try requireCurrentCommitAuthorization(authorization)
        let identity = try await reserveReplacement(for: authorization)
        try consumeReplacement(identity)

        let task = Task {
            try await Self.blockRecoveredUploads(
                authorization: authorization,
                validateAuthorization: validateAuthorization,
                nextRecoveredUpload: nextRecoveredUpload,
                blockUploadOutcome: blockUploadOutcome
            )
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

    private func reserveReplacement(
        for authorization: SessionRequestAuthorization
    ) async throws(any Error) -> OperationIdentity {
        let identity = OperationIdentity()
        pendingReplacement = identity

        if let priorFlight = activeFlight {
            priorFlight.task.cancel()
            _ = try? await priorFlight.task.value
            clear(priorFlight)
        }

        do {
            try Task.checkCancellation()
            guard pendingReplacement === identity else { throw CancellationError() }
            guard try await validateAuthorization(authorization) else {
                throw CollectionOutboxSyncError.sessionChanged
            }
            try Task.checkCancellation()
            guard pendingReplacement === identity else { throw CancellationError() }
            try requireCurrentCommitAuthorization(authorization)
            return identity
        } catch {
            clearReplacement(identity)
            throw error
        }
    }

    private func consumeReplacement(_ identity: OperationIdentity) throws(any Error) {
        do {
            try Task.checkCancellation()
            guard pendingReplacement === identity else { throw CancellationError() }
            pendingReplacement = nil
        } catch {
            clearReplacement(identity)
            throw error
        }
    }

    private func clearReplacement(_ identity: OperationIdentity) {
        if pendingReplacement === identity { pendingReplacement = nil }
    }

    private func requireCurrentCommitAuthorization(_ authorization: SessionRequestAuthorization) throws(any Error) {
        do {
            try authorization.commitAuthorization.perform {}
        } catch is SessionCommitAuthorizationError {
            throw CollectionOutboxSyncError.sessionChanged
        }
    }

    private static func run(
        importedSnapshot: CollectionImportedSnapshot?,
        authorization: SessionRequestAuthorization,
        validateAuthorization: ValidateAuthorization,
        claimNextUpload: ClaimNextUpload,
        submit: Submit,
        fetchRemote: FetchRemote,
        fetchRemoteEntry: FetchRemoteEntry,
        importRemote: ImportRemote,
        confirmUpload: ResolveUpload,
        resolveDeletion: ResolveDeletion,
        blockUploadOutcome: ResolveUpload,
        hasBlockedOutcome: HasBlockedOutcome
    ) async throws(any Error) {
        var hasUnconfirmedOutcome = false

        while true {
            try Task.checkCancellation()
            guard try await validateAuthorization(authorization) else {
                throw CollectionOutboxSyncError.sessionChanged
            }
            let claim = try await performCollectionStoreOperation {
                try await claimNextUpload(authorization.commitAuthorization)
            }
            guard let claim else {
                let hasPersistedBlockedOutcome = try await performCollectionStoreOperation {
                    try await hasBlockedOutcome(authorization.commitAuthorization)
                }
                if hasUnconfirmedOutcome || hasPersistedBlockedOutcome {
                    throw CollectionOutboxSyncError.outcomeUnconfirmed
                }
                return
            }

            switch claim {
            case let .send(workItem):
                var hasConfirmedDeleteTransport = false
                do {
                    try await submit(workItem, authorization.accessToken)
                    hasConfirmedDeleteTransport = workItem.isTombstone
                    try Task.checkCancellation()
                    guard try await validateAuthorization(authorization) else {
                        throw CollectionOutboxSyncError.sessionChanged
                    }
                    if workItem.isTombstone {
                        let confirmed = try await resolveDeletionEvidence(
                            workItem,
                            evidence: .absent,
                            authorization: authorization,
                            validateAuthorization: validateAuthorization,
                            resolveDeletion: resolveDeletion
                        )
                        hasUnconfirmedOutcome = hasUnconfirmedOutcome || confirmed == false
                    } else {
                        try await performCollectionStoreOperation {
                            try await confirmUpload(workItem, authorization.commitAuthorization)
                        }
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch let error as CollectionOutboxSyncError {
                    throw error
                } catch let error as SessionControllerError
                    where error == .temporarilyUnavailable || error == .persistenceUnavailable {
                    throw error
                } catch {
                    if hasConfirmedDeleteTransport { throw error }
                    logUncertainWrite(error, workItem: workItem)
                    let confirmed = try await reconcile(
                        workItem,
                        authorization: authorization,
                        validateAuthorization: validateAuthorization,
                        fetchRemote: fetchRemote,
                        fetchRemoteEntry: fetchRemoteEntry,
                        importRemote: importRemote,
                        confirmUpload: confirmUpload,
                        resolveDeletion: resolveDeletion,
                        blockUploadOutcome: blockUploadOutcome
                    )
                    hasUnconfirmedOutcome = hasUnconfirmedOutcome || confirmed == false
                }
            case let .reconcile(workItem):
                let confirmed: Bool
                if let importedSnapshot {
                    confirmed = try await resolve(
                        workItem,
                        remoteEntries: importedSnapshot.entries,
                        authorization: authorization,
                        validateAuthorization: validateAuthorization,
                        confirmUpload: confirmUpload,
                        resolveDeletion: resolveDeletion,
                        blockUploadOutcome: blockUploadOutcome
                    )
                } else {
                    confirmed = try await reconcile(
                        workItem,
                        authorization: authorization,
                        validateAuthorization: validateAuthorization,
                        fetchRemote: fetchRemote,
                        fetchRemoteEntry: fetchRemoteEntry,
                        importRemote: importRemote,
                        confirmUpload: confirmUpload,
                        resolveDeletion: resolveDeletion,
                        blockUploadOutcome: blockUploadOutcome
                    )
                }
                hasUnconfirmedOutcome = hasUnconfirmedOutcome || confirmed == false
            }
        }
    }

    private static func reconcile(
        _ workItem: CollectionOutboxUploadWorkItem,
        authorization: SessionRequestAuthorization,
        validateAuthorization: ValidateAuthorization,
        fetchRemote: FetchRemote,
        fetchRemoteEntry: FetchRemoteEntry,
        importRemote: ImportRemote,
        confirmUpload: ResolveUpload,
        resolveDeletion: ResolveDeletion,
        blockUploadOutcome: ResolveUpload
    ) async throws(any Error) -> Bool {
        if workItem.isTombstone {
            return try await reconcileDeletion(
                workItem,
                authorization: authorization,
                validateAuthorization: validateAuthorization,
                fetchRemoteEntry: fetchRemoteEntry,
                resolveDeletion: resolveDeletion,
                blockUploadOutcome: blockUploadOutcome
            )
        }

        guard try await validateAuthorization(authorization) else {
            throw CollectionOutboxSyncError.sessionChanged
        }

        let remoteEntries: [CollectionRemoteEntry]
        do {
            remoteEntries = try await fetchRemote(authorization.accessToken)
            try Task.checkCancellation()
            guard try await validateAuthorization(authorization) else {
                throw CollectionOutboxSyncError.sessionChanged
            }
            try await performCollectionStoreOperation {
                try await importRemote(remoteEntries, authorization.commitAuthorization)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CollectionOutboxSyncError {
            throw error
        } catch let error as SessionControllerError
            where error == .temporarilyUnavailable || error == .persistenceUnavailable {
            throw error
        } catch {
            logUnconfirmedOutcome(origin: "collectionSnapshot", workItem: workItem)
            try await performCollectionStoreOperation {
                try await blockUploadOutcome(workItem, authorization.commitAuthorization)
            }
            return false
        }

        return try await resolve(
            workItem,
            remoteEntries: remoteEntries,
            authorization: authorization,
            validateAuthorization: validateAuthorization,
            confirmUpload: confirmUpload,
            resolveDeletion: resolveDeletion,
            blockUploadOutcome: blockUploadOutcome
        )
    }

    private static func resolve(
        _ workItem: CollectionOutboxUploadWorkItem,
        remoteEntries: [CollectionRemoteEntry],
        authorization: SessionRequestAuthorization,
        validateAuthorization: ValidateAuthorization,
        confirmUpload: ResolveUpload,
        resolveDeletion: ResolveDeletion,
        blockUploadOutcome: ResolveUpload
    ) async throws(any Error) -> Bool {
        guard try await validateAuthorization(authorization) else {
            throw CollectionOutboxSyncError.sessionChanged
        }

        if workItem.isTombstone {
            let evidence: CollectionDeletionEvidence
            if let remoteEntry = remoteEntries.first(where: { $0.manga.id == workItem.mangaID }) {
                evidence = .present(remoteEntry)
            } else {
                evidence = .absent
            }
            return try await resolveDeletionEvidence(
                workItem,
                evidence: evidence,
                authorization: authorization,
                validateAuthorization: validateAuthorization,
                resolveDeletion: resolveDeletion
            )
        }

        if remoteEntries.contains(where: { remoteEntry in matches(workItem, remoteEntry: remoteEntry) }) {
            try await performCollectionStoreOperation {
                try await confirmUpload(workItem, authorization.commitAuthorization)
            }
            return true
        }

        logUnconfirmedOutcome(origin: "remoteMismatch", workItem: workItem)
        try await performCollectionStoreOperation {
            try await blockUploadOutcome(workItem, authorization.commitAuthorization)
        }
        return false
    }

    private static func reconcileDeletion(
        _ workItem: CollectionOutboxUploadWorkItem,
        authorization: SessionRequestAuthorization,
        validateAuthorization: ValidateAuthorization,
        fetchRemoteEntry: FetchRemoteEntry,
        resolveDeletion: ResolveDeletion,
        blockUploadOutcome: ResolveUpload
    ) async throws(any Error) -> Bool {
        guard try await validateAuthorization(authorization) else {
            throw CollectionOutboxSyncError.sessionChanged
        }

        do {
            let remoteEntry = try await fetchRemoteEntry(workItem.mangaID, authorization.accessToken)
            try Task.checkCancellation()
            guard try await validateAuthorization(authorization) else {
                throw CollectionOutboxSyncError.sessionChanged
            }
            let evidence = remoteEntry.map(CollectionDeletionEvidence.present) ?? .absent
            return try await resolveDeletionEvidence(
                workItem,
                evidence: evidence,
                authorization: authorization,
                validateAuthorization: validateAuthorization,
                resolveDeletion: resolveDeletion
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as CollectionOutboxSyncError {
            throw error
        } catch let error as SessionControllerError
            where error == .temporarilyUnavailable || error == .persistenceUnavailable {
            throw error
        } catch {
            logUnconfirmedOutcome(origin: "individualLookup", workItem: workItem)
            try await performCollectionStoreOperation {
                try await blockUploadOutcome(workItem, authorization.commitAuthorization)
            }
            return false
        }
    }

    private static func resolveDeletionEvidence(
        _ workItem: CollectionOutboxUploadWorkItem,
        evidence: CollectionDeletionEvidence,
        authorization: SessionRequestAuthorization,
        validateAuthorization: ValidateAuthorization,
        resolveDeletion: ResolveDeletion
    ) async throws(any Error) -> Bool {
        guard try await validateAuthorization(authorization) else {
            throw CollectionOutboxSyncError.sessionChanged
        }
        let resolution = try await performCollectionStoreOperation {
            try await resolveDeletion(workItem, evidence, authorization.commitAuthorization)
        }
        if resolution == .blockedOutcome {
            logUnconfirmedOutcome(origin: "remotePresence", workItem: workItem)
        }
        return resolution == .confirmed
    }

    private static func blockRecoveredUploads(
        authorization: SessionRequestAuthorization,
        validateAuthorization: ValidateAuthorization,
        nextRecoveredUpload: NextRecoveredUpload,
        blockUploadOutcome: ResolveUpload
    ) async throws(any Error) {
        while true {
            try Task.checkCancellation()
            guard try await validateAuthorization(authorization) else {
                throw CollectionOutboxSyncError.sessionChanged
            }
            let workItem = try await performCollectionStoreOperation {
                try await nextRecoveredUpload(authorization.commitAuthorization)
            }
            guard let workItem else { return }

            logUnconfirmedOutcome(origin: "collectionSnapshot", workItem: workItem)
            try await performCollectionStoreOperation {
                try await blockUploadOutcome(workItem, authorization.commitAuthorization)
            }
        }
    }

    private static func matches(
        _ workItem: CollectionOutboxUploadWorkItem,
        remoteEntry: CollectionRemoteEntry
    ) -> Bool {
        remoteEntry.manga.id == workItem.mangaID &&
            Array(Set(remoteEntry.ownedVolumes)).sorted() == workItem.ownedVolumes &&
            remoteEntry.readingVolume == workItem.readingVolume &&
            remoteEntry.isComplete == workItem.isComplete
    }

    private static func performCollectionStoreOperation<Value: Sendable>(
        _ operation: @Sendable () async throws(any Error) -> Value
    ) async throws(any Error) -> Value {
        do {
            return try await operation()
        } catch let error as CollectionOutboxUploadError {
            switch error {
            case .sessionChanged:
                throw CollectionOutboxSyncError.sessionChanged
            case .cancelled:
                throw CancellationError()
            case .staleOperation, .persistenceConflict:
                throw error
            }
        } catch let error as CollectionRemoteImportError {
            switch error {
            case .sessionChanged:
                throw CollectionOutboxSyncError.sessionChanged
            case .cancelled:
                throw CancellationError()
            default:
                throw error
            }
        }
    }

    private static func logUncertainWrite(_ error: any Error, workItem: CollectionOutboxUploadWorkItem) {
        let method = workItem.isTombstone ? "DELETE" : "POST"
        if case let CollectionAPIClientError.network(.statusCode(statusCode)) = error {
            logger.error(
                "R2 write result uncertain: method=\(method, privacy: .public) status=\(statusCode, privacy: .public) action=reconcile"
            )
        } else {
            logger.error("R2 write result uncertain: method=\(method, privacy: .public) action=reconcile")
        }
    }

    private static func logUnconfirmedOutcome(origin: StaticString, workItem: CollectionOutboxUploadWorkItem) {
        let method = workItem.isTombstone ? "DELETE" : "POST"
        logger.error(
            "R2 write outcome unconfirmed: method=\(method, privacy: .public) origin=\(origin, privacy: .public) action=blockedOutcome"
        )
    }

}

extension CollectionOutboxSyncCoordinator {
    init(sessionController: SessionController, client: CollectionAPIClient, mutationActor: CollectionMutationActor) {
        self.init(
            authorize: { try await sessionController.requestAuthorization() },
            validateAuthorization: { authorization in
                try await sessionController.authorizes(authorization)
            },
            claimNextUpload: { authorization in
                try await mutationActor.claimNextUpload(authorization: authorization)
            },
            nextRecoveredUpload: { authorization in
                try await mutationActor.nextRecoveredUpload(authorization: authorization)
            },
            submit: { workItem, accessToken in
                if workItem.isTombstone {
                    _ = try await client.remove(mangaID: workItem.mangaID, accessToken: accessToken)
                } else {
                    _ = try await client.submit(
                        mangaID: workItem.mangaID,
                        ownedVolumes: workItem.ownedVolumes,
                        readingVolume: workItem.readingVolume,
                        isComplete: workItem.isComplete,
                        accessToken: accessToken
                    )
                }
            },
            fetchRemote: { accessToken in try await client.fetch(accessToken: accessToken) },
            fetchRemoteEntry: { mangaID, accessToken in
                try await client.fetch(mangaID: mangaID, accessToken: accessToken)
            },
            importRemote: { entries, authorization in
                try await mutationActor.importRemote(entries, authorization: authorization)
            },
            confirmUpload: { workItem, authorization in
                try await mutationActor.confirmUpload(workItem, authorization: authorization)
            },
            resolveDeletion: { workItem, evidence, authorization in
                try await mutationActor.resolveDeletion(workItem, evidence: evidence, authorization: authorization)
            },
            blockUploadOutcome: { workItem, authorization in
                try await mutationActor.blockUploadOutcome(workItem, authorization: authorization)
            },
            hasBlockedOutcome: { authorization in
                try await mutationActor.hasBlockedUploadOutcome(authorization: authorization)
            }
        )
    }
}
