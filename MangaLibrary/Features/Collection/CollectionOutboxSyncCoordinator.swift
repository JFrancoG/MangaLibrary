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

/// A closed classification supplied by the boundary that knows whether a write ran.
enum CollectionOutboxSubmissionDisposition: Equatable {
    case notSentTransient
    case permanentlyRejected
    case potentiallyApplied
}

/// Serializes Collection outbox writes and fences every effect to one session generation.
actor CollectionOutboxSyncCoordinator {
    typealias Authorize = @Sendable () async throws(any Error) -> SessionRequestAuthorization
    typealias ValidateAuthorization = @Sendable (SessionRequestAuthorization) async throws(any Error) -> Bool
    typealias ClaimNextUpload = @Sendable (
        SessionCommitAuthorization,
        Date
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
    typealias ScheduleRetry = @Sendable (
        CollectionOutboxUploadWorkItem,
        Date,
        SessionCommitAuthorization
    ) async throws(any Error) -> CollectionOutboxRetryResolution
    typealias ResolveDeletion = @Sendable (
        CollectionOutboxUploadWorkItem,
        CollectionDeletionEvidence,
        SessionCommitAuthorization
    ) async throws(any Error) -> CollectionOutboxResolution
    typealias HasBlockedOutcome = @Sendable (SessionCommitAuthorization) async throws(any Error) -> Bool
    typealias ResolveUploadAuthorization = @Sendable (SessionCommitAuthorization) async throws(any Error) -> Void
    typealias ClassifySubmissionFailure = @Sendable (any Error) -> CollectionOutboxSubmissionDisposition
    typealias Now = @Sendable () -> Date
    typealias Sleep = @Sendable (TimeInterval) async throws(any Error) -> Void

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
    private let scheduleRetry: ScheduleRetry
    private let resolveDeletion: ResolveDeletion
    private let blockUploadOutcome: ResolveUpload
    private let reactivateBlockedUploads: ResolveUploadAuthorization
    private let resolvePermanentRejection: ResolveUpload
    private let hasBlockedOutcome: HasBlockedOutcome
    private let classifySubmissionFailure: ClassifySubmissionFailure
    private let now: Now
    private let sleep: Sleep
    private var activeFlight: Flight?
    private var pendingReplacement: OperationIdentity?

    private static let logger = Logger(subsystem: "com.plusprojects.MangaLibrary", category: "CollectionOutbox")
    private static let maximumRetryDelay: TimeInterval = 30

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
        scheduleRetry: @escaping ScheduleRetry = { _, _, _ in
            throw CollectionOutboxUploadError.persistenceConflict
        },
        resolveDeletion: @escaping ResolveDeletion = { _, _, _ in
            throw CollectionOutboxUploadError.persistenceConflict
        },
        blockUploadOutcome: @escaping ResolveUpload,
        reactivateBlockedUploads: @escaping ResolveUploadAuthorization = { _ in },
        resolvePermanentRejection: @escaping ResolveUpload = { _, _ in
            throw CollectionOutboxUploadError.persistenceConflict
        },
        hasBlockedOutcome: @escaping HasBlockedOutcome = { _ in false },
        classifySubmissionFailure: @escaping ClassifySubmissionFailure = { _ in .potentiallyApplied },
        now: @escaping Now = { Date() },
        sleep: @escaping Sleep = { delay in
            try await Task.sleep(for: .seconds(delay), clock: .continuous)
        }
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
        self.scheduleRetry = scheduleRetry
        self.resolveDeletion = resolveDeletion
        self.blockUploadOutcome = blockUploadOutcome
        self.reactivateBlockedUploads = reactivateBlockedUploads
        self.resolvePermanentRejection = resolvePermanentRejection
        self.hasBlockedOutcome = hasBlockedOutcome
        self.classifySubmissionFailure = classifySubmissionFailure
        self.now = now
        self.sleep = sleep
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
        guard try await validateAuthorization(authorization) else { throw CollectionOutboxSyncError.sessionChanged }
        try Task.checkCancellation()
        try await requireCurrentCommitAuthorization(authorization)
        let identity = try await reserveReplacement(for: authorization)
        try consumeReplacement(identity)

        let task = Task {
            try await Self.run(
                importedSnapshot: importedSnapshot,
                authorization: authorization,
                authorize: authorize,
                validateAuthorization: validateAuthorization,
                claimNextUpload: claimNextUpload,
                submit: submit,
                fetchRemote: fetchRemote,
                fetchRemoteEntry: fetchRemoteEntry,
                importRemote: importRemote,
                confirmUpload: confirmUpload,
                scheduleRetry: scheduleRetry,
                resolveDeletion: resolveDeletion,
                blockUploadOutcome: blockUploadOutcome,
                reactivateBlockedUploads: reactivateBlockedUploads,
                resolvePermanentRejection: resolvePermanentRejection,
                hasBlockedOutcome: hasBlockedOutcome,
                classifySubmissionFailure: classifySubmissionFailure,
                now: now,
                sleep: sleep
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
        guard try await validateAuthorization(authorization) else { throw CollectionOutboxSyncError.sessionChanged }
        try Task.checkCancellation()
        try await requireCurrentCommitAuthorization(authorization)
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
        if activeFlight?.identity === flight.identity {
            activeFlight = nil
        }
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
            guard try await validateAuthorization(authorization) else { throw CollectionOutboxSyncError.sessionChanged }
            try Task.checkCancellation()
            guard pendingReplacement === identity else { throw CancellationError() }
            try await requireCurrentCommitAuthorization(authorization)
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
        if pendingReplacement === identity {
            pendingReplacement = nil
        }
    }

    private func requireCurrentCommitAuthorization(
        _ authorization: SessionRequestAuthorization
    ) async throws(any Error) {
        do {
            try authorization.commitAuthorization.perform {}
        } catch is SessionCommitAuthorizationError {
            _ = try await validateAuthorization(authorization)
            throw CollectionOutboxSyncError.sessionChanged
        }
    }

    private static func run(
        importedSnapshot: CollectionImportedSnapshot?,
        authorization: SessionRequestAuthorization,
        authorize: Authorize,
        validateAuthorization: ValidateAuthorization,
        claimNextUpload: ClaimNextUpload,
        submit: Submit,
        fetchRemote: FetchRemote,
        fetchRemoteEntry: FetchRemoteEntry,
        importRemote: ImportRemote,
        confirmUpload: ResolveUpload,
        scheduleRetry: ScheduleRetry,
        resolveDeletion: ResolveDeletion,
        blockUploadOutcome: ResolveUpload,
        reactivateBlockedUploads: ResolveUploadAuthorization,
        resolvePermanentRejection: ResolveUpload,
        hasBlockedOutcome: HasBlockedOutcome,
        classifySubmissionFailure: ClassifySubmissionFailure,
        now: Now,
        sleep: Sleep
    ) async throws(any Error) {
        var hasUnconfirmedOutcome = false
        var currentAuthorization = authorization

        try await performCollectionStoreOperation(
            authorization: currentAuthorization,
            validateAuthorization: validateAuthorization
        ) {
            try await reactivateBlockedUploads(authorization.commitAuthorization)
        }

        while true {
            try Task.checkCancellation()
            guard try await validateAuthorization(currentAuthorization) else {
                throw CollectionOutboxSyncError.sessionChanged
            }
            let operationAuthorization = currentAuthorization
            let claimDate = now()
            let claim = try await performCollectionStoreOperation(
                authorization: operationAuthorization,
                validateAuthorization: validateAuthorization
            ) {
                try await claimNextUpload(operationAuthorization.commitAuthorization, claimDate)
            }
            guard let claim else {
                let hasPersistedBlockedOutcome = try await performCollectionStoreOperation(
                    authorization: operationAuthorization,
                    validateAuthorization: validateAuthorization
                ) {
                    try await hasBlockedOutcome(operationAuthorization.commitAuthorization)
                }
                if hasUnconfirmedOutcome || hasPersistedBlockedOutcome {
                    throw CollectionOutboxSyncError.outcomeUnconfirmed
                }
                return
            }

            switch claim {
            case let .send(workItem):
                var hasConfirmedTransport = false
                do {
                    try await submit(workItem, operationAuthorization.accessToken)
                    hasConfirmedTransport = true
                    try Task.checkCancellation()
                    guard try await validateAuthorization(operationAuthorization) else {
                        throw CollectionOutboxSyncError.sessionChanged
                    }
                    if workItem.isTombstone {
                        let confirmed = try await resolveDeletionEvidence(
                            workItem,
                            evidence: .absent,
                            authorization: operationAuthorization,
                            validateAuthorization: validateAuthorization,
                            resolveDeletion: resolveDeletion
                        )
                        hasUnconfirmedOutcome = hasUnconfirmedOutcome || confirmed == false
                    } else {
                        try await performCollectionStoreOperation(
                            authorization: operationAuthorization,
                            validateAuthorization: validateAuthorization
                        ) {
                            try await confirmUpload(workItem, operationAuthorization.commitAuthorization)
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
                    if hasConfirmedTransport {
                        throw error
                    }
                    switch classifySubmissionFailure(error) {
                    case .notSentTransient:
                        let retryDate = nextRetryDate(after: workItem.retryCount, now: now())
                        let resolution = try await performCollectionStoreOperation(
                            authorization: operationAuthorization,
                            validateAuthorization: validateAuthorization
                        ) {
                            try await scheduleRetry(workItem, retryDate, operationAuthorization.commitAuthorization)
                        }
                        logRetryResolution(
                            resolution,
                            workItem: workItem,
                            retryCount: nextRetryCount(after: workItem.retryCount)
                        )
                    case .permanentlyRejected:
                        logPermanentRejection(workItem: workItem)
                        try await performCollectionStoreOperation(
                            authorization: operationAuthorization,
                            validateAuthorization: validateAuthorization
                        ) {
                            try await resolvePermanentRejection(workItem, operationAuthorization.commitAuthorization)
                        }
                    case .potentiallyApplied:
                        logUncertainWrite(error, workItem: workItem)
                        let confirmed = try await reconcile(
                            workItem,
                            authorization: operationAuthorization,
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
                }
            case let .reconcile(workItem):
                let confirmed: Bool
                if let importedSnapshot {
                    confirmed = try await resolve(
                        workItem,
                        remoteEntries: importedSnapshot.entries,
                        authorization: operationAuthorization,
                        validateAuthorization: validateAuthorization,
                        confirmUpload: confirmUpload,
                        resolveDeletion: resolveDeletion,
                        blockUploadOutcome: blockUploadOutcome
                    )
                } else {
                    confirmed = try await reconcile(
                        workItem,
                        authorization: operationAuthorization,
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
            case let .waitUntil(deadline):
                try await wait(until: deadline, now: now, sleep: sleep)
                let renewedAuthorization = try await authorize()
                guard renewedAuthorization.authority == currentAuthorization.authority else {
                    throw CollectionOutboxSyncError.sessionChanged
                }
                guard try await validateAuthorization(renewedAuthorization) else {
                    throw CollectionOutboxSyncError.sessionChanged
                }
                currentAuthorization = renewedAuthorization
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

        guard try await validateAuthorization(authorization) else { throw CollectionOutboxSyncError.sessionChanged }

        let remoteEntries: [CollectionRemoteEntry]
        do {
            remoteEntries = try await fetchRemote(authorization.accessToken)
            try Task.checkCancellation()
            guard try await validateAuthorization(authorization) else { throw CollectionOutboxSyncError.sessionChanged }
            try await performCollectionStoreOperation(
                authorization: authorization,
                validateAuthorization: validateAuthorization
            ) {
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
            try await performCollectionStoreOperation(
                authorization: authorization,
                validateAuthorization: validateAuthorization
            ) {
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

    private static func nextRetryDate(after retryCount: Int, now: Date) -> Date {
        now.addingTimeInterval(retryDelay(after: retryCount))
    }

    private static func retryDelay(after retryCount: Int) -> TimeInterval {
        switch retryCount {
        case ..<1:
            1
        case 1:
            2
        case 2:
            4
        case 3:
            8
        case 4:
            16
        default:
            maximumRetryDelay
        }
    }

    private static func nextRetryCount(after retryCount: Int) -> Int {
        retryCount == Int.max ? Int.max : retryCount + 1
    }

    private static func wait(until deadline: Date, now: Now, sleep: Sleep) async throws(any Error) {
        while true {
            try Task.checkCancellation()
            let remaining = deadline.timeIntervalSince(now())
            guard remaining > 0 else { return }

            try await sleep(min(remaining, maximumRetryDelay))
        }
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
        guard try await validateAuthorization(authorization) else { throw CollectionOutboxSyncError.sessionChanged }

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
            try await performCollectionStoreOperation(
                authorization: authorization,
                validateAuthorization: validateAuthorization
            ) {
                try await confirmUpload(workItem, authorization.commitAuthorization)
            }
            return true
        }

        logUnconfirmedOutcome(origin: "remoteMismatch", workItem: workItem)
        try await performCollectionStoreOperation(
            authorization: authorization,
            validateAuthorization: validateAuthorization
        ) {
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
        guard try await validateAuthorization(authorization) else { throw CollectionOutboxSyncError.sessionChanged }

        do {
            let remoteEntry = try await fetchRemoteEntry(workItem.mangaID, authorization.accessToken)
            try Task.checkCancellation()
            guard try await validateAuthorization(authorization) else { throw CollectionOutboxSyncError.sessionChanged }
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
            try await performCollectionStoreOperation(
                authorization: authorization,
                validateAuthorization: validateAuthorization
            ) {
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
        guard try await validateAuthorization(authorization) else { throw CollectionOutboxSyncError.sessionChanged }
        let resolution = try await performCollectionStoreOperation(
            authorization: authorization,
            validateAuthorization: validateAuthorization
        ) {
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
            guard try await validateAuthorization(authorization) else { throw CollectionOutboxSyncError.sessionChanged }
            let workItem = try await performCollectionStoreOperation(
                authorization: authorization,
                validateAuthorization: validateAuthorization
            ) {
                try await nextRecoveredUpload(authorization.commitAuthorization)
            }
            guard let workItem else { return }

            logUnconfirmedOutcome(origin: "collectionSnapshot", workItem: workItem)
            try await performCollectionStoreOperation(
                authorization: authorization,
                validateAuthorization: validateAuthorization
            ) {
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
        authorization: SessionRequestAuthorization,
        validateAuthorization: ValidateAuthorization,
        _ operation: @Sendable () async throws(any Error) -> Value
    ) async throws(any Error) -> Value {
        do {
            return try await operation()
        } catch let error as CollectionOutboxUploadError {
            switch error {
            case .sessionChanged:
                _ = try await validateAuthorization(authorization)
                throw CollectionOutboxSyncError.sessionChanged
            case .cancelled:
                throw CancellationError()
            case .staleOperation, .invalidVolumeState, .persistenceConflict:
                throw error
            }
        } catch let error as CollectionRemoteImportError {
            switch error {
            case .sessionChanged:
                _ = try await validateAuthorization(authorization)
                throw CollectionOutboxSyncError.sessionChanged
            case .cancelled:
                throw CancellationError()
            default:
                throw error
            }
        } catch CollectionOutboxSyncError.sessionChanged {
            _ = try await validateAuthorization(authorization)
            throw CollectionOutboxSyncError.sessionChanged
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

    private static func logRetryResolution(
        _ resolution: CollectionOutboxRetryResolution,
        workItem: CollectionOutboxUploadWorkItem,
        retryCount: Int
    ) {
        let method = workItem.isTombstone ? "DELETE" : "POST"
        switch resolution {
        case .scheduled:
            logger.error(
                "R2 write not sent: method=\(method, privacy: .public) retry=\(retryCount, privacy: .public) action=backoff"
            )
        case .superseded:
            logger.error("R2 write not sent: method=\(method, privacy: .public) action=superseded")
        }
    }

    private static func logPermanentRejection(workItem: CollectionOutboxUploadWorkItem) {
        let method = workItem.isTombstone ? "DELETE" : "POST"
        logger.error("R2 write rejected: method=\(method, privacy: .public) action=rollback")
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
            authorize: {
                try await sessionController.requestAuthorization()
            },
            validateAuthorization: { authorization in
                try await sessionController.authorizes(authorization)
            },
            claimNextUpload: { authorization, now in
                try await mutationActor.claimNextUpload(authorization: authorization, now: now)
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
            fetchRemote: { accessToken in
                try await client.fetch(accessToken: accessToken)
            },
            fetchRemoteEntry: { mangaID, accessToken in
                try await client.fetch(mangaID: mangaID, accessToken: accessToken)
            },
            importRemote: { entries, authorization in
                try await mutationActor.importRemote(entries, authorization: authorization)
            },
            confirmUpload: { workItem, authorization in
                try await mutationActor.confirmUpload(workItem, authorization: authorization)
            },
            scheduleRetry: { workItem, nextRetryAt, authorization in
                try await mutationActor.scheduleUploadRetry(
                    workItem,
                    nextRetryAt: nextRetryAt,
                    authorization: authorization
                )
            },
            resolveDeletion: { workItem, evidence, authorization in
                try await mutationActor.resolveDeletion(workItem, evidence: evidence, authorization: authorization)
            },
            blockUploadOutcome: { workItem, authorization in
                try await mutationActor.blockUploadOutcome(workItem, authorization: authorization)
            },
            reactivateBlockedUploads: { authorization in
                try await mutationActor.reactivateBlockedUploads(authorization: authorization)
            },
            resolvePermanentRejection: { workItem, authorization in
                try await mutationActor.resolvePermanentRejection(workItem, authorization: authorization)
            },
            hasBlockedOutcome: { authorization in
                try await mutationActor.hasBlockedUploadOutcome(authorization: authorization)
            }
        )
    }
}
