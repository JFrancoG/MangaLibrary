//
//  MangaLibraryApp.swift
//  MangaLibrary
//
//  Created by Jesús Franco on 15.08.2026.
//

import SwiftUI

@main
struct MangaLibraryApp: App {
    private let composition: AppComposition

    var body: some Scene {
        WindowGroup {
            MainShellView(catalogClient: composition.catalogClient)
        }
    }
}

extension MangaLibraryApp {
    init() {
        do {
            composition = try AppComposition.current()
        } catch {
            preconditionFailure("Manga Library could not create its app dependencies.")
        }
    }
}
