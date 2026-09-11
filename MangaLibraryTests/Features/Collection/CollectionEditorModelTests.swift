//
//  CollectionEditorModelTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@MainActor
@Suite("Collection editor model", .tags(.integration))
struct CollectionEditorModelTests {
    @Test("A pending unknown volume cannot be ignored by save")
    func pendingUnknownVolumeMustBeAddedBeforeSave() async throws {
        let context = try makeContext(total: nil)
        context.model.volumeInput = "4"

        #expect(context.model.canSave)
        #expect(await context.model.save() == false)
        #expect(context.model.inputFailure == .pendingOwnedVolume)
        #expect(try fetchEntries(context.container).isEmpty)

        context.model.addUnknownVolume()
        #expect(context.model.sortedOwnedVolumes == [4])
        #expect(context.model.canSave)
        #expect(await context.model.save())

        let entry = try #require(fetchEntries(context.container).first)
        #expect(entry.ownedVolumes == [4])
    }

    @Test(
        "Unknown-volume input rejects malformed and out-of-policy values",
        arguments: ["", "manga", "0", "-1", "301", String(Int64.max)]
    )
    func invalidUnknownVolumeCannotBecomeOwnership(volumeInput: String) throws {
        let context = try makeContext(total: nil)
        context.model.volumeInput = volumeInput

        context.model.addUnknownVolume()

        #expect(context.model.inputFailure == .invalidOwnedVolume)
        #expect(context.model.sortedOwnedVolumes.isEmpty)
        #expect(try fetchEntries(context.container).isEmpty)
        #expect(try fetchOperations(context.container).isEmpty)
    }

    @Test("An unknown total accepts owned and reading volumes through 300")
    func unknownTotalPreservesTheGlobalBoundary() async throws {
        let context = try makeContext(total: nil)
        context.model.volumeInput = "299"
        context.model.addUnknownVolume()
        context.model.volumeInput = "300"
        context.model.addUnknownVolume()
        context.model.readingVolumeText = "300"

        #expect(context.model.knownTotalVolumes == nil)
        #expect(context.model.sortedOwnedVolumes == [299, 300])
        #expect(await context.model.save())

        let entry = try #require(fetchEntries(context.container).first)
        let operation = try #require(fetchOperations(context.container).first)
        #expect(entry.ownedVolumes == [299, 300])
        #expect(entry.readingVolume == 300)
        #expect(entry.knownTotalVolumes == nil)
        #expect(operation.desiredState == entry.state)
    }

    @Test("Unknown-total reading progress above 300 leaves the store untouched", arguments: ["301", String(Int64.max)])
    func excessiveUnknownTotalReadingProgressDoesNotSubmit(readingVolume: String) async throws {
        let context = try makeContext(total: nil)
        context.model.readingVolumeText = readingVolume

        #expect(await context.model.save() == false)
        #expect(context.model.inputFailure == .invalidReadingVolume)
        #expect(try fetchEntries(context.container).isEmpty)
        #expect(try fetchOperations(context.container).isEmpty)
    }

    @Test("A known total of 300 can select and persist the complete bounded range")
    func maximumKnownTotalCanComplete() async throws {
        let context = try makeContext(total: 300)

        context.model.setComplete(true)

        #expect(context.model.sortedOwnedVolumes.count == 300)
        #expect(Array(context.model.sortedOwnedVolumes.prefix(3)) == [1, 2, 3])
        #expect(Array(context.model.sortedOwnedVolumes.suffix(3)) == [298, 299, 300])
        #expect(await context.model.save())

        let entry = try #require(fetchEntries(context.container).first)
        let operation = try #require(fetchOperations(context.container).first)
        #expect(entry.ownedVolumes.count == 300)
        #expect(entry.ownedVolumes.first == 1)
        #expect(entry.ownedVolumes.last == 300)
        #expect(entry.isComplete)
        #expect(operation.desiredState == entry.state)
    }

    @Test("An unsupported seed is blocked before the editor exposes an iterable range")
    func excessiveSeedTotalCannotBeEditedOrSaved() async throws {
        let context = try makeContext(total: 301)

        context.model.setComplete(true)

        #expect(context.model.knownTotalVolumes == 301)
        #expect(context.model.knownVolumeNumbers == nil)
        #expect(context.model.sortedOwnedVolumes.isEmpty)
        #expect(context.model.canSave == false)
        #expect(await context.model.save() == false)
        #expect(context.model.submissionState == .failed(.incompatibleStoredVolumeState))
        #expect(try fetchEntries(context.container).isEmpty)
        #expect(try fetchOperations(context.container).isEmpty)
    }

