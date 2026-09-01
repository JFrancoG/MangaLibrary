//
//  MangaLibraryApp.swift
//  MangaLibrary
//
//  Created by Jesús Franco on 15.08.2026.
//

import SwiftData
import SwiftUI

@main
struct MangaLibraryApp: App {
    private let modelContainer: ModelContainer
    private let collectionMutation: CollectionMutation
    private let loadCatalogPage: CatalogModel.PageLoader
    private let loadCatalogFilterOptions: CatalogModel.FilterOptionsLoader
    @State private var accountModel: AccountModel

    var body: some Scene {
        WindowGroup {
            MainShellView(
                loadCatalogPage: loadCatalogPage,
                loadCatalogFilterOptions: loadCatalogFilterOptions,
                accountModel: accountModel,
                collectionMutation: collectionMutation
            )
        }
        .modelContainer(modelContainer)
    }
}

extension MangaLibraryApp {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
#if DEBUG
            // UI automation owns one deterministic bootstrap and cannot select
            // fixtures or fall through to production networking.
            do {
                let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
                let account = AccountPreviewSupport.model(state: .signedOut(failure: nil))
                modelContainer = container
                collectionMutation = CollectionMutation(
                    actor: CollectionMutationActor(modelContainer: container),
                    accountModel: account
                )
                loadCatalogPage = CatalogPreviewSupport.pageLoader
                loadCatalogFilterOptions = CatalogPreviewSupport.filterOptionsLoader
                _accountModel = State(initialValue: account)
                return
            } catch {
                preconditionFailure("Manga Library could not create its UI testing data store.")
            }
#else
            preconditionFailure("UI testing data is unavailable in production builds.")
#endif
        }

        do {
            let composition = try AppComposition.live()
            let catalogClient = composition.catalogClient
            let account = AccountModel(
                operations: .live(controller: composition.sessionController, register: composition.registerUser)
            )
            modelContainer = composition.modelContainer
            collectionMutation = CollectionMutation(actor: composition.collectionMutations, accountModel: account)
            loadCatalogPage = { request in
                try await catalogClient.fetch(request)
            }
            loadCatalogFilterOptions = {
                try await catalogClient.fetchFilterOptions()
            }
            _accountModel = State(initialValue: account)
        } catch {
            preconditionFailure("Manga Library could not create its app dependencies.")
        }
    }
}
