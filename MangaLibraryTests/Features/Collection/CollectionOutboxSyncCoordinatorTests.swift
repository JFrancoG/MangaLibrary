//
//  CollectionOutboxSyncCoordinatorTests.swift
//  MangaLibraryTests
//

import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Collection outbox synchronization", .tags(.integration))
struct CollectionOutboxSyncCoordinatorTests {
    @Test("A confirmed POST resolves the exact claimed operation without reading again")
    func confirmedPostResolvesTheClaim() async throws(any Error) {
        let probe = WorkerProbe(actions: [.send(Self.workItem)])
        let coordinator = Self.makeCoordinator(probe: probe)

        try await coordinator.synchronizeAuthenticatedOutbox()

        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 1)
        #expect(evidence.fetchCount == 0)
        #expect(evidence.confirmedItems == [Self.workItem])
        #expect(evidence.blockedItems.isEmpty)
        #expect(evidence.accessTokens == ["synthetic-access"])
    }

    @Test("A lost POST response performs one full GET and confirms a matching remote state")
    func uncertainPostWithMatchingRemoteStateConfirmsWithoutRetry() async throws(any Error) {
        let probe = WorkerProbe(
            actions: [.send(Self.workItem)],
            submitFailure: .failed,
            remoteEntries: [Self.matchingRemoteEntry]
        )
        let coordinator = Self.makeCoordinator(probe: probe)

        try await coordinator.synchronizeAuthenticatedOutbox()

        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 1)
        #expect(evidence.fetchCount == 1)
        #expect(evidence.importCount == 1)
        #expect(evidence.confirmedItems == [Self.workItem])
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("A divergent reconciliation blocks the uncertain operation and never repeats POST")
    func divergentRemoteStateBlocksWithoutRetry() async throws(any Error) {
        let probe = WorkerProbe(
            actions: [.send(Self.workItem)],
            submitFailure: .failed,
            remoteEntries: [Self.divergentRemoteEntry]
        )
        let coordinator = Self.makeCoordinator(probe: probe)

        await #expect(throws: CollectionOutboxSyncError.outcomeUnconfirmed) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 1)
        #expect(evidence.fetchCount == 1)
        #expect(evidence.importCount == 1)
        #expect(evidence.confirmedItems.isEmpty)
        #expect(evidence.blockedItems == [Self.workItem])
    }

    @Test("A failed reconciliation read blocks the uncertain operation after one GET")
    func failedReconciliationReadBlocksWithoutRetry() async throws(any Error) {
        let probe = WorkerProbe(actions: [.send(Self.workItem)], submitFailure: .failed, fetchFailure: .failed)
        let coordinator = Self.makeCoordinator(probe: probe)

        await #expect(throws: CollectionOutboxSyncError.outcomeUnconfirmed) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 1)
        #expect(evidence.fetchCount == 1)
        #expect(evidence.importCount == 0)
        #expect(evidence.confirmedItems.isEmpty)
        #expect(evidence.blockedItems == [Self.workItem])
    }

    @Test("A recovered sending operation reconciles and never emits another POST")
    func recoveredSendingOperationReconcilesBeforeAnyWrite() async throws(any Error) {
        let probe = WorkerProbe(actions: [.reconcile(Self.workItem)], remoteEntries: [Self.matchingRemoteEntry])
        let coordinator = Self.makeCoordinator(probe: probe)

        try await coordinator.synchronizeAuthenticatedOutbox()

        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 0)
        #expect(evidence.fetchCount == 1)
        #expect(evidence.confirmedItems == [Self.workItem])
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("An invalid generation is rejected before claiming or writing")
    func invalidatedAuthorizationPreventsTheWrite() async throws(any Error) {
        let probe = WorkerProbe(actions: [.send(Self.workItem)], authorizationIsValid: false)
        let coordinator = Self.makeCoordinator(probe: probe)

        await #expect(throws: CollectionOutboxSyncError.sessionChanged) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 0)
        #expect(evidence.fetchCount == 0)
        #expect(evidence.confirmedItems.isEmpty)
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test(
        "A session change at every outbox store boundary uses the coordinator domain",
        arguments: WorkerStoreBoundary.allCases
    )
    private func storeSessionChangeIsMapped(boundary: WorkerStoreBoundary) async throws(any Error) {
        let probe = Self.failingProbe(at: boundary, error: .sessionChanged)
        let coordinator = Self.makeCoordinator(probe: probe)

        await #expect(throws: CollectionOutboxSyncError.sessionChanged) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }
    }

    @Test(
        "Cancellation at every outbox store boundary remains task cancellation",
        arguments: WorkerStoreBoundary.allCases
    )
    private func storeCancellationIsMapped(boundary: WorkerStoreBoundary) async throws(any Error) {
        let probe = Self.failingProbe(at: boundary, error: .cancelled)
        let coordinator = Self.makeCoordinator(probe: probe)

        await #expect(throws: CancellationError.self) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }
    }

    @Test("A session change while importing reconciliation evidence never blocks the upload")
    func remoteImportSessionChangeIsMapped() async throws(any Error) {
        let probe = WorkerProbe(
            actions: [.reconcile(Self.workItem)],
            remoteEntries: [Self.matchingRemoteEntry],
            remoteImportFailure: .sessionChanged
        )
        let coordinator = Self.makeCoordinator(probe: probe)

        await #expect(throws: CollectionOutboxSyncError.sessionChanged) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.confirmedItems.isEmpty)
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("Cancellation while importing reconciliation evidence remains cancellation")
    func remoteImportCancellationIsMapped() async throws(any Error) {
        let probe = WorkerProbe(
            actions: [.reconcile(Self.workItem)],
            remoteEntries: [Self.matchingRemoteEntry],
            remoteImportFailure: .cancelled
        )
        let coordinator = Self.makeCoordinator(probe: probe)

        await #expect(throws: CancellationError.self) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.confirmedItems.isEmpty)
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("A generation invalidated during POST cannot confirm its late response")
    func invalidatedAuthorizationAfterWritePreventsTheCommit() async throws(any Error) {
        let probe = WorkerProbe(actions: [.send(Self.workItem)], invalidatesAfterSubmit: true)
        let coordinator = Self.makeCoordinator(probe: probe)

        await #expect(throws: CollectionOutboxSyncError.sessionChanged) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 1)
        #expect(evidence.fetchCount == 0)
        #expect(evidence.confirmedItems.isEmpty)
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test(
        "A session persistence failure after POST is never reclassified as write uncertainty",
        arguments: OutboxSessionPersistenceFailure.allCases
    )
    private func sessionPersistenceFailureAfterPostPrecedesReconciliation(
        failure: OutboxSessionPersistenceFailure
    ) async throws(any Error) {
        let probe = WorkerProbe(actions: [.send(Self.workItem)])
        let validationCount = Mutex(0)
        let coordinator = Self.makeCoordinator(
            probe: probe,
            validateAuthorization: { _ in
                let invocation = validationCount.withLock {
                    $0 += 1
                    return $0
                }
                if invocation == 4 {
                    throw failure.error
                }
                return invocation < 5
            }
        )

        await #expect(throws: failure.error) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(validationCount.withLock { $0 } == 4)
        #expect(evidence.submitCount == 1)
        #expect(evidence.fetchCount == 0)
        #expect(evidence.confirmedItems.isEmpty)
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test(
        "A session persistence failure after reconciliation GET never blocks the upload",
        arguments: OutboxSessionPersistenceFailure.allCases
    )
    private func sessionPersistenceFailureAfterReconciliationReadPrecedesBlocking(
        failure: OutboxSessionPersistenceFailure
    ) async throws(any Error) {
        let probe = WorkerProbe(actions: [.reconcile(Self.workItem)], remoteEntries: [Self.matchingRemoteEntry])
        let validationCount = Mutex(0)
        let coordinator = Self.makeCoordinator(
            probe: probe,
            validateAuthorization: { _ in
                let invocation = validationCount.withLock {
                    $0 += 1
                    return $0
                }
                if invocation == 5 {
                    throw failure.error
                }
                return true
            }
        )

        await #expect(throws: failure.error) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(validationCount.withLock { $0 } == 5)
        #expect(evidence.submitCount == 0)
        #expect(evidence.fetchCount == 1)
        #expect(evidence.importCount == 0)
        #expect(evidence.confirmedItems.isEmpty)
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("A persisted blocked outcome remains visible without another request")
    func persistedBlockedOutcomeRemainsObservable() async throws(any Error) {
        let probe = WorkerProbe(actions: [], hasBlockedOutcome: true)
        let coordinator = Self.makeCoordinator(probe: probe)

        await #expect(throws: CollectionOutboxSyncError.outcomeUnconfirmed) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 0)
        #expect(evidence.fetchCount == 0)
    }

    @Test("A replacement cancels one suspended POST and reconciles without another write")
    func replacementReconcilesTheSinglePersistedFlight() async throws(any Error) {
        let probe = ControlledSingleFlightProbe()
        let coordinator = CollectionOutboxSyncCoordinator(
            authorize: { await probe.authorization() },
            validateAuthorization: { authorization in await probe.validates(authorization) },
            claimNextUpload: { authorization in try await probe.claim(authorization) },
            submit: { item, accessToken in try await probe.submit(item, accessToken: accessToken) },
            fetchRemote: { accessToken in try await probe.fetchRemote(accessToken: accessToken) },
            importRemote: { entries, authorization in
                try await probe.importRemote(entries, authorization: authorization)
            },
            confirmUpload: { item, authorization in
                try await probe.confirm(item, authorization: authorization)
            },
            blockUploadOutcome: { item, authorization in
                try await probe.block(item, authorization: authorization)
            }
        )

        let first = Task { try await coordinator.synchronizeAuthenticatedOutbox() }
        await probe.waitUntilSubmitStarts()
        let replacement = Task { try await coordinator.synchronizeAuthenticatedOutbox() }
        await probe.waitUntilSubmitCancellation()

        await #expect(throws: CancellationError.self) { try await first.value }
        try await replacement.value

        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 1)
        #expect(evidence.fetchCount == 1)
        #expect(evidence.confirmedItems == [Self.workItem])
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("A cancelled late R1 failure cannot interrupt the current outbox flight")
    func cancelledLateSnapshotFailureDoesNotCancelCurrentFlight() async throws(any Error) {
        let probe = ControlledSingleFlightProbe()
        let outboxCoordinator = CollectionOutboxSyncCoordinator(
            authorize: { await probe.authorization() },
            validateAuthorization: { authorization in await probe.validates(authorization) },
            claimNextUpload: { authorization in try await probe.claim(authorization) },
            submit: { item, accessToken in try await probe.submit(item, accessToken: accessToken) },
            fetchRemote: { accessToken in try await probe.fetchRemote(accessToken: accessToken) },
            importRemote: { entries, authorization in
                try await probe.importRemote(entries, authorization: authorization)
            },
            confirmUpload: { item, authorization in
                try await probe.confirm(item, authorization: authorization)
            },
            blockUploadOutcome: { item, authorization in
                try await probe.block(item, authorization: authorization)
            }
        )
        let lateFailure = LateSnapshotFailure()
        let importCoordinator = CollectionSyncCoordinator(
            authorize: { await probe.authorization() },
            validateAuthorization: { authorization in await probe.validates(authorization) },
            fetchRemote: { _ in try await lateFailure.fetch() },
            importRemote: { _, _ in }
        )

        let current = Task { try await outboxCoordinator.synchronizeAuthenticatedOutbox() }
        await probe.waitUntilSubmitStarts()
        let stale = Task {
            try await importCoordinator.importAuthenticatedCollection { authorization in
                try await outboxCoordinator.blockRecoveredUploadsAfterUnusableSnapshot(for: authorization)
            }
        }
        await lateFailure.waitUntilRequested()
        stale.cancel()
        await lateFailure.failRequest()

        await #expect(throws: CancellationError.self) { try await stale.value }
        await probe.finishSubmit()
        try await current.value

        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 1)
        #expect(evidence.fetchCount == 0)
        #expect(evidence.submitWasCancelled == false)
        #expect(evidence.confirmedItems == [Self.workItem])
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("A stale snapshot cannot cancel the current generation's outbox flight")
    func staleSnapshotDoesNotCancelCurrentFlight() async throws(any Error) {
        let probe = ControlledSingleFlightProbe()
        let coordinator = Self.makeControlledCoordinator(probe: probe)
        let currentAuthorization = await probe.authorization()
        let currentSnapshot = CollectionImportedSnapshot(authority: currentAuthorization.authority, entries: [])

        let current = Task {
            try await coordinator.synchronizeAuthenticatedOutbox(reusing: currentSnapshot)
        }
        await probe.waitUntilSubmitStarts()

        let staleSnapshot = CollectionImportedSnapshot(authority: Self.staleAuthorization().authority, entries: [])
        await #expect(throws: CollectionOutboxSyncError.sessionChanged) {
            try await coordinator.synchronizeAuthenticatedOutbox(reusing: staleSnapshot)
        }

        let suspendedEvidence = await probe.evidence()
        #expect(suspendedEvidence.submitWasCancelled == false)
        await probe.finishSubmit()
        try await current.value

        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 1)
        #expect(evidence.fetchCount == 0)
        #expect(evidence.submitWasCancelled == false)
        #expect(evidence.confirmedItems == [Self.workItem])
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("A stale R1 failure cannot cancel the current generation's outbox flight")
    func staleSnapshotFailureDoesNotCancelCurrentFlight() async throws(any Error) {
        let probe = ControlledSingleFlightProbe()
        let coordinator = Self.makeControlledCoordinator(probe: probe)
        let currentAuthorization = await probe.authorization()
        let currentSnapshot = CollectionImportedSnapshot(authority: currentAuthorization.authority, entries: [])

        let current = Task {
            try await coordinator.synchronizeAuthenticatedOutbox(reusing: currentSnapshot)
        }
        await probe.waitUntilSubmitStarts()

        await #expect(throws: CollectionOutboxSyncError.sessionChanged) {
            try await coordinator.blockRecoveredUploadsAfterUnusableSnapshot(for: Self.staleAuthorization())
        }

        let suspendedEvidence = await probe.evidence()
        #expect(suspendedEvidence.submitWasCancelled == false)
        await probe.finishSubmit()
        try await current.value

        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 1)
        #expect(evidence.fetchCount == 0)
        #expect(evidence.submitWasCancelled == false)
        #expect(evidence.confirmedItems == [Self.workItem])
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("The current generation replaces a suspended prior-generation flight")
    func currentGenerationReplacesPriorFlight() async throws(any Error) {
        let probe = ControlledSingleFlightProbe()
        let coordinator = Self.makeControlledCoordinator(probe: probe)
        let priorAuthorization = await probe.authorization()
        let priorSnapshot = CollectionImportedSnapshot(authority: priorAuthorization.authority, entries: [])
        let prior = Task {
            try await coordinator.synchronizeAuthenticatedOutbox(reusing: priorSnapshot)
        }
        await probe.waitUntilSubmitStarts()

        let currentAuthorization = await probe.activateReplacementGeneration()
        let currentSnapshot = CollectionImportedSnapshot(
            authority: currentAuthorization.authority,
            entries: [Self.matchingRemoteEntry]
        )
        let current = Task {
            try await coordinator.synchronizeAuthenticatedOutbox(reusing: currentSnapshot)
        }

        var currentSucceeded = false
        do {
            try await current.value
            currentSucceeded = true
        } catch {
            currentSucceeded = false
        }
        await probe.finishSubmit()
        _ = try? await prior.value

        #expect(currentSucceeded)
        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 1)
        #expect(evidence.fetchCount == 0)
        #expect(evidence.submitWasCancelled)
        #expect(evidence.confirmedItems == [Self.workItem])
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("A current R1 failure replaces and blocks a prior-generation flight")
    func currentSnapshotFailureReplacesPriorFlight() async throws(any Error) {
        let probe = ControlledSingleFlightProbe()
        let coordinator = Self.makeControlledCoordinator(probe: probe)
        let priorAuthorization = await probe.authorization()
        let priorSnapshot = CollectionImportedSnapshot(authority: priorAuthorization.authority, entries: [])
        let prior = Task {
            try await coordinator.synchronizeAuthenticatedOutbox(reusing: priorSnapshot)
        }
        await probe.waitUntilSubmitStarts()

        let currentAuthorization = await probe.activateReplacementGeneration()
        try await coordinator.blockRecoveredUploadsAfterUnusableSnapshot(for: currentAuthorization)
        await probe.finishSubmit()
        _ = try? await prior.value

        let evidence = await probe.evidence()
        #expect(evidence.submitCount == 1)
        #expect(evidence.fetchCount == 0)
        #expect(evidence.submitWasCancelled)
        #expect(evidence.confirmedItems.isEmpty)
        #expect(evidence.blockedItems == [Self.workItem])
    }

    private static func makeCoordinator(probe: WorkerProbe) -> CollectionOutboxSyncCoordinator {
        makeCoordinator(
            probe: probe,
            validateAuthorization: { authorization in await probe.validates(authorization) }
        )
    }

    private static func makeCoordinator(
        probe: WorkerProbe,
        validateAuthorization: @escaping CollectionOutboxSyncCoordinator.ValidateAuthorization
    ) -> CollectionOutboxSyncCoordinator {
        CollectionOutboxSyncCoordinator(
            authorize: { await probe.authorization() },
            validateAuthorization: validateAuthorization,
            claimNextUpload: { authorization in try await probe.claim(authorization) },
            submit: { item, accessToken in try await probe.submit(item, accessToken: accessToken) },
            fetchRemote: { accessToken in try await probe.fetchRemote(accessToken: accessToken) },
            importRemote: { entries, authorization in
                try await probe.importRemote(entries, authorization: authorization)
            },
            confirmUpload: { item, authorization in try await probe.confirm(item, authorization: authorization) },
            blockUploadOutcome: { item, authorization in
                try await probe.block(item, authorization: authorization)
            },
            hasBlockedOutcome: { authorization in try await probe.hasBlocked(authorization) }
        )
    }

    private static func makeControlledCoordinator(
        probe: ControlledSingleFlightProbe
    ) -> CollectionOutboxSyncCoordinator {
        CollectionOutboxSyncCoordinator(
            authorize: { await probe.authorization() },
            validateAuthorization: { authorization in await probe.validates(authorization) },
            claimNextUpload: { authorization in try await probe.claim(authorization) },
            nextRecoveredUpload: { authorization in try await probe.nextRecovered(authorization) },
            submit: { item, accessToken in try await probe.submit(item, accessToken: accessToken) },
            fetchRemote: { accessToken in try await probe.fetchRemote(accessToken: accessToken) },
            importRemote: { entries, authorization in
                try await probe.importRemote(entries, authorization: authorization)
            },
            confirmUpload: { item, authorization in
                try await probe.confirm(item, authorization: authorization)
            },
            blockUploadOutcome: { item, authorization in
                try await probe.block(item, authorization: authorization)
            }
        )
    }

    private static func staleAuthorization() -> SessionRequestAuthorization {
        let authority = SessionAuthority(
            userID: workItem.userID,
            generation: UUID(uuidString: "33333333-4444-5555-6666-777777777777")!
        )
        let gate = SessionCommitGate(activeAuthority: authority)
        return SessionRequestAuthorization(
            authority: authority,
            accessToken: "stale-synthetic-access",
            commitAuthorization: gate.authorization(for: authority)
        )
    }

    private static func failingProbe(
        at boundary: WorkerStoreBoundary,
        error: CollectionOutboxUploadError
    ) -> WorkerProbe {
        switch boundary {
        case .claim:
            WorkerProbe(actions: [.send(workItem)], storeFailure: (boundary, error))
        case .confirm:
            WorkerProbe(actions: [.send(workItem)], storeFailure: (boundary, error))
        case .block:
            WorkerProbe(
                actions: [.send(workItem)],
                submitFailure: .failed,
                fetchFailure: .failed,
                storeFailure: (boundary, error)
            )
        case .hasBlocked:
            WorkerProbe(actions: [], storeFailure: (boundary, error))
        }
    }

    fileprivate static let workItem = CollectionOutboxUploadWorkItem(
        operationID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        userID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        mangaID: 42,
        sequence: 3,
        ownedVolumes: [1, 3],
        readingVolume: 2,
        isComplete: false,
        isTombstone: false
    )

    fileprivate static let matchingRemoteEntry = remoteEntry(ownedVolumes: [1, 3])
    private static let divergentRemoteEntry = remoteEntry(ownedVolumes: [1])

    private static func remoteEntry(ownedVolumes: [Int64]) -> CollectionRemoteEntry {
        CollectionRemoteEntry(
            remoteID: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
            manga: Manga(
                id: 42,
                title: "Remote Forty-Two",
                titleEnglish: nil,
                titleJapanese: nil,
                synopsis: nil,
                score: 8,
                status: .publishing,
                authors: [],
                demographics: [],
                genres: [],
                themes: [],
                totalVolumes: 3,
                coverURL: nil
            ),
            ownedVolumes: ownedVolumes,
            readingVolume: 2,
            isComplete: false
        )
    }
}

private actor ControlledSingleFlightProbe {
    struct Evidence: Equatable {
        let submitCount: Int
        let fetchCount: Int
        let submitWasCancelled: Bool
        let confirmedItems: [CollectionOutboxUploadWorkItem]
        let blockedItems: [CollectionOutboxUploadWorkItem]
    }

    enum Failure: Error {
        case invalidInput
    }

    private var requestAuthorization: SessionRequestAuthorization
    private var claimCount = 0
    private var recoveredCount = 0
    private var submitCount = 0
    private var fetchCount = 0
    private var confirmedItems: [CollectionOutboxUploadWorkItem] = []
    private var blockedItems: [CollectionOutboxUploadWorkItem] = []
    private var submitStarted = false
    private var submitWasCancelled = false
    private var resumeSubmitWhenInstalled = false
    private var submitContinuation: CheckedContinuation<Void, Never>?
    private var submitStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var submitCancellationWaiters: [CheckedContinuation<Void, Never>] = []

    init() {
        let authority = SessionAuthority(
            userID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            generation: UUID(uuidString: "22222222-3333-4444-5555-666666666666")!
        )
        let gate = SessionCommitGate(activeAuthority: authority)
        requestAuthorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "synthetic-access",
            commitAuthorization: gate.authorization(for: authority)
        )
    }

    func authorization() -> SessionRequestAuthorization {
        requestAuthorization
    }

    func activateReplacementGeneration() -> SessionRequestAuthorization {
        let authority = SessionAuthority(
            userID: requestAuthorization.authority.userID,
            generation: UUID(uuidString: "44444444-5555-6666-7777-888888888888")!
        )
        let gate = SessionCommitGate(activeAuthority: authority)
        requestAuthorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "replacement-synthetic-access",
            commitAuthorization: gate.authorization(for: authority)
        )
        return requestAuthorization
    }

    func validates(_ authorization: SessionRequestAuthorization) -> Bool {
        authorization.authority == requestAuthorization.authority
    }

    func claim(_ authorization: SessionCommitAuthorization) throws -> CollectionOutboxUploadClaim? {
        guard authorization.authority == requestAuthorization.authority else { throw Failure.invalidInput }
        let claim: CollectionOutboxUploadClaim?
        if claimCount == 0 {
            claim = .send(CollectionOutboxSyncCoordinatorTests.workItem)
        } else if confirmedItems.isEmpty {
            claim = .reconcile(CollectionOutboxSyncCoordinatorTests.workItem)
        } else {
            claim = nil
        }
        claimCount += 1
        return claim
    }

    func nextRecovered(_ authorization: SessionCommitAuthorization) throws -> CollectionOutboxUploadWorkItem? {
        guard authorization.authority == requestAuthorization.authority else { throw Failure.invalidInput }
        guard recoveredCount == 0 else { return nil }
        recoveredCount += 1
        return CollectionOutboxSyncCoordinatorTests.workItem
    }

    func submit(_ item: CollectionOutboxUploadWorkItem, accessToken: String) async throws(any Error) {
        guard
            item == CollectionOutboxSyncCoordinatorTests.workItem,
            accessToken == requestAuthorization.accessToken
        else { throw Failure.invalidInput }

        submitCount += 1
        submitStarted = true
        let startWaiters = submitStartWaiters
        submitStartWaiters.removeAll()
        for waiter in startWaiters {
            waiter.resume()
        }

        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if resumeSubmitWhenInstalled {
                    continuation.resume()
                } else {
                    submitContinuation = continuation
                }
            }
        } onCancel: {
            Task { await self.cancelSuspendedSubmit() }
        }
        try Task.checkCancellation()
    }

    func fetchRemote(accessToken: String) throws -> [CollectionRemoteEntry] {
        guard accessToken == requestAuthorization.accessToken else { throw Failure.invalidInput }
        fetchCount += 1
        return [CollectionOutboxSyncCoordinatorTests.matchingRemoteEntry]
    }

    func importRemote(_ entries: [CollectionRemoteEntry], authorization: SessionCommitAuthorization) throws {
        guard
            entries == [CollectionOutboxSyncCoordinatorTests.matchingRemoteEntry],
            authorization.authority == requestAuthorization.authority
        else { throw Failure.invalidInput }
    }

    func confirm(_ item: CollectionOutboxUploadWorkItem, authorization: SessionCommitAuthorization) throws {
        guard authorization.authority == requestAuthorization.authority else { throw Failure.invalidInput }
        confirmedItems.append(item)
    }

    func block(_ item: CollectionOutboxUploadWorkItem, authorization: SessionCommitAuthorization) throws {
        guard authorization.authority == requestAuthorization.authority else { throw Failure.invalidInput }
        blockedItems.append(item)
    }

    func waitUntilSubmitStarts() async {
        if submitStarted {
            return
        }
        await withCheckedContinuation { submitStartWaiters.append($0) }
    }

    func waitUntilSubmitCancellation() async {
        if submitWasCancelled {
            return
        }
        await withCheckedContinuation { submitCancellationWaiters.append($0) }
    }

    func finishSubmit() {
        if let submitContinuation {
            self.submitContinuation = nil
            submitContinuation.resume()
        } else {
            resumeSubmitWhenInstalled = true
        }
    }

    private func cancelSuspendedSubmit() {
        submitWasCancelled = true
        let cancellationWaiters = submitCancellationWaiters
        submitCancellationWaiters.removeAll()
        for waiter in cancellationWaiters {
            waiter.resume()
        }

        if let submitContinuation {
            self.submitContinuation = nil
            submitContinuation.resume()
        } else {
            resumeSubmitWhenInstalled = true
        }
    }

    func evidence() -> Evidence {
        Evidence(
            submitCount: submitCount,
            fetchCount: fetchCount,
            submitWasCancelled: submitWasCancelled,
            confirmedItems: confirmedItems,
            blockedItems: blockedItems
        )
    }
}

