//
//  CollectionPersistenceTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@Suite("Collection persistence", .tags(.integration))
struct CollectionPersistenceTests {
    @Test("The active query isolates one user and excludes tombstones")
    func activeQueryScopesAtTheStore() async throws {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let actor = CollectionMutationActor(modelContainer: container)

        _ = try await actor.apply(
            command(userID: Self.userA, manga: manga(id: 42), ownedVolumes: [1]),
            newOperationID: Self.operationA
        )
        _ = try await actor.apply(
            command(userID: Self.userA, manga: manga(id: 84), ownedVolumes: [2]),
            newOperationID: Self.operationB
        )
        _ = try await actor.apply(
            CollectionMutationCommand(
                authority: Self.authorityA,
                mangaID: 84,
                knownTotalVolumes: 3,
                change: .delete
            ),
            newOperationID: Self.operationC
        )
        _ = try await actor.apply(
            command(userID: Self.userB, manga: manga(id: 42), ownedVolumes: [3]),
            newOperationID: Self.operationD
        )

        let context = ModelContext(container)
        let entries = try context.fetch(
            FetchDescriptor<CollectionEntry>(
                predicate: CollectionEntry.activePredicate(userID: Self.userA),
                sortBy: [SortDescriptor(\CollectionEntry.mangaID)]
            )
        )
        let userBEntries = try context.fetch(
            FetchDescriptor<CollectionEntry>(
                predicate: CollectionEntry.activePredicate(userID: Self.userB),
                sortBy: [SortDescriptor(\CollectionEntry.mangaID)]
            )
        )
        let activePair = try context.fetch(
            FetchDescriptor<CollectionEntry>(
                predicate: CollectionEntry.activePredicate(userID: Self.userA, mangaID: 42)
            )
        )
        let deletedPair = try context.fetch(
            FetchDescriptor<CollectionEntry>(
                predicate: CollectionEntry.activePredicate(userID: Self.userA, mangaID: 84)
            )
        )

        #expect(entries.map(\.userID) == [Self.userA])
        #expect(entries.map(\.mangaID) == [42])
        #expect(entries.allSatisfy { $0.isTombstone == false })
        #expect(userBEntries.map(\.userID) == [Self.userB])
        #expect(userBEntries.map(\.mangaID) == [42])
        #expect(activePair.map(\.mangaID) == [42])
        #expect(deletedPair.isEmpty)
    }

    @Test("A V1 disk store migrates to V2 without inventing presentation data")
    func migratesV1StoreToV2() throws {
        let location = try makeStoreLocation()
        defer { removeStoreLocation(location.directory) }
        try seedV1Store(at: location.store)

        let container = try MangaLibrarySchema.makeContainer(storeURL: location.store)
        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
        let entry = try #require(entries.first)
        let operation = try #require(operations.first)

        #expect(entries.count == 1)
        #expect(entry.userID == Self.userA)
        #expect(entry.mangaID == 42)
        #expect(entry.ownedVolumes == [1, 3])
        #expect(entry.readingVolume == 2)
        #expect(entry.isComplete == false)
        #expect(entry.knownTotalVolumes == 3)
        #expect(entry.confirmedState == nil)
        #expect(entry.isTombstone == false)
        #expect(entry.mangaSnapshot == nil)
        #expect(operations.count == 1)
        #expect(operation.operationID == Self.operationA)
        #expect(operation.userID == Self.userA)
        #expect(operation.mangaID == 42)
        #expect(operation.sequence == 7)
        #expect(operation.desiredState.ownedVolumes == [1, 3])
        #expect(operation.desiredState.readingVolume == 2)
        #expect(operation.desiredState.isComplete == false)
        #expect(operation.desiredState.knownTotalVolumes == 3)
        #expect(operation.desiredState.isTombstone == false)
        #expect(operation.state == .queued)
        #expect(operation.retryCount == 0)
        #expect(operation.nextRetryAt == nil)
        #expect(operation.isTombstone == false)
    }

