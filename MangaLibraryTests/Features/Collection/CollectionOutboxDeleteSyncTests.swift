//
//  CollectionOutboxDeleteSyncTests.swift
//  MangaLibraryTests
//

import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Collection outbox DELETE synchronization", .tags(.integration))
struct CollectionOutboxDeleteSyncTests {
    @Test("A confirmed DELETE retires the tombstone without a reconciliation GET")
    func confirmedDeleteDoesNotReadAgain() async throws(any Error) {
        let probe = DeleteSyncProbe(claim: .send(Self.workItem))
        let coordinator = Self.coordinator(probe: probe)

        try await coordinator.synchronizeAuthenticatedOutbox()

        let evidence = await probe.evidence()
        #expect(evidence.deleteCount == 1)
        #expect(evidence.individualGetCount == 0)
        #expect(evidence.fullGetCount == 0)
        #expect(evidence.resolutions == [.absent])
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test(
        "A local resolution failure after DELETE 200 never becomes remote uncertainty",
        arguments: [CollectionOutboxUploadError.staleOperation, .persistenceConflict]
    )
    func confirmedDeleteResolutionFailureDoesNotReadOrBlock(
        failure: CollectionOutboxUploadError
    ) async throws(any Error) {
        let probe = DeleteSyncProbe(claim: .send(Self.workItem), resolutionFailure: failure)
        let coordinator = Self.coordinator(probe: probe)

        await #expect(throws: failure) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.deleteCount == 1)
        #expect(evidence.individualGetCount == 0)
        #expect(evidence.fullGetCount == 0)
        #expect(evidence.resolutions == [.absent])
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("A lost DELETE response uses one individual 404 and confirms without repeating DELETE")
    func uncertainDeleteWithRemoteAbsenceConfirms() async throws(any Error) {
        let probe = DeleteSyncProbe(claim: .send(Self.workItem), deleteFails: true, lookup: .absent)
        let coordinator = Self.coordinator(probe: probe)

        try await coordinator.synchronizeAuthenticatedOutbox()

        let evidence = await probe.evidence()
        #expect(evidence.deleteCount == 1)
        #expect(evidence.individualGetCount == 1)
        #expect(evidence.fullGetCount == 0)
        #expect(evidence.resolutions == [.absent])
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("A present individual entry blocks an uncertain DELETE without repeating it")
    func uncertainDeleteWithRemotePresenceBlocks() async throws(any Error) {
        let probe = DeleteSyncProbe(claim: .send(Self.workItem), deleteFails: true, lookup: .present(Self.remoteEntry))
        let coordinator = Self.coordinator(probe: probe)

        await #expect(throws: CollectionOutboxSyncError.outcomeUnconfirmed) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.deleteCount == 1)
        #expect(evidence.individualGetCount == 1)
        #expect(evidence.fullGetCount == 0)
        #expect(evidence.resolutions == [.present(Self.remoteEntry)])
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("A failed individual reconciliation blocks the tombstone and never repeats DELETE")
    func failedIndividualGetBlocks() async throws(any Error) {
        let probe = DeleteSyncProbe(claim: .send(Self.workItem), deleteFails: true, lookup: .failed)
        let coordinator = Self.coordinator(probe: probe)

        await #expect(throws: CollectionOutboxSyncError.outcomeUnconfirmed) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.deleteCount == 1)
        #expect(evidence.individualGetCount == 1)
        #expect(evidence.fullGetCount == 0)
        #expect(evidence.resolutions.isEmpty)
        #expect(evidence.blockedItems == [Self.workItem])
    }

    @Test("Cancellation during individual reconciliation preserves sending without blocking")
    func cancelledIndividualGetPropagates() async throws(any Error) {
        let probe = DeleteSyncProbe(claim: .send(Self.workItem), deleteFails: true, lookup: .cancelled)
        let coordinator = Self.coordinator(probe: probe)

        await #expect(throws: CancellationError.self) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.deleteCount == 1)
        #expect(evidence.individualGetCount == 1)
        #expect(evidence.resolutions.isEmpty)
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("A session invalidated after DELETE cannot resolve or reconcile the tombstone")
    func sessionChangeAfterDeletePreventsAnyLaterEffect() async throws(any Error) {
        let probe = DeleteSyncProbe(claim: .send(Self.workItem))
        let coordinator = Self.coordinator(
            probe: probe,
            validateAuthorization: { authorization in
                let isCurrent = await probe.validates(authorization)
                let evidence = await probe.evidence()
                return isCurrent && evidence.deleteCount == 0
            }
        )

        await #expect(throws: CollectionOutboxSyncError.sessionChanged) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.deleteCount == 1)
        #expect(evidence.individualGetCount == 0)
        #expect(evidence.resolutions.isEmpty)
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test(
        "Session persistence failures after DELETE are never reclassified as write uncertainty",
        arguments: DeleteSessionPersistenceFailure.allCases
    )
    private func sessionPersistenceFailureAfterDeletePrecedesReconciliation(
        failure: DeleteSessionPersistenceFailure
    ) async throws(any Error) {
        let probe = DeleteSyncProbe(claim: .send(Self.workItem))
        let pendingFailure = Mutex<SessionControllerError?>(failure.error)
        let coordinator = Self.coordinator(
            probe: probe,
            validateAuthorization: { authorization in
                if await probe.evidence().deleteCount > 0 {
                    let error = pendingFailure.withLock { pending in
                        defer { pending = nil }
                        return pending
                    }
                    if let error {
                        throw error
                    }
                }
                return await probe.validates(authorization)
            }
        )

        await #expect(throws: failure.error) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.deleteCount == 1)
        #expect(evidence.individualGetCount == 0)
        #expect(evidence.resolutions.isEmpty)
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("A session invalidated after individual GET cannot resolve or block the tombstone")
    func sessionChangeAfterIndividualGetPreventsAnyCommit() async throws(any Error) {
        let probe = DeleteSyncProbe(claim: .send(Self.workItem), deleteFails: true, lookup: .absent)
        let coordinator = Self.coordinator(
            probe: probe,
            validateAuthorization: { authorization in
                let isCurrent = await probe.validates(authorization)
                let evidence = await probe.evidence()
                return isCurrent && evidence.individualGetCount == 0
            }
        )

        await #expect(throws: CollectionOutboxSyncError.sessionChanged) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.deleteCount == 1)
        #expect(evidence.individualGetCount == 1)
        #expect(evidence.resolutions.isEmpty)
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test(
        "Session persistence failures after individual GET are never reclassified as delete uncertainty",
        arguments: DeleteSessionPersistenceFailure.allCases
    )
    private func sessionPersistenceFailureAfterIndividualGetPrecedesBlocking(
        failure: DeleteSessionPersistenceFailure
    ) async throws(any Error) {
        let probe = DeleteSyncProbe(claim: .send(Self.workItem), deleteFails: true, lookup: .absent)
        let pendingFailure = Mutex<SessionControllerError?>(failure.error)
        let coordinator = Self.coordinator(
            probe: probe,
            validateAuthorization: { authorization in
                if await probe.evidence().individualGetCount > 0 {
                    let error = pendingFailure.withLock { pending in
                        defer { pending = nil }
                        return pending
                    }
                    if let error {
                        throw error
                    }
                }
                return await probe.validates(authorization)
            }
        )

        await #expect(throws: failure.error) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        let evidence = await probe.evidence()
        #expect(evidence.deleteCount == 1)
        #expect(evidence.individualGetCount == 1)
        #expect(evidence.resolutions.isEmpty)
        #expect(evidence.blockedItems.isEmpty)
    }

    @Test("A recovered tombstone reuses R1 absence with no additional request")
    func recoveredTombstoneUsesImportedAbsence() async throws(any Error) {
        let probe = DeleteSyncProbe(claim: .reconcile(Self.workItem))
        let coordinator = Self.coordinator(probe: probe)
        let snapshot = CollectionImportedSnapshot(authority: (await probe.authorization()).authority, entries: [])

        try await coordinator.synchronizeAuthenticatedOutbox(reusing: snapshot)

        let evidence = await probe.evidence()
        #expect(evidence.deleteCount == 0)
        #expect(evidence.individualGetCount == 0)
        #expect(evidence.fullGetCount == 0)
        #expect(evidence.resolutions == [.absent])
    }

    @Test("A recovered tombstone reuses R1 presence and blocks with no additional request")
    func recoveredTombstoneUsesImportedPresence() async throws(any Error) {
        let probe = DeleteSyncProbe(claim: .reconcile(Self.workItem))
        let coordinator = Self.coordinator(probe: probe)
        let snapshot = CollectionImportedSnapshot(
            authority: (await probe.authorization()).authority,
            entries: [Self.remoteEntry]
        )

        await #expect(throws: CollectionOutboxSyncError.outcomeUnconfirmed) {
            try await coordinator.synchronizeAuthenticatedOutbox(reusing: snapshot)
        }

        let evidence = await probe.evidence()
        #expect(evidence.deleteCount == 0)
        #expect(evidence.individualGetCount == 0)
        #expect(evidence.fullGetCount == 0)
        #expect(evidence.resolutions == [.present(Self.remoteEntry)])
    }

    private static func coordinator(probe: DeleteSyncProbe) -> CollectionOutboxSyncCoordinator {
        coordinator(
            probe: probe,
            validateAuthorization: { authorization in
                await probe.validates(authorization)
            }
        )
    }

    private static func coordinator(
        probe: DeleteSyncProbe,
        validateAuthorization: @escaping CollectionOutboxSyncCoordinator.ValidateAuthorization
    ) -> CollectionOutboxSyncCoordinator {
        CollectionOutboxSyncCoordinator(
            authorize: {
                await probe.authorization()
            },
            validateAuthorization: validateAuthorization,
            claimNextUpload: { authorization, _ in
                try await probe.claim(authorization)
            },
            submit: { item, token in
                try await probe.delete(item, accessToken: token)
            },
            fetchRemote: { token in
                try await probe.fetchFull(accessToken: token)
            },
            fetchRemoteEntry: { mangaID, token in
                try await probe.fetchIndividual(mangaID: mangaID, accessToken: token)
            },
            importRemote: { _, _ in
                Issue.record("A tombstone reconciliation must not import a partial snapshot")
            },
            confirmUpload: { _, _ in
                Issue.record("A tombstone must use its deletion resolution")
            },
            resolveDeletion: { item, evidence, authorization in
                try await probe.resolve(item, evidence: evidence, authorization: authorization)
            },
            blockUploadOutcome: { item, authorization in
                try await probe.block(item, authorization: authorization)
            }
        )
    }

    fileprivate static let workItem = CollectionOutboxUploadWorkItem(
        operationID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        userID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        mangaID: 42,
        sequence: 3,
        retryCount: 0,
        ownedVolumes: [1, 3],
        readingVolume: 2,
        isComplete: false,
        isTombstone: true
    )

    fileprivate static let remoteEntry = CollectionRemoteEntry(
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
        ownedVolumes: [1, 3],
        readingVolume: 2,
        isComplete: false
    )
}

private enum DeleteSessionPersistenceFailure: CaseIterable {
    case temporarilyUnavailable
    case persistenceUnavailable

    var error: SessionControllerError {
        switch self {
        case .temporarilyUnavailable: .temporarilyUnavailable
        case .persistenceUnavailable: .persistenceUnavailable
        }
    }
}

private actor DeleteSyncProbe {
    enum Lookup {
        case absent
        case present(CollectionRemoteEntry)
        case failed
        case cancelled
    }

    enum Failure: Error {
        case expected
        case invalidInput
    }

    struct Evidence: Equatable {
        let deleteCount: Int
        let individualGetCount: Int
        let fullGetCount: Int
        let resolutions: [CollectionDeletionEvidence]
        let blockedItems: [CollectionOutboxUploadWorkItem]
    }

    private let requestAuthorization: SessionRequestAuthorization
    private let deleteFails: Bool
    private let lookup: Lookup
    private let resolutionFailure: CollectionOutboxUploadError?
    private var nextClaim: CollectionOutboxUploadClaim?
    private var deleteCount = 0
    private var individualGetCount = 0
    private var fullGetCount = 0
    private var resolutions: [CollectionDeletionEvidence] = []
    private var blockedItems: [CollectionOutboxUploadWorkItem] = []

    init(
        claim: CollectionOutboxUploadClaim,
        deleteFails: Bool = false,
        lookup: Lookup = .absent,
        resolutionFailure: CollectionOutboxUploadError? = nil
    ) {
        let authority = SessionAuthority(
            userID: CollectionOutboxDeleteSyncTests.workItem.userID,
            generation: UUID(uuidString: "22222222-3333-4444-5555-666666666666")!
        )
        let gate = SessionCommitGate(activeAuthority: authority)
        requestAuthorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "synthetic-access",
            commitAuthorization: gate.authorization(for: authority)
        )
        nextClaim = claim
        self.deleteFails = deleteFails
        self.lookup = lookup
        self.resolutionFailure = resolutionFailure
    }

    func authorization() -> SessionRequestAuthorization { requestAuthorization }

    func validates(_ authorization: SessionRequestAuthorization) -> Bool {
        authorization.authority == requestAuthorization.authority
    }

    func claim(_ authorization: SessionCommitAuthorization) throws -> CollectionOutboxUploadClaim? {
        guard authorization.authority == requestAuthorization.authority else { throw Failure.invalidInput }
        defer { nextClaim = nil }
        return nextClaim
    }

    func delete(_ item: CollectionOutboxUploadWorkItem, accessToken: String) throws {
        guard item == CollectionOutboxDeleteSyncTests.workItem, accessToken == requestAuthorization.accessToken else {
            throw Failure.invalidInput
        }
        deleteCount += 1
        if deleteFails {
            throw Failure.expected
        }
    }

    func fetchFull(accessToken: String) throws -> [CollectionRemoteEntry] {
        guard accessToken == requestAuthorization.accessToken else { throw Failure.invalidInput }
        fullGetCount += 1
        return []
    }

    func fetchIndividual(mangaID: Manga.ID, accessToken: String) throws -> CollectionRemoteEntry? {
        guard mangaID == 42, accessToken == requestAuthorization.accessToken else { throw Failure.invalidInput }
        individualGetCount += 1
        return switch lookup {
        case .absent: nil
        case let .present(entry): entry
        case .failed: throw Failure.expected
        case .cancelled: throw CancellationError()
        }
    }

    func resolve(
        _ item: CollectionOutboxUploadWorkItem,
        evidence: CollectionDeletionEvidence,
        authorization: SessionCommitAuthorization
    ) throws -> CollectionOutboxResolution {
        guard
            item == CollectionOutboxDeleteSyncTests.workItem,
            authorization.authority == requestAuthorization.authority
        else { throw Failure.invalidInput }
        resolutions.append(evidence)
        if let resolutionFailure {
            throw resolutionFailure
        }
        return switch evidence {
        case .absent: .confirmed
        case .present: .blockedOutcome
        }
    }

    func block(_ item: CollectionOutboxUploadWorkItem, authorization: SessionCommitAuthorization) throws {
        guard authorization.authority == requestAuthorization.authority else { throw Failure.invalidInput }
        blockedItems.append(item)
    }

    func evidence() -> Evidence {
        Evidence(
            deleteCount: deleteCount,
            individualGetCount: individualGetCount,
            fullGetCount: fullGetCount,
            resolutions: resolutions,
            blockedItems: blockedItems
        )
    }
}
