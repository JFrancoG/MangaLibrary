//
//  CollectionOutboxRecoveryCoordinatorTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Collection outbox automatic recovery", .tags(.integration))
struct CollectionOutboxRecoveryCoordinatorTests {
    @Test("Backoff follows the persisted attempt count and remains capped", arguments: RetryDelayScenario.allCases)
    private func retryBackoffIsBounded(_ scenario: RetryDelayScenario) async throws(any Error) {
        let authorization = Self.authorization()
        let claimCount = Mutex(0)
        let scheduledDate = Mutex<Date?>(nil)
        let item = Self.workItem(retryCount: scenario.retryCount)
        let coordinator = CollectionOutboxSyncCoordinator(
            authorize: { authorization },
            validateAuthorization: { $0.authority == authorization.authority },
            claimNextUpload: { _, _ in
                claimCount.withLock { count in
                    defer {
                        count += 1
                    }
                    return count == 0 ? .send(item) : nil
                }
            },
            submit: { _, _ in
                throw ProbeFailure.transport
            },
            fetchRemote: { _ in
                throw ProbeFailure.unexpectedEffect
            },
            importRemote: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            confirmUpload: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            scheduleRetry: { scheduledItem, nextRetryAt, _ in
                guard scheduledItem == item else { throw ProbeFailure.invalidInput }
                scheduledDate.withLock {
                    $0 = nextRetryAt
                }
                return .scheduled
            },
            blockUploadOutcome: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            classifySubmissionFailure: { _ in .notSentTransient },
            now: { Self.now }
        )

        try await coordinator.synchronizeAuthenticatedOutbox()

        #expect(scheduledDate.withLock { $0 } == Self.now.addingTimeInterval(scenario.delay))
        #expect(claimCount.withLock { $0 } == 2)
    }

    @Test("A future retry waits, reauthorizes, and sends exactly once after wakeup")
    func dueRetryReauthorizesBeforeSending() async throws(any Error) {
        let authorization = Self.authorization(accessToken: "initial-access")
        let renewedAuthorization = SessionRequestAuthorization(
            authority: authorization.authority,
            accessToken: "renewed-access",
            commitAuthorization: authorization.commitAuthorization
        )
        let authorizationCount = Mutex(0)
        let claimCount = Mutex(0)
        let currentDate = Mutex(Self.now)
        let sleepDurations = Mutex<[TimeInterval]>([])
        let submittedItems = Mutex<[CollectionOutboxUploadWorkItem]>([])
        let submittedTokens = Mutex<[String]>([])
        let confirmedItems = Mutex<[CollectionOutboxUploadWorkItem]>([])
        let dueItem = Self.workItem(retryCount: 1)
        let deadline = Self.now.addingTimeInterval(2)
        let coordinator = CollectionOutboxSyncCoordinator(
            authorize: {
                authorizationCount.withLock { count in
                    defer {
                        count += 1
                    }
                    return count == 0 ? authorization : renewedAuthorization
                }
            },
            validateAuthorization: { $0.authority == authorization.authority },
            claimNextUpload: { _, _ in
                claimCount.withLock { count in
                    defer {
                        count += 1
                    }
                    return switch count {
                    case 0: .waitUntil(deadline)
                    case 1: .send(dueItem)
                    default: nil
                    }
                }
            },
            submit: { item, accessToken in
                submittedItems.withLock {
                    $0.append(item)
                }
                submittedTokens.withLock {
                    $0.append(accessToken)
                }
            },
            fetchRemote: { _ in
                throw ProbeFailure.unexpectedEffect
            },
            importRemote: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            confirmUpload: { item, _ in
                confirmedItems.withLock {
                    $0.append(item)
                }
            },
            blockUploadOutcome: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            now: { currentDate.withLock { $0 } },
            sleep: { delay in
                sleepDurations.withLock {
                    $0.append(delay)
                }
                currentDate.withLock {
                    $0 = deadline
                }
            }
        )

        try await coordinator.synchronizeAuthenticatedOutbox()

        #expect(authorizationCount.withLock { $0 } == 2)
        #expect(sleepDurations.withLock { $0 } == [2])
        #expect(submittedItems.withLock { $0 } == [dueItem])
        #expect(submittedTokens.withLock { $0 } == ["renewed-access"])
        #expect(confirmedItems.withLock { $0 } == [dueItem])
    }

