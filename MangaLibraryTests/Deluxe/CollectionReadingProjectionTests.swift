//
//  CollectionReadingProjectionTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@Suite("Persisted Deluxe reading projection", .tags(.integration))
struct CollectionReadingProjectionTests {
    @Test
    func `projects the approved persisted batch without requiring ownership`() async throws {
        let fixture = try ProjectionFixture.load()
        let container = try fixture.container(caseNames: fixture.validBatch.caseNames)
        let actor = CollectionMutationActor(modelContainer: container)

        let projection = try await actor.readingProjection(authorization: Self.authorization())

        #expect(projection.authority == Self.authority)
        #expect(projection.items.map(\.mangaID) == fixture.validBatch.expectedOrderedIDs)
        #expect(projection.totalEligibleCount == fixture.validBatch.expectedTotalEligibleCount)
        #expect(projection.items.map(\.readingVolume) == [3, 2, 300])
        #expect(projection.items.map(\.totalVolumes) == [3, 3, nil])
        #expect(projection.items.map(\.title) == ["Alba de papel", "Bosque de tinta", nil])
    }

    @Test(arguments: [0, 1])
    func `orders by the independent DX1 title examples`(_ index: Int) async throws {
        let fixture = try ProjectionFixture.load()
        let example = fixture.orderingExamples[index]
        let container = try Self.container()
        let context = ModelContext(container)
        for (id, title) in example.titlesByID {
            context.insert(Self.entry(mangaID: try #require(Int64(id)), title: title))
        }
        try context.save()

        let projection = try await CollectionMutationActor(modelContainer: container)
            .readingProjection(authorization: Self.authorization())

        #expect(projection.items.map(\.mangaID) == example.expectedOrderedIDs)
    }

    @Test
    func `excluded rows cannot poison the authorized reading batch`() async throws {
        let container = try Self.container()
        let context = ModelContext(container)
        context.insert(Self.entry(mangaID: 10, title: "Valid"))
        context.insert(Self.entry(mangaID: 20, reading: 301, tombstone: true))
        context.insert(Self.entry(mangaID: 30, reading: nil, total: 0))
        context.insert(Self.entry(userID: Self.otherUser, mangaID: 10, reading: .max))
        try context.save()

        let projection = try await CollectionMutationActor(modelContainer: container)
            .readingProjection(authorization: Self.authorization())

        #expect(projection.items.map(\.mangaID) == [10])
        #expect(projection.totalEligibleCount == 1)
    }

    @Test
    func `historical ownership does not invalidate a valid current reading`() async throws {
        let container = try Self.container()
        let context = ModelContext(container)
        context.insert(
            Self.entry(
                reading: 2,
                total: 3,
                owned: [301, -1, 301],
                complete: true
            )
        )
        try context.save()

        let projection = try await CollectionMutationActor(modelContainer: container)
            .readingProjection(authorization: Self.authorization())

        #expect(projection.items.map(\.readingVolume) == [2])
        let persisted = try #require(ModelContext(container).fetch(FetchDescriptor<CollectionEntry>()).first)
        #expect(persisted.ownedVolumes == [301, -1, 301])
        #expect(persisted.isComplete)
    }

    @Test(
        arguments: [
            (Int64(0), Optional<Int64>.none), (301, nil), (.min, nil), (.max, nil),
            (1, 0), (1, 301), (1, .min), (1, .max), (3, 2)
        ]
    )
    func `rejects the entire batch for an incompatible selected reading`(
        _ reading: Int64,
        _ total: Int64?
    ) async throws {
        let container = try Self.container()
        let context = ModelContext(container)
        context.insert(Self.entry(mangaID: 10, title: "Valid"))
        context.insert(Self.entry(mangaID: 20, reading: reading, total: total))
        try context.save()
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionReadingProjectionError.incompatibleStoredReading) {
            try await actor.readingProjection(authorization: Self.authorization())
        }

        #expect(try ModelContext(container).fetchCount(FetchDescriptor<CollectionEntry>()) == 2)
    }

    @Test
    func `the approved historical fixture rejects preparation instead of becoming empty`() async throws {
        let fixture = try ProjectionFixture.load()
        let container = try fixture.container(caseNames: ["invalid-historical-reading"])
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionReadingProjectionError.incompatibleStoredReading) {
            try await actor.readingProjection(authorization: Self.authorization())
        }
    }

