//
//  CollectionSyncCoordinatorTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
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
            validateAuthority: { authority in
                await authorityState.isCurrent(authority)
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
            validateAuthority: { _ in true },
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
            validateAuthority: { _ in true },
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
            validateAuthority: { _ in true },
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

    @Test(
        "A protected authentication rejection invalidates the captured credential",
        arguments: [401, 403]
    )
    func unauthorizedResponseInvalidatesItsRequest(_ statusCode: Int) async throws(any Error) {
        let authority = SessionAuthority(userID: Self.userA, generation: Self.generationA)
        let authorization = Self.authorization(authority: authority, accessToken: "fixture-access-A")
        let rejections = CollectionAuthorizationRejectionRecorder()
        let imports = CollectionImportRecorder()
        let coordinator = CollectionSyncCoordinator(
            authorize: { authorization },
            validateAuthority: { _ in true },
            rejectAuthorization: { rejectedAuthorization in
                await rejections.record(rejectedAuthorization)
            },
            fetchRemote: { _ in throw CollectionAPIClientError.network(.statusCode(statusCode)) },
            importRemote: { entries, commitAuthorization in
                await imports.record(
                    entries: entries,
                    userID: commitAuthorization.authority.userID
                )
            }
        )

        await #expect(throws: SessionControllerError.authenticationRequired) {
            try await coordinator.importAuthenticatedCollection()
        }

        let rejectedRequests = await rejections.requests()
        #expect(rejectedRequests.count == 1)
        #expect(rejectedRequests.first?.authority == authorization.authority)
        #expect(rejectedRequests.first?.accessToken == authorization.accessToken)
        #expect(await imports.events().isEmpty)
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
            validateAuthority: { _ in true },
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

    private static func authorization(
        authority: SessionAuthority,
        accessToken: String
    ) -> SessionRequestAuthorization {
        let gate = SessionCommitGate(activeAuthority: authority)
        return SessionRequestAuthorization(
            authority: authority,
            accessToken: accessToken,
            commitAuthorization: gate.authorization(for: authority)
        )
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

private actor CollectionAuthorizationRejectionRecorder {
    private var recordedRequests: [SessionRequestAuthorization] = []

    func record(_ authorization: SessionRequestAuthorization) {
        recordedRequests.append(authorization)
    }

    func requests() -> [SessionRequestAuthorization] {
        recordedRequests
    }
}
