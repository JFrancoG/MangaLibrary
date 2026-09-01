//
//  CatalogGridView.swift
//  MangaLibrary
//

import SwiftUI

struct CatalogGridView: View {
    let content: CatalogModel.Content
    let model: CatalogModel
    @Binding var selection: Manga.ID?
    let navigationMode: CatalogNavigationMode

    @ScaledMetric(relativeTo: .body) private var minimumItemWidth: CGFloat = 128

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(content.items) { manga in
                    navigationControl(for: manga)
                    .accessibilityIdentifier("catalog.grid.item.\(manga.id)")
                    .accessibilityAddTraits(selection == manga.id ? .isSelected : [])
                    .onAppear {
                        model.requestNextPageIfNeeded(after: manga.id)
                    }
                }
            }

            CatalogPaginationView(pagination: content.pagination, model: model)
            .padding(.vertical, 12)
        }
        .contentMargins(16, for: .scrollContent)
        .background(.canvas)
        .accessibilityIdentifier("catalog.grid")
    }

    @ViewBuilder
    private func navigationControl(for manga: Manga) -> some View {
        switch navigationMode {
        case .compactStack:
            NavigationLink(value: manga.id) {
                MangaGridItemView(manga: manga)
            }
            .buttonStyle(.plain)
        case .regularSplit:
            Button {
                selection = manga.id
            } label: {
                MangaGridItemView(manga: manga)
            }
            .buttonStyle(.plain)
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: min(minimumItemWidth, 240)), spacing: 16, alignment: .top)
        ]
    }
}

#Preview("Catalog grid") {
    @Previewable @State var selection: Manga.ID?
    let content = CatalogModel.Content(items: CatalogPreviewSupport.mangas, pagination: .end)
    let model = CatalogPreviewSupport.model(state: .content(content))

    NavigationStack {
        CatalogGridView(
            content: content,
            model: model,
            selection: $selection,
            navigationMode: .compactStack
        )
    }
}