private actor LateSnapshotFailure {
    enum Failure: Error {
        case unavailable
    }

    private var requestStarted = false
    private var resumeRequestWhenInstalled = false
    private var requestContinuation: CheckedContinuation<Void, Never>?
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []

    func fetch() async throws(any Error) -> [CollectionRemoteEntry] {
        requestStarted = true
        let waiters = requestWaiters
        requestWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }

        await withCheckedContinuation { continuation in
            if resumeRequestWhenInstalled {
                continuation.resume()
            } else {
                requestContinuation = continuation
            }
        }
        throw Failure.unavailable
    }

    func waitUntilRequested() async {
        if requestStarted {
            return
        }
        await withCheckedContinuation { requestWaiters.append($0) }
    }

    func failRequest() {
        if let requestContinuation {
            self.requestContinuation = nil
            requestContinuation.resume()
        } else {
            resumeRequestWhenInstalled = true
        }
    }
}

private enum WorkerStoreBoundary: CaseIterable {
    case claim
    case confirm
    case block
    case hasBlocked
}

private enum OutboxSessionPersistenceFailure: CaseIterable {
    case temporarilyUnavailable
    case persistenceUnavailable

    var error: SessionControllerError {
        switch self {
        case .temporarilyUnavailable: .temporarilyUnavailable
        case .persistenceUnavailable: .persistenceUnavailable
        }
    }
}

