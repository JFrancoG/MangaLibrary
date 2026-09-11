//
//  DeluxeSessionTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Deluxe session retirement", .tags(.integration))
struct DeluxeSessionTests {
    @Test(arguments: RecoverySession.allCases, [false, true])
    func `pending widget recovery cannot send watch content before session restoration`(
        sessionState: RecoverySession,
        empty: Bool
    ) async throws {
        let fixture = try DeluxeSessionFixture()
        defer {
            fixture.removeDirectory()
        }
        let initial = fixture.makePublisher(requestReload: { _ in
            throw ReadingSnapshotStorageError.unavailable
        })
        let owner = try fixture.makeController(publisher: initial)
        _ = try await owner.restore()
        let authorization = try #require(try await owner.commitAuthorization(for: fixture.session.authority))
        let item = try ReadingSnapshot.Item(
            mangaID: 42,
            title: "Persisted reading",
            readingVolume: 2,
            totalVolumes: 3,
            coverResourceID: nil
        )
        _ = try await initial.publish(
            items: empty ? [] : [item],
            totalEligibleCount: empty ? 0 : 1,
            authorization: authorization
        )
        switch sessionState {
        case .absent:
            try fixture.keychain.operations().removeAll()
        case .expired:
            fixture.clock.advance(by: 3_601)
        case .inaccessible:
            fixture.keychain.failNext(.load, with: .temporarilyUnavailable)
        case .valid:
            break
        }
        let contexts = Mutex<[Data]>([])
        let reloads = Mutex(0)
        let relaunchedPublisher = fixture.makePublisher(
            requestReload: { _ in
                reloads.withLock {
                    $0 += 1
                }
            },
            sendWatchContext: { data in
                contexts.withLock {
                    $0.append(data)
                }
            }
        )
        let relaunched = try fixture.makeController(publisher: relaunchedPublisher)
        if sessionState == .inaccessible {
            await #expect(throws: SessionControllerError.temporarilyUnavailable) {
                try await relaunched.restore()
            }
        } else {
            let result = try await relaunched.restore()
            switch sessionState {
            case .absent:
                #expect(result == .signedOut)
            case .expired:
                #expect(result == .authenticationRequired(fixture.session.userID))
            case .valid:
                #expect(result == .active(fixture.account))
            case .inaccessible:
                Issue.record("An inaccessible session must fail restoration.")
            }
        }
        let snapshots = try contexts.withLock { try $0.map(ReadingSnapshotCodec.decode) }
        #expect(snapshots.allSatisfy { $0.state == .redacted })
        #expect(reloads.withLock { $0 } >= 1)
        if sessionState == .valid {
            let before = try fixture.storage.read(.snapshot)
            try await relaunched.deliverWatchContext { data in
                contexts.withLock {
                    $0.append(data)
                }
            }
            let delivered = try #require(contexts.withLock { $0.last })
            let snapshot = try ReadingSnapshotCodec.decode(delivered)
            #expect(snapshot.state == (empty ? .empty : .content))
            #expect(snapshot.items.map(\.mangaID) == (empty ? [] : [42]))
            #expect(snapshot.items.map(\.readingVolume) == (empty ? [] : [2]))
            #expect(try fixture.storage.read(.snapshot) == before)
        }
    }

    enum RecoverySession: CaseIterable {
        case absent, expired, inaccessible, valid
    }

    @Test(arguments: [false, true])
    func `watch activation revalidates local expiry before offering the persisted context`(expired: Bool) async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController(requireClosedFenceForDeletion: true)
        try await fixture.restoreAndPublishEmpty(using: controller)
        if expired {
            fixture.clock.advance(by: 3_601)
        }
        let contexts = Mutex<[Data]>([])

        try await controller.deliverWatchContext { data in
            contexts.withLock { $0.append(data) }
        }

        let bytes = try #require(contexts.withLock { $0.last })
        let snapshot = try ReadingSnapshotCodec.decode(bytes)
        #expect(snapshot.state == (expired ? .redacted : .empty))
        #expect((fixture.keychain.snapshot().record == nil) == expired)
    }

    @Test
    func `watch activation cannot resend a prior launch before the session owner restores it`() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController()
        try await fixture.restoreAndPublishEmpty(using: controller)
        let contexts = Mutex<[Data]>([])
        try await controller.deliverWatchContext { data in
            contexts.withLock { $0.append(data) }
        }
        try #require(contexts.withLock { $0.count } == 1)
        contexts.withLock { $0.removeAll() }

        let relaunched = try fixture.makeController()
        try await relaunched.deliverWatchContext { data in
            contexts.withLock { $0.append(data) }
        }

        #expect(contexts.withLock { $0.isEmpty })
        #expect(fixture.keychain.snapshot().record == fixture.session)
    }

    @Test
    func `an unreachable watch does not block logout and its next attempt sends the retirement`() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let attempts = Mutex<[Data]>([])
        let publisher = ReadingSnapshotPublisher(
            storage: fixture.storage,
            now: { fixture.clock.value },
            makeGeneration: { UUID() },
            requestReload: { _ in },
            sendWatchContext: { data in
                attempts.withLock { $0.append(data) }
                throw WatchReadingConnectivityError.deliveryFailed
            }
        )
        let controller = try fixture.makeController(publisher: publisher, requireClosedFenceForDeletion: true)
        try await fixture.restoreAndPublishEmpty(using: controller)

        #expect(try await controller.logout() == .signedOut)

        #expect(fixture.keychain.snapshot().record == nil)
        let attempted = try #require(attempts.withLock { $0.last })
        #expect(try ReadingSnapshotCodec.decode(attempted).state == .redacted)
        let delivered = Mutex<[Data]>([])
        try await controller.deliverWatchContext { data in
            delivered.withLock { $0.append(data) }
        }
        let retried = try #require(delivered.withLock { $0.last })
        #expect(try ReadingSnapshotCodec.decode(retried).state == .redacted)
    }

    @Test(arguments: [false, true], [false, true])
    func `expiry during cover loading retires the old manifest and a failed close remains retryable`(
        failClose: Bool,
        cancel: Bool
    ) async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let composition = try fixture.makeReadingComposition(withCover: true)
        let controller = try fixture.makeController(readingEvents: composition.events)
        _ = try await controller.restore()
        let initial = try #require(composition.events.currentEvent())
        let projection = try await composition.mutations.readingProjection(authorization: initial.authorization)
        _ = try await fixture.publisher.publish(
            projection: projection,
            preparedCovers: [:],
            authorization: initial.authorization,
            ticket: initial.ticket
        )
        let pipeline = ReadingPublicationPipeline(
            events: composition.events,
            mutations: composition.mutations,
            publisher: fixture.publisher,
            loadCover: { _ in
                fixture.clock.advance(by: 3_601)
                if failClose {
                    fixture.faults.failNextFenceReplacement()
                }
                if cancel {
                    // A loader can finish with cancellation after the credential has expired.
                    throw CancellationError()
                }
                return nil
            },
            reconcileSession: { authority in
                try await controller.reconcileReadingAuthorization(for: authority)
            }
        )

        if failClose {
            await #expect(throws: ReadingPublicationSessionReconciliationError.self) {
                try await pipeline.process(initial)
            }
            #expect(fixture.keychain.snapshot().record == fixture.session)
            #expect(await controller.currentSnapshot() == .authenticationRequired(fixture.session.userID))
            // Retry the rejected intent before loading again: it must complete the captured retirement.
            await #expect(throws: SessionCommitAuthorizationError.self) {
                try await pipeline.process(initial)
            }
        } else if cancel {
            await #expect(throws: CancellationError.self) {
                try await pipeline.process(initial)
            }
        } else {
            await #expect(throws: SessionCommitAuthorizationError.self) {
                try await pipeline.process(initial)
            }
        }

        #expect(fixture.keychain.snapshot().record == nil)
        #expect(await controller.currentSnapshot() == .authenticationRequired(fixture.session.userID))
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)
        let bytes = try #require(try fixture.storage.read(.snapshot))
        #expect(try ReadingSnapshotCodec.decode(bytes).state == .redacted)
    }

    @Test(arguments: [false, true])
    func `restoration publishes persisted reading even when identity is offline`(offline: Bool) async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let composition = try fixture.makeReadingComposition()
        let controller = try fixture.makeController(
            publisher: composition.publisher,
            readingEvents: composition.events,
            identityUnavailable: offline
        )

        let pipeline = composition.makePipeline(sessionController: controller)
        _ = try await controller.restore()
        let event = try #require(composition.events.currentEvent())
        let result = try #require(try await pipeline.process(event))

        #expect(result.sessionGeneration == fixture.session.generation)
        #expect(result.items.map(\.readingVolume) == [1])
        #expect(result.items.map(\.mangaID) == [42])
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == result)
        #expect(fixture.keychain.snapshot().record == fixture.session)
    }

    @Test
    func `refresh creates a fresh reading capability and preserves an identical manifest`() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let events = ReadingPublicationEvents()
        let controller = try fixture.makeController(readingEvents: events)
        _ = try await controller.restore()
        let original = try #require(events.currentEvent())
        let projection = CollectionReadingProjection(authority: fixture.session.authority, items: [])
        _ = try await fixture.publisher.publish(
            projection: projection,
            preparedCovers: [:],
            authorization: original.authorization,
            ticket: original.ticket
        )
        let previous = try fixture.storage.read(.snapshot)
        fixture.clock.advance(by: 3_301)

        _ = try await controller.accessCredential()

        let renewed = try #require(events.currentEvent())
        #expect(throws: SessionCommitAuthorizationError.self) {
            try original.authorization.perform {}
        }
        #expect(throws: ReadingPublicationError.self) {
            try original.ticket.validate(authority: fixture.session.authority)
        }
        let result = try await fixture.publisher.publish(
            projection: projection,
            preparedCovers: [:],
            authorization: renewed.authorization,
            ticket: renewed.ticket
        )
        #expect(result == nil)
        #expect(try fixture.storage.read(.snapshot) == previous)
        #expect(fixture.keychain.snapshot().record?.access.value == "fixture-deluxe-renewed")
    }

    @Test
    func `replacement login can publish its collection and cannot reuse the outgoing intent`() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let composition = try fixture.makeReadingComposition()
        let userB = UUID()
        let controller = try fixture.makeController(
            publisher: composition.publisher,
            loginUserID: userB,
            readingEvents: composition.events
        )
        let pipeline = composition.makePipeline(sessionController: controller)
        _ = try await controller.restore()
        let outgoing = try #require(composition.events.currentEvent())
        _ = try await pipeline.process(outgoing)
        _ = try await controller.logout()

        _ = try await controller.login(email: "b@example.invalid", password: "fixture-password-b")

        let replacement = try #require(composition.events.currentEvent())
        await #expect(throws: (any Error).self) {
            try await pipeline.process(outgoing)
        }
        let result = try #require(try await pipeline.process(replacement))
        #expect(replacement.authorization.authority.userID == userB)
        #expect(result.state == .empty)
        #expect(result.items.isEmpty)
        #expect(result.sessionGeneration != fixture.session.generation)
    }

    @Test
    func `failed logout after discarding local reading republishes the committed remote baseline`() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let composition = try fixture.makeReadingComposition()
        let controller = try fixture.makeController(
            hasPendingChanges: true,
            readingEvents: composition.events,
            discardPendingChanges: { authorization in
                try await composition.mutations.discardPendingChangesForLogout(authorization: authorization)
            }
        )
        let pipeline = ReadingPublicationPipeline(
            events: composition.events,
            mutations: composition.mutations,
            publisher: fixture.publisher,
            loadCover: { _ in nil },
            reconcileSession: { authority in
                try await controller.reconcileReadingAuthorization(for: authority)
            }
        )
        _ = try await controller.restore()
        let restored = try #require(composition.events.currentEvent())
        _ = try await composition.mutations.apply(
            CollectionMutationCommand(
                authority: fixture.session.authority,
                mangaID: 42,
                knownTotalVolumes: 3,
                change: .setReadingVolume(2)
            ),
            authorization: restored.authorization
        )
        let local = try #require(composition.events.currentEvent())
        #expect(try await pipeline.process(local)?.items.first?.readingVolume == 2)
        fixture.faults.failNextFenceReplacement()

        await #expect(throws: SessionControllerError.persistenceUnavailable) {
            try await controller.logout(discardPendingChanges: true)
        }

        let resumed = try #require(composition.events.currentEvent())
        let result = try #require(try await pipeline.process(resumed))
        #expect(result.items.first?.readingVolume == 1)
        // The failed retirement consumed revision 2 before its fence replacement failed.
        #expect(result.revision == 3)
        #expect(throws: SessionCommitAuthorizationError.self) {
            try local.authorization.perform {}
        }
        #expect(throws: ReadingPublicationError.self) {
            try local.ticket.validate(authority: fixture.session.authority)
        }
        #expect(await controller.currentSnapshot() == .active(fixture.account))
    }

    @Test("A new closed bridge does not retire the existing Advanced session")
    func bootstrapRequiresExplicitPublicationAuthorization() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController()

        let snapshot = try await controller.restore()

        #expect(snapshot == .active(fixture.account))
        #expect(fixture.keychain.snapshot().record == fixture.session)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)
        let authorization = try #require(try await controller.commitAuthorization(for: fixture.session.authority))
        _ = try await fixture.publisher.publish(items: [], totalEligibleCount: 0, authorization: authorization)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read()?.state == .empty)
    }

    @Test("A missing or corrupt Keychain authority closes previously published content", arguments: [false, true])
    func signedOutRestorationRetiresThePreviouslyOpenBridge(corruptKeychain: Bool) async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController()
        try await fixture.restoreAndPublishEmpty(using: controller)
        if corruptKeychain {
            fixture.keychain.failNext(.load, with: .corruptSessionRecord)
        } else {
            try fixture.keychain.operations().removeAll()
        }

        let relaunched = try fixture.makeController(publisher: fixture.makePublisher())

        #expect(try await relaunched.restore() == .signedOut)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)
        #expect(fixture.keychain.snapshot().record == nil)
        #expect(fixture.networkRequestCount.value == 1)
    }

    @Test("Logout verifies the shared closed fence before deleting Keychain")
    func logoutOrdersFenceBeforeKeychain() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController(requireClosedFenceForDeletion: true)
        try await fixture.restoreAndPublishEmpty(using: controller)

        #expect(try await controller.logout() == .signedOut)

        #expect(fixture.keychain.snapshot().record == nil)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)
        #expect(try await fixture.publisher.pendingRetirement() == nil)
    }

    @Test("A fence write failure aborts logout before Keychain and preserves the valid session")
    func failedFencePreservesSessionAndCredentials() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController()
        try await fixture.restoreAndPublishEmpty(using: controller)
        fixture.faults.failNextFenceReplacement()

        await #expect(throws: SessionControllerError.persistenceUnavailable) {
            try await controller.logout()
        }

        #expect(await controller.currentSnapshot() == .active(fixture.account))
        #expect(fixture.keychain.snapshot().record == fixture.session)
        #expect(fixture.keychain.snapshot().journal.contains(.removeAll) == false)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read()?.state == .empty)
        #expect(try await controller.commitAuthorization(for: fixture.session.authority) != nil)
    }

    @Test("A failed fence verification never starts Keychain deletion and remains retryable")
    func failedFenceVerificationPreservesCredentials() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController()
        try await fixture.restoreAndPublishEmpty(using: controller)
        fixture.faults.failNextClosedFenceRead()

        await #expect(throws: SessionControllerError.persistenceUnavailable) {
            try await controller.logout()
        }

        #expect(fixture.keychain.snapshot().record == fixture.session)
        #expect(fixture.keychain.snapshot().journal.contains(.removeAll) == false)
        #expect(await controller.currentSnapshot() == .active(fixture.account))
        #expect(try await controller.logout() == .signedOut)
    }

    @Test("A committed fence prevents session restoration after Keychain deletion failed")
    func interruptedRetirementCannotRestoreTheOutgoingGeneration() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController()
        try await fixture.restoreAndPublishEmpty(using: controller)
        fixture.keychain.failNext(.removeAll, with: .temporarilyUnavailable)

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.logout()
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(fixture.session.userID))
        #expect(try await controller.commitAuthorization(for: fixture.session.authority) == nil)
        #expect(fixture.keychain.snapshot().record == fixture.session)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)

        let relaunchedPublisher = fixture.makePublisher()
        let relaunched = try fixture.makeController(publisher: relaunchedPublisher)
        #expect(try await relaunched.restore() == .signedOut)
        #expect(fixture.keychain.snapshot().record == nil)
        #expect(fixture.networkRequestCount.value == 1)
        #expect(try await relaunchedPublisher.pendingRetirement() == nil)
    }

    @Test("A closed fence with corrupt publisher intent cannot restore residual Keychain credentials")
    func corruptRetirementIntentRemainsFailClosed() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController()
        try await fixture.restoreAndPublishEmpty(using: controller)
        fixture.keychain.failNext(.removeAll, with: .temporarilyUnavailable)
        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.logout()
        }
        try fixture.storage.replace(.publisherState, Data("interrupted-write".utf8))

        let relaunched = try fixture.makeController(publisher: fixture.makePublisher())

        #expect(try await relaunched.restore() == .signedOut)
        #expect(fixture.keychain.snapshot().record == nil)
        #expect(fixture.networkRequestCount.value == 1)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)
    }

    @Test("A failed committed retirement remains retryable without reopening the outgoing session")
    func logoutRetriesOnlyTheCommittedRetirement() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController()
        try await fixture.restoreAndPublishEmpty(using: controller)
        fixture.keychain.failNext(.removeAll, with: .temporarilyUnavailable)

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.logout()
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(fixture.session.userID))
        #expect(try await controller.commitAuthorization(for: fixture.session.authority) == nil)
        let closedFence = try #require(try fixture.storage.read(.fence))
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)
        #expect(try await controller.logout() == .signedOut)

        #expect(fixture.keychain.snapshot().record == nil)
        #expect(try fixture.storage.read(.fence) == closedFence)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)
        #expect(fixture.networkRequestCount.value == 1)
    }

    @Test("Signing in as B completes A's committed retirement before activating the replacement")
    func replacementLoginCannotInheritTheRetiredBridge() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let userB = try #require(UUID(uuidString: "BBBBBBBB-1111-2222-3333-444444444444"))
        let controller = try fixture.makeController(loginUserID: userB)
        try await fixture.restoreAndPublishEmpty(using: controller)
        fixture.keychain.failNext(.removeAll, with: .temporarilyUnavailable)
        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.logout()
        }

        let snapshot = try await controller.login(email: "b@example.invalid", password: "fixture-password-b")

        guard case let .active(accountB) = snapshot else {
            Issue.record("The replacement login did not become active")
            return
        }
        #expect(accountB.id == userB)
        #expect(accountB.authority.generation != fixture.session.generation)
        #expect(fixture.keychain.snapshot().record?.authority == accountB.authority)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)
        #expect(try await controller.commitAuthorization(for: fixture.session.authority) == nil)
        let authorization = try #require(try await controller.commitAuthorization(for: accountB.authority))
        _ = try await fixture.publisher.publish(items: [], totalEligibleCount: 0, authorization: authorization)
        let published = try ReadingSnapshotReader(storage: fixture.storage).read()
        #expect(published?.sessionGeneration == accountB.authority.generation)
    }

    @Test("B can sign out before publishing when A's eventual redaction could not be written")
    func replacementLogoutDoesNotDependOnRetiredRedaction() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let userB = try #require(UUID(uuidString: "BBBBBBBB-1111-2222-3333-444444444444"))
        let controller = try fixture.makeController(loginUserID: userB)
        try await fixture.restoreAndPublishEmpty(using: controller)
        fixture.faults.failNextSnapshotReplacement()
        #expect(try await controller.logout() == .signedOut)
        _ = try await controller.login(email: "b@example.invalid", password: "fixture-password-b")

        #expect(try await controller.logout() == .signedOut)

        #expect(fixture.keychain.snapshot().record == nil)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)
    }

    @Test("A crash retiring B preserves its durable retirement and the pending redaction recipient A")
    func replacementRetirementRecoversBWithoutLosingRedactionA() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let userB = try #require(UUID(uuidString: "BBBBBBBB-1111-2222-3333-444444444444"))
        let controller = try fixture.makeController(loginUserID: userB)
        try await fixture.restoreAndPublishEmpty(using: controller)
        fixture.faults.failNextSnapshotReplacement()
        #expect(try await controller.logout() == .signedOut)
        _ = try await controller.login(email: "b@example.invalid", password: "fixture-password-b")
        let sessionB = try #require(fixture.keychain.snapshot().record)
        fixture.keychain.failNext(.removeAll, with: .temporarilyUnavailable)

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.logout()
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(userB))
        #expect(fixture.keychain.snapshot().record == sessionB)

        let relaunched = try fixture.makeController(publisher: fixture.makePublisher())
        #expect(try await relaunched.restore() == .signedOut)
        #expect(fixture.keychain.snapshot().record == nil)
        #expect(fixture.networkRequestCount.value == 3)
        let data = try #require(try fixture.storage.read(.snapshot))
        let redaction = try ReadingSnapshotCodec.decode(data)
        #expect(redaction.state == .redacted)
        #expect(redaction.sessionGeneration == fixture.session.generation)
    }

    @Test("A failed fence replacement for B restores its predecessor without retiring B")
    func interruptedReplacementBeforeFenceKeepsBAuthenticated() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let userB = try #require(UUID(uuidString: "BBBBBBBB-1111-2222-3333-444444444444"))
        let controller = try fixture.makeController(loginUserID: userB)
        try await fixture.restoreAndPublishEmpty(using: controller)
        fixture.faults.failNextSnapshotReplacement()
        #expect(try await controller.logout() == .signedOut)
        let login = try await controller.login(email: "b@example.invalid", password: "fixture-password-b")
        guard case let .active(accountB) = login else {
            Issue.record("The replacement login did not become active")
            return
        }
        let sessionB = try #require(fixture.keychain.snapshot().record)
        let previousFence = try #require(try fixture.storage.read(.fence))
        fixture.faults.failNextFenceReplacement()

        await #expect(throws: SessionControllerError.persistenceUnavailable) {
            try await controller.logout()
        }
        #expect(await controller.currentSnapshot() == .active(accountB))
        #expect(fixture.keychain.snapshot().record == sessionB)
        #expect(try fixture.storage.read(.fence) == previousFence)

        let relaunched = try fixture.makeController(publisher: fixture.makePublisher(), restoredUserID: userB)
        #expect(try await relaunched.restore() == .active(accountB))
        #expect(fixture.keychain.snapshot().record == sessionB)
        #expect(fixture.networkRequestCount.value == 4)
        let data = try #require(try fixture.storage.read(.snapshot))
        let redaction = try ReadingSnapshotCodec.decode(data)
        #expect(redaction.state == .redacted)
        #expect(redaction.sessionGeneration == fixture.session.generation)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)
    }

    @Test("Cancellation after reading back the closed fence cannot stop Keychain retirement")
    func cancellationAfterFenceCommitCompletesLogout() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController(requireClosedFenceForDeletion: true)
        try await fixture.restoreAndPublishEmpty(using: controller)
        fixture.faults.cancelAfterNextClosedFenceRead()

        let logout = Task {
            try await controller.logout()
        }
        #expect(try await logout.value == .signedOut)

        #expect(logout.isCancelled)
        #expect(fixture.keychain.snapshot().record == nil)
        #expect(await controller.currentSnapshot() == .signedOut)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)
    }

    @Test("Credential expiry closes the bridge before removing its Keychain authority")
    func expiryRetiresBothAuthoritiesInOrder() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController(requireClosedFenceForDeletion: true)
        try await fixture.restoreAndPublishEmpty(using: controller)
        fixture.clock.advance(by: 3_601)

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await controller.requestAuthorization()
        }

        #expect(await controller.currentSnapshot() == .authenticationRequired(fixture.session.userID))
        #expect(fixture.keychain.snapshot().record == nil)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)
        #expect(fixture.networkRequestCount.value == 1)
    }

    @Test("A failed invalidation fence keeps Keychain without reauthorizing the expired session")
    func invalidationFenceFailureRemainsFailClosedAndRetryable() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController()
        try await fixture.restoreAndPublishEmpty(using: controller)
        fixture.clock.advance(by: 3_601)
        fixture.faults.failNextFenceReplacement()

        await #expect(throws: SessionControllerError.persistenceUnavailable) {
            try await controller.requestAuthorization()
        }

        #expect(await controller.currentSnapshot() == .authenticationRequired(fixture.session.userID))
        #expect(try await controller.commitAuthorization(for: fixture.session.authority) == nil)
        #expect(fixture.keychain.snapshot().record == fixture.session)
        #expect(fixture.keychain.snapshot().journal.contains(.removeAll) == false)
        #expect(try await controller.restore() == .authenticationRequired(fixture.session.userID))
        #expect(fixture.keychain.snapshot().record == nil)
        #expect(try ReadingSnapshotReader(storage: fixture.storage).read() == nil)
    }

    @Test("Pending Collection work leaves the existing bridge untouched")
    func pendingWorkAbortsBeforeClosingTheFence() async throws {
        let fixture = try DeluxeSessionFixture()
        defer { fixture.removeDirectory() }
        let controller = try fixture.makeController(hasPendingChanges: true)
        try await fixture.restoreAndPublishEmpty(using: controller)
        let originalFence = try #require(try fixture.storage.read(.fence))

        await #expect(throws: SessionControllerError.pendingCollectionChanges) {
            try await controller.logout()
        }

        #expect(try fixture.storage.read(.fence) == originalFence)
        #expect(await controller.currentSnapshot() == .active(fixture.account))
        #expect(fixture.keychain.snapshot().record == fixture.session)
    }
}

