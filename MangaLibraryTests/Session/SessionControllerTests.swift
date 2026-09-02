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
    @Test("Login completes the remote chain before saving one session")
    func loginActivatesOnlyAfterIdentity() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.refreshResponse), .data(Self.accessResponse), .data(Self.identityResponse)]
        )
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()

        let snapshot = try await controller.login(email: "reader@example.invalid", password: "synthetic-passphrase")

        #expect(snapshot == .active(Self.remoteAccount))
        #expect(storage.snapshot().record?.userID == Self.userID)
        #expect(storage.snapshot().record?.generation == Self.generation)
        #expect(storage.snapshot().record?.access.value == "fixture-access")
        #expect(storage.snapshot().record?.refresh.value == "fixture-refresh")
        #expect(await loader.requestPaths() == ["/users/session/login", "/users/session/access", "/users/session/me"])
    }

    @Test("A failed identity lookup never persists preceding credentials")
    func failedIdentityLeavesTheControllerSignedOut() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.refreshResponse), .data(Self.accessResponse), .network(.statusCode(503))]
        )
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()

        await #expect(throws: SessionControllerError.network(.statusCode(503))) {
            try await controller.login(email: "reader@example.invalid", password: "synthetic-passphrase")
        }

        #expect(await controller.currentSnapshot() == .signedOut)
        #expect(storage.snapshot().record == nil)
    }

    @Test("Cancellation before durable activation leaves no session")
    func cancelledLoginBeforeActivationDoesNotPersist() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.refreshResponse), .data(Self.accessResponse), .data(Self.identityResponse)],
            identityGate: gate
        )
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()

        let login = Task {
            try await controller.login(email: "reader@example.invalid", password: "synthetic-passphrase")
        }
        await gate.waitUntilArrived()
        login.cancel()
        await gate.open()

        await #expect(throws: CancellationError.self) { try await login.value }
        #expect(storage.snapshot().record == nil)
        #expect(await controller.currentSnapshot() == .signedOut)
    }

    @Test("Restore publishes stable identity even when account refresh is offline")
    func offlineRestoreKeepsThePersistedScope() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.network(.statusCode(503))])
        let controller = try makeController(loader: loader, storage: storage)

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
        #expect(storage.snapshot().record == session)
    }

    @Test("Restore with expired access validates the renewed identity exactly once")
    func expiredAccessRestoreReusesTheValidatedRefreshIdentity() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(-1))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponse),
                .network(.statusCode(401)),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage)

        #expect(try await controller.restore() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record?.access.value == "fixture-access-renewed")
        #expect(storage.snapshot().record?.refresh == session.refresh)
        #expect(await loader.requestPaths() == ["/users/session/access", "/users/session/me"])
    }

    @Test("Request authorization returns the token bound to the active generation")
    func requestAuthorizationCapturesTheActiveAuthority() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()

        let authorization = try await controller.requestAuthorization()

        #expect(authorization.authority == SessionAuthority(userID: Self.userID, generation: Self.generation))
        #expect(authorization.accessToken == "fixture-access")
        #expect(await controller.authorizes(authorization))
    }

    @Test("A rejected unexpired access forces refresh and identity validation")
    func rejectedAuthorizationRenewsItsExactAccess() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()
        let rejectedAuthorization = try await controller.requestAuthorization()

        let renewedAuthorization = try await controller.recoverAuthorization(after: rejectedAuthorization)

        #expect(renewedAuthorization.authority == rejectedAuthorization.authority)
        #expect(renewedAuthorization.accessToken == "fixture-access-renewed")
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record?.access.value == "fixture-access-renewed")
        #expect(storage.snapshot().record?.refresh == session.refresh)
        #expect(await controller.authorizes(rejectedAuthorization) == false)
        #expect(await controller.authorizes(renewedAuthorization))
        #expect(await loader.requestPaths() == ["/users/session/me", "/users/session/access", "/users/session/me"])
    }

    @Test("A permanently rejected forced refresh requires authentication")
    func rejectedAuthorizationWithRejectedRefreshRequiresAuthentication() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse), .network(.statusCode(401))])
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()
        let authorization = try await controller.requestAuthorization()

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await controller.recoverAuthorization(after: authorization)
        }

        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
        #expect(await controller.authorizes(authorization) == false)
    }

    @Test("An access rejected by renewed identity validation keeps the session envelope")
    func renewedAccessRejectedByIdentityKeepsTheSession() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .network(.statusCode(401)),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()
        let authorization = try await controller.requestAuthorization()

        await #expect(throws: SessionAuthorizationRecoveryError.identityRejected(statusCode: 401)) {
            try await controller.recoverAuthorization(after: authorization)
        }

        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record == session)
        #expect(await controller.authorizes(authorization) == false)
    }

    @Test("A late rejection from generation A cannot invalidate generation B")
    func staleGenerationRejectionPreservesReplacementSession() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.refreshResponse),
                .data(Self.accessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage,
            generationFactory: { Self.generationB }
        )
        _ = try await controller.restore()
        let staleAuthorization = try await controller.requestAuthorization()
        _ = try await controller.logout()
        _ = try await controller.login(email: "reader@example.invalid", password: "synthetic-passphrase")

        await #expect(throws: SessionControllerError.sessionChanged) {
            try await controller.recoverAuthorization(after: staleAuthorization)
        }

        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record?.generation == Self.generationB)
    }

    @Test("A late rejection for an old access token preserves its renewed generation")
    func staleAccessRejectionCannotInvalidateRenewedCredential() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(60))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        let staleAuthorization = try await controller.requestAuthorization()
        clock.advance(by: 120)
        let renewedCredential = try await controller.accessCredential()

        await #expect(throws: SessionControllerError.sessionChanged) {
            try await controller.recoverAuthorization(after: staleAuthorization)
        }

        #expect(renewedCredential.value == "fixture-access-renewed")
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record?.access.value == "fixture-access-renewed")
        #expect(await controller.authorizes(staleAuthorization) == false)
    }

    @Test("Session invalidation linearizes after an authorized synchronous commit")
    func commitAuthorizationSerializesInvalidation() async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userID, generation: Self.generation)
        let commitGate = SessionCommitGate(activeAuthority: authority)
        let authorization = commitGate.authorization(for: authority)
        let criticalSection = SynchronousPersistenceGate()
        let invalidationStarted = Atomic(false)
        let invalidationFinished = Atomic(false)
        let commit = Task {
            try authorization.perform {
                criticalSection.pause()
                return true
            }
        }
        await criticalSection.waitUntilEntered()
        let invalidation = Task {
            invalidationStarted.store(true, ordering: .releasing)
            commitGate.invalidate(authority)
            invalidationFinished.store(true, ordering: .releasing)
        }
        while invalidationStarted.load(ordering: .acquiring) == false { await Task.yield() }

        let finishedBeforeCommit = invalidationFinished.load(ordering: .acquiring)
        #expect(finishedBeforeCommit == false)
        criticalSection.open()
        #expect(try await commit.value)
        await invalidation.value
        let finishedAfterCommit = invalidationFinished.load(ordering: .acquiring)
        #expect(finishedAfterCommit)
        #expect(throws: SessionCommitAuthorizationError.sessionChanged) {
            try authorization.perform { true }
        }
    }

    @Test("Authorization suspended in refresh cannot survive logout")
    func requestAuthorizationCannotReturnAfterLogout() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(60))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.identityResponse), .data(Self.renewedAccessResponse)],
            accessGate: gate
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        clock.advance(by: 120)

        let authorization = Task { try await controller.requestAuthorization() }
        await gate.waitUntilArrived()
        #expect(try await controller.logout() == .signedOut)
        await gate.open()

        await #expect(throws: SessionControllerError.sessionChanged) {
            try await authorization.value
        }
        #expect(storage.snapshot().record == nil)
    }

    @Test("Concurrent expired access requests share one refresh and identity validation")
    func concurrentAccessRequestsShareTheValidatedRefreshFlight() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(60))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponse),
            ],
            accessGate: gate
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        clock.advance(by: 120)

        let first = Task { try await controller.accessCredential() }
        await gate.waitUntilArrived()
        let second = Task { try await controller.accessCredential() }
        await gate.open()

        let firstCredential = try await first.value
        let secondCredential = try await second.value
        #expect(firstCredential.value == "fixture-access-renewed")
        #expect(secondCredential == firstCredential)
        #expect(await loader.requestPaths().filter { $0 == "/users/session/access" }.count == 1)
        #expect(await loader.requestPaths().filter { $0 == "/users/session/me" }.count == 2)
        #expect(storage.snapshot().record?.refresh == session.refresh)
    }

    @Test("Authorization entering during ordinary refresh shares the renewed access")
    func authorizationEnteringDuringRefreshSharesTheRenewedAccess() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(60))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponse),
            ],
            accessGate: gate
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        clock.advance(by: 120)

        let refresh = Task { try await controller.accessCredential() }
        await gate.waitUntilArrived()
        let authorization = Task { try await controller.requestAuthorization() }
        await gate.open()

        let renewedCredential = try await refresh.value
        let renewedAuthorization = try await authorization.value
        #expect(renewedAuthorization.accessToken == renewedCredential.value)
        #expect(await controller.authorizes(renewedAuthorization))
        #expect(await loader.requestPaths().filter { $0 == "/users/session/access" }.count == 1)
        #expect(await loader.requestPaths().filter { $0 == "/users/session/me" }.count == 2)
        #expect(storage.snapshot().record?.refresh == session.refresh)
    }

    @Test("A replacement session ignores a residual refresh flight")
    func replacementSessionIgnoresResidualRefreshFlight() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(60))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = ResidualRefreshDataLoader(gate: gate)
        let controller = try makeController(
            loadData: { request in try await loader.load(request) },
            storage: storage,
            clock: clock,
            generationFactory: { Self.generationB }
        )
        _ = try await controller.restore()
        clock.advance(by: 120)

        let residualRefresh = Task { try await controller.accessCredential() }
        await gate.waitUntilArrived()
        #expect(try await controller.logout() == .signedOut)
        #expect(
            try await controller.login(email: "b@example.invalid", password: "synthetic-passphrase-b")
                == .active(Self.remoteAccountB)
        )

        let authorization = try await controller.requestAuthorization()
        #expect(authorization.authority == SessionAuthority(userID: Self.userB, generation: Self.generationB))
        #expect(authorization.accessToken == "fixture-access-b")
        #expect(await controller.authorizes(authorization))

        let recoveredAuthorization = try await controller.recoverAuthorization(after: authorization)
        #expect(recoveredAuthorization.authority == authorization.authority)
        #expect(recoveredAuthorization.accessToken == "fixture-access-b-renewed")
        #expect(await controller.authorizes(authorization) == false)
        #expect(await controller.authorizes(recoveredAuthorization))

        await gate.open()
        await #expect(throws: SessionControllerError.sessionChanged) {
            try await residualRefresh.value
        }
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccountB))
        #expect(storage.snapshot().record?.authority == recoveredAuthorization.authority)
        #expect(storage.snapshot().record?.access.value == recoveredAuthorization.accessToken)
        #expect(await loader.requestPaths() == [
            "/users/session/me",
            "/users/session/access",
            "/users/session/login",
            "/users/session/access",
            "/users/session/me",
            "/users/session/access",
            "/users/session/me",
        ])
    }

    @Test("An ordinary refresh rejected by identity never replaces the session envelope")
    func ordinaryRefreshRejectedByIdentityKeepsTheSession() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(60))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .network(.statusCode(401)),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        clock.advance(by: 120)

        await #expect(throws: SessionAuthorizationRecoveryError.identityRejected(statusCode: 401)) {
            try await controller.accessCredential()
        }

        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record == session)
        #expect(await loader.requestPaths() == ["/users/session/me", "/users/session/access", "/users/session/me"])
    }

    @Test("Forced recovery and an access request share one refresh")
    func forcedRecoverySharesTheRefreshFlight() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponse),
            ],
            accessGate: gate
        )
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()
        let rejectedAuthorization = try await controller.requestAuthorization()

        let recovery = Task {
            try await controller.recoverAuthorization(after: rejectedAuthorization)
        }
        await gate.waitUntilArrived()
        let access = Task { try await controller.accessCredential() }
        await gate.open()

        let recoveredAuthorization = try await recovery.value
        let sharedCredential = try await access.value
        #expect(recoveredAuthorization.accessToken == "fixture-access-renewed")
        #expect(sharedCredential.value == recoveredAuthorization.accessToken)
        #expect(await loader.requestPaths().filter { $0 == "/users/session/access" }.count == 1)
        #expect(await loader.requestPaths().filter { $0 == "/users/session/me" }.count == 2)
        #expect(storage.snapshot().record?.refresh == session.refresh)
    }

    @Test("A transient refresh failure preserves authority and remains retryable")
    func transientRefreshFailureKeepsTheSession() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(60))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .network(.statusCode(503)),
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        clock.advance(by: 120)

        await #expect(throws: SessionControllerError.network(.statusCode(503))) {
            try await controller.accessCredential()
        }
        #expect(storage.snapshot().record == session)

        #expect(try await controller.accessCredential().value == "fixture-access-renewed")
        #expect(storage.snapshot().record?.refresh == session.refresh)
    }

    @Test("A permanent refresh rejection removes credentials and requires sign in")
    func rejectedRefreshRequiresAuthentication() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(60))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse), .network(.statusCode(401))])
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        clock.advance(by: 120)

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await controller.accessCredential()
        }

        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)

        let relaunched = try makeController(
            loader: ScriptedSessionDataLoader(replies: []),
            storage: storage,
            clock: clock
        )
        #expect(try await relaunched.restore() == .signedOut)
    }

    @Test("A rejected session is not reused when Keychain cleanup fails")
    func rejectedRefreshWithFailedCleanupBlocksCredentials() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(60))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse), .network(.statusCode(401))])
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        clock.advance(by: 120)
        storage.failNext(.removeAll, with: .temporarilyUnavailable)

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.accessCredential()
        }

        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == session)
        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await controller.accessCredential()
        }
        #expect(await loader.requestPaths().filter { $0 == "/users/session/access" }.count == 1)
    }

    @Test("Sign in replaces only the rejected generation left after failed cleanup")
    func signInReplacesTheResidualRejectedGeneration() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(60))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .network(.statusCode(401)),
                .data(Self.refreshResponse),
                .data(Self.accessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage,
            clock: clock,
            generationFactory: { Self.generationB }
        )
        _ = try await controller.restore()
        clock.advance(by: 120)
        storage.failNext(.removeAll, with: .temporarilyUnavailable)
        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.accessCredential()
        }

        let snapshot = try await controller.login(email: "reader@example.invalid", password: "synthetic-passphrase")

        #expect(snapshot == .active(Self.remoteAccount))
        #expect(storage.snapshot().record?.generation == Self.generationB)
        #expect(storage.snapshot().record?.access.value == "fixture-access")
        #expect(storage.snapshot().record?.refresh.value == "fixture-refresh")
    }

    @Test("Logout publishes signed out only after deleting Keychain")
    func logoutDeletesTheCurrentSession() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()

        #expect(try await controller.logout() == .signedOut)
        #expect(storage.snapshot().record == nil)
    }

    @Test("A failed Keychain deletion keeps the session and a second logout retries")
    func failedLogoutCanBeRetriedFromTheActiveSession() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage)
        let restored = try await controller.restore()
        storage.failNext(.removeAll, with: .temporarilyUnavailable)

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.logout()
        }
        #expect(await controller.currentSnapshot() == restored)
        #expect(storage.snapshot().record == session)

        #expect(try await controller.logout() == .signedOut)
        #expect(storage.snapshot().record == nil)
    }

    @Test("A credential rejected during failed logout forces refresh before reuse")
    func rejectionDuringFailedLogoutForcesRefresh() async throws(any Error) {
        let deletionGate = SynchronousPersistenceGate()
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session, removeAllGate: deletionGate)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()
        let authorization = try await controller.requestAuthorization()
        storage.failNext(.removeAll, with: .temporarilyUnavailable)

        let logout = Task { try await controller.logout() }
        await deletionGate.waitUntilEntered()
        await #expect(throws: SessionControllerError.transitionInProgress) {
            try await controller.recoverAuthorization(after: authorization)
        }
        deletionGate.open()

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await logout.value
        }
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record == session)
        #expect(await controller.authorizes(authorization) == false)

        let renewedAuthorization = try await controller.requestAuthorization()
        #expect(renewedAuthorization.accessToken == "fixture-access-renewed")
        #expect(await controller.authorizes(renewedAuthorization))
        #expect(storage.snapshot().record?.access.value == "fixture-access-renewed")
    }

    @Test("A stale rejection during failed logout preserves the renewed access")
    func staleRejectionDuringFailedLogoutPreservesRenewedAccess() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let deletionGate = SynchronousPersistenceGate()
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(60))
        let storage = ControlledSessionPersistenceStorage(record: session, removeAllGate: deletionGate)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        let staleAuthorization = try await controller.requestAuthorization()
        clock.advance(by: 120)
        let renewedCredential = try await controller.accessCredential()
        let renewedAuthorization = try await controller.requestAuthorization()
        storage.failNext(.removeAll, with: .temporarilyUnavailable)

        let logout = Task { try await controller.logout() }
        await deletionGate.waitUntilEntered()
        await #expect(throws: SessionControllerError.sessionChanged) {
            try await controller.recoverAuthorization(after: staleAuthorization)
        }
        deletionGate.open()

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await logout.value
        }
        #expect(renewedCredential.value == "fixture-access-renewed")
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record?.access.value == "fixture-access-renewed")
        #expect(await controller.authorizes(staleAuthorization) == false)
        #expect(await controller.authorizes(renewedAuthorization))
    }

    @Test("An interrupted logout restores the still-present session after relaunch")
    func interruptedLogoutRestoresThePresentSession() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let controller = try makeController(
            loader: ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)]),
            storage: storage
        )
        _ = try await controller.restore()
        storage.failNext(.removeAll, with: .temporarilyUnavailable)

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.logout()
        }

        let relaunched = try makeController(
            loader: ScriptedSessionDataLoader(replies: [.network(.statusCode(503))]),
            storage: storage
        )
        #expect(
            try await relaunched.restore()
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
        #expect(storage.snapshot().record == session)
    }

    @Test("Cancellation after Keychain deletion reconciles to signed out")
    func cancellationAfterLogoutCommitRemainsSignedOut() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let controller = try makeController(
            loader: ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)]),
            storage: storage
        )
        _ = try await controller.restore()
        storage.cancelCurrentTaskAfter(.removeAll)

        let logout = Task { try await controller.logout() }

        #expect(try await logout.value == .signedOut)
        #expect(logout.isCancelled)
        #expect(await controller.currentSnapshot() == .signedOut)
        #expect(storage.snapshot().record == nil)
    }

    @Test("A second session cannot begin while logout deletes the current generation")
    func loginCannotActivateDuringLogoutDeletion() async throws(any Error) {
        let deletionGate = SynchronousPersistenceGate()
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session, removeAllGate: deletionGate)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()

        let logout = Task { try await controller.logout() }
        await deletionGate.waitUntilEntered()

        await #expect(throws: SessionControllerError.transitionInProgress) {
            try await controller.login(email: "b@example.invalid", password: "synthetic-passphrase-b")
        }
        #expect(storage.snapshot().record == session)
        #expect(await loader.requestPaths() == ["/users/session/me"])

        deletionGate.open()
        #expect(try await logout.value == .signedOut)
        #expect(storage.snapshot().record == nil)
    }

    @Test("An expired refresh token removes the local session without a network call")
    func expiredRefreshRequiresAuthenticationLocally() async throws(any Error) {
        let session = try makeSession(
            accessExpiresAt: Self.now.addingTimeInterval(-60),
            refreshExpiresAt: Self.now.addingTimeInterval(-1)
        )
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [])
        let controller = try makeController(loader: loader, storage: storage)

        #expect(try await controller.restore() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
        #expect(await loader.requestPaths().isEmpty)
    }

    @Test("Cancelling one restore waiter does not cancel shared restoration")
    func cancelledRestoreWaiterDoesNotCancelTheFlight() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)], identityGate: gate)
        let controller = try makeController(loader: loader, storage: storage)

        let cancelled = Task { try await controller.restore() }
        await gate.waitUntilArrived()
        let remaining = Task { try await controller.restore() }
        cancelled.cancel()
        await gate.open()

        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(try await remaining.value == .active(Self.remoteAccount))
        #expect(storage.snapshot().journal.filter { $0 == .load }.count == 1)
    }

    @Test("A superseded login cannot replace the newer account")
    func lateLoginCannotReplaceTheNewerAccount() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        let gate = SessionRequestGate()
        let loader = ConcurrentLoginDataLoader(gate: gate)
        let controller = try makeController(
            loadData: { request in try await loader.load(request) },
            storage: storage,
            generationFactory: { Self.generation }
        )
        _ = try await controller.restore()

        let loginA = Task {
            try await controller.login(email: "a@example.invalid", password: "synthetic-passphrase-a")
        }
        await gate.waitUntilArrived()
        let accountB = try await controller.login(email: "b@example.invalid", password: "synthetic-passphrase-b")
        await gate.open()

        #expect(accountB == .active(Self.remoteAccountB))
        await #expect(throws: SessionControllerError.sessionChanged) { try await loginA.value }
        #expect(storage.snapshot().record?.userID == Self.userB)
    }

    private func makeController(
        loader: ScriptedSessionDataLoader,
        storage: ControlledSessionPersistenceStorage,
        clock: TestSessionClock = TestSessionClock(now: Self.now),
        generationFactory: @escaping @Sendable () -> UUID = { Self.generation }
    ) throws(any Error) -> SessionController {
        try makeController(
            loadData: { request in try await loader.load(request) },
            storage: storage,
            clock: clock,
            generationFactory: generationFactory
        )
    }

    private func makeController(
        loadData: @escaping SessionAPIClient.DataLoader,
        storage: ControlledSessionPersistenceStorage,
        clock: TestSessionClock = TestSessionClock(now: Self.now),
        generationFactory: @escaping @Sendable () -> UUID = { Self.generation }
    ) throws(any Error) -> SessionController {
        let baseURL = try #require(URL(string: "https://session.example.test"))
        let apiClient = SessionAPIClient(
            configuration: try APIConfiguration(baseURL: baseURL),
            loadData: loadData,
            now: { clock.value() }
        )
        return SessionController(
            apiClient: apiClient,
            persistence: SessionPersistenceActor(operations: storage.operations()),
            now: { clock.value() },
            makeGeneration: generationFactory
        )
    }

    private func makeSession(
        accessExpiresAt: Date,
        refreshExpiresAt: Date = Self.now.addingTimeInterval(2_592_000)
    ) throws(SessionStorageError) -> SessionPersistedSession {
        try SessionPersistedSession(
            userID: Self.userID,
            generation: Self.generation,
            access: SessionCredential(value: "fixture-access", use: .access, expiresAt: accessExpiresAt),
            refresh: SessionCredential(value: "fixture-refresh", use: .refresh, expiresAt: refreshExpiresAt)
        )
    }

    private static let now = Date(timeIntervalSince1970: 1_700_000_000)
    private static let userID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let userB = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
    private static let generation = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private static let generationB = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!
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
    private static let remoteAccountB = SessionAccount(
        id: userB,
        email: "b@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
}

