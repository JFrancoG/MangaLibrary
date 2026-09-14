//
//  AppStartupPersistenceTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@Suite("App startup persistence", .tags(.integration))
struct AppStartupPersistenceTests {
    @Test
    @MainActor
    func `retry opens the same durable collection without replacing its pending intent`() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("Could not remove the isolated startup store.")
            }
        }
        let storeURL = directory.appending(path: "MangaLibrary.store")
        try await seedStore(at: storeURL)
        let originalFileNumber = try fileNumber(at: storeURL)
        let opener = RecoverableStoreOpening(storeURL: storeURL)
        var compositions = 0
        let model = AppStartupModel(
            openStore: {
                try await opener.open()
            },
            compose: { container in
                compositions += 1
                return AppStartupTestSupport.runtime(modelContainer: container)
            }
        )

        await model.startIfNeeded()

        guard case .unavailable = model.state else {
            Issue.record("The unavailable disk store must leave startup recoverable.")
            return
        }
        #expect(compositions == 0)
        #expect(try fileNumber(at: storeURL) == originalFileNumber)

        await opener.allowOpening()
        await model.retry()

        guard case let .ready(runtime) = model.state else {
            Issue.record("Explicit retry must open the existing disk store.")
            return
        }
        #expect(compositions == 1)
        #expect(try fileNumber(at: storeURL) == originalFileNumber)
        try expectSeededCollection(in: runtime.modelContainer)

        await model.startIfNeeded()
        await model.retry()

        guard case let .ready(retained) = model.state else {
            Issue.record("A ready composition must survive later startup requests.")
            return
        }
        #expect(retained.modelContainer === runtime.modelContainer)
        #expect(retained.accountModel === runtime.accountModel)
        #expect(compositions == 1)
        #expect(await opener.openedLocations == [storeURL, storeURL])
        try expectSeededCollection(in: retained.modelContainer)
    }

    private func seedStore(at storeURL: URL) async throws {
        let container = try MangaLibrarySchema.makeContainer(storeURL: storeURL)
        let mutations = CollectionMutationActor(modelContainer: container)
        _ = try await mutations.apply(
            CollectionMutationCommand(
                authority: Self.authority,
                mangaID: 42,
                mangaSnapshot: CollectionMangaSnapshot(manga: Self.manga),
                knownTotalVolumes: 5,
                change: .replaceState(ownedVolumes: [1, 3], readingVolume: 2, isComplete: false)
            ),
            newOperationID: Self.operationID
        )
    }

    private func expectSeededCollection(in container: ModelContainer) throws {
        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
        let entry = try #require(entries.first)
        let operation = try #require(operations.first)
        let expectedState = CollectionSnapshot(
            ownedVolumes: [1, 3],
            readingVolume: 2,
            isComplete: false,
            knownTotalVolumes: 5,
            isTombstone: false
        )

        #expect(entries.count == 1)
        #expect(entry.userID == Self.authority.userID)
        #expect(entry.mangaID == 42)
        #expect(entry.state == expectedState)
        #expect(entry.confirmedState == nil)
        #expect(entry.mangaSnapshot?.manga(knownTotalVolumes: entry.knownTotalVolumes) == Self.manga)
        #expect(operations.count == 1)
        #expect(operation.operationID == Self.operationID)
        #expect(operation.userID == Self.authority.userID)
        #expect(operation.mangaID == 42)
        #expect(operation.sequence == 1)
        #expect(operation.desiredState == expectedState)
        #expect(operation.state == .queued)
        #expect(operation.retryCount == 0)
        #expect(operation.nextRetryAt == nil)
        #expect(operation.isTombstone == false)
    }

    private func fileNumber(at url: URL) throws -> NSNumber {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try #require(attributes[.systemFileNumber] as? NSNumber)
    }

    private static let authority = SessionAuthority(
        userID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        generation: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    )
    private static let operationID = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!
    private static let manga = Manga(
        id: 42,
        title: "Saved before startup failed",
        titleEnglish: nil,
        titleJapanese: nil,
        synopsis: "Available offline after retry.",
        score: 8.5,
        status: .publishing,
        authors: [],
        demographics: [],
        genres: [],
        themes: [],
        totalVolumes: 5,
        coverURL: nil
    )
}

private actor RecoverableStoreOpening {
    private let storeURL: URL
    private var isAvailable = false
    private(set) var openedLocations: [URL] = []

    init(storeURL: URL) {
        self.storeURL = storeURL
    }

    func allowOpening() {
        isAvailable = true
    }

    func open() throws -> ModelContainer {
        openedLocations.append(storeURL)
        guard isAvailable else { throw CocoaError(.fileReadNoPermission) }
        return try MangaLibrarySchema.makeContainer(storeURL: storeURL)
    }
}