private struct DeluxeSessionFixture {
    let directory: URL
    let storage: ReadingSnapshotStorage
    let publisher: ReadingSnapshotPublisher
    let faults: DeluxeSessionFileFaults
    let keychain: ControlledSessionPersistenceStorage
    let session: SessionPersistedSession
    let account: SessionAccount
    let clock: DeluxeSessionClock
    let networkRequestCount = DeluxeSessionCounter()

    func makePublisher(
        requestReload: @escaping @Sendable (Data) throws -> Void = { _ in },
        sendWatchContext: @escaping @Sendable (Data) throws -> Void = { _ in }
    ) -> ReadingSnapshotPublisher {
        ReadingSnapshotPublisher(
            storage: storage,
            now: { clock.value },
            makeGeneration: { UUID() },
            requestReload: requestReload,
            sendWatchContext: sendWatchContext
        )
    }

    func makeController(
        publisher: ReadingSnapshotPublisher? = nil,
        requireClosedFenceForDeletion: Bool = false,
        hasPendingChanges: Bool = false,
        loginUserID: UUID? = nil,
        restoredUserID: UUID? = nil,
        readingEvents: ReadingPublicationEvents? = nil,
        identityUnavailable: Bool = false,
        discardPendingChanges: @escaping SessionController.LogoutPendingChangesDiscarder = { _ in }
    ) throws -> SessionController {
        let baseURL = try #require(URL(string: "https://deluxe-session.example.test"))
        let remote = DeluxeSessionRemote(
            originalUserID: restoredUserID ?? session.userID,
            loginUserID: loginUserID ?? session.userID,
            requestCount: networkRequestCount,
            identityUnavailable: identityUnavailable
        )
        let client = SessionAPIClient(
            configuration: try APIConfiguration(baseURL: baseURL),
            loadData: {
                try await remote.load($0)
            },
            now: { clock.value }
        )
        let operations = keychain.operations()
        let persistence = SessionPersistenceActor(
            operations: SessionPersistenceActor.Operations(
                load: operations.load,
                save: operations.save,
                removeLegacy: operations.removeLegacy,
                removeAll: {
                    if requireClosedFenceForDeletion {
                        let data = try #require(try storage.read(.fence))
                        let fence = try JSONDecoder().decode(SessionFence.self, from: data)
                        guard fence.allowedSessionGeneration == nil else {
                            throw DeluxeSessionFixtureError.unsafeKeychainDeletion
                        }
                    }
                    try operations.removeAll()
                }
            )
        )
        return SessionController(
            apiClient: client,
            persistence: persistence,
            now: { clock.value },
            makeGeneration: { UUID() },
            deluxePublisher: publisher ?? self.publisher,
            readingEvents: readingEvents,
            logoutPendingChangesObserver: { _ in hasPendingChanges },
            logoutPendingChangesDiscarder: discardPendingChanges,
            authenticationInvalidationObserver: { _ in }
        )
    }