    @Test("Selecting every known volume completes the collection until one is removed")
    func knownTotalSelectionDerivesCompletion() async throws {
        let context = try makeContext(total: 3)
        context.model.setOwned(true, volume: 1)
        context.model.setOwned(true, volume: 2)

        #expect(context.model.isComplete == false)
        context.model.setOwned(true, volume: 3)
        #expect(context.model.isComplete)
        #expect(context.model.sortedOwnedVolumes == [1, 2, 3])

        context.model.setOwned(false, volume: 2)
        #expect(context.model.isComplete == false)
        #expect(context.model.sortedOwnedVolumes == [1, 3])

        #expect(await context.model.save())

        let entry = try #require(fetchEntries(context.container).first)
        let operation = try #require(fetchOperations(context.container).first)
        #expect(entry.ownedVolumes == [1, 3])
        #expect(entry.isComplete == false)
        #expect(operation.desiredState == entry.state)
    }

    @Test("The complete toggle selects and clears every known volume")
    func completeToggleControlsKnownVolumeSelection() async throws {
        let context = try makeContext(total: 3)
        context.model.setOwned(true, volume: 1)
        context.model.setOwned(true, volume: 3)
        context.model.readingVolumeText = "2"

        #expect(context.model.sortedOwnedVolumes == [1, 3])
        context.model.setComplete(true)
        #expect(context.model.isComplete)
        #expect(context.model.sortedOwnedVolumes == [1, 2, 3])
        context.model.setComplete(false)
        #expect(context.model.isComplete == false)
        #expect(context.model.sortedOwnedVolumes.isEmpty)

        #expect(await context.model.save())

        let entry = try #require(fetchEntries(context.container).first)
        let operation = try #require(fetchOperations(context.container).first)
        #expect(entry.ownedVolumes.isEmpty)
        #expect(entry.readingVolume == 2)
        #expect(entry.isComplete == false)
        #expect(try fetchOperations(context.container).count == 1)
        #expect(operation.desiredState == entry.state)
    }

    @Test("Reading progress outside a known total leaves the store untouched")
    func invalidReadingProgressDoesNotSubmit() async throws {
        let context = try makeContext(total: 3)
        context.model.readingVolumeText = "4"

        #expect(context.model.canSave)
        #expect(await context.model.save() == false)
        #expect(context.model.inputFailure == .invalidReadingVolume)
        #expect(try fetchEntries(context.container).isEmpty)
        #expect(try fetchOperations(context.container).isEmpty)
    }

    @Test("A compatible published total enriches an existing unknown collection")
    func compatiblePublishedTotalBecomesEditable() throws {
        let seed = CollectionEditorSeed.catalog(
            authority: AccountPreviewSupport.account.authority,
            manga: makeManga(total: 4),
            existingState: CollectionSnapshot(
                ownedVolumes: [1, 3],
                readingVolume: 2,
                isComplete: false,
                knownTotalVolumes: nil,
                isTombstone: false
            )
        )

        #expect(seed.state.knownTotalVolumes == 4)
        #expect(seed.state.ownedVolumes == [1, 3])
        #expect(seed.state.readingVolume == 2)
    }

    @Test("Catalog metadata cannot replace an incompatible historical total")
    func compatibleCatalogTotalDoesNotSanitizeHistoricalState() throws {
        let historicalState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: 1,
            isComplete: false,
            knownTotalVolumes: 301,
            isTombstone: false
        )
        let seed = CollectionEditorSeed.catalog(
            authority: AccountPreviewSupport.account.authority,
            manga: makeManga(total: 300),
            existingState: historicalState
        )