    @Test("A replacement generation after wakeup cannot claim or submit")
    func replacementGenerationAfterWakeupStopsTheFlight() async throws(any Error) {
        let authorization = Self.authorization()
        let replacementAuthorization = Self.authorization(
            generation: UUID(uuidString: "33333333-4444-5555-6666-777777777777")!
        )
        let authorizationCount = Mutex(0)
        let claimCount = Mutex(0)
        let submitCount = Mutex(0)
        let currentDate = Mutex(Self.now)
        let deadline = Self.now.addingTimeInterval(2)
        let coordinator = CollectionOutboxSyncCoordinator(
            authorize: {
                authorizationCount.withLock { count in
                    defer {
                        count += 1
                    }
                    return count == 0 ? authorization : replacementAuthorization
                }
            },
            validateAuthorization: { _ in true },
            claimNextUpload: { _, _ in
                claimCount.withLock {
                    $0 += 1
                }
                return .waitUntil(deadline)
            },
            submit: { _, _ in
                submitCount.withLock {
                    $0 += 1
                }
            },
            fetchRemote: { _ in
                throw ProbeFailure.unexpectedEffect
            },
            importRemote: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            confirmUpload: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            blockUploadOutcome: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            now: { currentDate.withLock { $0 } },
            sleep: { _ in
                currentDate.withLock {
                    $0 = deadline
                }
            }
        )

        await #expect(throws: CollectionOutboxSyncError.sessionChanged) {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }

        #expect(authorizationCount.withLock { $0 } == 2)
        #expect(claimCount.withLock { $0 } == 1)
        #expect(submitCount.withLock { $0 } == 0)
    }

    @Test("Cancelling a retry wait emits no late request")
    func cancellingRetryWaitStopsBeforeReauthorizationAndSubmission() async throws(any Error) {
        let authorization = Self.authorization()
        let authorizationCount = Mutex(0)
        let claimCount = Mutex(0)
        let submitCount = Mutex(0)
        let sleepStarted = Atomic(false)
        let deadline = Self.now.addingTimeInterval(30)
        let coordinator = CollectionOutboxSyncCoordinator(
            authorize: {
                authorizationCount.withLock {
                    $0 += 1
                }
                return authorization
            },
            validateAuthorization: { $0.authority == authorization.authority },
            claimNextUpload: { _, _ in
                claimCount.withLock {
                    $0 += 1
                }
                return .waitUntil(deadline)
            },
            submit: { _, _ in
                submitCount.withLock {
                    $0 += 1
                }
            },
            fetchRemote: { _ in
                throw ProbeFailure.unexpectedEffect
            },
            importRemote: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            confirmUpload: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            blockUploadOutcome: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            now: { Self.now },
            sleep: { _ in
                sleepStarted.store(true, ordering: .releasing)
                while Task.isCancelled == false {
                    await Task.yield()
                }
                throw CancellationError()
            }
        )
        let task = Task {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }
        while sleepStarted.load(ordering: .acquiring) == false {
            await Task.yield()
        }

        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(authorizationCount.withLock { $0 } == 1)
        #expect(claimCount.withLock { $0 } == 1)
        #expect(submitCount.withLock { $0 } == 0)
    }