    @Test
    func `returns empty only when no persisted readings are eligible`() async throws {
        let fixture = try ProjectionFixture.load()
        let container = try fixture.container(caseNames: ["no-current-reading", "tombstone", "other-identity"])

        let projection = try await CollectionMutationActor(modelContainer: container)
            .readingProjection(authorization: Self.authorization())

        #expect(projection.items.isEmpty)
        #expect(projection.totalEligibleCount == 0)
    }

    @Test(
        arguments: [
            (" \n Principal \t", Optional("Principal")),
            (" \n\t ", nil),
            (String(repeating: "a", count: 512), String(repeating: "a", count: 512)),
            (String(repeating: "a", count: 513), String(repeating: "a", count: 509) + "…"),
            (String(repeating: "é", count: 257), String(repeating: "é", count: 254) + "…"),
            (String(repeating: "e\u{301}", count: 172), String(repeating: "e\u{301}", count: 169) + "…"),
            (String(repeating: "a", count: 500) + "👨‍👩‍👧‍👦Z", String(repeating: "a", count: 500) + "…"),
            ("a" + String(repeating: "\u{301}", count: 300), "…")
        ]
    )
    func `prepares the principal title without modifying persisted text`(
        _ source: String,
        _ expected: String?
    ) async throws {
        let container = try Self.container()
        let context = ModelContext(container)
        context.insert(Self.entry(title: source))
        try context.save()

        let projection = try await CollectionMutationActor(modelContainer: container)
            .readingProjection(authorization: Self.authorization())

        let item = try #require(projection.items.first)
        #expect(item.title == expected)
        #expect(item.title.map { Array($0.utf8) } == expected.map { Array($0.utf8) })
        let persisted = try #require(ModelContext(container).fetch(FetchDescriptor<CollectionEntry>()).first)
        #expect(persisted.mangaSnapshot?.title == source)
        #expect(persisted.mangaSnapshot.map { Array($0.title.utf8) } == Array(source.utf8))
    }

    @Test
    func `missing snapshots preserve reading with absent title and cover`() async throws {
        let container = try Self.container()
        let context = ModelContext(container)
        context.insert(Self.entry(title: nil))
        try context.save()

        let projection = try await CollectionMutationActor(modelContainer: container)
            .readingProjection(authorization: Self.authorization())

        let item = try #require(projection.items.first)
        #expect(item.title == nil)
        #expect(item.coverURL == nil)
        #expect(item.readingVolume == 1)
    }

    @Test
    func `retains the optional cover URL as private preparation input`() async throws {
        let container = try Self.container()
        let context = ModelContext(container)
        let cover = try #require(URL(string: "https://covers.example.test/local-input.jpg"))
        context.insert(Self.entry(title: "Primary", coverURL: cover))
        try context.save()

        let projection = try await CollectionMutationActor(modelContainer: container)
            .readingProjection(authorization: Self.authorization())

        #expect(projection.items.first?.coverURL == cover)
        #expect(projection.items.first?.title == "Primary")
    }

    @Test
    func `canonical equivalents and abbreviated titles use the stable byte order`() async throws {
        let container = try Self.container()
        let context = ModelContext(container)
        context.insert(Self.entry(mangaID: 8, title: "Éclair"))
        context.insert(Self.entry(mangaID: 3, title: "E\u{301}CLAIR"))
        context.insert(Self.entry(mangaID: 4, title: String(repeating: "x", count: 512) + "a"))
        context.insert(Self.entry(mangaID: 2, title: String(repeating: "x", count: 512) + "z"))
        context.insert(Self.entry(mangaID: 1, title: " \n"))
        context.insert(Self.entry(mangaID: 5, title: "Volume 2"))
        context.insert(Self.entry(mangaID: 6, title: "Volume 10"))
        try context.save()

        let projection = try await CollectionMutationActor(modelContainer: container)
            .readingProjection(authorization: Self.authorization())

        #expect(projection.items.map(\.mangaID) == [3, 8, 6, 5, 2, 4, 1])
    }