    @Test("Add, edit, delete, and user isolation survive reopening the same disk store")
    func collectionLifecycleAndIsolationSurviveReopening() async throws {
        let location = try makeStoreLocation()
        defer { removeStoreLocation(location.directory) }
        let expectedManga = manga(id: 42)

        try await seedCurrentStore(at: location.store, manga: expectedManga)

        do {
            let reopened = try MangaLibrarySchema.makeContainer(storeURL: location.store)
            let context = ModelContext(reopened)
            let userAEntries = try context.fetch(
                FetchDescriptor<CollectionEntry>(predicate: CollectionEntry.activePredicate(userID: Self.userA))
            )
            let userBEntries = try context.fetch(
                FetchDescriptor<CollectionEntry>(predicate: CollectionEntry.activePredicate(userID: Self.userB))
            )
            let entryA = try #require(userAEntries.first)
            let entryB = try #require(userBEntries.first)

            #expect(userAEntries.count == 1)
            #expect(userBEntries.count == 1)
            #expect(entryA.ownedVolumes == [1, 3])
            #expect(entryB.ownedVolumes == [2])
            #expect(entryA.mangaSnapshot?.manga(knownTotalVolumes: entryA.knownTotalVolumes) == expectedManga)
            #expect(entryB.mangaSnapshot?.manga(knownTotalVolumes: entryB.knownTotalVolumes) == expectedManga)

            let actor = CollectionMutationActor(modelContainer: reopened)
            _ = try await actor.apply(
                CollectionMutationCommand(
                    authority: Self.authorityA,
                    mangaID: expectedManga.id,
                    knownTotalVolumes: expectedManga.totalVolumes,
                    change: .replaceState(ownedVolumes: [2, 3], readingVolume: 2, isComplete: false)
                ),
                newOperationID: Self.operationB
            )
        }

        do {
            let editedStore = try MangaLibrarySchema.makeContainer(storeURL: location.store)
            let context = ModelContext(editedStore)
            let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
            let entryA = try #require(entries.first { $0.userID == Self.userA })
            let entryB = try #require(entries.first { $0.userID == Self.userB })
            let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
            let operationA = try #require(operations.first { $0.userID == Self.userA })
            let operationB = try #require(operations.first { $0.userID == Self.userB })

            #expect(entryA.ownedVolumes == [2, 3])
            #expect(entryA.readingVolume == 2)
            #expect(entryA.isTombstone == false)
            #expect(entryB.ownedVolumes == [2])
            #expect(entryB.readingVolume == nil)
            #expect(entryB.isTombstone == false)
            #expect(operationA.operationID == Self.operationA)
            #expect(operationA.sequence == 2)
            #expect(operationA.desiredState == entryA.state)
            #expect(operationB.operationID == Self.operationD)
            #expect(operationB.sequence == 1)
            #expect(operationB.desiredState == entryB.state)

            let actor = CollectionMutationActor(modelContainer: editedStore)
            _ = try await actor.apply(
                CollectionMutationCommand(
                    authority: Self.authorityA,
                    mangaID: expectedManga.id,
                    knownTotalVolumes: expectedManga.totalVolumes,
                    change: .delete
                ),
                newOperationID: Self.operationC
            )
        }

        let deletedStore = try MangaLibrarySchema.makeContainer(storeURL: location.store)
        let context = ModelContext(deletedStore)
        let activeA = try context.fetch(
            FetchDescriptor<CollectionEntry>(predicate: CollectionEntry.activePredicate(userID: Self.userA))
        )
        let activeB = try context.fetch(
            FetchDescriptor<CollectionEntry>(predicate: CollectionEntry.activePredicate(userID: Self.userB))
        )
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        let entryA = try #require(entries.first { $0.userID == Self.userA })
        let entryB = try #require(entries.first { $0.userID == Self.userB })
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
        let operationA = try #require(operations.first { $0.userID == Self.userA })
        let operationB = try #require(operations.first { $0.userID == Self.userB })

        #expect(activeA.isEmpty)
        #expect(activeB.map(\.userID) == [Self.userB])
        #expect(entryA.ownedVolumes == [2, 3])
        #expect(entryA.readingVolume == 2)
        #expect(entryA.isTombstone)
        #expect(entryA.mangaSnapshot?.manga(knownTotalVolumes: entryA.knownTotalVolumes) == expectedManga)
        #expect(entryB.ownedVolumes == [2])
        #expect(entryB.isTombstone == false)
        #expect(operationA.operationID == Self.operationA)
        #expect(operationA.sequence == 3)
        #expect(operationA.isTombstone)
        #expect(operationA.desiredState == entryA.state)
        #expect(operationB.operationID == Self.operationD)
        #expect(operationB.sequence == 1)
        #expect(operationB.isTombstone == false)
        #expect(operationB.desiredState == entryB.state)
    }

