//
//  CollectionPreviewSupport.swift
//  MangaLibrary
//

import SwiftData
import SwiftUI

@MainActor
enum CollectionPreviewSupport {
    static func shell(container: ModelContainer) -> some View {
        let context = makeContext(
            state: .authenticated(AccountPreviewSupport.account, notice: nil),
            container: container
        )

        return MainShellView(
            loadCatalogPage: CatalogPreviewSupport.pageLoader,
            loadCatalogFilterOptions: CatalogPreviewSupport.filterOptionsLoader,
            accountModel: context.accountModel,
            collectionMutation: context.mutation,
            collectionSynchronization: .disabled
        )
    }

    static func content(container: ModelContainer) -> some View {
        let context = makeContext(
            state: .authenticated(AccountPreviewSupport.account, notice: nil),
            container: container
        )

        return CollectionRootView(access: context.accountModel.state.collectionAccess, mutation: context.mutation)
    }

    static func empty(container: ModelContainer) -> some View {
        let context = makeContext(
            state: .authenticated(AccountPreviewSupport.account, notice: nil),
            container: container
        )

        return CollectionRootView(access: context.accountModel.state.collectionAccess, mutation: context.mutation)
    }

    static func readOnly(container: ModelContainer) -> some View {
        let state = AccountModel.State.authenticationRequired(
            userID: AccountPreviewSupport.account.id,
            failure: .authenticationRequired
        )
        let context = makeContext(state: state, container: container)

        return CollectionRootView(access: context.accountModel.state.collectionAccess, mutation: context.mutation)
    }

    static func signedOut(container: ModelContainer) -> some View {
        let context = makeContext(state: .signedOut(failure: nil), container: container)

        return CollectionRootView(access: context.accountModel.state.collectionAccess, mutation: context.mutation)
    }

    static func restoring(container: ModelContainer) -> some View {
        let context = makeContext(state: .restoring, container: container)

        return CollectionRootView(access: context.accountModel.state.collectionAccess, mutation: context.mutation)
    }

    static func restorationFailed(container: ModelContainer) -> some View {
        let context = makeContext(state: .restorationFailed(failure: .persistenceUnavailable), container: container)

        return CollectionRootView(access: context.accountModel.state.collectionAccess, mutation: context.mutation)
    }

    static func userRoot(container: ModelContainer) -> some View {
        let context = makeContext(
            state: .authenticated(AccountPreviewSupport.account, notice: nil),
            container: container
        )

        return CollectionUserRootView(
            scope: CollectionUserScope(
                userID: AccountPreviewSupport.account.id,
                authority: AccountPreviewSupport.account.authority
            ),
            restriction: nil,
            mutation: context.mutation
        )
    }

    static func controls(container: ModelContainer) -> some View {
        controls(state: .authenticated(AccountPreviewSupport.account, notice: nil), container: container)
    }

    static func signedOutControls(container: ModelContainer) -> some View {
        controls(state: .signedOut(failure: nil), container: container)
    }

    static func readOnlyControls(container: ModelContainer) -> some View {
        controls(
            state: .authenticationRequired(userID: AccountPreviewSupport.account.id, failure: .authenticationRequired),
            container: container
        )
    }

    private static func controls(state: AccountModel.State, container: ModelContainer) -> some View {
        let context = makeContext(state: state, container: container)
        let manga = CatalogPreviewSupport.mangas[0]

        return CollectionControlsView(
            manga: manga,
            access: context.accountModel.state.collectionAccess,
            mutation: context.mutation
        )
        .padding()
    }

    static func entryDetail(container: ModelContainer) -> some View {
        let context = makeContext(
            state: .authenticated(AccountPreviewSupport.account, notice: nil),
            container: container
        )
        let entry = requireEntry(mangaID: CatalogPreviewSupport.mangas[0].id, in: container)

        return NavigationStack {
            CollectionEntryDetailView(
                entry: entry,
                scope: CollectionUserScope(
                    userID: AccountPreviewSupport.account.id,
                    authority: AccountPreviewSupport.account.authority
                ),
                restriction: nil,
                mutation: context.mutation
            )
        }
    }

    static func migratedEntryDetail(container: ModelContainer) -> some View {
        let context = makeContext(
            state: .authenticated(AccountPreviewSupport.account, notice: nil),
            container: container
        )
        let entry = requireEntry(mangaID: 99, in: container)

        return NavigationStack {
            CollectionEntryDetailView(
                entry: entry,
                scope: CollectionUserScope(
                    userID: AccountPreviewSupport.account.id,
                    authority: AccountPreviewSupport.account.authority
                ),
                restriction: nil,
                mutation: context.mutation
            )
        }
    }

    static func row(container: ModelContainer) -> some View {
        let entry = requireEntry(mangaID: CatalogPreviewSupport.mangas[1].id, in: container)

        return List {
            CollectionRowView(entry: entry)
        }
    }