    func restoreAndPublishEmpty(using controller: SessionController) async throws {
        _ = try await controller.restore()
        let authorization = try #require(try await controller.commitAuthorization(for: session.authority))
        _ = try await publisher.publish(items: [], totalEligibleCount: 0, authorization: authorization)
    }

    func removeDirectory() {
        try? FileManager.default.removeItem(at: directory)
    }

    func makeReadingComposition(withCover: Bool = false) throws -> ReadingPublicationComposition {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let baseline = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: 1,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        context.insert(CollectionEntry(
            userID: session.userID,
            mangaID: 42,
            state: baseline,
            confirmedState: baseline,
            mangaSnapshot: withCover ? readingPresentation() : nil
        ))
        try context.save()
        return try AppComposition.makeReadingPublication(
            modelContainer: container,
            sharedDirectory: directory.appending(path: "shared"),
            publisherDirectory: directory.appending(path: "publisher"),
            now: { clock.value },
            makeGeneration: { UUID() },
            loadCover: { _ in throw DeluxeSessionFixtureError.unexpectedCoverRequest },
            requestReload: { _ in }
        )
    }

    private func readingPresentation() -> CollectionMangaSnapshot {
        CollectionMangaSnapshot(
            mangaID: 42,
            title: "Persisted reading",
            titleEnglish: nil,
            titleJapanese: nil,
            synopsis: nil,
            score: 0,
            status: .unspecified,
            authors: [],
            demographics: [],
            genres: [],
            themes: [],
            coverURL: URL(string: "https://covers.example.invalid/42.jpg")
        )
    }
}

