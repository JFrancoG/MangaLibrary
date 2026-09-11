//
//  CollectionReadingEventTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@Suite("Committed Collection reading events", .tags(.integration))
struct CollectionReadingEventTests {
    @Test
    func `local mutation signals only the committed reading`() async throws {
        let fixture = try await ReadingEventFixture()

        _ = try await fixture.actor.apply(fixture.command(reading: 2), authorization: fixture.authorization)

        let event = try #require(fixture.events.currentEvent())
        try event.ticket.validate(authority: fixture.authority)
        #expect(try fixture.persistedReading() == 2)
    }

    @Test
    func `remote import signals a changed title under local intent`() async throws {
        let fixture = try await ReadingEventFixture(localReading: 2)

        try await fixture.actor.importRemote(
            [ReadingEventFixture.remote(title: "Updated remote title", reading: 3)],
            authorization: fixture.authorization
        )

        let event = try #require(fixture.events.currentEvent())
        try event.ticket.validate(authority: fixture.authority)
        #expect(try fixture.persistedReading() == 2)
        #expect(try fixture.persistedTitle() == "Updated remote title")
    }

    @Test
    func `permanent rejection signals the restored baseline`() async throws {
        let fixture = try await ReadingEventFixture(localReading: 2, claim: true)
        let work = try #require(fixture.work)

        try await fixture.actor.resolvePermanentRejection(work, authorization: fixture.authorization)

        let event = try #require(fixture.events.currentEvent())
        try event.ticket.validate(authority: fixture.authority)
        #expect(try fixture.persistedReading() == 1)
    }

    @Test
    func `deletion reconciliation signals a later intentions changed title`() async throws {
        let fixture = try await ReadingEventFixture(deletionWithLaterReading: true)
        let work = try #require(fixture.work)

        _ = try await fixture.actor.resolveDeletion(
            work,
            evidence: .present(ReadingEventFixture.remote(title: "Deletion evidence title", reading: 1)),
            authorization: fixture.authorization
        )

        let event = try #require(fixture.events.currentEvent())
        try event.ticket.validate(authority: fixture.authority)
        #expect(try fixture.persistedReading() == 2)
        #expect(try fixture.persistedTitle() == "Deletion evidence title")
    }

    @Test
    func `blocked outcome adoption signals the remote projection`() async throws {
        let fixture = try await ReadingEventFixture(localReading: 2, claim: true, blocked: true)
        let work = try #require(fixture.work)
        let context = try await fixture.actor.blockedOutcomeContext(
            operationID: work.operationID,
            authorization: fixture.authorization
        )

        _ = try await fixture.actor.resolveBlockedOutcome(
            context,
            evidence: .present(
                state: ReadingEventFixture.state(reading: 3),
                mangaSnapshot: CollectionMangaSnapshot(manga: ReadingEventFixture.remote(reading: 3).manga)
            ),
            decision: .useRemote,
            authorization: fixture.authorization
        )

        let event = try #require(fixture.events.currentEvent())
        try event.ticket.validate(authority: fixture.authority)
        #expect(try fixture.persistedReading() == 3)
    }