    static func knownTotalEditor(container: ModelContainer) -> some View {
        let manga = CatalogPreviewSupport.mangas[0]
        let state = CollectionSnapshot(
            ownedVolumes: [1, 3],
            readingVolume: 2,
            isComplete: false,
            knownTotalVolumes: manga.totalVolumes,
            isTombstone: false
        )
        let context = makeContext(
            state: .authenticated(AccountPreviewSupport.account, notice: nil),
            container: container
        )

        return CollectionEditorView(
            seed: CollectionEditorSeed(
                identity: CollectionIdentity(userID: AccountPreviewSupport.account.id, mangaID: manga.id),
                authority: AccountPreviewSupport.account.authority,
                title: manga.title,
                mangaSnapshot: CollectionMangaSnapshot(manga: manga),
                state: state,
                isExistingEntry: true
            ),
            mutation: context.mutation
        )
    }

    static func unknownTotalEditor(container: ModelContainer) -> some View {
        let manga = CatalogPreviewSupport.mangas[1]
        let state = CollectionSnapshot(
            ownedVolumes: [1, 12],
            readingVolume: 8,
            isComplete: false,
            knownTotalVolumes: nil,
            isTombstone: false
        )
        let context = makeContext(
            state: .authenticated(AccountPreviewSupport.account, notice: nil),
            container: container
        )

        return CollectionEditorView(
            seed: CollectionEditorSeed(
                identity: CollectionIdentity(userID: AccountPreviewSupport.account.id, mangaID: manga.id),
                authority: AccountPreviewSupport.account.authority,
                title: manga.title,
                mangaSnapshot: CollectionMangaSnapshot(manga: manga),
                state: state,
                isExistingEntry: true
            ),
            mutation: context.mutation
        )
    }

    static func makeContainer(seed: CollectionPreviewSeed) throws -> ModelContainer {
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)

        switch seed {
        case .empty:
            break
        case .content:
            try seedContent(in: container)
        }

        return container
    }

    private static func makeContext(state: AccountModel.State, container: ModelContainer) -> CollectionPreviewContext {
        let accountModel = AccountPreviewSupport.model(state: state)
        let mutation = CollectionMutation(
            actor: CollectionMutationActor(modelContainer: container),
            accountModel: accountModel,
            sessionAuthorization: .deterministic
        )

        return CollectionPreviewContext(accountModel: accountModel, mutation: mutation)
    }

    private static func seedContent(in container: ModelContainer) throws {
        let context = ModelContext(container)
        let manga = CatalogPreviewSupport.mangas[0]
        let state = CollectionSnapshot(
            ownedVolumes: [1, 3],
            readingVolume: 2,
            isComplete: false,
            knownTotalVolumes: manga.totalVolumes,
            isTombstone: false
        )
        context.insert(
            CollectionEntry(
                userID: AccountPreviewSupport.account.id,
                mangaID: manga.id,
                state: state,
                confirmedState: nil,
                mangaSnapshot: CollectionMangaSnapshot(manga: manga)
            )
        )
        context.insert(
            CollectionEntry(
                userID: AccountPreviewSupport.account.id,
                mangaID: 99,
                state: CollectionSnapshot(
                    ownedVolumes: [1],
                    readingVolume: nil,
                    isComplete: false,
                    knownTotalVolumes: nil,
                    isTombstone: false
                ),
                confirmedState: nil
            )
        )
        let longTitleManga = CatalogPreviewSupport.mangas[1]
        context.insert(
            CollectionEntry(
                userID: AccountPreviewSupport.account.id,
                mangaID: longTitleManga.id,
                state: CollectionSnapshot(
                    ownedVolumes: [1, 12],
                    readingVolume: 8,
                    isComplete: false,
                    knownTotalVolumes: nil,
                    isTombstone: false
                ),
                confirmedState: nil,
                mangaSnapshot: CollectionMangaSnapshot(manga: longTitleManga)
            )
        )
        try context.save()
    }

    private static func requireEntry(mangaID: Manga.ID, in container: ModelContainer) -> CollectionEntry {
        do {
            let context = ModelContext(container)
            var descriptor = FetchDescriptor(
                predicate: CollectionEntry.activePredicate(userID: AccountPreviewSupport.account.id, mangaID: mangaID)
            )
            descriptor.fetchLimit = 1
            guard let entry = try context.fetch(descriptor).first else {
                preconditionFailure("Collection preview entry is missing.")
            }

            return entry
        } catch {
            preconditionFailure("Collection preview entry could not be read: \(error)")
        }
    }
}

enum CollectionPreviewSeed {
    case empty
    case content
}

private struct CollectionPreviewContext {
    let accountModel: AccountModel
    let mutation: CollectionMutation
}