private extension DeluxeSessionFixture {
    init() throws {
        let userID = try #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        let generation = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let directory = FileManager.default.temporaryDirectory.appending(path: "DeluxeSession-\(UUID())")
        let disk = try ReadingSnapshotStorage(directory: directory)
        let faults = DeluxeSessionFileFaults()
        let clock = DeluxeSessionClock(now: now)
        let storage = ReadingSnapshotStorage(
            read: { file in
                let data = try disk.read(file)
                try faults.didRead(file, data: data)
                return data
            },
            replace: { file, data in
                try faults.willReplace(file)
                try disk.replace(file, data)
            }
        )
        let session = try SessionPersistedSession(
            userID: userID,
            generation: generation,
            access: SessionCredential(value: "fixture-deluxe-access", expiresAt: now.addingTimeInterval(3_600))
        )
        self.directory = directory
        self.storage = storage
        self.faults = faults
        self.clock = clock
        self.session = session
        keychain = ControlledSessionPersistenceStorage(record: session)
        account = SessionAccount(
            authority: session.authority,
            id: userID,
            email: "reader@example.invalid",
            isActive: true,
            isAdmin: false,
            role: "user"
        )
        publisher = ReadingSnapshotPublisher(
            storage: storage,
            now: { clock.value },
            makeGeneration: { UUID() },
            requestReload: { _ in }
        )
    }

}

