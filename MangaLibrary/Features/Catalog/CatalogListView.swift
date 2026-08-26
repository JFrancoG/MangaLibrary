//
//  CatalogListView.swift
//  MangaLibrary
//

import SwiftUI

struct CatalogListView: View {
    let content: CatalogModel.Content
    let model: CatalogModel
    @Binding var selection: Manga.ID?

    var body: some View {
        List(selection: $selection) {
            ForEach(content.items) { manga in
                NavigationLink(value: manga.id) {
                    MangaRowView(manga: manga)
                }
                .accessibilityIdentifier("catalog.row.\(manga.id)")
                .onAppear {
                    model.requestNextPageIfNeeded(after: manga.id)
                }
            }

            CatalogPaginationView(
                pagination: content.pagination,
                model: model
            )
            .listRowSeparator(.hidden)
        }
        .accessibilityIdentifier("catalog.content")
    }
}

#Preview("Catalog list") {
    @Previewable @State var selection: Manga.ID?
    let content = CatalogModel.Content(
        items: CatalogPreviewSupport.mangas,
        pagination: .end
    )
    let model = CatalogPreviewSupport.model(state: .content(content))

    NavigationStack {
        CatalogListView(
            content: content,
            model: model,
            selection: $selection
        )
    }
}
