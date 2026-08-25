//
//  CatalogListView.swift
//  MangaLibrary
//

import SwiftUI

struct CatalogListView: View {
    let items: [Manga]
    @Binding var selection: Manga.ID?

    var body: some View {
        List(items, selection: $selection) { manga in
            NavigationLink(value: manga.id) {
                MangaRowView(manga: manga)
            }
            .accessibilityIdentifier("catalog.row.\(manga.id)")
        }
        .accessibilityIdentifier("catalog.content")
    }
}

#Preview("Catalog list") {
    @Previewable @State var selection: Manga.ID?

    NavigationStack {
        CatalogListView(
            items: CatalogPreviewSupport.mangas,
            selection: $selection
        )
    }
}
