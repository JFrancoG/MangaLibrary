//
//  MangaLibraryApp.swift
//  MangaLibrary
//
//  Created by Jesús Franco on 15.08.2026.
//

import SwiftUI

@main
struct MangaLibraryApp: App {
    private let loadCatalogPage: CatalogModel.PageLoader
    private let loadCatalogFilterOptions: CatalogModel.FilterOptionsLoader
    @State private var accountModel: AccountModel

    var body: some Scene {
        WindowGroup {
            MainShellView(
                loadCatalogPage: loadCatalogPage,
                loadCatalogFilterOptions: loadCatalogFilterOptions,
                accountModel: accountModel
            )
        }
    }
}

extension MangaLibraryApp {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
#if DEBUG
            // UI automation owns one deterministic bootstrap and cannot select
            // fixtures or fall through to production networking.
            loadCatalogPage = CatalogPreviewSupport.pageLoader
            loadCatalogFilterOptions = CatalogPreviewSupport.filterOptionsLoader
            accountModel = AccountPreviewSupport.model(
                state: .signedOut(failure: nil)
            )
            return
#else
            preconditionFailure("UI testing data is unavailable in production builds.")
#endif
        }

        do {
            let composition = try AppComposition.live()
            let catalogClient = composition.catalogClient
            loadCatalogPage = { request in
                try await catalogClient.fetch(request)
            }
            loadCatalogFilterOptions = {
                try await catalogClient.fetchFilterOptions()
            }
            accountModel = AccountModel(
                operations: .live(
                    controller: composition.sessionController
                )
            )
        } catch {
            preconditionFailure("Manga Library could not create its app dependencies.")
        }
    }
}