        #expect(seed.state == historicalState)
        #expect(CollectionVolumePolicy.isValid(seed.state) == false)
    }

    @Test(
        "A conflicting published total cannot discard saved collection state",
        arguments: [
            CollectionSnapshot(
                ownedVolumes: [1, 5],
                readingVolume: 2,
                isComplete: false,
                knownTotalVolumes: nil,
                isTombstone: false
            ),
            CollectionSnapshot(
                ownedVolumes: [1],
                readingVolume: 5,
                isComplete: false,
                knownTotalVolumes: nil,
                isTombstone: false
            ),
            CollectionSnapshot(
                ownedVolumes: [1, 2, 3],
                readingVolume: 3,
                isComplete: true,
                knownTotalVolumes: 3,
                isTombstone: false
            )
        ]
    )
    func conflictingPublishedTotalPreservesSavedMetadata(existingState: CollectionSnapshot) throws {
        let seed = CollectionEditorSeed.catalog(
            authority: AccountPreviewSupport.account.authority,
            manga: makeManga(total: 4),
            existingState: existingState
        )

        #expect(seed.state.knownTotalVolumes == existingState.knownTotalVolumes)
        #expect(seed.state.ownedVolumes == existingState.ownedVolumes)
        #expect(seed.state.readingVolume == existingState.readingVolume)
        #expect(seed.state.isComplete == existingState.isComplete)
    }

    @Test("Delete requires an existing entry and tombstones through the collection mutation")
    func deleteUsesTheSoleMutationPath() async throws {
        let context = try makeContext(total: 3)

        #expect(await context.model.delete() == false)
        #expect(context.model.submissionState == .idle)
        #expect(try fetchEntries(context.container).isEmpty)
        #expect(try fetchOperations(context.container).isEmpty)

        context.model.setOwned(true, volume: 1)
        #expect(await context.model.save())
        let savedState = try #require(fetchEntries(context.container).first).state
        let existingModel = CollectionEditorModel(
            seed: CollectionEditorSeed(
                identity: context.model.seed.identity,
                authority: context.model.seed.authority,
                title: context.model.seed.title,
                mangaSnapshot: context.model.seed.mangaSnapshot,
                state: savedState,
                isExistingEntry: true
            ),
            mutation: context.mutation
        )

        #expect(await existingModel.delete())
        #expect(existingModel.submissionState == .idle)

        let entry = try #require(fetchEntries(context.container).first)
        let operation = try #require(fetchOperations(context.container).first)
        #expect(entry.isTombstone)
        #expect(operation.sequence == 2)
        #expect(operation.isTombstone)
        #expect(operation.desiredState == entry.state)
    }

    @Test("Delete surfaces lost authorization without changing either persisted half")
    func deleteAuthorizationFailureLeavesTheStoreUntouched() async throws {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let manga = makeManga(total: 3)
        let initialState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: nil,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )
        let actor = CollectionMutationActor(modelContainer: container)
        _ = try await actor.apply(
            CollectionMutationCommand(
                authority: AccountPreviewSupport.account.authority,
                mangaID: manga.id,
                mangaSnapshot: CollectionMangaSnapshot(manga: manga),
                knownTotalVolumes: manga.totalVolumes,
                change: .replaceState(ownedVolumes: [1], readingVolume: nil, isComplete: false)
            )
        )
        let signedOutAccount = AccountPreviewSupport.model(state: .signedOut(failure: nil))
        let mutation = CollectionMutation(
            actor: actor,
            accountModel: signedOutAccount,
            sessionAuthorization: .deterministic
        )
        let model = CollectionEditorModel(
            seed: CollectionEditorSeed(
                identity: CollectionIdentity(userID: AccountPreviewSupport.account.id, mangaID: manga.id),
                authority: AccountPreviewSupport.account.authority,
                title: manga.title,
                mangaSnapshot: CollectionMangaSnapshot(manga: manga),
                state: initialState,
                isExistingEntry: true
            ),
            mutation: mutation
        )

        #expect(await model.delete() == false)
        #expect(model.submissionState == .failed(.authenticationRequired))

        let entry = try #require(fetchEntries(container).first)
        let operation = try #require(fetchOperations(container).first)
        #expect(entry.state == initialState)
        #expect(operation.sequence == 1)
        #expect(operation.desiredState == initialState)
    }

    @Test("An incompatible historical seed blocks save but remains explicitly deletable")
    func incompatibleHistoricalSeedCanOnlyBeDeleted() async throws {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let historicalState = CollectionSnapshot(
            ownedVolumes: [1],
            readingVolume: nil,
            isComplete: false,
            knownTotalVolumes: 301,
            isTombstone: false
        )
        let manga = makeManga(total: 301)
        let operationID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let seedContext = ModelContext(container)
        seedContext.insert(
            CollectionEntry(
                userID: AccountPreviewSupport.account.id,
                mangaID: manga.id,
                state: historicalState,
                confirmedState: nil,
                mangaSnapshot: CollectionMangaSnapshot(manga: manga)
            )
        )
        seedContext.insert(
            CollectionOutboxOperation(
                operationID: operationID,
                userID: AccountPreviewSupport.account.id,
                mangaID: manga.id,
                sequence: 1,
                desiredState: historicalState
            )
        )
        try seedContext.save()
        let account = AccountPreviewSupport.model(state: .authenticated(AccountPreviewSupport.account, notice: nil))
        let mutation = CollectionMutation(
            actor: CollectionMutationActor(modelContainer: container),
            accountModel: account,
            sessionAuthorization: .deterministic
        )
        let model = CollectionEditorModel(
            seed: CollectionEditorSeed(
                identity: CollectionIdentity(userID: AccountPreviewSupport.account.id, mangaID: manga.id),
                authority: AccountPreviewSupport.account.authority,
                title: manga.title,
                mangaSnapshot: CollectionMangaSnapshot(manga: manga),
                state: historicalState,
                isExistingEntry: true
            ),
            mutation: mutation
        )

        #expect(model.knownTotalVolumes == 301)
        #expect(model.knownVolumeNumbers == nil)
        #expect(model.canSave == false)
        #expect(await model.save() == false)
        #expect(model.submissionState == .failed(.incompatibleStoredVolumeState))

        var entries = try fetchEntries(container)
        var operations = try fetchOperations(container)
        #expect(entries.map(\.state) == [historicalState])
        #expect(operations.map(\.desiredState) == [historicalState])
        #expect(operations.map(\.sequence) == [1])

        #expect(await model.delete())

        entries = try fetchEntries(container)
        operations = try fetchOperations(container)
        let tombstone = try #require(entries.first)
        let operation = try #require(operations.first)
        #expect(tombstone.ownedVolumes == historicalState.ownedVolumes)
        #expect(tombstone.readingVolume == historicalState.readingVolume)
        #expect(tombstone.knownTotalVolumes == historicalState.knownTotalVolumes)
        #expect(tombstone.isTombstone)
        #expect(operation.operationID == operationID)
        #expect(operation.sequence == 2)
        #expect(operation.isTombstone)
        #expect(operation.desiredState == tombstone.state)
    }

    private func makeContext(total: Int64?) throws -> CollectionEditorTestContext {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let account = AccountPreviewSupport.model(state: .authenticated(AccountPreviewSupport.account, notice: nil))
        let mutation = CollectionMutation(
            actor: CollectionMutationActor(modelContainer: container),
            accountModel: account,
            sessionAuthorization: .deterministic
        )
        let manga = makeManga(total: total)
        let seed = CollectionEditorSeed(
            identity: CollectionIdentity(userID: AccountPreviewSupport.account.id, mangaID: manga.id),
            authority: AccountPreviewSupport.account.authority,
            title: manga.title,
            mangaSnapshot: CollectionMangaSnapshot(manga: manga),
            state: CollectionSnapshot(
                ownedVolumes: [],
                readingVolume: nil,
                isComplete: false,
                knownTotalVolumes: total,
                isTombstone: false
            ),
            isExistingEntry: false
        )

        return CollectionEditorTestContext(
            container: container,
            mutation: mutation,
            model: CollectionEditorModel(seed: seed, mutation: mutation)
        )
    }

    private func makeManga(total: Int64?) -> Manga {
        Manga(
            id: 42,
            title: "Manga A",
            titleEnglish: nil,
            titleJapanese: nil,
            synopsis: nil,
            score: 8,
            status: .publishing,
            authors: [],
            demographics: [],
            genres: [],
            themes: [],
            totalVolumes: total,
            coverURL: nil
        )
    }

    private func fetchEntries(_ container: ModelContainer) throws -> [CollectionEntry] {
        try ModelContext(container).fetch(FetchDescriptor<CollectionEntry>())
    }

    private func fetchOperations(_ container: ModelContainer) throws -> [CollectionOutboxOperation] {
        try ModelContext(container).fetch(FetchDescriptor<CollectionOutboxOperation>())
    }
}

private struct CollectionEditorTestContext {
    let container: ModelContainer
    let mutation: CollectionMutation
    let model: CollectionEditorModel
}
