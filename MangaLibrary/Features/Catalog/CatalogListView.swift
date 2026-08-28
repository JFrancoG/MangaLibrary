//
//  CatalogListView.swift
//  MangaLibrary
//

import SwiftUI

struct CatalogListView: View {
    let content: CatalogModel.Content
    let model: CatalogModel
    @Binding var selection: Manga.ID?
    let navigationMode: CatalogNavigationMode

    var body: some View {
        switch navigationMode {
        case .compactStack:
            List {
                rows
            }
            .accessibilityIdentifier("catalog.content")
        case .regularSplit:
            List(selection: $selection) {
                rows
            }
            .accessibilityIdentifier("catalog.content")
        }
    }

    @ViewBuilder
    private var rows: some View {
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
            selection: $selection,
            navigationMode: .compactStack
        )
    }
}
