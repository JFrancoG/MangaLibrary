//
//  CollectionOutcomeResolutionSessionTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("Collection outcome resolution session safety", .tags(.integration))
struct CollectionOutcomeResolutionSessionTests {
    @Test("A Collection 403 preserves the active session envelope")
    func forbiddenPreservesSessionEnvelope() async throws(any Error) {
        let harness = try Self.makeHarness()
        _ = try await harness.controller.restore()
        let coordinator = Self.coordinator(
            controller: harness.controller,
            fetch: { _, _ in
                throw CollectionAPIClientError.network(.statusCode(403))
            }
        )

        await #expect(throws: CollectionBlockedOutcomeError.authorizationDenied(statusCode: 403)) {
            try await coordinator.review(operationID: Self.operationID, expectedAuthority: Self.authority)
        }

        #expect(await harness.controller.currentSnapshot() == Self.activeSnapshot)
        #expect(harness.storage.snapshot().record == harness.persistedSession)
        #expect(harness.storage.snapshot().journal.contains(.removeAll) == false)
    }

    @Test("A second Collection 401 preserves the renewed session envelope")
    func repeatedUnauthorizedPreservesRenewedSessionEnvelope() async throws(any Error) {
        let harness = try Self.makeHarness()
        _ = try await harness.controller.restore()
        let coordinator = Self.coordinator(
            controller: harness.controller,
            fetch: { _, _ in
                throw CollectionAPIClientError.network(.statusCode(401))
            }
        )

        await #expect(throws: CollectionBlockedOutcomeError.authenticationIncompatible(statusCode: 401)) {
            try await coordinator.review(operationID: Self.operationID, expectedAuthority: Self.authority)
        }

        #expect(await harness.controller.currentSnapshot() == Self.activeSnapshot)
        #expect(harness.storage.snapshot().record?.authority == Self.authority)
        #expect(harness.storage.snapshot().record?.access.value == "renewed-access")
        #expect(harness.storage.snapshot().journal.contains(.removeAll) == false)
    }
}

private extension CollectionOutcomeResolutionSessionTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let generation = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let authority = SessionAuthority(userID: userID, generation: generation)
    static let operationID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let account = SessionAccount(
        authority: authority,
        id: userID,
        email: "r24@example.invalid",
        isActive: true,
        isAdmin: false,
        role: "user"
    )
    static let activeSnapshot = SessionSnapshot.active(account)
    static let localState = CollectionSnapshot(
        ownedVolumes: [1, 2],
        readingVolume: 2,
        isComplete: false,
        knownTotalVolumes: 3,
        isTombstone: false
    )
    static let context = CollectionBlockedOutcomeContext(
        operation: CollectionBlockedOutcomeOperationReference(
            authority: authority,
            operationID: operationID,
            userID: userID,
            mangaID: 42,
            sequence: 1,
            retryCount: 0,
            desiredState: localState
        ),
        deviceState: localState,
        mangaSnapshot: nil,
        laterIntent: nil
    )

    static func makeHarness() throws(any Error) -> R24SessionHarness {
        let persistedSession = try SessionPersistedSession(
            userID: userID,
            generation: generation,
            access: SessionCredential(value: "initial-access", expiresAt: now.addingTimeInterval(86_400))
        )
        let storage = ControlledSessionPersistenceStorage(record: persistedSession)
        let loader = R24SessionDataLoader()
        let baseURL = try #require(URL(string: "https://session.example.test"))
        let controller = SessionController(
            apiClient: SessionAPIClient(
                configuration: try APIConfiguration(baseURL: baseURL),
                loadData: { request in
                    try await loader.load(request)
                },
                now: { now }
            ),
            persistence: SessionPersistenceActor(operations: storage.operations()),
            now: { now },
            makeGeneration: { generation },
            logoutPendingChangesObserver: { _ in false },
            logoutPendingChangesDiscarder: { _ in },
            authenticationInvalidationObserver: { _ in }
        )
        return R24SessionHarness(controller: controller, storage: storage, persistedSession: persistedSession)
    }

    static func coordinator(
        controller: SessionController,
        fetch: @escaping CollectionOutcomeResolutionCoordinator.FetchRemoteEntry
    ) -> CollectionOutcomeResolutionCoordinator {
        CollectionOutcomeResolutionCoordinator(
            authorize: {
                try await controller.requestAuthorization()
            },
            validateAuthorization: { authorization in
                try await controller.authorizes(authorization)
            },
            recoverAuthorization: { authorization in
                try await controller.recoverAuthorization(after: authorization)
            },
            loadContext: { _, _ in context },
            fetchRemoteEntry: fetch,
            validateEvidence: { _, _ in .absent },
            resolveStore: { _, _, _, _, _ in .adoptedRemote }
        )
    }
}

private struct R24SessionHarness {
    let controller: SessionController
    let storage: ControlledSessionPersistenceStorage
    let persistedSession: SessionPersistedSession
}

private actor R24SessionDataLoader {
    func load(_ request: URLRequest) throws(any Error) -> Data {
        switch request.url?.path {
        case "/users/jwt/me":
            Data(
                #"""
                {
                  "email": "r24@example.invalid",
                  "id": "11111111-1111-1111-1111-111111111111",
                  "role": "user",
                  "isActive": true,
                  "isAdmin": false
                }
                """#.utf8
            )
        case "/users/jwt/refresh":
            Data(#"{"token":"renewed-access","tokenType":"Bearer","expiresIn":86400}"#.utf8)
        default:
            throw CollectionBlockedOutcomeError.unavailable
        }
    }
}