    @Test("Replacing a flight during backoff preserves and later sends the persisted retry")
    func replacementDuringBackoffPreservesThePersistedRetry() async throws(any Error) {
        let authorization = Self.authorization()
        let expectedItem = Self.workItem(retryCount: 1)
        let deadline = Self.now.addingTimeInterval(30)
        let desiredState = CollectionSnapshot(
            ownedVolumes: expectedItem.ownedVolumes,
            readingVolume: expectedItem.readingVolume,
            isComplete: expectedItem.isComplete,
            knownTotalVolumes: nil,
            isTombstone: expectedItem.isTombstone
        )
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.insert(
            CollectionEntry(
                userID: expectedItem.userID,
                mangaID: expectedItem.mangaID,
                state: desiredState,
                confirmedState: nil
            )
        )
        context.insert(
            CollectionOutboxOperation(
                operationID: expectedItem.operationID,
                userID: expectedItem.userID,
                mangaID: expectedItem.mangaID,
                sequence: expectedItem.sequence,
                desiredState: desiredState,
                state: .retry,
                retryCount: expectedItem.retryCount,
                nextRetryAt: deadline
            )
        )
        try context.save()

        let mutationActor = CollectionMutationActor(modelContainer: container)
        let authorizationCount = Mutex(0)
        let currentDate = Mutex(Self.now)
        let sleepDurations = Mutex<[TimeInterval]>([])
        let sleepCount = Mutex(0)
        let firstSleepStarted = Atomic(false)
        let submittedItems = Mutex<[CollectionOutboxUploadWorkItem]>([])
        let coordinator = CollectionOutboxSyncCoordinator(
            authorize: {
                authorizationCount.withLock {
                    $0 += 1
                }
                return authorization
            },
            validateAuthorization: { $0.authority == authorization.authority },
            claimNextUpload: { commitAuthorization, now in
                try await mutationActor.claimNextUpload(authorization: commitAuthorization, now: now)
            },
            submit: { item, _ in
                submittedItems.withLock {
                    $0.append(item)
                }
            },
            fetchRemote: { _ in
                throw ProbeFailure.unexpectedEffect
            },
            importRemote: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            confirmUpload: { item, commitAuthorization in
                try await mutationActor.confirmUpload(item, authorization: commitAuthorization)
            },
            blockUploadOutcome: { item, commitAuthorization in
                try await mutationActor.blockUploadOutcome(item, authorization: commitAuthorization)
            },
            reactivateBlockedUploads: { commitAuthorization in
                try await mutationActor.reactivateBlockedUploads(authorization: commitAuthorization)
            },
            hasBlockedOutcome: { commitAuthorization in
                try await mutationActor.hasBlockedUploadOutcome(authorization: commitAuthorization)
            },
            now: { currentDate.withLock { $0 } },
            sleep: { delay in
                sleepDurations.withLock {
                    $0.append(delay)
                }
                let invocation = sleepCount.withLock { count in
                    count += 1
                    return count
                }
                if invocation == 1 {
                    firstSleepStarted.store(true, ordering: .releasing)
                    while Task.isCancelled == false {
                        await Task.yield()
                    }
                    throw CancellationError()
                }
                currentDate.withLock {
                    $0 = deadline
                }
            }
        )
        let firstFlight = Task {
            try await coordinator.synchronizeAuthenticatedOutbox()
        }
        while firstSleepStarted.load(ordering: .acquiring) == false {
            await Task.yield()
        }
        #expect(submittedItems.withLock { $0 }.isEmpty)

        try await coordinator.synchronizeAuthenticatedOutbox()

        await #expect(throws: CancellationError.self) {
            try await firstFlight.value
        }
        #expect(authorizationCount.withLock { $0 } == 3)
        #expect(sleepDurations.withLock { $0 } == [30, 30])
        #expect(submittedItems.withLock { $0 } == [expectedItem])
        let operation = try #require(try context.fetch(FetchDescriptor<CollectionOutboxOperation>()).first)
        #expect(operation.state == .confirmed)
        #expect(operation.retryCount == 0)
        #expect(operation.nextRetryAt == nil)
    }

    @Test("A positively classified rejection rolls back without reconciliation or retry")
    func permanentRejectionUsesTheAtomicResolutionPath() async throws(any Error) {
        let authorization = Self.authorization()
        let claimCount = Mutex(0)
        let rejectedItems = Mutex<[CollectionOutboxUploadWorkItem]>([])
        let item = Self.workItem()
        let coordinator = CollectionOutboxSyncCoordinator(
            authorize: { authorization },
            validateAuthorization: { $0.authority == authorization.authority },
            claimNextUpload: { _, _ in
                claimCount.withLock { count in
                    defer {
                        count += 1
                    }
                    return count == 0 ? .send(item) : nil
                }
            },
            submit: { _, _ in
                throw ProbeFailure.transport
            },
            fetchRemote: { _ in
                throw ProbeFailure.unexpectedEffect
            },
            importRemote: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            confirmUpload: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            blockUploadOutcome: { _, _ in
                throw ProbeFailure.unexpectedEffect
            },
            resolvePermanentRejection: { rejectedItem, _ in
                rejectedItems.withLock {
                    $0.append(rejectedItem)
                }
            },
            classifySubmissionFailure: { _ in .permanentlyRejected }
        )

        try await coordinator.synchronizeAuthenticatedOutbox()

        #expect(rejectedItems.withLock { $0 } == [item])
        #expect(claimCount.withLock { $0 } == 2)
    }

    private static func authorization(
        generation: UUID = UUID(uuidString: "22222222-3333-4444-5555-666666666666")!,
        accessToken: String = "synthetic-access"
    ) -> SessionRequestAuthorization {
        let authority = SessionAuthority(
            userID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            generation: generation
        )
        let gate = SessionCommitGate(activeAuthority: authority)
        return SessionRequestAuthorization(
            authority: authority,
            accessToken: accessToken,
            commitAuthorization: gate.authorization(for: authority)
        )
    }

    private static func workItem(retryCount: Int = 0) -> CollectionOutboxUploadWorkItem {
        CollectionOutboxUploadWorkItem(
            operationID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            userID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            mangaID: 42,
            sequence: 3,
            retryCount: retryCount,
            ownedVolumes: [1, 3],
            readingVolume: 2,
            isComplete: false,
            isTombstone: false
        )
    }

    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
}

private enum RetryDelayScenario: CaseIterable, CustomTestStringConvertible {
    case first
    case second
    case third
    case fourth
    case fifth
    case sixth
    case saturated

    var retryCount: Int {
        switch self {
        case .first: 0
        case .second: 1
        case .third: 2
        case .fourth: 3
        case .fifth: 4
        case .sixth: 5
        case .saturated: .max
        }
    }

    var delay: TimeInterval {
        switch self {
        case .first: 1
        case .second: 2
        case .third: 4
        case .fourth: 8
        case .fifth: 16
        case .sixth, .saturated: 30
        }
    }

    var testDescription: String {
        switch self {
        case .first: "retry 1"
        case .second: "retry 2"
        case .third: "retry 3"
        case .fourth: "retry 4"
        case .fifth: "retry 5"
        case .sixth: "retry 6"
        case .saturated: "saturated counter"
        }
    }
}

private enum ProbeFailure: Error {
    case invalidInput
    case transport
    case unexpectedEffect
}
