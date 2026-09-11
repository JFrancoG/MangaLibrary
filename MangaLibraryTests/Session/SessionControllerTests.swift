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
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.accessResponse), .data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()

        let snapshot = try await controller.login(email: "reader@example.invalid", password: "synthetic-passphrase")

        #expect(snapshot == .active(Self.remoteAccount))
        #expect(storage.snapshot().record?.userID == Self.userID)
        #expect(storage.snapshot().record?.generation == Self.generation)
        #expect(storage.snapshot().record?.access.value == "fixture-access")
        #expect(await loader.requestPaths() == ["/users/jwt/login", "/users/jwt/me"])
    }

    @Test("A failed identity lookup never persists preceding credentials")
    func failedIdentityLeavesTheControllerSignedOut() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.accessResponse), .network(.statusCode(503))])
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
            replies: [.data(Self.accessResponse), .data(Self.identityResponse)],
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

        await #expect(throws: CancellationError.self) {
            try await login.value
        }
        #expect(storage.snapshot().record == nil)
        #expect(await controller.currentSnapshot() == .signedOut)
    }

    @Test("Login never persists a JWT that expires while identity is validated")
    func loginJWTExpiringDuringIdentityDoesNotPersist() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let storage = ControlledSessionPersistenceStorage()
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.shortLivedAccessResponse), .data(Self.identityResponse)],
            identityGate: gate
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()

        let login = Task {
            try await controller.login(email: "reader@example.invalid", password: "synthetic-passphrase")
        }
        await gate.waitUntilArrived()
        clock.advance(by: 2)
        await gate.open()

        await #expect(throws: SessionControllerError.contractDrift) {
            try await login.value
        }
        #expect(storage.snapshot().record == nil)
        #expect(await controller.currentSnapshot() == .signedOut)
    }

    @Test("Login never sends a newly expired JWT to identity")
    func loginJWTExpiredBeforeIdentityStopsAfterLogin() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let storage = ControlledSessionPersistenceStorage()
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.shortLivedAccessResponse), .data(Self.identityResponse)]
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        clock.advanceAfterNextRead(by: 2)

        await #expect(throws: SessionControllerError.contractDrift) {
            try await controller.login(email: "reader@example.invalid", password: "synthetic-passphrase")
        }

        #expect(await loader.requestPaths() == ["/users/jwt/login"])
        #expect(storage.snapshot().record == nil)
        #expect(await controller.currentSnapshot() == .signedOut)
    }

    @Test("Login removes a JWT that expires while Keychain activation is suspended")
    func loginJWTExpiringDuringPersistenceDoesNotPublish() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let saveGate = SynchronousPersistenceGate()
        let storage = ControlledSessionPersistenceStorage(saveGate: saveGate)
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.shortLivedAccessResponse), .data(Self.identityResponse)]
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()

        let login = Task {
            try await controller.login(email: "reader@example.invalid", password: "synthetic-passphrase")
        }
        await saveGate.waitUntilEntered()
        clock.advance(by: 2)
        saveGate.open()

        await #expect(throws: SessionControllerError.contractDrift) {
            try await login.value
        }
        #expect(storage.snapshot().record == nil)
        #expect(await controller.currentSnapshot() == .signedOut)
    }

    @Test("A failed cleanup of an expired login JWT remains replaceable")
    func expiredLoginCleanupFailureAllowsAnotherLogin() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let saveGate = SynchronousPersistenceGate()
        let storage = ControlledSessionPersistenceStorage(saveGate: saveGate)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.shortLivedAccessResponse),
                .data(Self.identityResponse),
                .data(Self.accessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()

        let firstLogin = Task {
            try await controller.login(email: "reader@example.invalid", password: "synthetic-passphrase")
        }
        await saveGate.waitUntilEntered()
        clock.advance(by: 2)
        storage.failNext(.removeAll, with: .temporarilyUnavailable)
        saveGate.open()

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await firstLogin.value
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record?.access.value == "fixture-short-lived")

        #expect(
            try await controller.login(email: "reader@example.invalid", password: "synthetic-passphrase")
                == .active(Self.remoteAccount)
        )
        #expect(storage.snapshot().record?.access.value == "fixture-access")
    }

    @Test("A cancelled login still reports failed cleanup of its expired JWT")
    func cancelledLoginPreservesExpiredCredentialCleanupFailure() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let saveGate = SynchronousPersistenceGate()
        let storage = ControlledSessionPersistenceStorage(saveGate: saveGate)
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.shortLivedAccessResponse), .data(Self.identityResponse)]
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()

        let login = Task {
            try await controller.login(email: "reader@example.invalid", password: "synthetic-passphrase")
        }
        await saveGate.waitUntilEntered()
        clock.advance(by: 2)
        storage.failNext(.removeAll, with: .temporarilyUnavailable)
        login.cancel()
        saveGate.open()

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await login.value
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record?.access.value == "fixture-short-lived")
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
                        authority: session.authority,
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

    @Test(
        "Restore invalidates a JWT that expires while identity is suspended",
        arguments: RestoreIdentityCompletion.allCases
    )
    private func restoreIdentityExpirationRequiresAuthentication(
        completion: RestoreIdentityCompletion
    ) async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let reply: ScriptedSessionDataLoader.Reply = switch completion {
        case .success: .data(Self.identityResponse)
        case .unavailable: .network(.statusCode(503))
        }
        let loader = ScriptedSessionDataLoader(replies: [reply], identityGate: gate)
        let controller = try makeController(loader: loader, storage: storage, clock: clock)

        let restore = Task {
            try await controller.restore()
        }
        await gate.waitUntilArrived()
        clock.advance(by: 601)
        await gate.open()

        #expect(try await restore.value == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
        #expect(await loader.requestPaths() == ["/users/jwt/me"])
    }

    @Test("Restore at the renewal-window boundary validates the renewed identity exactly once")
    func renewalWindowRestoreReusesTheValidatedRefreshIdentity() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(300))
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
        #expect(await loader.requestPaths() == ["/users/jwt/refresh", "/users/jwt/me"])
    }

    @Test("Refresh never replaces V3 with a JWT expired during identity validation")
    func refreshedJWTExpiringDuringIdentityKeepsThePreviousEnvelope() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(300))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.shortLivedAccessResponse), .data(Self.identityResponse)],
            identityGate: gate
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)

        let restore = Task {
            try await controller.restore()
        }
        await gate.waitUntilArrived()
        clock.advance(by: 2)
        await gate.open()

        #expect(
            try await restore.value
                == .active(
                    SessionAccount(
                        authority: session.authority,
                        id: Self.userID,
                        email: nil,
                        isActive: nil,
                        isAdmin: nil,
                        role: nil
                    )
                )
        )
        #expect(storage.snapshot().record == session)
        #expect(await loader.requestPaths() == ["/users/jwt/refresh", "/users/jwt/me"])
    }

    @Test("Refresh never sends a newly expired JWT to identity")
    func refreshedJWTExpiredBeforeIdentityKeepsThePreviousEnvelope() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let refreshGate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.shortLivedAccessResponse),
                .data(Self.identityResponse),
            ],
            refreshGate: refreshGate
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        #expect(try await controller.restore() == .active(Self.remoteAccount))
        clock.advance(by: 301)

        let request = Task {
            try await controller.requestAuthorization()
        }
        await refreshGate.waitUntilArrived()
        clock.advanceAfterNextRead(by: 2)
        await refreshGate.open()

        await #expect(throws: SessionControllerError.contractDrift) {
            try await request.value
        }
        #expect(await loader.requestPaths() == ["/users/jwt/me", "/users/jwt/refresh"])
        #expect(storage.snapshot().record == session)
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
    }

    @Test("Refresh requires authentication when both JWTs expire during identity validation")
    func bothJWTsExpiringDuringIdentityRequireAuthentication() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(1))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.shortLivedAccessResponse), .data(Self.identityResponse)],
            identityGate: gate
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)

        let restore = Task {
            try await controller.restore()
        }
        await gate.waitUntilArrived()
        clock.advance(by: 2)
        await gate.open()

        #expect(try await restore.value == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
        #expect(await loader.requestPaths() == ["/users/jwt/refresh", "/users/jwt/me"])
    }

    @Test("Identity mismatch preserves authenticationRequired after the original JWT expires")
    func identityMismatchAfterOriginalExpiryRequiresAuthentication() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(1))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.renewedAccessResponse), .data(Self.identityResponseB)],
            identityGate: gate
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)

        let restore = Task {
            try await controller.restore()
        }
        await gate.waitUntilArrived()
        clock.advance(by: 2)
        await gate.open()

        #expect(try await restore.value == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
        #expect(await loader.requestPaths() == ["/users/jwt/refresh", "/users/jwt/me"])
    }

    @Test("Restore one second outside the renewal window reuses the current JWT")
    func restoreOutsideRenewalWindowDoesNotRefresh() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(301))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage)

        #expect(try await controller.restore() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record == session)
        #expect(await loader.requestPaths() == ["/users/jwt/me"])
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
        #expect(try await controller.authorizes(authorization))
    }

    @Test("Request authorization rechecks expiration immediately before emission")
    func requestAuthorizationNeverEmitsAnExpiredJWT() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        clock.advanceAfterNextRead(by: 601)

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await controller.requestAuthorization()
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
    }

    @Test("Post-transport authorization invalidates a JWT that expired in flight")
    func expiredRequestAuthorizationCannotCommit() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        let authorization = try await controller.requestAuthorization()
        clock.advance(by: 601)

        #expect(try await controller.authorizes(authorization) == false)
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
    }

    @Test("Post-transport expiry preserves a failed Keychain cleanup")
    func expiredRequestAuthorizationSurfacesCleanupFailure() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        let authorization = try await controller.requestAuthorization()
        storage.failNext(.removeAll, with: .temporarilyUnavailable)
        clock.advance(by: 601)

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.authorizes(authorization)
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == session)
    }

    @Test("Local commit authorization invalidates an expired session")
    func expiredSessionCannotAuthorizeALocalCommit() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        clock.advance(by: 601)

        #expect(try await controller.commitAuthorization(for: session.authority) == nil)
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
    }

    @Test("Authentication expiry grants only the exact invalidation commit")
    func expiredSessionInvokesExactInvalidationAuthorization() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let observer = SessionInvalidationObserverProbe()
        let controller = try makeController(
            loader: loader,
            storage: storage,
            clock: clock,
            authenticationInvalidationObserver: { authorization in
                observer.observe(authorization)
            }
        )
        _ = try await controller.restore()
        let normalAuthorization = try await controller.requestAuthorization()
        observer.install(normalAuthorization.commitAuthorization)
        clock.advance(by: 601)

        #expect(throws: SessionCommitAuthorizationError.credentialExpired) {
            try normalAuthorization.commitAuthorization.perform { true }
        }

        #expect(try await controller.commitAuthorization(for: session.authority) == nil)

        let evidence = observer.evidence()
        #expect(evidence.authorities == [session.authority])
        #expect(evidence.successfulInvalidationCommits == 1)
        #expect(evidence.rejectedNormalCommits == 1)
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
        let invalidationAuthorization = try #require(observer.latestAuthorization())
        #expect(throws: SessionCommitAuthorizationError.sessionChanged) {
            try invalidationAuthorization.perform { true }
        }
    }

    @Test("Caller cancellation cannot skip authentication invalidation persistence")
    func cancelledCallerStillRunsAuthenticationInvalidationObserver() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let observerSawCancellation = Atomic(false)
        let invalidationCommitCount = Mutex(0)
        let controller = try makeController(
            loader: loader,
            storage: storage,
            clock: clock,
            authenticationInvalidationObserver: { authorization in
                observerSawCancellation.store(Task.isCancelled, ordering: .releasing)
                try authorization.perform {
                    invalidationCommitCount.withLock {
                        $0 += 1
                    }
                }
            }
        )
        _ = try await controller.restore()
        clock.advance(by: 601)

        let task = Task {
            withUnsafeCurrentTask {
                $0?.cancel()
            }
            return try await controller.commitAuthorization(for: session.authority)
        }
        let authorization = try await task.value

        #expect(authorization == nil)
        let sawCancellation = observerSawCancellation.load(ordering: .acquiring)
        #expect(sawCancellation)
        #expect(invalidationCommitCount.withLock { $0 } == 1)
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
    }

    @Test("Local authorization expiry preserves a failed Keychain cleanup")
    func expiredLocalAuthorizationSurfacesCleanupFailure() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        storage.failNext(.removeAll, with: .temporarilyUnavailable)
        clock.advance(by: 601)

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.commitAuthorization(for: session.authority)
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == session)
    }

    @Test("A local commit capability rechecks expiry inside its synchronous transaction")
    func localCommitCapabilityCannotCrossExpiration() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        let authorization = try #require(try await controller.commitAuthorization(for: session.authority))
        clock.advance(by: 601)
        var didCommit = false

        #expect(throws: SessionCommitAuthorizationError.credentialExpired) {
            try authorization.perform {
                didCommit = true
            }
        }
        #expect(didCommit == false)
        #expect(try await controller.commitAuthorization(for: session.authority) == nil)
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
    }

    @Test(
        "A stale restore identity response cannot invalidate a renewed JWT",
        arguments: StaleRestoreIdentityReply.allCases
    )
    private func staleRestoreIdentityResponsePreservesRenewedJWT(
        oldReply: StaleRestoreIdentityReply
    ) async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = StaleRestoreIdentityDataLoader(gate: gate, oldReply: oldReply)
        let controller = try makeController(
            loadData: { request in
                try await loader.load(request)
            },
            storage: storage
        )

        let restore = Task {
            try await controller.restore()
        }
        await gate.waitUntilArrived()
        let rejectedAuthorization = try await controller.requestAuthorization()
        let renewedAuthorization = try await controller.recoverAuthorization(after: rejectedAuthorization)
        await gate.open()

        #expect(try await restore.value == .active(Self.remoteAccount))
        #expect(renewedAuthorization.accessToken == "fixture-access-renewed")
        #expect(storage.snapshot().record?.access.value == "fixture-access-renewed")
        #expect(try await controller.authorizes(renewedAuthorization))
        #expect(await loader.requestPaths() == ["/users/jwt/me", "/users/jwt/refresh", "/users/jwt/me"])
    }

    @Test(
        "A stale restore yields to the refresh that is still validating its replacement",
        arguments: StaleRestoreRefreshScenario.allCases
    )
    private func staleRestoreWaitsForInFlightRenewedIdentity(
        scenario: StaleRestoreRefreshScenario
    ) async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let oldIdentityGate = SessionRequestGate()
        let renewedIdentityGate = SessionRequestGate()
        let synchronizationGate = SessionRequestGate()
        let loader = StaleRestoreIdentityDataLoader(
            gate: oldIdentityGate,
            renewedIdentityGate: renewedIdentityGate,
            oldReply: scenario.oldReply,
            reusesJWTText: scenario.reusesJWTText
        )
        let controller = try makeController(
            loadData: { request in
                try await loader.load(request)
            },
            storage: storage,
            synchronizationObserver: { point in
                if point == .restorationAwaitingRefresh {
                    await synchronizationGate.suspendUntilOpen()
                }
            }
        )

        let restore = Task {
            try await controller.restore()
        }
        await oldIdentityGate.waitUntilArrived()
        let rejectedAuthorization = try await controller.requestAuthorization()
        let recovery = Task {
            try await controller.recoverAuthorization(after: rejectedAuthorization)
        }
        await renewedIdentityGate.waitUntilArrived()
        await oldIdentityGate.open()
        await loader.waitUntilOldReplyWasDelivered()
        await synchronizationGate.waitUntilArrived()

        #expect(await controller.currentSnapshot() == .active(Self.localAccount))
        #expect(storage.snapshot().record == session)

        await synchronizationGate.open()
        await renewedIdentityGate.open()
        let renewedAuthorization = try await recovery.value
        #expect(try await restore.value == .active(Self.remoteAccount))
        #expect(renewedAuthorization.accessToken == scenario.expectedAccessToken)
        #expect(storage.snapshot().record?.access.value == scenario.expectedAccessToken)
        #expect(try await controller.authorizes(renewedAuthorization))
    }

    @Test("An expiring stale restore yields to a refresh that is validating a usable replacement")
    func expiringRestoreWaitsForInFlightRenewedIdentity() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let oldIdentityGate = SessionRequestGate()
        let renewedIdentityGate = SessionRequestGate()
        let synchronizationGate = SessionRequestGate()
        let loader = StaleRestoreIdentityDataLoader(
            gate: oldIdentityGate,
            renewedIdentityGate: renewedIdentityGate,
            oldReply: .unauthorized,
            reusesJWTText: true
        )
        let controller = try makeController(
            loadData: { request in
                try await loader.load(request)
            },
            storage: storage,
            clock: clock,
            synchronizationObserver: { point in
                if point == .restorationAwaitingRefresh {
                    await synchronizationGate.suspendUntilOpen()
                }
            }
        )

        let restore = Task {
            try await controller.restore()
        }
        await oldIdentityGate.waitUntilArrived()
        let rejectedAuthorization = try await controller.requestAuthorization()
        let recovery = Task {
            try await controller.recoverAuthorization(after: rejectedAuthorization)
        }
        await renewedIdentityGate.waitUntilArrived()
        clock.advance(by: 601)
        await oldIdentityGate.open()
        await loader.waitUntilOldReplyWasDelivered()
        await synchronizationGate.waitUntilArrived()

        #expect(await controller.currentSnapshot() == .active(Self.localAccount))
        #expect(storage.snapshot().record == session)

        await synchronizationGate.open()
        await renewedIdentityGate.open()
        let renewedAuthorization = try await recovery.value
        #expect(try await restore.value == .active(Self.remoteAccount))
        #expect(renewedAuthorization.accessToken == "fixture-access")
        #expect(storage.snapshot().record?.access.value == "fixture-access")
        #expect(try await controller.authorizes(renewedAuthorization))
    }

    @Test("A coincident refresh cleanup failure remains visible to restoration")
    func coincidentRefreshCleanupFailurePropagatesFromRestore() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let deletionGate = SynchronousPersistenceGate()
        let storage = ControlledSessionPersistenceStorage(record: session, removeAllGate: deletionGate)
        storage.failNext(.removeAll, with: .temporarilyUnavailable)
        let identityGate = SessionRequestGate()
        let synchronizationGate = SessionRequestGate()
        let loader = CoincidentRefreshCleanupDataLoader(identityGate: identityGate)
        let controller = try makeController(
            loadData: { request in
                try await loader.load(request)
            },
            storage: storage,
            synchronizationObserver: { point in
                if point == .restorationAwaitingRefresh {
                    await synchronizationGate.suspendUntilOpen()
                }
            }
        )
        let restore = Task {
            try await controller.restore()
        }
        await identityGate.waitUntilArrived()
        let rejectedAuthorization = try await controller.requestAuthorization()
        let recovery = Task {
            try await controller.recoverAuthorization(after: rejectedAuthorization)
        }
        await deletionGate.waitUntilEntered()
        await identityGate.open()
        await synchronizationGate.waitUntilArrived()
        await synchronizationGate.open()
        deletionGate.open()

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await recovery.value
        }
        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await restore.value
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == session)
    }

    @Test("A cancelled refresh waiter still receives an authoritative cleanup failure")
    func cancelledRefreshWaiterPreservesCleanupFailure() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let deletionGate = SynchronousPersistenceGate()
        let storage = ControlledSessionPersistenceStorage(record: session, removeAllGate: deletionGate)
        storage.failNext(.removeAll, with: .temporarilyUnavailable)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse), .network(.statusCode(401))])
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()
        let authorization = try await controller.requestAuthorization()
        let recovery = Task {
            try await controller.recoverAuthorization(after: authorization)
        }
        await deletionGate.waitUntilEntered()
        recovery.cancel()
        deletionGate.open()

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await recovery.value
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == session)
    }

    @Test("A cancelled refresh waiter still receives an authoritative replacement failure")
    func cancelledRefreshWaiterPreservesReplacementFailure() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let saveGate = SynchronousPersistenceGate()
        let storage = ControlledSessionPersistenceStorage(record: session, saveGate: saveGate)
        storage.failNext(.save, with: .temporarilyUnavailable)
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

        let recovery = Task {
            try await controller.recoverAuthorization(after: authorization)
        }
        await saveGate.waitUntilEntered()
        recovery.cancel()
        saveGate.open()

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await recovery.value
        }
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record == session)
        #expect(await loader.requestPaths() == ["/users/jwt/me", "/users/jwt/refresh", "/users/jwt/me"])
    }

    @Test("A rejected unexpired JWT forces refresh and identity validation")
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
        #expect(try await controller.authorizes(rejectedAuthorization) == false)
        #expect(try await controller.authorizes(renewedAuthorization))
        #expect(await loader.requestPaths() == ["/users/jwt/me", "/users/jwt/refresh", "/users/jwt/me"])
    }

    @Test("A same-text renewed JWT rotates the opaque request and commit identity")
    func sameTextRenewedJWTInvalidatesPriorCapabilities() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.sameTextRenewedAccessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()
        let prior = try await controller.requestAuthorization()

        let renewed = try await controller.recoverAuthorization(after: prior)

        #expect(prior.accessToken == renewed.accessToken)
        #expect(try await controller.authorizes(prior) == false)
        #expect(try await controller.authorizes(renewed))
        #expect(throws: SessionCommitAuthorizationError.sessionChanged) {
            try prior.commitAuthorization.perform { true }
        }
        #expect(try renewed.commitAuthorization.perform { true })
        await #expect(throws: SessionControllerError.sessionChanged) {
            try await controller.recoverAuthorization(after: prior)
        }
        #expect(await loader.requestPaths() == ["/users/jwt/me", "/users/jwt/refresh", "/users/jwt/me"])
        #expect(storage.snapshot().record?.access.value == renewed.accessToken)
        #expect(storage.snapshot().record?.access.expiresAt == Self.now.addingTimeInterval(86_400))
    }

    @Test("A permanently rejected forced refresh requires authentication", arguments: [401, 403])
    func rejectedAuthorizationWithRejectedRefreshRequiresAuthentication(statusCode: Int) async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.identityResponse), .network(.statusCode(statusCode))]
        )
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()
        let authorization = try await controller.requestAuthorization()

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await controller.recoverAuthorization(after: authorization)
        }

        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
        #expect(try await controller.authorizes(authorization) == false)
    }

    @Test("A permanently rejected refresh grants only the exact invalidation commit")
    func rejectedRefreshInvokesExactInvalidationAuthorization() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse), .network(.statusCode(401))])
        let observer = SessionInvalidationObserverProbe()
        let controller = try makeController(
            loader: loader,
            storage: storage,
            authenticationInvalidationObserver: { authorization in
                observer.observe(authorization)
            }
        )
        _ = try await controller.restore()
        let normalAuthorization = try await controller.requestAuthorization()
        observer.install(normalAuthorization.commitAuthorization)

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await controller.recoverAuthorization(after: normalAuthorization)
        }

        let evidence = observer.evidence()
        #expect(evidence.authorities == [session.authority])
        #expect(evidence.successfulInvalidationCommits == 1)
        #expect(evidence.rejectedNormalCommits == 1)
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
    }

    @Test("An invalidation observer failure cannot preserve rejected credentials")
    func failedInvalidationObserverDoesNotPreventAuthenticationCleanup() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse), .network(.statusCode(401))])
        let observerWasInvoked = Atomic(false)
        let controller = try makeController(
            loader: loader,
            storage: storage,
            authenticationInvalidationObserver: { _ in
                observerWasInvoked.store(true, ordering: .releasing)
                throw SessionInvalidationObserverTestError.expected
            }
        )
        _ = try await controller.restore()
        let authorization = try await controller.requestAuthorization()

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await controller.recoverAuthorization(after: authorization)
        }

        let wasInvoked = observerWasInvoked.load(ordering: .acquiring)
        #expect(wasInvoked)
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
        #expect(try await controller.authorizes(authorization) == false)
        #expect(throws: SessionCommitAuthorizationError.sessionChanged) {
            try authorization.commitAuthorization.perform { true }
        }
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
        #expect(try await controller.authorizes(authorization) == false)
    }

    @Test("A refreshed JWT mapped to another user invalidates the exact session")
    func renewedJWTWithDifferentIdentityRequiresAuthentication() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponseB),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage)
        _ = try await controller.restore()
        let authorization = try await controller.requestAuthorization()

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await controller.recoverAuthorization(after: authorization)
        }

        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
        #expect(try await controller.authorizes(authorization) == false)
        #expect(await loader.requestPaths() == ["/users/jwt/me", "/users/jwt/refresh", "/users/jwt/me"])
    }

    @Test("A late rejection from generation A cannot invalidate generation B")
    func staleGenerationRejectionPreservesReplacementSession() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
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

        #expect(await controller.currentSnapshot() == .active(Self.remoteAccountGenerationB))
        #expect(storage.snapshot().record?.generation == Self.generationB)
    }

    @Test("A late rejection for an old JWT preserves its renewed generation")
    func staleJWTRejectionCannotInvalidateRenewedCredential() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
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
        #expect(try await controller.authorizes(staleAuthorization) == false)
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
        while invalidationStarted.load(ordering: .acquiring) == false {
            await Task.yield()
        }

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
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.identityResponse), .data(Self.renewedAccessResponse)],
            refreshGate: gate
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        clock.advance(by: 120)

        let authorization = Task {
            try await controller.requestAuthorization()
        }
        await gate.waitUntilArrived()
        #expect(try await controller.logout() == .signedOut)
        await gate.open()

        await #expect(throws: SessionControllerError.sessionChanged) {
            try await authorization.value
        }
        #expect(storage.snapshot().record == nil)
    }

    @Test("Concurrent requests inside the renewal window share one refresh and identity validation")
    func concurrentPreventiveRequestsShareTheValidatedRefreshFlight() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let joiningGate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewalWindowAccessResponse),
                .data(Self.identityResponse),
            ],
            refreshGate: gate
        )
        let controller = try makeController(
            loader: loader,
            storage: storage,
            clock: clock,
            synchronizationObserver: { point in
                if point == .accessCredentialAwaitingRefresh {
                    await joiningGate.suspendUntilOpen()
                }
            }
        )
        _ = try await controller.restore()
        clock.advance(by: 120)

        let first = Task {
            try await controller.accessCredential()
        }
        await gate.waitUntilArrived()
        let second = Task {
            try await controller.accessCredential()
        }
        await joiningGate.waitUntilArrived()
        await joiningGate.open()
        await gate.open()

        let firstCredential = try await first.value
        let secondCredential = try await second.value
        #expect(firstCredential.value == "fixture-access-renewed")
        #expect(secondCredential == firstCredential)
        #expect(await loader.requestPaths().filter { $0 == "/users/jwt/refresh" }.count == 1)
        #expect(await loader.requestPaths().filter { $0 == "/users/jwt/me" }.count == 2)
        #expect(storage.snapshot().record?.authority == session.authority)
    }

    @Test("Authorization entering during ordinary refresh shares the renewed access")
    func authorizationEnteringDuringRefreshSharesTheRenewedAccess() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let joiningGate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewalWindowAccessResponse),
                .data(Self.identityResponse),
            ],
            refreshGate: gate
        )
        let controller = try makeController(
            loader: loader,
            storage: storage,
            clock: clock,
            synchronizationObserver: { point in
                if point == .accessCredentialAwaitingRefresh {
                    await joiningGate.suspendUntilOpen()
                }
            }
        )
        _ = try await controller.restore()
        clock.advance(by: 120)

        let refresh = Task {
            try await controller.accessCredential()
        }
        await gate.waitUntilArrived()
        let authorization = Task {
            try await controller.requestAuthorization()
        }
        await joiningGate.waitUntilArrived()
        await joiningGate.open()
        await gate.open()

        let renewedCredential = try await refresh.value
        let renewedAuthorization = try await authorization.value
        #expect(renewedAuthorization.accessToken == renewedCredential.value)
        #expect(try await controller.authorizes(renewedAuthorization))
        #expect(await loader.requestPaths().filter { $0 == "/users/jwt/refresh" }.count == 1)
        #expect(await loader.requestPaths().filter { $0 == "/users/jwt/me" }.count == 2)
        #expect(storage.snapshot().record?.authority == session.authority)
    }

    @Test("A replacement session ignores a residual refresh flight")
    func replacementSessionIgnoresResidualRefreshFlight() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = ResidualRefreshDataLoader(gate: gate)
        let controller = try makeController(
            loadData: { request in
                try await loader.load(request)
            },
            storage: storage,
            clock: clock,
            generationFactory: { Self.generationB }
        )
        _ = try await controller.restore()
        clock.advance(by: 120)

        let residualRefresh = Task {
            try await controller.accessCredential()
        }
        await gate.waitUntilArrived()
        #expect(try await controller.logout() == .signedOut)
        #expect(
            try await controller.login(email: "b@example.invalid", password: "synthetic-passphrase-b")
                == .active(Self.remoteAccountB)
        )

        let authorization = try await controller.requestAuthorization()
        #expect(authorization.authority == SessionAuthority(userID: Self.userB, generation: Self.generationB))
        #expect(authorization.accessToken == "fixture-access-b")
        #expect(try await controller.authorizes(authorization))

        let recoveredAuthorization = try await controller.recoverAuthorization(after: authorization)
        #expect(recoveredAuthorization.authority == authorization.authority)
        #expect(recoveredAuthorization.accessToken == "fixture-access-b-renewed")
        #expect(try await controller.authorizes(authorization) == false)
        #expect(try await controller.authorizes(recoveredAuthorization))

        await gate.open()
        await #expect(throws: SessionControllerError.sessionChanged) {
            try await residualRefresh.value
        }
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccountB))
        #expect(storage.snapshot().record?.authority == recoveredAuthorization.authority)
        #expect(storage.snapshot().record?.access.value == recoveredAuthorization.accessToken)
        #expect(await loader.requestPaths() == [
            "/users/jwt/me",
            "/users/jwt/refresh",
            "/users/jwt/login",
            "/users/jwt/me",
            "/users/jwt/refresh",
            "/users/jwt/me",
        ])
    }

    @Test("A completed refresh cannot return its same-text JWT after the account is replaced")
    func completedRefreshCannotSupplyAReplacementSession() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let completionGate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewalWindowAccessResponse),
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponseB),
            ]
        )
        let controller = try makeController(
            loader: loader,
            storage: storage,
            clock: clock,
            generationFactory: { Self.generationB },
            synchronizationObserver: { point in
                if point == .accessCredentialResolvedRefresh {
                    await completionGate.suspendUntilOpen()
                }
            }
        )
        _ = try await controller.restore()
        clock.advance(by: 120)

        let staleAccess = Task {
            try await controller.accessCredential()
        }
        await completionGate.waitUntilArrived()
        #expect(try await controller.logout() == .signedOut)
        #expect(
            try await controller.login(email: "b@example.invalid", password: "synthetic-passphrase-b")
                == .active(Self.remoteAccountB)
        )
        await completionGate.open()

        await #expect(throws: SessionControllerError.sessionChanged) {
            try await staleAccess.value
        }
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccountB))
        #expect(storage.snapshot().record?.authority == Self.remoteAccountB.authority)
    }

    @Test("A resolved refresh cannot return after its JWT starts a replacement refresh")
    func resolvedRefreshCannotReturnARejectedJWT() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let completionGate = SessionRequestGate()
        let secondRefreshGate = SessionRequestGate()
        let loader = RejectedResolvedCredentialDataLoader(secondRefreshGate: secondRefreshGate)
        let controller = try makeController(
            loadData: { request in
                try await loader.load(request)
            },
            storage: storage,
            clock: clock,
            synchronizationObserver: { point in
                if point == .accessCredentialResolvedRefresh {
                    await completionGate.suspendUntilOpen()
                }
            }
        )
        _ = try await controller.restore()
        clock.advance(by: 120)

        let staleAccess = Task {
            try await controller.accessCredential()
        }
        await completionGate.waitUntilArrived()
        let rejectedAuthorization = try await controller.requestAuthorization()
        #expect(rejectedAuthorization.accessToken == "fixture-access-renewed")

        let recovery = Task {
            try await controller.recoverAuthorization(after: rejectedAuthorization)
        }
        await secondRefreshGate.waitUntilArrived()
        await completionGate.open()

        await #expect(throws: SessionControllerError.sessionChanged) {
            try await staleAccess.value
        }

        await secondRefreshGate.open()
        let recoveredAuthorization = try await recovery.value
        #expect(recoveredAuthorization.accessToken == "fixture-access-renewed-again")
        #expect(try await controller.authorizes(recoveredAuthorization))
        #expect(storage.snapshot().record?.access.value == recoveredAuthorization.accessToken)
        #expect(await loader.requestPaths() == [
            "/users/jwt/me",
            "/users/jwt/refresh",
            "/users/jwt/me",
            "/users/jwt/refresh",
            "/users/jwt/me",
        ])
    }

    @Test("A recovery waiter joins a replacement refresh before returning an intermediate JWT")
    func recoveryWaiterJoinsReplacementRefresh() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let resolvedGate = SessionRequestGate()
        let joiningGate = SessionRequestGate()
        let secondRefreshGate = SessionRequestGate()
        let loader = RejectedResolvedCredentialDataLoader(secondRefreshGate: secondRefreshGate)
        let controller = try makeController(
            loadData: { request in
                try await loader.load(request)
            },
            storage: storage,
            synchronizationObserver: { point in
                switch point {
                case .authorizationRecoveryResolvedRefresh:
                    await resolvedGate.suspendUntilOpen()
                case .authorizationRecoveryAwaitingRefresh:
                    await joiningGate.suspendUntilOpen()
                default:
                    break
                }
            }
        )
        _ = try await controller.restore()
        let initialAuthorization = try await controller.requestAuthorization()

        let initialRecovery = Task {
            try await controller.recoverAuthorization(after: initialAuthorization)
        }
        await resolvedGate.waitUntilArrived()
        let intermediateAuthorization = try await controller.requestAuthorization()
        #expect(intermediateAuthorization.accessToken == "fixture-access-renewed")

        let replacementRecovery = Task {
            try await controller.recoverAuthorization(after: intermediateAuthorization)
        }
        await secondRefreshGate.waitUntilArrived()
        await resolvedGate.open()
        await joiningGate.waitUntilArrived()
        await joiningGate.open()
        await secondRefreshGate.open()

        let initialResult = try await initialRecovery.value
        let replacementResult = try await replacementRecovery.value
        #expect(initialResult.accessToken == "fixture-access-renewed-again")
        #expect(replacementResult.accessToken == initialResult.accessToken)
        #expect(try await controller.authorizes(initialResult))
        #expect(storage.snapshot().record?.access.value == initialResult.accessToken)
        #expect(await loader.requestPaths() == [
            "/users/jwt/me",
            "/users/jwt/refresh",
            "/users/jwt/me",
            "/users/jwt/refresh",
            "/users/jwt/me",
        ])
    }

    @Test("A stale refresh error cannot leak into a replacement session", arguments: StaleRefreshFailureStage.allCases)
    private func staleRefreshErrorIsSessionChanged(stage: StaleRefreshFailureStage) async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = StaleRefreshFailureDataLoader(gate: gate, stage: stage)
        let controller = try makeController(
            loadData: { request in
                try await loader.load(request)
            },
            storage: storage,
            clock: clock,
            generationFactory: { Self.generationB }
        )
        _ = try await controller.restore()
        clock.advance(by: 120)

        let staleRefresh = Task {
            try await controller.accessCredential()
        }
        await gate.waitUntilArrived()
        #expect(try await controller.logout() == .signedOut)
        #expect(
            try await controller.login(email: "b@example.invalid", password: "synthetic-passphrase-b")
                == .active(Self.remoteAccountB)
        )
        await gate.open()

        await #expect(throws: SessionControllerError.sessionChanged) {
            try await staleRefresh.value
        }
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccountB))
        #expect(
            storage.snapshot().record?.authority
                == SessionAuthority(userID: Self.userB, generation: Self.generationB)
        )
        #expect(storage.snapshot().record?.access.value == "fixture-access-b")
    }

    @Test("An ordinary refresh rejected by identity never replaces the session envelope", arguments: [401, 403])
    func ordinaryRefreshRejectedByIdentityKeepsTheSession(statusCode: Int) async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .network(.statusCode(statusCode)),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        clock.advance(by: 120)

        await #expect(throws: SessionAuthorizationRecoveryError.identityRejected(statusCode: statusCode)) {
            try await controller.accessCredential()
        }

        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record == session)
        #expect(await loader.requestPaths() == ["/users/jwt/me", "/users/jwt/refresh", "/users/jwt/me"])
    }

    @Test("Forced recovery and an access request share one refresh")
    func forcedRecoverySharesTheRefreshFlight() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let joiningGate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewalWindowAccessResponse),
                .data(Self.identityResponse),
            ],
            refreshGate: gate
        )
        let controller = try makeController(
            loader: loader,
            storage: storage,
            synchronizationObserver: { point in
                if point == .accessCredentialAwaitingRefresh {
                    await joiningGate.suspendUntilOpen()
                }
            }
        )
        _ = try await controller.restore()
        let rejectedAuthorization = try await controller.requestAuthorization()

        let recovery = Task {
            try await controller.recoverAuthorization(after: rejectedAuthorization)
        }
        await gate.waitUntilArrived()
        let access = Task {
            try await controller.accessCredential()
        }
        await joiningGate.waitUntilArrived()
        await joiningGate.open()
        await gate.open()

        let recoveredAuthorization = try await recovery.value
        let sharedCredential = try await access.value
        #expect(recoveredAuthorization.accessToken == "fixture-access-renewed")
        #expect(sharedCredential.value == recoveredAuthorization.accessToken)
        #expect(await loader.requestPaths().filter { $0 == "/users/jwt/refresh" }.count == 1)
        #expect(await loader.requestPaths().filter { $0 == "/users/jwt/me" }.count == 2)
        #expect(storage.snapshot().record?.authority == session.authority)
    }

    @Test("A local authorization waiting on refresh cannot cross an ABA generation change")
    func localAuthorizationWaitingForRefreshRejectsSameUserReplacement() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let refreshGate = SessionRequestGate()
        let synchronizationGate = SessionRequestGate()
        let loader = RefreshABADataLoader(refreshGate: refreshGate)
        let controller = try makeController(
            loadData: { request in
                try await loader.load(request)
            },
            storage: storage,
            generationFactory: { Self.generationB },
            synchronizationObserver: { point in
                if point == .localAuthorizationAwaitingRefresh {
                    await synchronizationGate.suspendUntilOpen()
                }
            }
        )
        _ = try await controller.restore()
        let rejectedAuthorization = try await controller.requestAuthorization()
        let recovery = Task {
            try await controller.recoverAuthorization(after: rejectedAuthorization)
        }
        await refreshGate.waitUntilArrived()
        let localAuthorization = Task {
            try await controller.commitAuthorization(for: rejectedAuthorization.authority)
        }
        await synchronizationGate.waitUntilArrived()

        #expect(try await controller.logout() == .signedOut)
        #expect(
            try await controller.login(
                email: "reader@example.invalid",
                password: "synthetic-passphrase"
            ) == .active(Self.remoteAccountGenerationB)
        )
        await synchronizationGate.open()
        await refreshGate.open()

        await #expect(throws: SessionControllerError.sessionChanged) {
            try await recovery.value
        }
        await #expect(throws: SessionControllerError.sessionChanged) {
            try await localAuthorization.value
        }
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccountGenerationB))
        #expect(storage.snapshot().record?.generation == Self.generationB)
        #expect(storage.snapshot().record?.access.value == "fixture-access-login-B")
        #expect(
            await loader.requestPaths()
                == ["/users/jwt/me", "/users/jwt/refresh", "/users/jwt/login", "/users/jwt/me"]
        )
    }

    @Test("A transient refresh failure preserves authority and remains retryable")
    func transientRefreshFailureKeepsTheSession() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
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
        #expect(storage.snapshot().record?.authority == session.authority)
    }

    @Test("A transient refresh failure cannot preserve a JWT that expired in flight")
    func transientRefreshFailureAfterExpiryRequiresAuthentication() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(
            replies: [.data(Self.identityResponse), .network(.statusCode(503))],
            refreshGate: gate
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        clock.advance(by: 120)

        let refresh = Task {
            try await controller.accessCredential()
        }
        await gate.waitUntilArrived()
        clock.advance(by: 241)
        await gate.open()

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await refresh.value
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
    }

    @Test("A renewed JWT expiring during Keychain replacement is never published")
    func renewedJWTExpiringDuringPersistenceRequiresAuthentication() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let saveGate = SynchronousPersistenceGate()
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session, saveGate: saveGate)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.shortLivedAccessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        let authorization = try await controller.requestAuthorization()

        let recovery = Task {
            try await controller.recoverAuthorization(after: authorization)
        }
        await saveGate.waitUntilEntered()
        clock.advance(by: 2)
        saveGate.open()

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await recovery.value
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
    }

    @Test("Logout cannot cross the durable JWT replacement")
    func logoutWaitsForTheRefreshCommitBoundary() async throws(any Error) {
        let saveGate = SynchronousPersistenceGate()
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session, saveGate: saveGate)
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

        let recovery = Task {
            try await controller.recoverAuthorization(after: authorization)
        }
        await saveGate.waitUntilEntered()
        await #expect(throws: SessionControllerError.transitionInProgress) {
            try await controller.logout()
        }
        saveGate.open()

        let renewedAuthorization = try await recovery.value
        #expect(renewedAuthorization.accessToken == "fixture-access-renewed")
        #expect(storage.snapshot().record?.access.value == "fixture-access-renewed")
        storage.failNext(.removeAll, with: .temporarilyUnavailable)
        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.logout()
        }
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record?.access.value == "fixture-access-renewed")
        #expect(try await controller.requestAuthorization().accessToken == "fixture-access-renewed")
    }

    @Test("A failed JWT replacement cannot retain an original credential that expired in flight")
    func failedPersistenceAfterOriginalExpiryRequiresAuthentication() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let saveGate = SynchronousPersistenceGate()
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session, saveGate: saveGate)
        storage.failNext(.save, with: .temporarilyUnavailable)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        let authorization = try await controller.requestAuthorization()

        let recovery = Task {
            try await controller.recoverAuthorization(after: authorization)
        }
        await saveGate.waitUntilEntered()
        clock.advance(by: 601)
        saveGate.open()

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await recovery.value
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
    }

    @Test("A permanent refresh rejection removes credentials and requires sign in")
    func rejectedRefreshRequiresAuthentication() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
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
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
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
        #expect(await loader.requestPaths().filter { $0 == "/users/jwt/refresh" }.count == 1)
    }

    @Test("Sign in replaces only the rejected generation left after failed cleanup")
    func signInReplacesTheResidualRejectedGeneration() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .network(.statusCode(401)),
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

        #expect(snapshot == .active(Self.remoteAccountGenerationB))
        #expect(storage.snapshot().record?.generation == Self.generationB)
        #expect(storage.snapshot().record?.access.value == "fixture-access")
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

    @Test("Pending Collection work aborts logout and rotates the reactivated commit gate")
    func pendingCollectionWorkKeepsTheExactSessionActive() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let probe = SessionPendingLogoutProbe()
        let controller = try makeController(
            loader: loader,
            storage: storage,
            logoutPendingChangesObserver: { authorization in
                try probe.inspect(authorization)
            },
            logoutPendingChangesDiscarder: { authorization in
                try probe.discard(authorization)
            }
        )
        _ = try await controller.restore()
        let authorizationBeforeLogout = try await controller.requestAuthorization()
        probe.install(authorizationBeforeLogout.commitAuthorization)

        await #expect(throws: SessionControllerError.pendingCollectionChanges) {
            try await controller.logout()
        }

        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record == session)
        #expect(try await controller.authorizes(authorizationBeforeLogout) == false)
        let authorizationAfterLogout = try await controller.requestAuthorization()
        #expect(try await controller.authorizes(authorizationAfterLogout))
        #expect(
            probe.evidence()
                == .init(inspections: 1, discards: 0, successfulLogoutCommits: 1, rejectedNormalCommits: 1)
        )
    }

    @Test("Another account cannot activate while logout inspects pending work")
    func loginCannotActivateDuringPendingWorkInspection() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let inspectionGate = SessionRequestGate()
        let controller = try makeController(
            loader: loader,
            storage: storage,
            logoutPendingChangesObserver: { authorization in
                _ = try authorization.perform { true }
                await inspectionGate.suspendUntilOpen()
                return true
            }
        )
        _ = try await controller.restore()

        let logout = Task {
            try await controller.logout()
        }
        await inspectionGate.waitUntilArrived()
        await #expect(throws: SessionControllerError.transitionInProgress) {
            try await controller.login(email: "b@example.invalid", password: "synthetic-passphrase-b")
        }
        await inspectionGate.open()

        await #expect(throws: SessionControllerError.pendingCollectionChanges) {
            try await logout.value
        }
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record == session)
    }

    @Test("Cancellation after pending-work inspection never requests a logout decision")
    func cancellationAfterPendingInspectionKeepsTheExactSessionActive() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(
            loader: loader,
            storage: storage,
            logoutPendingChangesObserver: { authorization in
                _ = try authorization.perform { true }
                withUnsafeCurrentTask { task in
                    task?.cancel()
                }
                return true
            }
        )
        _ = try await controller.restore()

        let logout = Task {
            try await controller.logout()
        }

        await #expect(throws: CancellationError.self) {
            try await logout.value
        }
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record == session)
        #expect(storage.snapshot().journal.filter { $0 == .removeAll }.isEmpty)
    }

    @Test("A failed discard keeps Keychain and the active session untouched")
    func failedPendingChangesDiscardAbortsLogout() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(
            loader: loader,
            storage: storage,
            logoutPendingChangesDiscarder: { _ in
                throw SessionControllerError.pendingCollectionPersistenceUnavailable
            }
        )
        _ = try await controller.restore()

        await #expect(throws: SessionControllerError.pendingCollectionPersistenceUnavailable) {
            try await controller.logout(discardPendingChanges: true)
        }

        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record == session)
        #expect(storage.snapshot().journal.filter { $0 == .removeAll }.isEmpty)
    }

    @Test("A discard failure does not claim an expired session remains active")
    func failedPendingChangesDiscardAfterExpirationRequiresAuthentication() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(
            loader: loader,
            storage: storage,
            clock: clock,
            logoutPendingChangesDiscarder: { _ in
                clock.advance(by: 601)
                throw SessionControllerError.pendingCollectionPersistenceUnavailable
            }
        )
        _ = try await controller.restore()

        await #expect(throws: SessionControllerError.pendingCollectionPersistenceUnavailable) {
            try await controller.logout(discardPendingChanges: true)
        }

        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == session)
        #expect(storage.snapshot().journal.filter { $0 == .removeAll }.isEmpty)
    }

    @Test("A discarded outbox remains resolved when Keychain deletion fails and logout retries")
    func failedKeychainDeletionDoesNotResurrectDiscardedWork() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let probe = SessionPendingLogoutProbe()
        let controller = try makeController(
            loader: loader,
            storage: storage,
            logoutPendingChangesObserver: { authorization in
                try probe.inspect(authorization)
            },
            logoutPendingChangesDiscarder: { authorization in
                try probe.discard(authorization)
            }
        )
        _ = try await controller.restore()
        await #expect(throws: SessionControllerError.pendingCollectionChanges) {
            try await controller.logout()
        }
        storage.failNext(.removeAll, with: .temporarilyUnavailable)

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await controller.logout(discardPendingChanges: true)
        }
        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record == session)
        #expect(probe.evidence().discards == 1)

        #expect(try await controller.logout() == .signedOut)
        #expect(storage.snapshot().record == nil)
        #expect(
            probe.evidence()
                == .init(inspections: 2, discards: 1, successfulLogoutCommits: 3, rejectedNormalCommits: 0)
        )
    }

    @Test("A cancelled discard never starts Keychain deletion")
    func cancelledPendingChangesDiscardAbortsLogout() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(
            loader: loader,
            storage: storage,
            logoutPendingChangesDiscarder: { _ in
                throw CancellationError()
            }
        )
        _ = try await controller.restore()

        await #expect(throws: CancellationError.self) {
            try await controller.logout(discardPendingChanges: true)
        }

        #expect(await controller.currentSnapshot() == .active(Self.remoteAccount))
        #expect(storage.snapshot().record == session)
        #expect(storage.snapshot().journal.filter { $0 == .removeAll }.isEmpty)
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

    @Test("A failed logout cannot reactivate a JWT that expired during Keychain deletion")
    func failedLogoutAfterExpirationRequiresAuthentication() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let deletionGate = SynchronousPersistenceGate()
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session, removeAllGate: deletionGate)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        storage.failNext(.removeAll, with: .temporarilyUnavailable)

        let logout = Task {
            try await controller.logout()
        }
        await deletionGate.waitUntilEntered()
        clock.advance(by: 601)
        deletionGate.open()

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await logout.value
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == session)
        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await controller.requestAuthorization()
        }
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

        let logout = Task {
            try await controller.logout()
        }
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
        #expect(try await controller.authorizes(authorization) == false)

        let renewedAuthorization = try await controller.requestAuthorization()
        #expect(renewedAuthorization.accessToken == "fixture-access-renewed")
        #expect(try await controller.authorizes(renewedAuthorization))
        #expect(storage.snapshot().record?.access.value == "fixture-access-renewed")
    }

    @Test("A stale rejection during failed logout preserves the renewed access")
    func staleRejectionDuringFailedLogoutPreservesRenewedAccess() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let deletionGate = SynchronousPersistenceGate()
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(360))
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

        let logout = Task {
            try await controller.logout()
        }
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
        #expect(try await controller.authorizes(staleAuthorization) == false)
        #expect(try await controller.authorizes(renewedAuthorization) == false)
        let currentAuthorization = try await controller.requestAuthorization()
        #expect(currentAuthorization.accessToken == renewedAuthorization.accessToken)
        #expect(try await controller.authorizes(currentAuthorization))
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
                        authority: session.authority,
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

        let logout = Task {
            try await controller.logout()
        }

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

        let logout = Task {
            try await controller.logout()
        }
        await deletionGate.waitUntilEntered()

        await #expect(throws: SessionControllerError.transitionInProgress) {
            try await controller.login(email: "b@example.invalid", password: "synthetic-passphrase-b")
        }
        #expect(storage.snapshot().record == session)
        #expect(await loader.requestPaths() == ["/users/jwt/me"])

        deletionGate.open()
        #expect(try await logout.value == .signedOut)
        #expect(storage.snapshot().record == nil)
    }

    @Test("An expired JWT removes the local session without a network call")
    func expiredJWTRequiresAuthenticationLocally() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now)
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [])
        let controller = try makeController(loader: loader, storage: storage)

        #expect(try await controller.restore() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
        #expect(await loader.requestPaths().isEmpty)
    }

    @Test("A cancelled restore still reports failed cleanup of an expired JWT")
    func cancelledRestorePreservesExpiredCredentialCleanupFailure() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now)
        let deletionGate = SynchronousPersistenceGate()
        let storage = ControlledSessionPersistenceStorage(record: session, removeAllGate: deletionGate)
        storage.failNext(.removeAll, with: .temporarilyUnavailable)
        let loader = ScriptedSessionDataLoader(replies: [])
        let controller = try makeController(loader: loader, storage: storage)

        let restore = Task {
            try await controller.restore()
        }
        await deletionGate.waitUntilEntered()
        restore.cancel()
        deletionGate.open()

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await restore.value
        }
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == session)
        #expect(await loader.requestPaths().isEmpty)
    }

    @Test("A cancelled restore waiter still receives an authoritative load failure")
    func cancelledRestoreWaiterPreservesLoadFailure() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let loadGate = SynchronousPersistenceGate()
        let storage = ControlledSessionPersistenceStorage(record: session, loadGate: loadGate)
        storage.failNext(.load, with: .temporarilyUnavailable)
        let loader = ScriptedSessionDataLoader(replies: [])
        let controller = try makeController(loader: loader, storage: storage)

        let restore = Task {
            try await controller.restore()
        }
        await loadGate.waitUntilEntered()
        restore.cancel()
        loadGate.open()

        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await restore.value
        }
        #expect(await controller.currentSnapshot() == .notRestored)
        #expect(storage.snapshot().record == session)
        #expect(await loader.requestPaths().isEmpty)
    }

    @Test("Refresh rechecks JWT validity immediately before the network request")
    func JWTExpiringBeforeRefreshStartsRequiresAuthentication() async throws(any Error) {
        let clock = TestSessionClock(now: Self.now)
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeController(loader: loader, storage: storage, clock: clock)
        _ = try await controller.restore()
        let authorization = try await controller.requestAuthorization()
        clock.advanceAfterNextRead(by: 601)

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await controller.recoverAuthorization(after: authorization)
        }

        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userID))
        #expect(storage.snapshot().record == nil)
        #expect(await loader.requestPaths() == ["/users/jwt/me"])
    }

    @Test("Cancelling one restore waiter does not cancel shared restoration")
    func cancelledRestoreWaiterDoesNotCancelTheFlight() async throws(any Error) {
        let session = try makeSession(accessExpiresAt: Self.now.addingTimeInterval(600))
        let storage = ControlledSessionPersistenceStorage(record: session)
        let gate = SessionRequestGate()
        let loader = ScriptedSessionDataLoader(replies: [.data(Self.identityResponse)], identityGate: gate)
        let controller = try makeController(loader: loader, storage: storage)

        let cancelled = Task {
            try await controller.restore()
        }
        await gate.waitUntilArrived()
        let remaining = Task {
            try await controller.restore()
        }
        cancelled.cancel()
        await gate.open()

        await #expect(throws: CancellationError.self) {
            try await cancelled.value
        }
        #expect(try await remaining.value == .active(Self.remoteAccount))
        #expect(storage.snapshot().journal.filter { $0 == .load }.count == 1)
    }

    @Test("A superseded login cannot replace the newer account")
    func lateLoginCannotReplaceTheNewerAccount() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        let gate = SessionRequestGate()
        let loader = ConcurrentLoginDataLoader(gate: gate)
        let controller = try makeController(
            loadData: { request in
                try await loader.load(request)
            },
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

        #expect(accountB == .active(Self.remoteAccountBGenerationA))
        await #expect(throws: SessionControllerError.sessionChanged) {
            try await loginA.value
        }
        #expect(storage.snapshot().record?.userID == Self.userB)
    }

    private func makeController(
        loader: ScriptedSessionDataLoader,
        storage: ControlledSessionPersistenceStorage,
        clock: TestSessionClock = TestSessionClock(now: Self.now),
        generationFactory: @escaping @Sendable () -> UUID = { Self.generation },
        synchronizationObserver: @escaping SessionController.SynchronizationObserver = { _ in },
        logoutPendingChangesObserver: @escaping SessionController.LogoutPendingChangesObserver = { _ in false },
        logoutPendingChangesDiscarder: @escaping SessionController.LogoutPendingChangesDiscarder = { _ in },
        authenticationInvalidationObserver: @escaping SessionController.AuthenticationInvalidationObserver = { _ in }
    ) throws(any Error) -> SessionController {
        try makeController(
            loadData: { request in
                try await loader.load(request)
            },
            storage: storage,
            clock: clock,
            generationFactory: generationFactory,
            synchronizationObserver: synchronizationObserver,
            logoutPendingChangesObserver: logoutPendingChangesObserver,
            logoutPendingChangesDiscarder: logoutPendingChangesDiscarder,
            authenticationInvalidationObserver: authenticationInvalidationObserver
        )
    }

    private func makeController(
        loadData: @escaping SessionAPIClient.DataLoader,
        storage: ControlledSessionPersistenceStorage,
        clock: TestSessionClock = TestSessionClock(now: Self.now),
        generationFactory: @escaping @Sendable () -> UUID = { Self.generation },
        synchronizationObserver: @escaping SessionController.SynchronizationObserver = { _ in },
        logoutPendingChangesObserver: @escaping SessionController.LogoutPendingChangesObserver = { _ in false },
        logoutPendingChangesDiscarder: @escaping SessionController.LogoutPendingChangesDiscarder = { _ in },
        authenticationInvalidationObserver: @escaping SessionController.AuthenticationInvalidationObserver = { _ in }
    ) throws(any Error) -> SessionController {
        let baseURL = try #require(URL(string: "https://session.example.test"))
        let apiClient = SessionAPIClient(
            configuration: try APIConfiguration(baseURL: baseURL),
            loadData: loadData,
            now: {
                clock.value()
            }
        )
        return SessionController(
            apiClient: apiClient,
            persistence: SessionPersistenceActor(operations: storage.operations()),
            now: {
                clock.value()
            },
            makeGeneration: generationFactory,
            synchronizationObserver: synchronizationObserver,
            logoutPendingChangesObserver: logoutPendingChangesObserver,
            logoutPendingChangesDiscarder: logoutPendingChangesDiscarder,
            authenticationInvalidationObserver: authenticationInvalidationObserver
        )
    }

    private func makeSession(accessExpiresAt: Date) throws(SessionStorageError) -> SessionPersistedSession {
        try SessionPersistedSession(
            userID: Self.userID,
            generation: Self.generation,
            access: SessionCredential(value: "fixture-access", expiresAt: accessExpiresAt)
        )
    }

    private static let now = Date(timeIntervalSince1970: 1_700_000_000)
    private static let userID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let userB = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
    private static let generation = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private static let generationB = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!
    private static let accessResponse = Data(
        #"{"token":"fixture-access","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let renewedAccessResponse = Data(
        #"{"token":"fixture-access-renewed","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let renewalWindowAccessResponse = Data(
        #"{"token":"fixture-access-renewed","tokenType":"Bearer","expiresIn":300}"#.utf8
    )
    private static let sameTextRenewedAccessResponse = Data(
        #"{"token":"fixture-access","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let shortLivedAccessResponse = Data(
        #"{"token":"fixture-short-lived","tokenType":"Bearer","expiresIn":1}"#.utf8
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
    private static let identityResponseB = Data(
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
    private static let remoteAccount = SessionAccount(
        authority: SessionAuthority(userID: userID, generation: generation),
        id: userID,
        email: "reader@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
    private static let remoteAccountGenerationB = SessionAccount(
        authority: SessionAuthority(userID: userID, generation: generationB),
        id: userID,
        email: "reader@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
    private static let localAccount = SessionAccount(
        authority: SessionAuthority(userID: userID, generation: generation),
        id: userID,
        email: nil,
        isActive: nil,
        isAdmin: nil,
        role: nil
    )
    private static let remoteAccountB = SessionAccount(
        authority: SessionAuthority(userID: userB, generation: generationB),
        id: userB,
        email: "b@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
    private static let remoteAccountBGenerationA = SessionAccount(
        authority: SessionAuthority(userID: userB, generation: generation),
        id: userB,
        email: "b@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
}

private enum SessionInvalidationObserverTestError: Error {
    case expected
}

private final class SessionInvalidationObserverProbe: Sendable {
    struct Evidence: Equatable {
        let authorities: [SessionAuthority]
        let successfulInvalidationCommits: Int
        let rejectedNormalCommits: Int
    }

    private struct State {
        var normalAuthorization: SessionCommitAuthorization?
        var invalidationAuthorization: SessionInvalidationAuthorization?
        var authorities: [SessionAuthority] = []
        var successfulInvalidationCommits = 0
        var rejectedNormalCommits = 0
    }

    private let state = Mutex(State())

    func install(_ authorization: SessionCommitAuthorization) {
        state.withLock {
            $0.normalAuthorization = authorization
        }
    }

    func observe(_ authorization: SessionInvalidationAuthorization) {
        let invalidationCommitSucceeded = (try? authorization.perform { true }) == true
        let normalCommitWasRejected = state.withLock { state in
            guard let normalAuthorization = state.normalAuthorization else { return false }
            do {
                _ = try normalAuthorization.perform { true }
                return false
            } catch SessionCommitAuthorizationError.sessionChanged {
                return true
            } catch {
                return false
            }
        }

        state.withLock { state in
            state.invalidationAuthorization = authorization
            state.authorities.append(authorization.authority)
            if invalidationCommitSucceeded {
                state.successfulInvalidationCommits += 1
            }
            if normalCommitWasRejected {
                state.rejectedNormalCommits += 1
            }
        }
    }

    func latestAuthorization() -> SessionInvalidationAuthorization? {
        state.withLock(\.invalidationAuthorization)
    }

    func evidence() -> Evidence {
        state.withLock {
            Evidence(
                authorities: $0.authorities,
                successfulInvalidationCommits: $0.successfulInvalidationCommits,
                rejectedNormalCommits: $0.rejectedNormalCommits
            )
        }
    }
}

private final class SessionPendingLogoutProbe: Sendable {
    struct Evidence: Equatable {
        let inspections: Int
        let discards: Int
        let successfulLogoutCommits: Int
        let rejectedNormalCommits: Int
    }

    private struct State {
        var hasPendingChanges = true
        var normalAuthorization: SessionCommitAuthorization?
        var inspections = 0
        var discards = 0
        var successfulLogoutCommits = 0
        var rejectedNormalCommits = 0
    }

    private let state = Mutex(State())

    func install(_ authorization: SessionCommitAuthorization) {
        state.withLock {
            $0.normalAuthorization = authorization
        }
    }

    func inspect(_ authorization: SessionLogoutAuthorization) throws -> Bool {
        let logoutCommitSucceeded = try authorization.perform { true }
        let normalCommitWasRejected = state.withLock { state in
            guard let normalAuthorization = state.normalAuthorization else { return false }
            do {
                _ = try normalAuthorization.perform { true }
                return false
            } catch SessionCommitAuthorizationError.sessionChanged {
                return true
            } catch {
                return false
            }
        }

        return state.withLock { state in
            state.inspections += 1
            if logoutCommitSucceeded {
                state.successfulLogoutCommits += 1
            }
            if normalCommitWasRejected {
                state.rejectedNormalCommits += 1
            }
            return state.hasPendingChanges
        }
    }

    func discard(_ authorization: SessionLogoutAuthorization) throws {
        let logoutCommitSucceeded = try authorization.perform { true }
        state.withLock { state in
            state.hasPendingChanges = false
            state.discards += 1
            if logoutCommitSucceeded {
                state.successfulLogoutCommits += 1
            }
        }
    }

    func evidence() -> Evidence {
        state.withLock {
            Evidence(
                inspections: $0.inspections,
                discards: $0.discards,
                successfulLogoutCommits: $0.successfulLogoutCommits,
                rejectedNormalCommits: $0.rejectedNormalCommits
            )
        }
    }
}

private actor ScriptedSessionDataLoader {
    enum Reply {
        case data(Data)
        case network(NetworkError)
    }

    private var replies: [Reply]
    private var requests: [URLRequest] = []
    private let refreshGate: SessionRequestGate?
    private let identityGate: SessionRequestGate?

    init(replies: [Reply], refreshGate: SessionRequestGate? = nil, identityGate: SessionRequestGate? = nil) {
        self.replies = replies
        self.refreshGate = refreshGate
        self.identityGate = identityGate
    }

    func load(_ request: URLRequest) async throws(any Error) -> Data {
        requests.append(request)
        if request.url?.path == "/users/jwt/refresh", let refreshGate {
            await refreshGate.suspendUntilOpen()
        }
        if request.url?.path == "/users/jwt/me", let identityGate {
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

private enum StaleRestoreIdentityReply: CaseIterable, CustomTestStringConvertible {
    case unauthorized
    case differentUser

    var testDescription: String {
        switch self {
        case .unauthorized: "401"
        case .differentUser: "different user"
        }
    }
}

private enum StaleRestoreRefreshScenario: CaseIterable, CustomTestStringConvertible {
    case unauthorizedNewText
    case differentUserNewText
    case unauthorizedSameText
    case differentUserSameText

    var oldReply: StaleRestoreIdentityReply {
        switch self {
        case .unauthorizedNewText, .unauthorizedSameText: .unauthorized
        case .differentUserNewText, .differentUserSameText: .differentUser
        }
    }

    var reusesJWTText: Bool {
        switch self {
        case .unauthorizedNewText, .differentUserNewText: false
        case .unauthorizedSameText, .differentUserSameText: true
        }
    }

    var expectedAccessToken: String {
        reusesJWTText ? "fixture-access" : "fixture-access-renewed"
    }

    var testDescription: String {
        "\(oldReply.testDescription), \(reusesJWTText ? "same JWT text" : "new JWT text")"
    }
}

private enum RestoreIdentityCompletion: CaseIterable, CustomTestStringConvertible {
    case success
    case unavailable

    var testDescription: String {
        switch self {
        case .success: "200"
        case .unavailable: "503"
        }
    }
}

private actor StaleRestoreIdentityDataLoader {
    private let gate: SessionRequestGate
    private let renewedIdentityGate: SessionRequestGate?
    private let oldReply: StaleRestoreIdentityReply
    private let reusesJWTText: Bool
    private var requests: [URLRequest] = []
    private var identityRequestCount = 0
    private var oldReplyWasDelivered = false
    private var oldReplyDeliveryWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        gate: SessionRequestGate,
        renewedIdentityGate: SessionRequestGate? = nil,
        oldReply: StaleRestoreIdentityReply,
        reusesJWTText: Bool = false
    ) {
        self.gate = gate
        self.renewedIdentityGate = renewedIdentityGate
        self.oldReply = oldReply
        self.reusesJWTText = reusesJWTText
    }

    func load(_ request: URLRequest) async throws(any Error) -> Data {
        requests.append(request)
        switch (request.url?.path, request.value(forHTTPHeaderField: "Authorization")) {
        case ("/users/jwt/me", "Bearer fixture-access"):
            identityRequestCount += 1
            if reusesJWTText, identityRequestCount > 1 {
                if let renewedIdentityGate {
                    await renewedIdentityGate.suspendUntilOpen()
                }
                return Self.identityA
            }
            await gate.suspendUntilOpen()
            markOldReplyWasDelivered()
            switch oldReply {
            case .unauthorized:
                throw NetworkError.statusCode(401)
            case .differentUser:
                return Self.identityB
            }
        case ("/users/jwt/refresh", "Bearer fixture-access"):
            return reusesJWTText ? Self.sameTextRenewedAccess : Self.renewedAccess
        case ("/users/jwt/me", "Bearer fixture-access-renewed"):
            if let renewedIdentityGate {
                await renewedIdentityGate.suspendUntilOpen()
            }
            return Self.identityA
        default:
            throw SessionAPIClientError.unavailable
        }
    }

    func requestPaths() -> [String] {
        requests.compactMap(\.url?.path)
    }

    func waitUntilOldReplyWasDelivered() async {
        guard oldReplyWasDelivered == false else { return }
        await withCheckedContinuation {
            oldReplyDeliveryWaiters.append($0)
        }
    }

    private func markOldReplyWasDelivered() {
        oldReplyWasDelivered = true
        oldReplyDeliveryWaiters.forEach {
            $0.resume()
        }
        oldReplyDeliveryWaiters.removeAll()
    }

    private static let renewedAccess = Data(
        #"{"token":"fixture-access-renewed","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let sameTextRenewedAccess = Data(
        #"{"token":"fixture-access","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let identityA = Data(
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

private actor CoincidentRefreshCleanupDataLoader {
    private let identityGate: SessionRequestGate

    init(identityGate: SessionRequestGate) {
        self.identityGate = identityGate
    }

    func load(_ request: URLRequest) async throws(any Error) -> Data {
        switch (request.url?.path, request.value(forHTTPHeaderField: "Authorization")) {
        case ("/users/jwt/me", "Bearer fixture-access"):
            await identityGate.suspendUntilOpen()
            throw NetworkError.statusCode(401)
        case ("/users/jwt/refresh", "Bearer fixture-access"):
            throw NetworkError.statusCode(401)
        default:
            throw SessionAPIClientError.unavailable
        }
    }
}

private actor RejectedResolvedCredentialDataLoader {
    private let secondRefreshGate: SessionRequestGate
    private var requests: [URLRequest] = []

    init(secondRefreshGate: SessionRequestGate) {
        self.secondRefreshGate = secondRefreshGate
    }

    func load(_ request: URLRequest) async throws(any Error) -> Data {
        requests.append(request)
        switch (request.url?.path, request.value(forHTTPHeaderField: "Authorization")) {
        case ("/users/jwt/me", "Bearer fixture-access"),
             ("/users/jwt/me", "Bearer fixture-access-renewed"),
             ("/users/jwt/me", "Bearer fixture-access-renewed-again"):
            return Self.identity
        case ("/users/jwt/refresh", "Bearer fixture-access"):
            return Self.firstRenewedAccess
        case ("/users/jwt/refresh", "Bearer fixture-access-renewed"):
            await secondRefreshGate.suspendUntilOpen()
            return Self.secondRenewedAccess
        default:
            throw SessionAPIClientError.unavailable
        }
    }

    func requestPaths() -> [String] {
        requests.compactMap(\.url?.path)
    }

    private static let firstRenewedAccess = Data(
        #"{"token":"fixture-access-renewed","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let secondRenewedAccess = Data(
        #"{"token":"fixture-access-renewed-again","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let identity = Data(
        #"{"email":"reader@example.invalid","id":"11111111-2222-3333-4444-555555555555","isActive":true,"isAdmin":false,"role":"user"}"#.utf8
    )
}

private actor RefreshABADataLoader {
    private let refreshGate: SessionRequestGate
    private var requests: [URLRequest] = []

    init(refreshGate: SessionRequestGate) {
        self.refreshGate = refreshGate
    }

    func load(_ request: URLRequest) async throws(any Error) -> Data {
        requests.append(request)
        switch (request.url?.path, request.value(forHTTPHeaderField: "Authorization")) {
        case ("/users/jwt/me", "Bearer fixture-access"):
            return Self.identity
        case ("/users/jwt/refresh", "Bearer fixture-access"):
            await refreshGate.suspendUntilOpen()
            return Self.renewedAccess
        case ("/users/jwt/login", _):
            return Self.loginAccess
        case ("/users/jwt/me", "Bearer fixture-access-login-B"):
            return Self.identity
        default:
            throw SessionAPIClientError.unavailable
        }
    }

    func requestPaths() -> [String] {
        requests.compactMap(\.url?.path)
    }

    private static let renewedAccess = Data(
        #"{"token":"fixture-access-renewed","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let loginAccess = Data(
        #"{"token":"fixture-access-login-B","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let identity = Data(
        #"{"email":"reader@example.invalid","id":"11111111-2222-3333-4444-555555555555","isActive":true,"isAdmin":false,"role":"user"}"#.utf8
    )
}

private actor ConcurrentLoginDataLoader {
    private let gate: SessionRequestGate

    init(gate: SessionRequestGate) {
        self.gate = gate
    }

    func load(_ request: URLRequest) async throws(any Error) -> Data {
        switch (request.url?.path, request.value(forHTTPHeaderField: "Authorization")) {
        case ("/users/jwt/login", Self.basicA):
            await gate.suspendUntilOpen()
            return Self.accessA
        case ("/users/jwt/login", Self.basicB):
            return Self.accessB
        case ("/users/jwt/me", "Bearer fixture-access-b"):
            return Self.identityB
        default:
            throw SessionAPIClientError.unavailable
        }
    }

    private static let basicA = "Basic \(Data("a@example.invalid:synthetic-passphrase-a".utf8).base64EncodedString())"
    private static let basicB = "Basic \(Data("b@example.invalid:synthetic-passphrase-b".utf8).base64EncodedString())"
    private static let accessA = Data(#"{"token":"fixture-access-a","tokenType":"Bearer","expiresIn":86400}"#.utf8)
    private static let accessB = Data(#"{"token":"fixture-access-b","tokenType":"Bearer","expiresIn":86400}"#.utf8)
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

    init(gate: SessionRequestGate) {
        self.gate = gate
    }

    func load(_ request: URLRequest) async throws(any Error) -> Data {
        requests.append(request)
        switch (request.url?.path, request.value(forHTTPHeaderField: "Authorization")) {
        case ("/users/jwt/me", "Bearer fixture-access"):
            return Self.identityA
        case ("/users/jwt/refresh", "Bearer fixture-access"):
            await gate.suspendUntilOpen()
            return Self.renewedAccessA
        case ("/users/jwt/login", Self.basicB):
            return Self.accessB
        case ("/users/jwt/me", "Bearer fixture-access-b"),
             ("/users/jwt/me", "Bearer fixture-access-b-renewed"):
            return Self.identityB
        case ("/users/jwt/refresh", "Bearer fixture-access-b"):
            return Self.renewedAccessB
        default:
            throw SessionAPIClientError.unavailable
        }
    }

    func requestPaths() -> [String] {
        requests.compactMap(\.url?.path)
    }

    private static let basicB = "Basic \(Data("b@example.invalid:synthetic-passphrase-b".utf8).base64EncodedString())"
    private static let renewedAccessA = Data(
        #"{"token":"fixture-access-renewed","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let accessB = Data(#"{"token":"fixture-access-b","tokenType":"Bearer","expiresIn":86400}"#.utf8)
    private static let renewedAccessB = Data(
        #"{"token":"fixture-access-b-renewed","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let identityA = Data(
        #"{"email":"reader@example.invalid","id":"11111111-2222-3333-4444-555555555555","isActive":true,"isAdmin":false,"role":"user"}"#.utf8
    )
    private static let identityB = Data(
        #"{"email":"b@example.invalid","id":"66666666-7777-8888-9999-AAAAAAAAAAAA","isActive":true,"isAdmin":false,"role":"user"}"#.utf8
    )
}

private enum StaleRefreshFailureStage: CaseIterable, CustomTestStringConvertible {
    case refresh
    case identity

    var testDescription: String {
        switch self {
        case .refresh: "refresh 503"
        case .identity: "identity 401"
        }
    }
}

private actor StaleRefreshFailureDataLoader {
    private let gate: SessionRequestGate
    private let stage: StaleRefreshFailureStage

    init(gate: SessionRequestGate, stage: StaleRefreshFailureStage) {
        self.gate = gate
        self.stage = stage
    }

    func load(_ request: URLRequest) async throws(any Error) -> Data {
        switch (request.url?.path, request.value(forHTTPHeaderField: "Authorization")) {
        case ("/users/jwt/me", "Bearer fixture-access"):
            return Self.identityA
        case ("/users/jwt/refresh", "Bearer fixture-access"):
            if stage == .refresh {
                await gate.suspendUntilOpen()
                throw NetworkError.statusCode(503)
            }
            return Self.renewedAccessA
        case ("/users/jwt/me", "Bearer fixture-access-renewed"):
            await gate.suspendUntilOpen()
            throw NetworkError.statusCode(401)
        case ("/users/jwt/login", Self.basicB):
            return Self.accessB
        case ("/users/jwt/me", "Bearer fixture-access-b"):
            return Self.identityB
        default:
            throw SessionAPIClientError.unavailable
        }
    }

    private static let basicB = "Basic \(Data("b@example.invalid:synthetic-passphrase-b".utf8).base64EncodedString())"
    private static let renewedAccessA = Data(
        #"{"token":"fixture-access-renewed","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let accessB = Data(#"{"token":"fixture-access-b","tokenType":"Bearer","expiresIn":86400}"#.utf8)
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
        arrivalWaiters.forEach {
            $0.resume()
        }
        arrivalWaiters.removeAll()
        guard isOpen == false else { return }
        await withCheckedContinuation {
            openWaiters.append($0)
        }
    }

    func waitUntilArrived() async {
        guard arrived == false else { return }
        await withCheckedContinuation {
            arrivalWaiters.append($0)
        }
    }

    func open() {
        isOpen = true
        openWaiters.forEach {
            $0.resume()
        }
        openWaiters.removeAll()
    }
}

private final class TestSessionClock: Sendable {
    private struct State {
        var now: Date
        var advanceAfterRead: TimeInterval?
    }

    private let state: Mutex<State>

    init(now: Date) {
        state = Mutex(State(now: now))
    }

    func value() -> Date {
        state.withLock { state in
            let value = state.now
            if let interval = state.advanceAfterRead {
                state.now = state.now.addingTimeInterval(interval)
                state.advanceAfterRead = nil
            }
            return value
        }
    }

    func advance(by interval: TimeInterval) {
        state.withLock {
            $0.now = $0.now.addingTimeInterval(interval)
        }
    }

    func advanceAfterNextRead(by interval: TimeInterval) {
        state.withLock {
            $0.advanceAfterRead = interval
        }
    }
}
