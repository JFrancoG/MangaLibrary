//
//  CollectionEditorModelTests.swift
//  MangaLibraryTests
//

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

    @Test("Unknown-volume input rejects empty, malformed, and nonpositive values", arguments: ["", "manga", "0", "-1"])
    func invalidUnknownVolumeCannotBecomeOwnership(volumeInput: String) throws {
        let context = try makeContext(total: nil)
        context.model.volumeInput = volumeInput

        context.model.addUnknownVolume()

        #expect(context.model.inputFailure == .invalidOwnedVolume)
        #expect(context.model.sortedOwnedVolumes.isEmpty)
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

@MainActor
private struct CollectionEditorTestContext {
    let container: ModelContainer
    let mutation: CollectionMutation
    let model: CollectionEditorModel
}