private enum DeluxeSessionFixtureError: Error {
    case fileUnavailable
    case unsafeKeychainDeletion
    case unexpectedCoverRequest
}

private final class DeluxeSessionFileFaults: Sendable {
    private struct State {
        var failFenceReplacement = false
        var failSnapshotReplacement = false
        var failClosedFenceRead = false
        var cancelAfterClosedFenceRead = false
    }

    private let state = Mutex(State())

    func failNextFenceReplacement() {
        state.withLock {
            $0.failFenceReplacement = true
        }
    }

    func failNextSnapshotReplacement() {
        state.withLock {
            $0.failSnapshotReplacement = true
        }
    }

    func cancelAfterNextClosedFenceRead() {
        state.withLock {
            $0.cancelAfterClosedFenceRead = true
        }
    }

    func failNextClosedFenceRead() {
        state.withLock {
            $0.failClosedFenceRead = true
        }
    }

    func willReplace(_ file: ReadingSnapshotStorage.File) throws {
        try state.withLock { state in
            if file == .fence, state.failFenceReplacement {
                state.failFenceReplacement = false
                throw DeluxeSessionFixtureError.fileUnavailable
            }
            if file == .snapshot, state.failSnapshotReplacement {
                state.failSnapshotReplacement = false
                throw DeluxeSessionFixtureError.fileUnavailable
            }
        }
    }

