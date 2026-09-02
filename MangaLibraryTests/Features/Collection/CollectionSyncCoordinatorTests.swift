//
//  CollectionSyncCoordinatorTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Synchronization
import Testing
@testable import MangaLibrary

@Suite("Collection sync coordinator", .tags(.integration))
struct CollectionSyncCoordinatorTests {
    @Test("An A to B authority change after fetch prevents the suspended response from committing")
    func changedAuthorityPreventsImport() async throws(any Error) {
        let authorityA = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let authorityB = SessionAuthority(userID: Self.userB, generation: Self.generationB)
        let authorityState = ControlledSessionAuthority(current: authorityA)
        let fetchRecorder = CollectionFetchRecorder()
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let actor = CollectionMutationActor(modelContainer: container)
        let coordinator = CollectionSyncCoordinator(
            authorize: {
                Self.authorization(authority: authorityA, accessToken: "fixture-access-A")
            },
            validateAuthorization: { authorization in
                await authorityState.isCurrent(authorization.authority)
            },
            fetchRemote: { accessToken in
                await fetchRecorder.record(accessToken)
                await authorityState.replace(with: authorityB)
                return [Self.remoteEntry]
            },
            importRemote: { entries, authorization in
                try await actor.importRemote(entries, authorization: authorization)
            }
        )

        await #expect(throws: CollectionSyncError.sessionChanged) {
            try await coordinator.importAuthenticatedCollection()
        }

        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())

        #expect(await fetchRecorder.accessTokens() == ["fixture-access-A"])
        #expect(await authorityState.currentAuthority() == authorityB)
        #expect(entries.isEmpty)
        #expect(operations.isEmpty)
    }

    @Test("A newer import cancels and replaces the suspended flight")
    func newerImportCancelsThePriorFlight() async throws(any Error) {
        let authorityA = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let authorityB = SessionAuthority(userID: Self.userB, generation: Self.generationB)
        let authorizations = CollectionAuthorizationSequence(
            values: [
                Self.authorization(authority: authorityA, accessToken: "fixture-access-A"),
                Self.authorization(authority: authorityB, accessToken: "fixture-access-B"),
            ]
        )
        let fetch = ReplacingCollectionFetch(remoteEntry: Self.remoteEntry)
        let imports = CollectionImportRecorder()
        let coordinator = CollectionSyncCoordinator(
            authorize: { try await authorizations.next() },
            validateAuthorization: { _ in true },
            fetchRemote: { accessToken in try await fetch.load(accessToken: accessToken) },
            importRemote: { entries, authorization in
                await imports.record(entries: entries, userID: authorization.authority.userID)
            }
        )

        let first = Task { try await coordinator.importAuthenticatedCollection() }
        await fetch.waitForRequestCount(1)
        let second = Task { try await coordinator.importAuthenticatedCollection() }

        try await second.value
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(await fetch.accessTokens() == ["fixture-access-A", "fixture-access-B"])
        #expect(await fetch.firstRequestWasCancelled())
        #expect(await imports.events() == [.init(userID: Self.userB, mangaIDs: [42])])
    }

    @Test("Cancelling the caller cancels the suspended remote request")
    func cancelledCallerCancelsTheActiveFlight() async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let fetch = ReplacingCollectionFetch(remoteEntry: Self.remoteEntry)
        let imports = CollectionImportRecorder()
        let coordinator = CollectionSyncCoordinator(
            authorize: {
                Self.authorization(authority: authority, accessToken: "fixture-access-A")
            },
            validateAuthorization: { _ in true },
            fetchRemote: { accessToken in try await fetch.load(accessToken: accessToken) },
            importRemote: { entries, authorization in
                await imports.record(entries: entries, userID: authorization.authority.userID)
            }
        )
        let caller = Task { try await coordinator.importAuthenticatedCollection() }
        await fetch.waitForRequestCount(1)

        caller.cancel()

        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(await fetch.firstRequestWasCancelled())
        #expect(await imports.events().isEmpty)
    }

    @Test("A model-actor cancellation remains cancellation without authorization revalidation")
    func remoteImportCancellationDoesNotBecomeAnAuthorizationFailure() async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let validationCount = Mutex(0)
        let importCount = Mutex(0)
        let coordinator = CollectionSyncCoordinator(
            authorize: {
                Self.authorization(authority: authority, accessToken: "fixture-access-A")
            },
            validateAuthorization: { _ in
                validationCount.withLock { $0 += 1 }
                return true
            },
            fetchRemote: { _ in [Self.remoteEntry] },
            importRemote: { _, _ in
                importCount.withLock { $0 += 1 }
                throw CollectionRemoteImportError.cancelled
            }
        )

        await #expect(throws: CancellationError.self) {
            try await coordinator.importAuthenticatedCollection()
        }

        #expect(validationCount.withLock { $0 } == 1)
        #expect(importCount.withLock { $0 } == 1)
    }

    @Test("A generation invalidated after validation cannot cross the SwiftData commit boundary")
    func invalidationAtCommitBoundaryPreventsImport() async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let gate = SessionCommitGate(activeAuthority: authority)
        let authorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "fixture-access-A",
            commitAuthorization: gate.authorization(for: authority)
        )
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let actor = CollectionMutationActor(modelContainer: container)
        let coordinator = CollectionSyncCoordinator(
            authorize: { authorization },
            validateAuthorization: { _ in true },
            fetchRemote: { _ in [Self.remoteEntry] },
            importRemote: { entries, commitAuthorization in
                gate.invalidate(authority)
                try await actor.importRemote(entries, authorization: commitAuthorization)
            }
        )

        await #expect(throws: CollectionRemoteImportError.sessionChanged) {
            try await coordinator.importAuthenticatedCollection()
        }

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<CollectionEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CollectionOutboxOperation>()) == 0)
    }

    @Test("A JWT replacement in the same generation invalidates the prior commit capability")
    func credentialReplacementAtCommitBoundaryPreventsImport() async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let gate = SessionCommitGate(activeAuthority: authority)
        let authorization = SessionRequestAuthorization(
            authority: authority,
            accessToken: "fixture-access-B",
            commitAuthorization: gate.authorization(for: authority)
        )
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let actor = CollectionMutationActor(modelContainer: container)
        let coordinator = CollectionSyncCoordinator(
            authorize: { authorization },
            validateAuthorization: { _ in true },
            fetchRemote: { _ in [Self.remoteEntry] },
            importRemote: { entries, commitAuthorization in
                gate.activate(authority)
                try await actor.importRemote(entries, authorization: commitAuthorization)
            }
        )

        await #expect(throws: CollectionRemoteImportError.sessionChanged) {
            try await coordinator.importAuthenticatedCollection()
        }

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<CollectionEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CollectionOutboxOperation>()) == 0)
        let replacementAuthorization = gate.authorization(for: authority)
        #expect(try replacementAuthorization.perform { true })
    }

    @Test("A Collection 403 keeps the request authorized without refresh or retry")
    func forbiddenResponseKeepsTheSession() async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let authorization = Self.authorization(authority: authority, accessToken: "fixture-access-A")
        let fetch = ScriptedCollectionFetch(replies: [.statusCode(403)])
        let recoveries = CollectionAuthorizationRecoveryRecorder()
        let imports = CollectionImportRecorder()
        let coordinator = CollectionSyncCoordinator(
            authorize: { authorization },
            validateAuthorization: { candidate in
                candidate.authority == authorization.authority
                    && candidate.accessToken == authorization.accessToken
            },
            recoverAuthorization: { rejectedAuthorization in
                await recoveries.record(rejectedAuthorization)
                return Self.authorization(authority: authority, accessToken: "unexpected-access")
            },
            fetchRemote: { accessToken in try await fetch.load(accessToken: accessToken) },
            importRemote: { entries, commitAuthorization in
                await imports.record(entries: entries, userID: commitAuthorization.authority.userID)
            }
        )

        await #expect(
            throws: CollectionSyncError.authorizationDenied(origin: .collectionSnapshot(attempt: 1), statusCode: 403)
        ) {
            try await coordinator.importAuthenticatedCollection()
        }

        #expect(await fetch.accessTokens() == ["fixture-access-A"])
        #expect(await recoveries.requests().isEmpty)
        #expect(await imports.events().isEmpty)
    }

    @Test("A stale Collection 403 cannot be presented over a renewed access")
    func staleForbiddenResponseIsSessionChanged() async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let initial = Self.authorization(authority: authority, accessToken: "fixture-access-A")
        let renewed = Self.authorization(authority: authority, accessToken: "fixture-access-B")
        let current = ControlledSessionAuthorization(current: initial)
        let imports = CollectionImportRecorder()
        let coordinator = CollectionSyncCoordinator(
            authorize: { initial },
            validateAuthorization: { candidate in await current.matches(candidate) },
            fetchRemote: { _ in
                await current.replace(with: renewed)
                throw CollectionAPIClientError.network(.statusCode(403))
            },
            importRemote: { entries, commitAuthorization in
                await imports.record(entries: entries, userID: commitAuthorization.authority.userID)
            }
        )

        await #expect(throws: CollectionSyncError.sessionChanged) {
            try await coordinator.importAuthenticatedCollection()
        }

        #expect(await current.matches(renewed))
        #expect(await imports.events().isEmpty)
    }

    @Test("A Collection 401 refreshes once and retries once with the renewed access")
    func unauthorizedResponseRetriesWithRenewedAccess() async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let initial = Self.authorization(authority: authority, accessToken: "fixture-access-A")
        let renewed = Self.authorization(authority: authority, accessToken: "fixture-access-B")
        let current = ControlledSessionAuthorization(current: initial)
        let fetch = ScriptedCollectionFetch(replies: [.statusCode(401), .entries([Self.remoteEntry])])
        let recoveries = CollectionAuthorizationRecoveryRecorder()
        let imports = CollectionImportRecorder()
        let coordinator = CollectionSyncCoordinator(
            authorize: { initial },
            validateAuthorization: { candidate in await current.matches(candidate) },
            recoverAuthorization: { rejectedAuthorization in
                await recoveries.record(rejectedAuthorization)
                await current.replace(with: renewed)
                return renewed
            },
            fetchRemote: { accessToken in try await fetch.load(accessToken: accessToken) },
            importRemote: { entries, commitAuthorization in
                await imports.record(entries: entries, userID: commitAuthorization.authority.userID)
            }
        )

        try await coordinator.importAuthenticatedCollection()

        #expect(await fetch.accessTokens() == ["fixture-access-A", "fixture-access-B"])
        #expect(await recoveries.accessTokens() == ["fixture-access-A"])
        #expect(await imports.events() == [.init(userID: Self.userA, mangaIDs: [42])])
    }

    @Test("A permanently rejected refresh requires authentication without a Collection retry")
    func rejectedRefreshRequiresAuthentication() async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let authorization = Self.authorization(authority: authority, accessToken: "fixture-access-A")
        let fetch = ScriptedCollectionFetch(replies: [.statusCode(401)])
        let recoveries = CollectionAuthorizationRecoveryRecorder()
        let imports = CollectionImportRecorder()
        let coordinator = CollectionSyncCoordinator(
            authorize: { authorization },
            validateAuthorization: { _ in true },
            recoverAuthorization: { rejectedAuthorization in
                await recoveries.record(rejectedAuthorization)
                throw SessionControllerError.authenticationRequired
            },
            fetchRemote: { accessToken in try await fetch.load(accessToken: accessToken) },
            importRemote: { entries, commitAuthorization in
                await imports.record(entries: entries, userID: commitAuthorization.authority.userID)
            }
        )

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await coordinator.importAuthenticatedCollection()
        }

        #expect(await fetch.accessTokens() == ["fixture-access-A"])
        #expect(await recoveries.accessTokens() == ["fixture-access-A"])
        #expect(await imports.events().isEmpty)
    }

    @Test("A second Collection 401 after refresh exposes endpoint incompatibility")
    func renewedAccessRejectedByCollectionKeepsTheSession() async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let initial = Self.authorization(authority: authority, accessToken: "fixture-access-A")
        let renewed = Self.authorization(authority: authority, accessToken: "fixture-access-B")
        let current = ControlledSessionAuthorization(current: initial)
        let fetch = ScriptedCollectionFetch(replies: [.statusCode(401), .statusCode(401)])
        let recoveries = CollectionAuthorizationRecoveryRecorder()
        let imports = CollectionImportRecorder()
        let coordinator = CollectionSyncCoordinator(
            authorize: { initial },
            validateAuthorization: { candidate in await current.matches(candidate) },
            recoverAuthorization: { rejectedAuthorization in
                await recoveries.record(rejectedAuthorization)
                await current.replace(with: renewed)
                return renewed
            },
            fetchRemote: { accessToken in try await fetch.load(accessToken: accessToken) },
            importRemote: { entries, commitAuthorization in
                await imports.record(entries: entries, userID: commitAuthorization.authority.userID)
            }
        )

        await #expect(
            throws: CollectionSyncError.authenticationIncompatible(
                origin: .collectionSnapshot(attempt: 2),
                statusCode: 401
            )
        ) {
            try await coordinator.importAuthenticatedCollection()
        }

        #expect(await fetch.accessTokens() == ["fixture-access-A", "fixture-access-B"])
        #expect(await recoveries.accessTokens() == ["fixture-access-A"])
        #expect(await current.matches(renewed))
        #expect(await imports.events().isEmpty)
    }

    @Test("A Collection 403 after refresh keeps the renewed session without another retry")
    func renewedAccessForbiddenByCollectionKeepsTheSession() async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let initial = Self.authorization(authority: authority, accessToken: "fixture-access-A")
        let renewed = Self.authorization(authority: authority, accessToken: "fixture-access-B")
        let current = ControlledSessionAuthorization(current: initial)
        let fetch = ScriptedCollectionFetch(replies: [.statusCode(401), .statusCode(403)])
        let recoveries = CollectionAuthorizationRecoveryRecorder()
        let imports = CollectionImportRecorder()
        let coordinator = CollectionSyncCoordinator(
            authorize: { initial },
            validateAuthorization: { candidate in await current.matches(candidate) },
            recoverAuthorization: { rejectedAuthorization in
                await recoveries.record(rejectedAuthorization)
                await current.replace(with: renewed)
                return renewed
            },
            fetchRemote: { accessToken in try await fetch.load(accessToken: accessToken) },
            importRemote: { entries, commitAuthorization in
                await imports.record(entries: entries, userID: commitAuthorization.authority.userID)
            }
        )

        await #expect(
            throws: CollectionSyncError.authorizationDenied(origin: .collectionSnapshot(attempt: 2), statusCode: 403)
        ) {
            try await coordinator.importAuthenticatedCollection()
        }

        #expect(await fetch.accessTokens() == ["fixture-access-A", "fixture-access-B"])
        #expect(await recoveries.accessTokens() == ["fixture-access-A"])
        #expect(await current.matches(renewed))
        #expect(await imports.events().isEmpty)
    }

    @Test("Renewed access rejected by identity exposes backend incompatibility")
    func renewedAccessRejectedByIdentityKeepsTheSession() async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let authorization = Self.authorization(authority: authority, accessToken: "fixture-access-A")
        let fetch = ScriptedCollectionFetch(replies: [.statusCode(401)])
        let imports = CollectionImportRecorder()
        let coordinator = CollectionSyncCoordinator(
            authorize: { authorization },
            validateAuthorization: { _ in true },
            recoverAuthorization: { _ in
                throw SessionAuthorizationRecoveryError.identityRejected(statusCode: 401)
            },
            fetchRemote: { accessToken in try await fetch.load(accessToken: accessToken) },
            importRemote: { entries, commitAuthorization in
                await imports.record(entries: entries, userID: commitAuthorization.authority.userID)
            }
        )

        await #expect(
            throws: CollectionSyncError.authenticationIncompatible(origin: .renewedSessionIdentity, statusCode: 401)
        ) {
            try await coordinator.importAuthenticatedCollection()
        }

        #expect(await fetch.accessTokens() == ["fixture-access-A"])
        #expect(await imports.events().isEmpty)
    }

    @Test("Preventive refresh identity rejection exposes backend incompatibility before Collection")
    func initialAuthorizationRejectedByIdentityIsIncompatible() async throws(any Error) {
        let fetch = ScriptedCollectionFetch(replies: [])
        let imports = CollectionImportRecorder()
        let coordinator = CollectionSyncCoordinator(
            authorize: {
                throw SessionAuthorizationRecoveryError.identityRejected(statusCode: 401)
            },
            validateAuthorization: { _ in true },
            fetchRemote: { accessToken in try await fetch.load(accessToken: accessToken) },
            importRemote: { entries, commitAuthorization in
                await imports.record(entries: entries, userID: commitAuthorization.authority.userID)
            }
        )

        await #expect(
            throws: CollectionSyncError.authenticationIncompatible(origin: .renewedSessionIdentity, statusCode: 401)
        ) {
            try await coordinator.importAuthenticatedCollection()
        }

        #expect(await fetch.accessTokens().isEmpty)
        #expect(await imports.events().isEmpty)
    }

    @Test("JWT login authorizes the first Collection snapshot with the same credential")
    func jwtLoginAuthorizesCollectionImport() async throws(any Error) {
        let storage = ControlledSessionPersistenceStorage()
        let sessionLoader = R1SessionDataLoader(replies: [.data(Self.loginJWTResponse), .data(Self.identityResponse)])
        let controller = try makeSessionController(loader: sessionLoader, storage: storage)
        _ = try await controller.restore()
        #expect(
            try await controller.login(email: "reader@example.invalid", password: "synthetic-passphrase")
                == .active(Self.accountA)
        )
        let collectionLoader = R1CollectionDataLoader(replies: [.data(Self.remoteSnapshotResponse)])
        let client = try makeCollectionClient(loader: collectionLoader)
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let coordinator = CollectionSyncCoordinator(
            sessionController: controller,
            client: client,
            mutationActor: CollectionMutationActor(modelContainer: container)
        )

        try await coordinator.importAuthenticatedCollection()

        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        let sessionRequests = await sessionLoader.recordedRequests()
        let loginRequest = try #require(sessionRequests.first)
        let identityRequest = try #require(sessionRequests.last)
        #expect(entries.map(\.mangaID) == [42])
        #expect(storage.snapshot().record?.access.value == "fixture-login-jwt")
        #expect(sessionRequests.compactMap { $0.url?.path } == ["/users/jwt/login", "/users/jwt/me"])
        #expect(loginRequest.httpMethod == "POST")
        #expect(
            loginRequest.value(forHTTPHeaderField: "Authorization")
                == "Basic cmVhZGVyQGV4YW1wbGUuaW52YWxpZDpzeW50aGV0aWMtcGFzc3BocmFzZQ=="
        )
        #expect(identityRequest.httpMethod == "GET")
        #expect(identityRequest.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-login-jwt")
        #expect(await collectionLoader.authorizationHeaders() == ["Bearer fixture-login-jwt"])
        #expect(await controller.currentSnapshot() == .active(Self.accountA))
    }

    @Test("The live 403 composition keeps the active session and its persisted envelope")
    func liveForbiddenResponseKeepsTheSessionEnvelope() async throws(any Error) {
        let session = try makePersistedSession()
        let storage = ControlledSessionPersistenceStorage(record: session)
        let sessionLoader = R1SessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeSessionController(loader: sessionLoader, storage: storage)
        _ = try await controller.restore()
        let collectionLoader = R1CollectionDataLoader(replies: [.network(.statusCode(403))])
        let client = try makeCollectionClient(loader: collectionLoader)
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let coordinator = CollectionSyncCoordinator(
            sessionController: controller,
            client: client,
            mutationActor: CollectionMutationActor(modelContainer: container)
        )

        await #expect(
            throws: CollectionSyncError.authorizationDenied(origin: .collectionSnapshot(attempt: 1), statusCode: 403)
        ) {
            try await coordinator.importAuthenticatedCollection()
        }

        let authorization = try await controller.requestAuthorization()
        #expect(await controller.currentSnapshot() == .active(Self.accountA))
        #expect(storage.snapshot().record == session)
        #expect(try await controller.authorizes(authorization))
        #expect(await collectionLoader.requestCount() == 1)
        #expect(await sessionLoader.requestPaths() == ["/users/jwt/me"])
    }

    @Test("A live 401 refreshes validates identity retries once and imports")
    func liveUnauthorizedResponseRetriesWithValidatedAccess() async throws(any Error) {
        let session = try makePersistedSession()
        let storage = ControlledSessionPersistenceStorage(record: session)
        let sessionLoader = R1SessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeSessionController(loader: sessionLoader, storage: storage)
        _ = try await controller.restore()
        let collectionLoader = R1CollectionDataLoader(
            replies: [
                .network(.statusCode(401)),
                .data(Self.remoteSnapshotResponse),
            ]
        )
        let client = try makeCollectionClient(loader: collectionLoader)
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let coordinator = CollectionSyncCoordinator(
            sessionController: controller,
            client: client,
            mutationActor: CollectionMutationActor(modelContainer: container)
        )

        try await coordinator.importAuthenticatedCollection()

        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        let currentAuthorization = try await controller.requestAuthorization()
        #expect(entries.map(\.mangaID) == [42])
        #expect(await controller.currentSnapshot() == .active(Self.accountA))
        #expect(storage.snapshot().record?.access.value == "fixture-access-renewed")
        #expect(storage.snapshot().record?.authority == session.authority)
        #expect(try await controller.authorizes(currentAuthorization))
        #expect(await sessionLoader.requestPaths() == ["/users/jwt/me", "/users/jwt/refresh", "/users/jwt/me"])
        #expect(
            await collectionLoader.authorizationHeaders()
                == ["Bearer fixture-access-A", "Bearer fixture-access-renewed"]
        )
    }

    @Test("JWT expiry at the R1 commit boundary prevents import and converges session state")
    func expirationAtImportCommitRequiresAuthentication() async throws(any Error) {
        let clock = Mutex(Self.now)
        let session = try makePersistedSession()
        let storage = ControlledSessionPersistenceStorage(record: session)
        let sessionLoader = R1SessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeSessionController(
            loader: sessionLoader,
            storage: storage,
            now: { clock.withLock { $0 } }
        )
        _ = try await controller.restore()
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let actor = CollectionMutationActor(modelContainer: container)
        let coordinator = CollectionSyncCoordinator(
            authorize: { try await controller.requestAuthorization() },
            validateAuthorization: { authorization in
                try await controller.authorizes(authorization)
            },
            fetchRemote: { _ in [Self.remoteEntry] },
            importRemote: { entries, authorization in
                clock.withLock { $0 = $0.addingTimeInterval(601) }
                try await actor.importRemote(entries, authorization: authorization)
            }
        )

        await #expect(throws: CollectionSyncError.sessionChanged) {
            try await coordinator.importAuthenticatedCollection()
        }

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<CollectionEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CollectionOutboxOperation>()) == 0)
        #expect(await controller.currentSnapshot() == .authenticationRequired(Self.userA))
        #expect(storage.snapshot().record == nil)
    }

    @Test("A 401 observed during failed logout forces refresh before the session is reused")
    func unauthorizedDuringFailedLogoutForcesRefresh() async throws(any Error) {
        let deletionGate = SynchronousPersistenceGate()
        let responseGate = R1RequestGate()
        let session = try makePersistedSession()
        let storage = ControlledSessionPersistenceStorage(record: session, removeAllGate: deletionGate)
        let sessionLoader = R1SessionDataLoader(
            replies: [
                .data(Self.identityResponse),
                .data(Self.renewedAccessResponse),
                .data(Self.identityResponse),
            ]
        )
        let controller = try makeSessionController(loader: sessionLoader, storage: storage)
        _ = try await controller.restore()
        let rejectedAuthorization = try await controller.requestAuthorization()
        let collectionLoader = R1CollectionDataLoader(replies: [.network(.statusCode(401))], responseGate: responseGate)
        let client = try makeCollectionClient(loader: collectionLoader)
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let coordinator = CollectionSyncCoordinator(
            sessionController: controller,
            client: client,
            mutationActor: CollectionMutationActor(modelContainer: container)
        )
        let importTask = Task { try await coordinator.importAuthenticatedCollection() }
        await responseGate.waitUntilArrived()
        storage.failNext(.removeAll, with: .temporarilyUnavailable)
        let logoutTask = Task { try await controller.logout() }
        await deletionGate.waitUntilEntered()

        await responseGate.open()
        await #expect(throws: SessionControllerError.transitionInProgress) {
            try await importTask.value
        }
        deletionGate.open()
        await #expect(throws: SessionControllerError.temporarilyUnavailable) {
            try await logoutTask.value
        }

        #expect(await controller.currentSnapshot() == .active(Self.accountA))
        #expect(storage.snapshot().record == session)
        #expect(try await controller.authorizes(rejectedAuthorization) == false)
        let renewedAuthorization = try await controller.requestAuthorization()
        #expect(renewedAuthorization.accessToken == "fixture-access-renewed")
        #expect(try await controller.authorizes(renewedAuthorization))
        #expect(storage.snapshot().record?.access.value == "fixture-access-renewed")
        #expect(await sessionLoader.requestPaths() == ["/users/jwt/me", "/users/jwt/refresh", "/users/jwt/me"])
    }

    @Test("An empty live snapshot with confirmed pending and orphaned state never changes authentication")
    func emptyRemoteSnapshotNeverChangesAuthentication() async throws(any Error) {
        let session = try makePersistedSession()
        let storage = ControlledSessionPersistenceStorage(record: session)
        let sessionLoader = R1SessionDataLoader(replies: [.data(Self.identityResponse)])
        let controller = try makeSessionController(loader: sessionLoader, storage: storage)
        _ = try await controller.restore()
        let authorization = try await controller.requestAuthorization()
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let seedActor = CollectionMutationActor(modelContainer: container)
        try await seedActor.importRemote(
            [
                Self.collectionRemoteEntry(remoteID: Self.confirmedRemoteID, mangaID: 42, title: "Confirmed"),
                Self.collectionRemoteEntry(remoteID: Self.pendingRemoteID, mangaID: 84, title: "Pending"),
            ],
            authorization: authorization.commitAuthorization
        )
        _ = try await seedActor.apply(
            CollectionMutationCommand(
                authority: SessionAuthority(userID: Self.userA, generation: Self.generationA),
                mangaID: 84,
                knownTotalVolumes: 3,
                change: .replaceOwnedVolumes([1, 2])
            ),
            newOperationID: Self.pendingOperationID
        )
        let context = ModelContext(container)
        let orphanState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: nil,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        context.insert(
            CollectionEntry(
                userID: Self.userA,
                mangaID: 126,
                state: orphanState,
                confirmedState: nil,
                mangaSnapshot: CollectionMangaSnapshot(
                    manga: Self.collectionRemoteEntry(
                        remoteID: Self.orphanRemoteID,
                        mangaID: 126,
                        title: "Orphan"
                    ).manga
                )
            )
        )
        try context.save()
        let collectionLoader = R1CollectionDataLoader(replies: [.data(Data("[]".utf8))])
        let client = try makeCollectionClient(loader: collectionLoader)
        let coordinator = CollectionSyncCoordinator(
            sessionController: controller,
            client: client,
            mutationActor: CollectionMutationActor(modelContainer: container)
        )

        await #expect(throws: CollectionRemoteImportError.orphanedLocalEntry(126)) {
            try await coordinator.importAuthenticatedCollection()
        }

        let currentAuthorization = try await controller.requestAuthorization()
        #expect(await controller.currentSnapshot() == .active(Self.accountA))
        #expect(storage.snapshot().record == session)
        #expect(try await controller.authorizes(currentAuthorization))
        #expect(await collectionLoader.requestCount() == 1)
    }

    @Test("A pre-cancelled late trigger cannot cancel the current import")
    func preCancelledTriggerDoesNotReplaceCurrentFlight() async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userB, generation: Self.generationB)
        let authorizations = CollectionAuthorizationSequence(
            values: [Self.authorization(authority: authority, accessToken: "fixture-access-B")]
        )
        let fetch = ReplacingCollectionFetch(remoteEntry: Self.remoteEntry)
        let imports = CollectionImportRecorder()
        let callGate = CoordinatorCallGate()
        let coordinator = CollectionSyncCoordinator(
            authorize: { try await authorizations.next() },
            validateAuthorization: { _ in true },
            fetchRemote: { accessToken in try await fetch.load(accessToken: accessToken) },
            importRemote: { entries, authorization in
                await imports.record(entries: entries, userID: authorization.authority.userID)
            }
        )

        let current = Task { try await coordinator.importAuthenticatedCollection() }
        await fetch.waitForRequestCount(1)
        let stale = Task {
            await callGate.suspendUntilOpen()
            try await coordinator.importAuthenticatedCollection()
        }
        await callGate.waitUntilArrived()

        stale.cancel()
        await callGate.open()
        await #expect(throws: CancellationError.self) { try await stale.value }
        await fetch.succeedFirstRequest()
        try await current.value

        #expect(await fetch.accessTokens() == ["fixture-access-B"])
        #expect(await fetch.firstRequestWasCancelled() == false)
        #expect(await imports.events() == [.init(userID: Self.userB, mangaIDs: [42])])
    }

    private static let remoteEntry = CollectionRemoteEntry(
        remoteID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        manga: Manga(
            id: 42,
            title: "Stale response",
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
        ownedVolumes: [1],
        readingVolume: nil,
        isComplete: false
    )

    private static let userA = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let userB = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
    private static let generationA = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    private static let generationB = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!
    private static let now = Date(timeIntervalSince1970: 1_700_000_000)
    private static let confirmedRemoteID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private static let pendingRemoteID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    private static let orphanRemoteID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    private static let pendingOperationID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private static let accountA = SessionAccount(
        authority: SessionAuthority(userID: userA, generation: generationA),
        id: userA,
        email: "reader@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
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
    private static let renewedAccessResponse = Data(
        #"{"token":"fixture-access-renewed","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let loginJWTResponse = Data(
        #"{"token":"fixture-login-jwt","tokenType":"Bearer","expiresIn":86400}"#.utf8
    )
    private static let remoteSnapshotResponse = Data(
        #"""
        [
          {
            "id": "10000000-0000-0000-0000-000000000001",
            "manga": {
              "authors": [],
              "demographics": [],
              "genres": [],
              "id": 42,
              "mainPicture": null,
              "score": 8,
              "status": "currently_publishing",
              "sypnosis": null,
              "themes": [],
              "title": "Fixture",
              "titleEnglish": null,
              "titleJapanese": null,
              "volumes": 3
            },
            "completeCollection": false,
            "volumesOwned": [1],
            "readingVolume": null
          }
        ]
        """#.utf8
    )

    private static func authorization(authority: SessionAuthority, accessToken: String) -> SessionRequestAuthorization {
        let gate = SessionCommitGate(activeAuthority: authority)
        return SessionRequestAuthorization(
            authority: authority,
            accessToken: accessToken,
            commitAuthorization: gate.authorization(for: authority)
        )
    }

    private func makePersistedSession() throws(SessionStorageError) -> SessionPersistedSession {
        try SessionPersistedSession(
            userID: Self.userA,
            generation: Self.generationA,
            access: SessionCredential(value: "fixture-access-A", expiresAt: Self.now.addingTimeInterval(600))
        )
    }

    private func makeSessionController(
        loader: R1SessionDataLoader,
        storage: ControlledSessionPersistenceStorage,
        now: @escaping @Sendable () -> Date = { Self.now }
    ) throws(any Error) -> SessionController {
        let baseURL = try #require(URL(string: "https://session.example.test"))
        return SessionController(
            apiClient: SessionAPIClient(
                configuration: try APIConfiguration(baseURL: baseURL),
                loadData: { request in try await loader.load(request) },
                now: now
            ),
            persistence: SessionPersistenceActor(operations: storage.operations()),
            now: now,
            makeGeneration: { Self.generationA }
        )
    }

    private func makeCollectionClient(loader: R1CollectionDataLoader) throws(any Error) -> CollectionAPIClient {
        let baseURL = try #require(URL(string: "https://collection.example.test"))
        return CollectionAPIClient(
            configuration: try APIConfiguration(baseURL: baseURL),
            loadData: { request in try await loader.load(request) }
        )
    }

    private static func collectionRemoteEntry(
        remoteID: UUID,
        mangaID: Manga.ID,
        title: String
    ) -> CollectionRemoteEntry {
        CollectionRemoteEntry(
            remoteID: remoteID,
            manga: Manga(
                id: mangaID,
                title: title,
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
            ownedVolumes: [1],
            readingVolume: nil,
            isComplete: false
        )
    }
}

private actor R1SessionDataLoader {
    enum Reply {
        case data(Data)
        case network(NetworkError)
    }

    enum ScriptError: Error {
        case exhausted
    }

    private var replies: [Reply]
    private var requests: [URLRequest] = []

    init(replies: [Reply]) {
        self.replies = replies
    }

    func load(_ request: URLRequest) throws -> Data {
        requests.append(request)
        guard replies.isEmpty == false else { throw ScriptError.exhausted }

        switch replies.removeFirst() {
        case let .data(data):
            return data
        case let .network(error):
            throw error
        }
    }

    func requestPaths() -> [String] {
        requests.compactMap(\.url?.path)
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}

private actor R1CollectionDataLoader {
    enum Reply {
        case data(Data)
        case network(NetworkError)
    }

    enum ScriptError: Error {
        case exhausted
    }

    private var replies: [Reply]
    private var requests: [URLRequest] = []
    private let responseGate: R1RequestGate?

    init(replies: [Reply], responseGate: R1RequestGate? = nil) {
        self.replies = replies
        self.responseGate = responseGate
    }

    func load(_ request: URLRequest) async throws(any Error) -> Data {
        requests.append(request)
        if let responseGate { await responseGate.suspendUntilOpen() }
        guard replies.isEmpty == false else { throw ScriptError.exhausted }

        switch replies.removeFirst() {
        case let .data(data):
            return data
        case let .network(error):
            throw error
        }
    }

    func requestCount() -> Int {
        requests.count
    }

    func authorizationHeaders() -> [String] {
        requests.compactMap { $0.value(forHTTPHeaderField: "Authorization") }
    }
}

private actor R1RequestGate {
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

private actor ControlledSessionAuthority {
    private var current: SessionAuthority

    init(current: SessionAuthority) {
        self.current = current
    }

    func isCurrent(_ authority: SessionAuthority) -> Bool {
        current == authority
    }

    func replace(with authority: SessionAuthority) {
        current = authority
    }

    func currentAuthority() -> SessionAuthority {
        current
    }
}

private actor CollectionFetchRecorder {
    private var recordedAccessTokens: [String] = []

    func record(_ accessToken: String) {
        recordedAccessTokens.append(accessToken)
    }

    func accessTokens() -> [String] {
        recordedAccessTokens
    }
}

private actor ControlledSessionAuthorization {
    private var current: SessionRequestAuthorization

    init(current: SessionRequestAuthorization) {
        self.current = current
    }

    func matches(_ authorization: SessionRequestAuthorization) -> Bool {
        current.authority == authorization.authority
            && current.accessToken == authorization.accessToken
    }

    func replace(with authorization: SessionRequestAuthorization) {
        current = authorization
    }
}

private actor ScriptedCollectionFetch {
    enum Reply {
        case entries([CollectionRemoteEntry])
        case statusCode(Int)
    }

    enum ScriptError: Error {
        case exhausted
    }

    private var replies: [Reply]
    private var recordedAccessTokens: [String] = []

    init(replies: [Reply]) {
        self.replies = replies
    }

    func load(accessToken: String) throws -> [CollectionRemoteEntry] {
        recordedAccessTokens.append(accessToken)
        guard replies.isEmpty == false else { throw ScriptError.exhausted }

        switch replies.removeFirst() {
        case let .entries(entries):
            return entries
        case let .statusCode(statusCode):
            throw CollectionAPIClientError.network(.statusCode(statusCode))
        }
    }

    func accessTokens() -> [String] {
        recordedAccessTokens
    }
}

private actor CollectionAuthorizationSequence {
    enum SequenceError: Error {
        case exhausted
    }

    private var values: [SessionRequestAuthorization]

    init(values: [SessionRequestAuthorization]) {
        self.values = values
    }

    func next() throws -> SessionRequestAuthorization {
        guard values.isEmpty == false else { throw SequenceError.exhausted }

        return values.removeFirst()
    }
}

private actor ReplacingCollectionFetch {
    private struct RequestWaiter {
        let expectedCount: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private let remoteEntry: CollectionRemoteEntry
    private var recordedAccessTokens: [String] = []
    private var firstContinuation: CheckedContinuation<[CollectionRemoteEntry], any Error>?
    private var firstCancelled = false
    private var requestWaiters: [RequestWaiter] = []

    init(remoteEntry: CollectionRemoteEntry) {
        self.remoteEntry = remoteEntry
    }

    func load(accessToken: String) async throws(any Error) -> [CollectionRemoteEntry] {
        let requestIndex = recordedAccessTokens.count
        recordedAccessTokens.append(accessToken)
        resumeSatisfiedRequestWaiters()
        guard requestIndex == 0 else { return [remoteEntry] }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if firstCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    firstContinuation = continuation
                }
            }
        } onCancel: {
            Task { await self.cancelFirstRequest() }
        }
    }

    func waitForRequestCount(_ expectedCount: Int) async {
        guard recordedAccessTokens.count < expectedCount else { return }

        await withCheckedContinuation { continuation in
            requestWaiters.append(RequestWaiter(expectedCount: expectedCount, continuation: continuation))
        }
    }

    func accessTokens() -> [String] {
        recordedAccessTokens
    }

    func firstRequestWasCancelled() -> Bool {
        firstCancelled
    }

    func succeedFirstRequest() {
        firstContinuation?.resume(returning: [remoteEntry])
        firstContinuation = nil
    }

    private func cancelFirstRequest() {
        firstCancelled = true
        firstContinuation?.resume(throwing: CancellationError())
        firstContinuation = nil
    }

    private func resumeSatisfiedRequestWaiters() {
        let satisfied = requestWaiters.filter { recordedAccessTokens.count >= $0.expectedCount }
        requestWaiters.removeAll { recordedAccessTokens.count >= $0.expectedCount }
        satisfied.forEach { $0.continuation.resume() }
    }
}

private actor CoordinatorCallGate {
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

private actor CollectionImportRecorder {
    struct Event: Equatable {
        let userID: UUID
        let mangaIDs: [Manga.ID]
    }

    private var recordedEvents: [Event] = []

    func record(entries: [CollectionRemoteEntry], userID: UUID) {
        recordedEvents.append(Event(userID: userID, mangaIDs: entries.map(\.manga.id)))
    }

    func events() -> [Event] {
        recordedEvents
    }
}

private actor CollectionAuthorizationRecoveryRecorder {
    private var recordedRequests: [SessionRequestAuthorization] = []

    func record(_ authorization: SessionRequestAuthorization) {
        recordedRequests.append(authorization)
    }

    func requests() -> [SessionRequestAuthorization] {
        recordedRequests
    }

    func accessTokens() -> [String] {
        recordedRequests.map(\.accessToken)
    }
}