    @Test
    func `logout discard invalidates the previous reading without authorizing new content`() async throws {
        let fixture = try await ReadingEventFixture(localReading: 2)
        let previous = try fixture.recordPrevious()
        let logout = try #require(fixture.gate.suspendForLogout(fixture.authority))

        try await fixture.actor.discardPendingChangesForLogout(authorization: logout)

        #expect(try fixture.persistedReading() == 1)
        #expect(fixture.events.currentEvent() == nil)
        #expect(throws: (any Error).self) {
            try previous.ticket.validate(authority: fixture.authority)
        }
    }

    @Test
    func `the second local commit invalidates the first ticket`() async throws {
        let fixture = try await ReadingEventFixture()
        _ = try await fixture.actor.apply(fixture.command(reading: 2), authorization: fixture.authorization)
        let previous = try #require(fixture.events.currentEvent())

        _ = try await fixture.actor.apply(fixture.command(reading: 3), authorization: fixture.authorization)

        #expect(throws: (any Error).self) {
            try previous.ticket.validate(authority: fixture.authority)
        }
        let current = try #require(fixture.events.currentEvent())
        try current.ticket.validate(authority: fixture.authority)
        #expect(try fixture.persistedReading() == 3)
    }

    @Test(arguments: ReadingRollbackRoute.allCases)
    func `failed transactions never signal or invalidate prior committed content`(
        _ route: ReadingRollbackRoute
    ) async throws {
        let fixture = try await ReadingEventFixture(
            localReading: 2,
            claim: route == .rejection || route == .blockedOutcome,
            blocked: route == .blockedOutcome
        )
        let previous = try fixture.recordPrevious()

        switch route {
        case .remoteImport:
            await #expect(throws: CollectionRemoteImportError.persistenceConflict) {
                try await fixture.actor.importRemote(
                    [ReadingEventFixture.remote(title: "Rolled back title", reading: 3)],
                    authorization: fixture.authorization,
                    afterMutation: { _ in
                        throw ReadingEventFailure.injected
                    }
                )
            }
        case .rejection:
            let work = try #require(fixture.work)
            await #expect(throws: CollectionOutboxUploadError.persistenceConflict) {
                try await fixture.actor.resolvePermanentRejection(
                    work,
                    authorization: fixture.authorization,
                    afterMutation: {
                        throw ReadingEventFailure.injected
                    }
                )
            }
        case .blockedOutcome:
            let work = try #require(fixture.work)
            let context = try await fixture.actor.blockedOutcomeContext(
                operationID: work.operationID,
                authorization: fixture.authorization
            )
            await #expect(throws: CollectionBlockedOutcomeError.persistenceConflict) {
                _ = try await fixture.actor.resolveBlockedOutcome(
                    context,
                    evidence: .absent,
                    decision: .useRemote,
                    authorization: fixture.authorization,
                    afterMutation: {
                        throw ReadingEventFailure.injected
                    }
                )
            }
        case .logout:
            let logout = try #require(fixture.gate.suspendForLogout(fixture.authority))
            await #expect(throws: CollectionLogoutError.persistenceConflict) {
                try await fixture.actor.discardPendingChangesForLogout(
                    authorization: logout,
                    afterRestoringPair: { _ in
                        throw ReadingEventFailure.injected
                    }
                )
            }
        }

        try previous.ticket.validate(authority: fixture.authority)
        #expect(try fixture.persistedReading() == 2)
        #expect(try fixture.persistedTitle() == "Original remote title")
    }

    @Test
    func `invalid local input never produces a reading event`() async throws {
        let fixture = try await ReadingEventFixture()
        let previous = try fixture.recordPrevious()

        await #expect(throws: CollectionMutationError.nonPositiveVolume(0)) {
            _ = try await fixture.actor.apply(fixture.command(reading: 0), authorization: fixture.authorization)
        }

        try previous.ticket.validate(authority: fixture.authority)
        #expect(try fixture.persistedReading() == 1)
    }

    @Test
    func `an unauthorized mutation leaves the event source empty`() async throws {
        let fixture = try await ReadingEventFixture()
        fixture.gate.invalidate(fixture.authority)

        await #expect(throws: CollectionMutationError.authenticationRequired) {
            _ = try await fixture.actor.apply(fixture.command(reading: 2), authorization: fixture.authorization)
        }

        #expect(fixture.events.currentEvent() == nil)
        #expect(try fixture.persistedReading() == 1)
    }

    @Test
    func `cancellation before remote commit preserves the previous ticket`() async throws {
        let fixture = try await ReadingEventFixture()
        let previous = try fixture.recordPrevious()

        await #expect(throws: CollectionRemoteImportError.cancelled) {
            try await fixture.actor.importRemote(
                [ReadingEventFixture.remote(reading: 3)],
                authorization: fixture.authorization,
                afterMutation: { _ in
                    throw CancellationError()
                }
            )
        }

        try previous.ticket.validate(authority: fixture.authority)
        #expect(try fixture.persistedReading() == 1)
    }

    @Test(arguments: ReadingOutboxOnlyRoute.allCases)
    func `upload bookkeeping does not obsolete a reading preparation`(_ route: ReadingOutboxOnlyRoute) async throws {
        let fixture = try await ReadingEventFixture(localReading: 2)
        let previous = try fixture.recordPrevious()
        let claim = try #require(try await fixture.actor.claimNextUpload(authorization: fixture.authorization))
        guard case let .send(work) = claim else {
            Issue.record("Expected the queued local edit to be claimed for transport")
            return
        }
        try previous.ticket.validate(authority: fixture.authority)

        switch route {
        case .confirmation:
            try await fixture.actor.confirmUpload(work, authorization: fixture.authorization)
        case .retry:
            try await fixture.actor.scheduleUploadRetry(
                work,
                nextRetryAt: Date(timeIntervalSince1970: 1_800_000_000),
                authorization: fixture.authorization
            )
        case .blockedOutcome:
            try await fixture.actor.blockUploadOutcome(work, authorization: fixture.authorization)
        }

        try previous.ticket.validate(authority: fixture.authority)
        #expect(try fixture.persistedReading() == 2)
    }
}