private actor ScriptedSessionDataLoader {
    enum Reply {
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
        if request.url?.path == "/users/session/access", let accessGate {
            await accessGate.suspendUntilOpen()
        }
        if request.url?.path == "/users/session/me", let identityGate {
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
        switch (request.url?.path, request.value(forHTTPHeaderField: "Authorization")) {
        case ("/users/session/login", Self.basicA):
            await gate.suspendUntilOpen()
            return Self.refreshA
        case ("/users/session/login", Self.basicB):
            return Self.refreshB
        case ("/users/session/access", "Bearer fixture-refresh-b"):
            return Self.accessB
        case ("/users/session/me", "Bearer fixture-access-b"):
            return Self.identityB
        default:
            throw SessionAPIClientError.unavailable
        }
    }

    private static let basicA = "Basic \(Data("a@example.invalid:synthetic-passphrase-a".utf8).base64EncodedString())"
    private static let basicB = "Basic \(Data("b@example.invalid:synthetic-passphrase-b".utf8).base64EncodedString())"
    private static let refreshA = Data(
        #"{"token":"fixture-refresh-a","tokenType":"Bearer","expiresIn":2592000,"tokenUse":"refresh"}"#.utf8
    )
    private static let refreshB = Data(
        #"{"token":"fixture-refresh-b","tokenType":"Bearer","expiresIn":2592000,"tokenUse":"refresh"}"#.utf8
    )
    private static let accessB = Data(
        #"{"token":"fixture-access-b","tokenType":"Bearer","expiresIn":3600,"tokenUse":"access"}"#.utf8
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

private actor ResidualRefreshDataLoader {
    private let gate: SessionRequestGate
    private var requests: [URLRequest] = []
    private var issuedInitialAccessB = false

    init(gate: SessionRequestGate) {
        self.gate = gate
    }

    func load(_ request: URLRequest) async throws(any Error) -> Data {
        requests.append(request)
        switch (request.url?.path, request.value(forHTTPHeaderField: "Authorization")) {
        case ("/users/session/me", "Bearer fixture-access"):
            return Self.identityA
        case ("/users/session/access", "Bearer fixture-refresh"):
            await gate.suspendUntilOpen()
            return Self.renewedAccessA
        case ("/users/session/login", Self.basicB):
            return Self.refreshB
        case ("/users/session/access", "Bearer fixture-refresh-b"):
            if issuedInitialAccessB {
                return Self.renewedAccessB
            }
            issuedInitialAccessB = true
            return Self.accessB
        case ("/users/session/me", "Bearer fixture-access-b"),
             ("/users/session/me", "Bearer fixture-access-b-renewed"):
            return Self.identityB
        default:
            throw SessionAPIClientError.unavailable
        }
    }

    func requestPaths() -> [String] {
        requests.compactMap(\.url?.path)
    }

    private static let basicB = "Basic \(Data("b@example.invalid:synthetic-passphrase-b".utf8).base64EncodedString())"
    private static let renewedAccessA = Data(
        #"{"token":"fixture-access-renewed","tokenType":"Bearer","expiresIn":3600,"tokenUse":"access"}"#.utf8
    )
    private static let refreshB = Data(
        #"{"token":"fixture-refresh-b","tokenType":"Bearer","expiresIn":2592000,"tokenUse":"refresh"}"#.utf8
    )
    private static let accessB = Data(
        #"{"token":"fixture-access-b","tokenType":"Bearer","expiresIn":3600,"tokenUse":"access"}"#.utf8
    )
    private static let renewedAccessB = Data(
        #"{"token":"fixture-access-b-renewed","tokenType":"Bearer","expiresIn":3600,"tokenUse":"access"}"#.utf8
    )
    private static let identityA = Data(
        #"{"email":"reader@example.invalid","id":"11111111-2222-3333-4444-555555555555","isActive":true,"isAdmin":false,"role":"user"}"#.utf8
    )
    private static let identityB = Data(
        #"{"email":"b@example.invalid","id":"66666666-7777-8888-9999-AAAAAAAAAAAA","isActive":true,"isAdmin":false,"role":"user"}"#.utf8
    )
}

private actor SessionRequestGate {
    private var arrived = false
    private var isOpen = false
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
    private var openWaiters: [CheckedContinuation<Void, Never>] = []

    func suspendUntilOpen() async {
        arrived = true
        arrivalWaiters.forEach { $0.resume() }
        arrivalWaiters.removeAll()
        guard isOpen == false else { return }
        await withCheckedContinuation { openWaiters.append($0) }
    }

    func waitUntilArrived() async {
        guard arrived == false else { return }
        await withCheckedContinuation { arrivalWaiters.append($0) }
    }

    func open() {
        isOpen = true
        openWaiters.forEach { $0.resume() }
        openWaiters.removeAll()
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
        now.withLock { $0 = $0.addingTimeInterval(interval) }
    }
}
