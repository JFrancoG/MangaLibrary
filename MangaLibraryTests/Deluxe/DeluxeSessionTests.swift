//
//  DeluxeSessionTests.swift
//  MangaLibraryTests
//

import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Deluxe session retirement", .tags(.integration))
struct DeluxeSessionTests {
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

    func makePublisher() -> ReadingSnapshotPublisher {
        ReadingSnapshotPublisher(
            storage: storage,
            now: { clock.value },
            makeGeneration: { UUID() },
            requestReload: { _ in }
        )
    }

    func makeController(
        publisher: ReadingSnapshotPublisher? = nil,
        requireClosedFenceForDeletion: Bool = false,
        hasPendingChanges: Bool = false,
        loginUserID: UUID? = nil,
        restoredUserID: UUID? = nil
    ) throws -> SessionController {
        let baseURL = try #require(URL(string: "https://deluxe-session.example.test"))
        let remote = DeluxeSessionRemote(
            originalUserID: restoredUserID ?? session.userID,
            loginUserID: loginUserID ?? session.userID,
            requestCount: networkRequestCount
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
            logoutPendingChangesObserver: { _ in hasPendingChanges },
            logoutPendingChangesDiscarder: { _ in },
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
    private var didLogin = false

    init(originalUserID: UUID, loginUserID: UUID, requestCount: DeluxeSessionCounter) {
        self.originalUserID = originalUserID
        self.loginUserID = loginUserID
        self.requestCount = requestCount
    }

    func load(_ request: URLRequest) throws -> Data {
        requestCount.increment()
        switch request.url?.path {
        case "/users/jwt/login":
            didLogin = true
            return Data(#"{"token":"fixture-deluxe-replacement","tokenType":"Bearer","expiresIn":3600}"#.utf8)
        case "/users/jwt/me":
            let userID = didLogin ? loginUserID : originalUserID
            return Data(
                #"{"id":"\#(userID.uuidString)","email":"reader@example.invalid","isActive":true,"isAdmin":false,"role":"user"}"#.utf8
            )
        default:
            throw SessionAPIClientError.contractDrift
        }
    }
}