private struct ReadingEventFixture {
    let container: ModelContainer
    let actor: CollectionMutationActor
    let events: ReadingPublicationEvents
    let authority: SessionAuthority
    let gate: SessionCommitGate
    let authorization: SessionCommitAuthorization
    let work: CollectionOutboxUploadWorkItem?

    func command(reading: Int64) -> CollectionMutationCommand {
        Self.command(authority: authority, reading: reading)
    }

    func recordPrevious() throws -> ReadingPublicationEvent {
        try authorization.perform {
            events.record(authorization: authorization)
        }
    }

    func persistedReading() throws -> Int64? {
        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        return try #require(entries.first).readingVolume
    }

    func persistedTitle() throws -> String? {
        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        return try #require(entries.first).mangaSnapshot?.title
    }

    static func command(authority: SessionAuthority, reading: Int64) -> CollectionMutationCommand {
        CollectionMutationCommand(
            authority: authority,
            mangaID: 42,
            knownTotalVolumes: 3,
            change: .setReadingVolume(reading)
        )
    }

    static func state(reading: Int64) -> CollectionSnapshot {
        CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: reading,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
    }

    static func remote(title: String = "Original remote title", reading: Int64 = 1) -> CollectionRemoteEntry {
        CollectionRemoteEntry(
            remoteID: UUID(),
            manga: Manga(
                id: 42,
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
            readingVolume: reading,
            isComplete: false
        )
    }
}

private extension ReadingEventFixture {
    init(
        localReading: Int64? = nil,
        claim: Bool = false,
        blocked: Bool = false,
        deletionWithLaterReading: Bool = false
    ) async throws {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let authority = SessionAuthority(userID: UUID(), generation: UUID())
        let gate = SessionCommitGate(activeAuthority: authority)
        let authorization = gate.authorization(for: authority)
        let setup = CollectionMutationActor(modelContainer: container)
        try await setup.importRemote([Self.remote()], authorization: authorization)
        if let localReading {
            _ = try await setup.apply(
                Self.command(authority: authority, reading: localReading),
                authorization: authorization
            )
        }
        if deletionWithLaterReading {
            _ = try await setup.apply(
                CollectionMutationCommand(
                    authority: authority,
                    mangaID: 42,
                    knownTotalVolumes: 3,
                    change: .delete
                ),
                authorization: authorization
            )
        }
        let work: CollectionOutboxUploadWorkItem?
        if claim || deletionWithLaterReading {
            let claimed = try #require(try await setup.claimNextUpload(authorization: authorization))
            guard case let .send(item) = claimed else { throw ReadingEventFailure.expectedQueuedUpload }
            work = item
        } else {
            work = nil
        }
        if blocked, let work {
            try await setup.blockUploadOutcome(work, authorization: authorization)
        }
        if deletionWithLaterReading {
            _ = try await setup.apply(Self.command(authority: authority, reading: 2), authorization: authorization)
        }

        let events = ReadingPublicationEvents()
        self.container = container
        self.authority = authority
        self.gate = gate
        self.authorization = authorization
        self.work = work
        self.events = events
        actor = CollectionMutationActor(modelContainer: container, readingEvents: events)
    }
}

enum ReadingRollbackRoute: CaseIterable {
    case remoteImport
    case rejection
    case blockedOutcome
    case logout
}

enum ReadingOutboxOnlyRoute: CaseIterable {
    case confirmation
    case retry
    case blockedOutcome
}

private enum ReadingEventFailure: Error {
    case injected
    case expectedQueuedUpload
}