    func didRead(_ file: ReadingSnapshotStorage.File, data: Data?) throws {
        guard file == .fence, let data else { return }
        let fence = try JSONDecoder().decode(SessionFence.self, from: data)
        guard fence.allowedSessionGeneration == nil else { return }
        let shouldCancel = try state.withLock { state in
            if state.failClosedFenceRead {
                state.failClosedFenceRead = false
                throw DeluxeSessionFixtureError.fileUnavailable
            }
            let shouldCancel = state.cancelAfterClosedFenceRead
            state.cancelAfterClosedFenceRead = false
            return shouldCancel
        }
        if shouldCancel {
            withUnsafeCurrentTask {
                $0?.cancel()
            }
        }
    }
}

private final class DeluxeSessionClock: Sendable {
    private let now: Mutex<Date>

    var value: Date { now.withLock { $0 } }

    init(now: Date) {
        self.now = Mutex(now)
    }

    func advance(by interval: TimeInterval) {
        now.withLock {
            $0 = $0.addingTimeInterval(interval)
        }
    }
}

private final class DeluxeSessionCounter: Sendable {
    private let count = Mutex(0)

    var value: Int { count.withLock { $0 } }

    func increment() {
        count.withLock {
            $0 += 1
        }
    }
}

private actor DeluxeSessionRemote {
    private let originalUserID: UUID
    private let loginUserID: UUID
    private let requestCount: DeluxeSessionCounter
    private let identityUnavailable: Bool
    private var didLogin = false

    init(
        originalUserID: UUID,
        loginUserID: UUID,
        requestCount: DeluxeSessionCounter,
        identityUnavailable: Bool
    ) {
        self.originalUserID = originalUserID
        self.loginUserID = loginUserID
        self.requestCount = requestCount
        self.identityUnavailable = identityUnavailable
    }

    func load(_ request: URLRequest) throws -> Data {
        requestCount.increment()
        switch request.url?.path {
        case "/users/jwt/login":
            didLogin = true
            return Data(#"{"token":"fixture-deluxe-replacement","tokenType":"Bearer","expiresIn":3600}"#.utf8)
        case "/users/jwt/me":
            if identityUnavailable {
                throw SessionAPIClientError.unavailable
            }
            let userID = didLogin ? loginUserID : originalUserID
            return Data(
                #"{"id":"\#(userID.uuidString)","email":"reader@example.invalid","isActive":true,"isAdmin":false,"role":"user"}"#.utf8
            )
        case "/users/jwt/refresh":
            return Data(#"{"token":"fixture-deluxe-renewed","tokenType":"Bearer","expiresIn":3600}"#.utf8)
        default:
            throw SessionAPIClientError.contractDrift
        }
    }
}