    @Test
    func `a mismatched presentation identity never labels another manga`() async throws {
        let container = try Self.container()
        let context = ModelContext(container)
        let entry = Self.entry(mangaID: 10)
        entry.apply(entry.state, mangaSnapshot: Self.snapshot(mangaID: 20, title: "Other manga", coverURL: nil))
        context.insert(entry)
        try context.save()
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionReadingProjectionError.incompatibleSnapshotIdentity) {
            try await actor.readingProjection(authorization: Self.authorization())
        }
    }

    @Test(arguments: ["invalidated", "suspended", "new-generation", "other-user", "new-credential", "expired"])
    func `denies stale suspended and expired capabilities`(_ transition: String) async throws {
        let container = try Self.container()
        let context = ModelContext(container)
        context.insert(Self.entry())
        try context.save()
        let gate = SessionCommitGate(
            activeAuthority: Self.authority,
            expiresAt: transition == "expired" ? .distantPast : .distantFuture,
            now: { Date(timeIntervalSince1970: 1_788_652_800) }
        )
        let authorization = gate.authorization(for: Self.authority)
        switch transition {
        case "invalidated":
            gate.invalidateAll()
        case "suspended":
            gate.suspend(Self.authority)
        case "new-generation":
            gate.activate(SessionAuthority(userID: Self.user, generation: Self.otherGeneration))
        case "other-user":
            gate.activate(SessionAuthority(userID: Self.otherUser, generation: Self.otherGeneration))
        case "new-credential":
            gate.activate(Self.authority)
        default:
            break
        }
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionReadingProjectionError.authenticationRequired) {
            try await actor.readingProjection(authorization: authorization)
        }
    }

    @Test
    func `a replacement capability selects only its authorized identity`() async throws {
        let fixture = try ProjectionFixture.load()
        let container = try fixture.container(caseNames: fixture.validBatch.caseNames)
        let authority = SessionAuthority(userID: Self.otherUser, generation: Self.otherGeneration)
        let gate = SessionCommitGate(activeAuthority: Self.authority)
        gate.activate(authority)

        let projection = try await CollectionMutationActor(modelContainer: container)
            .readingProjection(authorization: gate.authorization(for: authority))

        #expect(projection.authority == authority)
        #expect(projection.items.map(\.title) == ["Otra biblioteca"])
        #expect(projection.items.map(\.readingVolume) == [1])
    }

    @Test
    func `observes committed mutations without changing collection or outbox`() async throws {
        let container = try Self.container()
        let actor = CollectionMutationActor(modelContainer: container)
        let authorization = Self.authorization()
        let command = CollectionMutationCommand(
            authority: Self.authority,
            mangaID: 10,
            mangaSnapshot: Self.snapshot(mangaID: 10, title: "Committed", coverURL: nil),
            knownTotalVolumes: 3,
            change: .setReadingVolume(2)
        )
        let committed = try await actor.apply(command, authorization: authorization, newOperationID: Self.generation)

        let projection = try await actor.readingProjection(authorization: authorization)

        #expect(projection.items.map(\.readingVolume) == [2])
        let context = ModelContext(container)
        let entry = try #require(context.fetch(FetchDescriptor<CollectionEntry>()).first)
        let operation = try #require(context.fetch(FetchDescriptor<CollectionOutboxOperation>()).first)
        #expect(entry.state == committed.state)
        #expect(operation.sequence == 1)
        #expect(operation.state == .queued)
        #expect(operation.desiredState.readingVolume == 2)

        _ = try await actor.apply(
            CollectionMutationCommand(
                authority: Self.authority,
                mangaID: 10,
                knownTotalVolumes: nil,
                change: .setReadingVolume(nil)
            ),
            authorization: authorization
        )
        let cleared = try await actor.readingProjection(authorization: authorization)
        #expect(cleared.items.isEmpty)
    }

    @Test
    func `refuses an uncommitted context without saving its speculative row`() async throws {
        let container = try Self.container()
        let actor = CollectionMutationActor(modelContainer: container)
        await actor.stageReadingProjectionTestRow(userID: Self.user)

        await #expect(throws: CollectionReadingProjectionError.uncommittedChanges) {
            try await actor.readingProjection(authorization: Self.authorization())
        }

        #expect(try ModelContext(container).fetchCount(FetchDescriptor<CollectionEntry>()) == 0)
    }

    @Test
    func `cancellation rejects preparation without partial content`() async throws {
        let container = try Self.container()
        let actor = CollectionMutationActor(modelContainer: container)

        await #expect(throws: CollectionReadingProjectionError.cancelled) {
            try await withThrowingTaskGroup(of: CollectionReadingProjection.self) { group in
                group.cancelAll()
                group.addTask {
                    try await actor.readingProjection(authorization: Self.authorization())
                }
                return try #require(try await group.next())
            }
        }
    }
}

