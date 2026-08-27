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

    var body: some Scene {
        WindowGroup {
            MainShellView(loadCatalogPage: loadCatalogPage)
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
            return
#else
            preconditionFailure("UI testing data is unavailable in production builds.")
#endif
        }

        do {
            let client = try AppComposition.live().catalogClient
            loadCatalogPage = { request in
                try await client.fetch(request)
            }
        } catch {
            preconditionFailure("Manga Library could not create its app dependencies.")
        }
    }
}