    private func command(userID: UUID, manga: Manga, ownedVolumes: [Int64]) -> CollectionMutationCommand {
        CollectionMutationCommand(
            authority: userID == Self.userA ? Self.authorityA : Self.authorityB,
            mangaID: manga.id,
            mangaSnapshot: CollectionMangaSnapshot(manga: manga),
            knownTotalVolumes: manga.totalVolumes,
            change: .replaceState(ownedVolumes: ownedVolumes, readingVolume: nil, isComplete: false)
        )
    }

    private func manga(id: Manga.ID) -> Manga {
        Manga(
            id: id,
            title: "Manga \(id)",
            titleEnglish: nil,
            titleJapanese: nil,
            synopsis: "Offline detail",
            score: 8.5,
            status: .publishing,
            authors: [],
            demographics: [],
            genres: [],
            themes: [],
            totalVolumes: 3,
            coverURL: nil
        )
    }

    private func seedCurrentStore(at storeURL: URL, manga: Manga) async throws {
        let container = try MangaLibrarySchema.makeContainer(storeURL: storeURL)
        let actor = CollectionMutationActor(modelContainer: container)

        _ = try await actor.apply(
            command(userID: Self.userA, manga: manga, ownedVolumes: [3, 1]),
            newOperationID: Self.operationA
        )
        _ = try await actor.apply(
            command(userID: Self.userB, manga: manga, ownedVolumes: [2]),
            newOperationID: Self.operationD
        )
    }

    private func seedV1Store(at storeURL: URL) throws {
        let schema = Schema(versionedSchema: MangaLibrarySchema.V1.self)
        let configuration = ModelConfiguration(
            "MangaLibrary",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        let state = MangaLibrarySchema.V1.CollectionSnapshot(
            ownedVolumes: [1, 3],
            readingVolume: 2,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        context.insert(
            MangaLibrarySchema.V1.CollectionEntry(
                userID: Self.userA,
                mangaID: 42,
                state: state,
                confirmedState: nil
            )
        )
        context.insert(
            MangaLibrarySchema.V1.CollectionOutboxOperation(
                operationID: Self.operationA,
                userID: Self.userA,
                mangaID: 42,
                sequence: 7,
                desiredState: state
            )
        )
        try context.save()
    }

    private func makeStoreLocation() throws -> (directory: URL, store: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, directory.appending(path: "MangaLibrary.store"))
    }

    private func removeStoreLocation(_ directory: URL) {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            Issue.record("Could not remove the isolated SwiftData store: \(error)")
        }
    }

    private static let userA = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private static let userB = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
    private static let authorityA = SessionAuthority(
        userID: userA,
        generation: UUID(uuidString: "A0A0A0A0-0000-0000-0000-000000000001")!
    )
    private static let authorityB = SessionAuthority(
        userID: userB,
        generation: UUID(uuidString: "B0B0B0B0-0000-0000-0000-000000000002")!
    )
    private static let operationA = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private static let operationB = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!
    private static let operationC = UUID(uuidString: "CCCCCCCC-DDDD-EEEE-FFFF-000000000000")!
    private static let operationD = UUID(uuidString: "DDDDDDDD-EEEE-FFFF-0000-111111111111")!
}
