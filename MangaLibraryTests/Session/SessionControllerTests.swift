//
//  SessionControllerTests.swift
//  MangaLibraryTests
//

import Foundation
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Session controller", .tags(.fast))
struct SessionControllerTests {
    @Test("Login completes the remote chain before activating durable identity")
    func loginActivatesOnlyAfterIdentity() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.refreshResponse),
                .data(Self.accessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage
        )
        #expect(try await controller.restore() == .signedOut)

        let snapshot = try await controller.login(
            email: "reader@example.invalid",
            password: "synthetic-passphrase"
        )

        #expect(
            snapshot
                == .active(Self.remoteAccount)
        )
        #expect(
            await loader.requestPaths() == [
                "/users/session/login",
                "/users/session/access",
                "/users/session/me",
            ]
        )
        let durable = storage.snapshot()
        #expect(durable.ledger?.phase == .active)
        #expect(durable.ledger?.userID == Self.userID)
        #expect(durable.ledger?.sessionGeneration == Self.generation)
        #expect(durable.bundles[Self.generation]?.refresh.value == "fixture-refresh")
        #expect(durable.bundles[Self.generation]?.access.value == "fixture-access")
    }

    @Test("A failed identity lookup never persists the preceding credentials")
    func failedIdentityLeavesTheControllerSignedOut() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.refreshResponse),
                .data(Self.accessResponse),
                .network(.transport(.notConnectedToInternet)),
            ]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage
        )
        _ = try await controller.restore()

        await #expect(
            throws: SessionControllerError.network(
                .transport(.notConnectedToInternet)
            )
        ) {
            try await controller.login(
                email: "reader@example.invalid",
                password: "synthetic-passphrase"
            )
        }

        #expect(await controller.currentSnapshot() == .signedOut)
        #expect(storage.snapshot().ledger == nil)
        #expect(storage.snapshot().bundles.isEmpty)
    }

    @Test("Cancellation before durable activation leaves no session authority")
    func cancelledLoginBeforeActivationDoesNotPersist() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.refreshResponse),
                .data(Self.accessResponse),
                .data(Self.identityResponse),
            ],
            identityGate: gate
        )
        let controller = try makeController(
            loader: loader,
            storage: storage
        )
        _ = try await controller.restore()

        let login = Task {
            try await controller.login(
                email: "reader@example.invalid",
                password: "synthetic-passphrase"
            )
        }
        await gate.waitUntilArrived()
        login.cancel()
        await gate.open()

        await #expect(throws: CancellationError.self) {
            try await login.value
        }
        #expect(await controller.currentSnapshot() == .signedOut)
        #expect(storage.snapshot().ledger == nil)
        #expect(storage.snapshot().bundles.isEmpty)
    }

    @Test("Cancellation after durable activation preserves the committed session")
    func cancelledLoginAfterActivationReturnsCommittedSession() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.refreshResponse),
                .data(Self.accessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage,
            generationFactory: {
                withUnsafeCurrentTask { task in
                    task?.cancel()
                }
                return Self.generation
            }
        )
        _ = try await controller.restore()

        let login = Task {
            try await controller.login(
                email: "reader@example.invalid",
                password: "synthetic-passphrase"
            )
        }

        #expect(
            try await login.value
                == .active(Self.remoteAccount)
        )
        #expect(
            await controller.currentSnapshot()
                == .active(Self.remoteAccount)
        )
        #expect(storage.snapshot().ledger?.phase == .active)
        #expect(storage.snapshot().bundles.count == 1)
    }

    @Test("Offline restore keeps the durable UUID without inventing account details")
    func offlineRestoreKeepsStableUserScope() async throws(any Error) {
        let bundle = try makeBundle(
            generation: Self.generation,
            accessExpiresAt: Self.now.addingTimeInterval(600)
        )
        let ledger = SessionLedgerRecord.active(
            userID: Self.userID,
            generation: Self.generation,
            revision: 4
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: ledger,
            bundles: [Self.generation: bundle]
        )
        let loader = ScriptedSessionDataLoader(
            replies: [.network(.transport(.notConnectedToInternet))]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage
        )

        #expect(
            try await controller.restore()
                == .active(
                    SessionAccount(
                        id: Self.userID,
                        email: nil,
                        isActive: nil,
                        isAdmin: nil,
                        role: nil
                    )
                )
        )
        #expect(storage.snapshot().ledger == ledger)
        #expect(storage.snapshot().bundles[Self.generation] == bundle)
    }

    @Test("Expired access refresh is shared and durably replaces access only once")
    func accessRefreshIsSingleFlight() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let bundle = try makeBundle(
            generation: Self.generation,
            accessExpiresAt: Self.now.addingTimeInterval(60)
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: .active(
                userID: Self.userID,
                generation: Self.generation,
                revision: 1
            ),
            bundles: [Self.generation: bundle]
        )
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
            ],
            accessGate: gate
        )
        let controller = try makeController(
            loader: loader,
            storage: storage,
            clock: clock
        )
        _ = try await controller.restore()
        clock.advance(by: 120)

        async let first = controller.accessCredential()
        async let second = controller.accessCredential()
        await gate.waitUntilArrived()
        await gate.open()
        let (firstCredential, secondCredential) = try await (first, second)

        #expect(firstCredential.value == "fixture-access-renewed")
        #expect(secondCredential == firstCredential)
        #expect(
            await loader.requestPaths().filter {
                $0 == "/users/session/access"
            }.count == 1
        )
        #expect(
            storage.snapshot().bundles[Self.generation]?.access
                == firstCredential
        )
        #expect(
            storage.snapshot().bundles[Self.generation]?.refresh
                == bundle.refresh
        )
    }

    @Test("A transient refresh failure preserves authority and remains retryable")
    func transientRefreshFailureKeepsTheSession() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let bundle = try makeBundle(
            generation: Self.generation,
            accessExpiresAt: Self.now.addingTimeInterval(60)
        )
        let ledger = SessionLedgerRecord.active(
            userID: Self.userID,
            generation: Self.generation,
            revision: 1
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: ledger,
            bundles: [Self.generation: bundle]
        )
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .network(.statusCode(503)),
                .data(Self.renewedAccessResponse),
            ]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage,
            clock: clock
        )
        _ = try await controller.restore()
        clock.advance(by: 120)

        await #expect(
            throws: SessionControllerError.network(.statusCode(503))
        ) {
            try await controller.accessCredential()
        }

        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().ledger == ledger)
        #expect(storage.snapshot().bundles[Self.generation] == bundle)

        let renewed = try await controller.accessCredential()
        #expect(renewed.value == "fixture-access-renewed")
        #expect(storage.snapshot().ledger == ledger)
        #expect(
            storage.snapshot().bundles[Self.generation]?.refresh
                == bundle.refresh
        )
    }

    @Test("A permanent refresh rejection keeps only authentication scope")
    func rejectedRefreshRequiresAuthentication() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let bundle = try makeBundle(
            generation: Self.generation,
            accessExpiresAt: Self.now.addingTimeInterval(60)
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: .active(
                userID: Self.userID,
                generation: Self.generation,
                revision: 1
            ),
            bundles: [Self.generation: bundle]
        )
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .network(.statusCode(401)),
            ]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage,
            clock: clock
        )
        _ = try await controller.restore()
        clock.advance(by: 120)

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await controller.accessCredential()
        }

        #expect(
            await controller.currentSnapshot()
                == .authenticationRequired(Self.userID)
        )
        #expect(storage.snapshot().ledger?.phase == .authenticationRequired)
        #expect(storage.snapshot().ledger?.userID == Self.userID)
        #expect(storage.snapshot().bundles.isEmpty)
    }

    @Test("Logout reaches signed-out only after conditional durable cleanup")
    func logoutCompletesTheDurableTransition() async throws(any Error) {
        let bundle = try makeBundle(
            generation: Self.generation,
            accessExpiresAt: Self.now.addingTimeInterval(600)
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: .active(
                userID: Self.userID,
                generation: Self.generation,
                revision: 1
            ),
            bundles: [Self.generation: bundle]
        )
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.identityResponse)]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage
        )
        _ = try await controller.restore()

        #expect(try await controller.logout() == .signedOut)
        #expect(storage.snapshot().ledger == nil)
        #expect(storage.snapshot().bundles.isEmpty)
    }

    @Test("Logout preparation blocks new access before durable invalidation")
    func logoutPreparationBlocksNewCredentials() async throws(any Error) {
        let bundle = try makeBundle(
            generation: Self.generation,
            accessExpiresAt: Self.now.addingTimeInterval(600)
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: .active(
                userID: Self.userID,
                generation: Self.generation,
                revision: 1
            ),
            bundles: [Self.generation: bundle]
        )
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.identityResponse)]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage
        )
        _ = try await controller.restore()
        let gate = storage.gateNext(.writeLedger)

        let logout = Task { try await controller.logout() }
        await gate.waitUntilArrived()

        await #expect(throws: SessionControllerError.transitionInProgress) {
            try await controller.accessCredential()
        }

        gate.open()
        #expect(try await logout.value == .signedOut)
    }

    @Test("Cancellation before invalidation preserves prepared logout")
    func cancelledLogoutBeforeInvalidationRemainsPrepared() async throws(any Error) {
        let bundle = try makeBundle(
            generation: Self.generation,
            accessExpiresAt: Self.now.addingTimeInterval(600)
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: .active(
                userID: Self.userID,
                generation: Self.generation,
                revision: 1
            ),
            bundles: [Self.generation: bundle]
        )
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.identityResponse)]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage
        )
        _ = try await controller.restore()
        let gate = storage.gateNext(.writeLedger)

        let logout = Task { try await controller.logout() }
        await gate.waitUntilArrived()
        logout.cancel()
        gate.open()

        await #expect(throws: CancellationError.self) {
            try await logout.value
        }
        #expect(
            await controller.currentSnapshot()
                == .logoutPrepared(Self.remoteAccount)
        )
        #expect(storage.snapshot().ledger?.phase == .logoutPrepared)
        #expect(storage.snapshot().bundles[Self.generation] == bundle)
    }

    @Test("Authentication invalidation blocks concurrent credential access")
    func authenticationInvalidationBlocksNewCredentials() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let bundle = try makeBundle(
            generation: Self.generation,
            accessExpiresAt: Self.now.addingTimeInterval(600)
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: .active(
                userID: Self.userID,
                generation: Self.generation,
                revision: 1
            ),
            bundles: [Self.generation: bundle]
        )
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.identityResponse)]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage,
            clock: clock
        )
        _ = try await controller.restore()
        clock.advance(by: 2_592_001)
        let gate = storage.gateNext(.writeLedger)

        let invalidation = Task { try await controller.accessCredential() }
        await gate.waitUntilArrived()

        await #expect(throws: SessionControllerError.transitionInProgress) {
            try await controller.accessCredential()
        }

        gate.open()
        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await invalidation.value
        }
        #expect(
            await controller.currentSnapshot()
                == .authenticationRequired(Self.userID)
        )
    }

    @Test("Cancelling one restore waiter does not cancel shared restoration")
    func cancelledRestoreWaiterDoesNotCancelTheFlight() async throws(any Error) {
        let bundle = try makeBundle(
            generation: Self.generation,
            accessExpiresAt: Self.now.addingTimeInterval(600)
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: .active(
                userID: Self.userID,
                generation: Self.generation,
                revision: 1
            ),
            bundles: [Self.generation: bundle]
        )
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.identityResponse)],
            identityGate: gate
        )
        let controller = try makeController(
            loader: loader,
            storage: storage
        )

        let cancelled = Task { try await controller.restore() }
        await gate.waitUntilArrived()
        let remaining = Task { try await controller.restore() }
        cancelled.cancel()
        await gate.open()

        await #expect(throws: CancellationError.self) {
            try await cancelled.value
        }
        #expect(
            try await remaining.value
                == .active(Self.remoteAccount)
        )
        #expect(
            storage.snapshot().journal.filter { $0 == .readLedger }.count == 1
        )
    }

    @Test("A failure before invalidation keeps the prepared session cancelable")
    func preInvalidationFailureKeepsTheSession() async throws(any Error) {
        let bundle = try makeBundle(
            generation: Self.generation,
            accessExpiresAt: Self.now.addingTimeInterval(600)
        )
        let ledger = SessionLedgerRecord.active(
            userID: Self.userID,
            generation: Self.generation,
            revision: 1
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: ledger,
            bundles: [Self.generation: bundle]
        )
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.identityResponse)]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage
        )
        let restored = try await controller.restore()
        storage.failNext(.writeLedger, with: .fileSystemFailure)

        await #expect(throws: SessionControllerError.persistenceUnavailable) {
            try await controller.logout()
        }

        #expect(await controller.currentSnapshot() == restored)
        #expect(storage.snapshot().ledger == ledger)
        #expect(storage.snapshot().bundles[Self.generation] == bundle)
    }

    @Test("A failure after invalidation remains cleaning and can be resumed")
    func postInvalidationFailureRemainsFailClosed() async throws(any Error) {
        let bundle = try makeBundle(
            generation: Self.generation,
            accessExpiresAt: Self.now.addingTimeInterval(600)
        )
        let storage = ControlledSessionPersistenceStorage(
            ledger: .active(
                userID: Self.userID,
                generation: Self.generation,
                revision: 1
            ),
            bundles: [Self.generation: bundle]
        )
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.identityResponse)]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage
        )
        _ = try await controller.restore()
        storage.failNext(.removeBundle, with: .temporarilyUnavailable)

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.logout()
        }

        #expect(
            await controller.currentSnapshot()
                == .cleaning(userID: Self.userID, completion: .signedOut)
        )
        #expect(
            storage.snapshot().ledger?.phase
                == .invalidatedCleanupPending
        )
        #expect(try await controller.retryCleanup() == .signedOut)
        #expect(storage.snapshot().ledger == nil)
        #expect(storage.snapshot().bundles.isEmpty)
    }

    @Test("A superseded login A cannot persist after login B completes")
    func lateLoginCannotReplaceTheNewerAccount() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        let gate = SessionRequestGate()
        let loader = ConcurrentLoginDataLoader(gate: gate)
        let controller = try makeController(
            loadData: { request in
                try await loader.load(request)
            },
            storage: storage
        )
        _ = try await controller.restore()

        let loginA = Task {
            try await controller.login(
                email: "a@example.invalid",
                password: "synthetic-passphrase-a"
            )
        }
        await gate.waitUntilArrived()
        let accountB = try await controller.login(
            email: "b@example.invalid",
            password: "synthetic-passphrase-b"
        )
        await gate.open()

        #expect(
            accountB
                == .active(
                    SessionAccount(
                        id: Self.userB,
                        email: "b@example.invalid",
                        isActive: true,
                        isAdmin: false,
                        role: "user"
                    )
                )
        )
        await #expect(throws: SessionControllerError.sessionChanged) {
            try await loginA.value
        }
        #expect(storage.snapshot().ledger?.userID == Self.userB)
        #expect(storage.snapshot().bundles.count == 1)
    }

    private func makeController(
        loader: ScriptedSessionDataLoader,
        storage: ControlledSessionPersistenceStorage,
        clock: TestSessionClock = TestSessionClock(now: Self.now),
        generationFactory: @escaping @Sendable () -> UUID = {
            Self.generation
        }
    ) throws(any Error) -> SessionController {
        try makeController(
            loadData: { request in
                try await loader.load(request)
            },
            storage: storage,
            clock: clock,
            generationFactory: generationFactory
        )
    }

    private func makeController(
        loadData: @escaping SessionAPIClient.DataLoader,
        storage: ControlledSessionPersistenceStorage,
        clock: TestSessionClock = TestSessionClock(now: Self.now),
        generationFactory: @escaping @Sendable () -> UUID = {
            Self.generation
        }
    ) throws(any Error) -> SessionController {
        let baseURL = try #require(URL(string: "https://session.example.test"))
        let apiClient = SessionAPIClient(
            configuration: try APIConfiguration(baseURL: baseURL),
            loadData: loadData,
            now: { clock.value() }
        )
        return SessionController(
            apiClient: apiClient,
            persistence: SessionPersistenceActor(
                operations: storage.operations()
            ),
            now: { clock.value() },
            makeGeneration: generationFactory
        )
    }

    private func makeBundle(
        generation: UUID,
        accessExpiresAt: Date
    ) throws(SessionStorageError) -> SessionSecretBundle {
        try SessionSecretBundle(
            generation: generation,
            access: SessionCredential(
                value: "fixture-access",
                use: .access,
                expiresAt: accessExpiresAt
            ),
            refresh: SessionCredential(
                value: "fixture-refresh",
                use: .refresh,
                expiresAt: Self.now.addingTimeInterval(2_592_000)
            )
        )
    }

    private static let now = Date(timeIntervalSince1970: 1_700_000_000)
    private static let userID = UUID(
        uuidString: "11111111-2222-3333-4444-555555555555"
    )!
    private static let userB = UUID(
        uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA"
    )!
    private static let generation = UUID(
        uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    )!
    private static let refreshResponse = Data(
        #"{"token":"fixture-refresh","tokenType":"Bearer","expiresIn":2592000,"tokenUse":"refresh"}"#.utf8
    )
    private static let accessResponse = Data(
        #"{"token":"fixture-access","tokenType":"Bearer","expiresIn":3600,"tokenUse":"access"}"#.utf8
    )
    private static let renewedAccessResponse = Data(
        #"{"token":"fixture-access-renewed","tokenType":"Bearer","expiresIn":3600,"tokenUse":"access"}"#.utf8
    )
    private static let identityResponse = Data(
        #"""
        {
          "email": "reader@example.invalid",
          "id": "11111111-2222-3333-4444-555555555555",
          "isActive": true,
          "isAdmin": false,
          "role": "user"
        }
        """#.utf8
    )
    private static let remoteAccount = SessionAccount(
        id: userID,
        email: "reader@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
}

private actor ScriptedSessionDataLoader {
    enum Reply: Sendable {
        case data(Data)
        case network(NetworkError)
    }

    private var replies: [Reply]
    private var requests: [URLRequest] = []
    private let accessGate: SessionRequestGate?
    private let identityGate: SessionRequestGate?

    init(replies: [Reply], accessGate: SessionRequestGate? = nil, identityGate: SessionRequestGate? = nil) {
        self.replies = replies
        self.accessGate = accessGate
        self.identityGate = identityGate
    }

    func load(_ request: URLRequest) async throws(any Error) -> Data {
        requests.append(request)
        if
            request.url?.path == "/users/session/access",
            let accessGate
        {
            await accessGate.suspendUntilOpen()
        }
        if
            request.url?.path == "/users/session/me",
            let identityGate
        {
            await identityGate.suspendUntilOpen()
        }

        let reply = try #require(replies.first)
        replies.removeFirst()
        switch reply {
        case let .data(data):
            return data
        case let .network(error):
            throw error
        }
    }

    func requestPaths() -> [String] {
        requests.compactMap(\.url?.path)
    }
}

private actor ConcurrentLoginDataLoader {
    private let gate: SessionRequestGate

    init(gate: SessionRequestGate) {
        self.gate = gate
    }

    func load(_ request: URLRequest) async throws(any Error) -> Data {
        let path = request.url?.path
        let authorization = request.value(
            forHTTPHeaderField: "Authorization"
        )

        switch (path, authorization) {
        case ("/users/session/login", Self.basicA):
            await gate.suspendUntilOpen()
            return Self.refreshA
        case ("/users/session/login", Self.basicB):
            return Self.refreshB
        case ("/users/session/access", "Bearer refresh-a"):
            return Self.accessA
        case ("/users/session/access", "Bearer refresh-b"):
            return Self.accessB
        case ("/users/session/me", "Bearer access-a"):
            return Self.identityA
        case ("/users/session/me", "Bearer access-b"):
            return Self.identityB
        default:
            throw NetworkError.invalidResponse
        }
    }

    private static let basicA = "Basic " + Data(
        "a@example.invalid:synthetic-passphrase-a".utf8
    ).base64EncodedString()
    private static let basicB = "Basic " + Data(
        "b@example.invalid:synthetic-passphrase-b".utf8
    ).base64EncodedString()
    private static let refreshA = Data(
        #"{"token":"refresh-a","tokenType":"Bearer","expiresIn":2592000,"tokenUse":"refresh"}"#.utf8
    )
    private static let refreshB = Data(
        #"{"token":"refresh-b","tokenType":"Bearer","expiresIn":2592000,"tokenUse":"refresh"}"#.utf8
    )
    private static let accessA = Data(
        #"{"token":"access-a","tokenType":"Bearer","expiresIn":3600,"tokenUse":"access"}"#.utf8
    )
    private static let accessB = Data(
        #"{"token":"access-b","tokenType":"Bearer","expiresIn":3600,"tokenUse":"access"}"#.utf8
    )
    private static let identityA = Data(
        #"""
        {
          "email": "a@example.invalid",
          "id": "11111111-2222-3333-4444-555555555555",
          "isActive": true,
          "isAdmin": false,
          "role": "user"
        }
        """#.utf8
    )
    private static let identityB = Data(
        #"""
        {
          "email": "b@example.invalid",
          "id": "66666666-7777-8888-9999-AAAAAAAAAAAA",
          "isActive": true,
          "isAdmin": false,
          "role": "user"
        }
        """#.utf8
    )
}

private actor SessionRequestGate {
    private var didArrive = false
    private var isOpen = false
    private var arrivalContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func waitUntilArrived() async {
        guard didArrive == false else {
            return
        }
        await withCheckedContinuation {
            arrivalContinuation = $0
        }
    }

    func suspendUntilOpen() async {
        didArrive = true
        arrivalContinuation?.resume()
        arrivalContinuation = nil
        guard isOpen == false else {
            return
        }
        await withCheckedContinuation {
            releaseContinuation = $0
        }
    }

    func open() {
        isOpen = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private final class TestSessionClock: Sendable {
    private let now: Mutex<Date>

    init(now: Date) {
        self.now = Mutex(now)
    }

    func value() -> Date {
        now.withLock { $0 }
    }

    func advance(by interval: TimeInterval) {
        now.withLock {
            $0 = $0.addingTimeInterval(interval)
        }
    }
}