private extension CollectionReadingProjectionTests {
    static let user = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    static let otherUser = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    static let generation = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3))
    static let otherGeneration = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4))
    static let authority = SessionAuthority(userID: user, generation: generation)

    static func authorization() -> SessionCommitAuthorization {
        SessionCommitGate(activeAuthority: authority).authorization(for: authority)
    }

    static func container() throws -> ModelContainer {
        try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
    }

    static func entry(
        userID: UUID = user,
        mangaID: Manga.ID = 10,
        title: String? = "Reading",
        reading: Int64? = 1,
        total: Int64? = nil,
        owned: [Int64] = [],
        complete: Bool = false,
        tombstone: Bool = false,
        coverURL: URL? = nil
    ) -> CollectionEntry {
        CollectionEntry(
            userID: userID,
            mangaID: mangaID,
            state: CollectionSnapshot(
                ownedVolumes: owned,
                readingVolume: reading,
                isComplete: complete,
                knownTotalVolumes: total,
                isTombstone: tombstone
            ),
            confirmedState: nil,
            mangaSnapshot: title.map { snapshot(mangaID: mangaID, title: $0, coverURL: coverURL) }
        )
    }

    static func snapshot(mangaID: Manga.ID, title: String, coverURL: URL?) -> CollectionMangaSnapshot {
        CollectionMangaSnapshot(
            mangaID: mangaID,
            title: title,
            titleEnglish: "Do not substitute this translation",
            titleJapanese: "別の翻訳",
            synopsis: nil,
            score: 0,
            status: .unspecified,
            authors: [],
            demographics: [],
            genres: [],
            themes: [],
            coverURL: coverURL
        )
    }
}

private struct ProjectionFixture: Decodable {
    struct Scenario: Decodable {
        struct Input: Decodable {
            let session: String
            let mangaID: Int64
            let title: String?
            let readingVolume: Int64?
            let totalVolumes: Int64?
            let ownedVolumes: [Int64]
            let isComplete: Bool
            let isTombstone: Bool
        }
        let name: String
        let input: Input
    }
    struct Batch: Decodable {
        let caseNames: [String]
        let expectedOrderedIDs: [Int64]
        let expectedTotalEligibleCount: Int64
    }
    struct Ordering: Decodable {
        let titlesByID: [String: String?]
        let expectedOrderedIDs: [Int64]
    }
    let cases: [Scenario]
    let validBatch: Batch
    let orderingExamples: [Ordering]

    static func load() throws -> Self {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: root.appending(path: "Contracts/Deluxe/projection-scenarios.json"))
        return try JSONDecoder().decode(Self.self, from: data)
    }

    func container(caseNames: [String]) throws -> ModelContainer {
        let container = try CollectionReadingProjectionTests.container()
        let context = ModelContext(container)
        for name in caseNames {
            let input = try #require(cases.first { $0.name == name }).input
            context.insert(
                CollectionReadingProjectionTests.entry(
                    userID: input.session == "A"
                        ? CollectionReadingProjectionTests.user
                        : CollectionReadingProjectionTests.otherUser,
                    mangaID: input.mangaID,
                    title: input.title,
                    reading: input.readingVolume,
                    total: input.totalVolumes,
                    owned: input.ownedVolumes,
                    complete: input.isComplete,
                    tombstone: input.isTombstone
                )
            )
        }
        try context.save()
        return container
    }
}

private extension CollectionMutationActor {
    func stageReadingProjectionTestRow(userID: UUID) {
        modelContext.autosaveEnabled = false
        modelContext.insert(
            CollectionEntry(
                userID: userID,
                mangaID: 99,
                state: CollectionSnapshot(
                    ownedVolumes: [],
                    readingVolume: 1,
                    isComplete: false,
                    knownTotalVolumes: nil,
                    isTombstone: false
                ),
                confirmedState: nil
            )
        )
    }
}