private actor WorkerProbe {
    enum Failure: Error {
        case failed
    }

    struct Evidence: Equatable {
        let submitCount: Int
        let fetchCount: Int
        let importCount: Int
        let confirmedItems: [CollectionOutboxUploadWorkItem]
        let blockedItems: [CollectionOutboxUploadWorkItem]
        let accessTokens: [String]
    }

    private let requestAuthorization: SessionRequestAuthorization
    private let submitFailure: Failure?
    private let fetchFailure: Failure?
    private let remoteEntries: [CollectionRemoteEntry]
    private let remoteImportFailure: CollectionRemoteImportError?
    private let authorizationIsValid: Bool
    private let invalidatesAfterSubmit: Bool
    private let hasBlockedOutcome: Bool
    private let storeFailure: (boundary: WorkerStoreBoundary, error: CollectionOutboxUploadError)?
    private var actions: [CollectionOutboxUploadClaim]
    private var submitCount = 0
    private var fetchCount = 0
    private var importCount = 0
    private var confirmedItems: [CollectionOutboxUploadWorkItem] = []
    private var blockedItems: [CollectionOutboxUploadWorkItem] = []
    private var accessTokens: [String] = []

    init(
        actions: [CollectionOutboxUploadClaim],
        submitFailure: Failure? = nil,
        fetchFailure: Failure? = nil,
        remoteEntries: [CollectionRemoteEntry] = [],
        remoteImportFailure: CollectionRemoteImportError? = nil,
        authorizationIsValid: Bool = true,
        invalidatesAfterSubmit: Bool = false,
        hasBlockedOutcome: Bool = false,
        storeFailure: (boundary: WorkerStoreBoundary, error: CollectionOutboxUploadError)? = nil
    ) {
        let authority = SessionAuthority(
            userID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            generation: UUID(uuidString: "22222222-3333-4444-5555-666666666666")!
        )
        let gate = SessionCommitGate(activeAuthority: authority)
        requestAuthorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "synthetic-access",
            commitAuthorization: gate.authorization(for: authority)
        )
        self.actions = actions
        self.submitFailure = submitFailure
        self.fetchFailure = fetchFailure
        self.remoteEntries = remoteEntries
        self.remoteImportFailure = remoteImportFailure
        self.authorizationIsValid = authorizationIsValid
        self.invalidatesAfterSubmit = invalidatesAfterSubmit
        self.hasBlockedOutcome = hasBlockedOutcome
        self.storeFailure = storeFailure
    }

    func authorization() -> SessionRequestAuthorization {
        requestAuthorization
    }

    func validates(_ authorization: SessionRequestAuthorization) -> Bool {
        let remainsValid = invalidatesAfterSubmit == false || submitCount == 0
        return authorizationIsValid && remainsValid && authorization.authority == requestAuthorization.authority
    }

    func claim(_ authorization: SessionCommitAuthorization) throws -> CollectionOutboxUploadClaim? {
        try failIfConfigured(at: .claim)
        guard authorization.authority == requestAuthorization.authority else { throw Failure.failed }
        guard actions.isEmpty == false else { return nil }

        return actions.removeFirst()
    }

    func submit(_ item: CollectionOutboxUploadWorkItem, accessToken: String) throws {
        submitCount += 1
        accessTokens.append(accessToken)
        guard item == CollectionOutboxSyncCoordinatorTests.workItem else { throw Failure.failed }
        if let submitFailure {
            throw submitFailure
        }
    }

    func fetchRemote(accessToken: String) throws -> [CollectionRemoteEntry] {
        fetchCount += 1
        accessTokens.append(accessToken)
        if let fetchFailure {
            throw fetchFailure
        }

        return remoteEntries
    }

    func importRemote(_ entries: [CollectionRemoteEntry], authorization: SessionCommitAuthorization) throws {
        guard authorization.authority == requestAuthorization.authority, entries == remoteEntries else {
            throw Failure.failed
        }
        if let remoteImportFailure {
            throw remoteImportFailure
        }
        importCount += 1
    }

    func confirm(_ item: CollectionOutboxUploadWorkItem, authorization: SessionCommitAuthorization) throws {
        try failIfConfigured(at: .confirm)
        guard authorization.authority == requestAuthorization.authority else { throw Failure.failed }
        confirmedItems.append(item)
    }

    func block(_ item: CollectionOutboxUploadWorkItem, authorization: SessionCommitAuthorization) throws {
        try failIfConfigured(at: .block)
        guard authorization.authority == requestAuthorization.authority else { throw Failure.failed }
        blockedItems.append(item)
    }

    func hasBlocked(_ authorization: SessionCommitAuthorization) throws -> Bool {
        try failIfConfigured(at: .hasBlocked)
        guard authorization.authority == requestAuthorization.authority else { throw Failure.failed }
        return hasBlockedOutcome
    }

    private func failIfConfigured(at boundary: WorkerStoreBoundary) throws {
        if storeFailure?.boundary == boundary, let error = storeFailure?.error {
            throw error
        }
    }

    func evidence() -> Evidence {
        Evidence(
            submitCount: submitCount,
            fetchCount: fetchCount,
            importCount: importCount,
            confirmedItems: confirmedItems,
            blockedItems: blockedItems,
            accessTokens: accessTokens
        )
    }
}
