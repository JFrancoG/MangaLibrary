//
//  CatalogRootView.swift
//  MangaLibrary
//

import SwiftUI

enum CatalogLayout: Hashable {
    case list
    case grid
}

struct CatalogRootView: View {
    @State private var model: CatalogModel
    @State private var retryRequest: Bool?
    @State private var layout: CatalogLayout
    @State private var preferredCompactColumn = NavigationSplitViewColumn.sidebar

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredCompactColumn) {
            sidebar
                .navigationTitle("Catalog")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        layoutPicker
                    }
                }
        } detail: {
            detail
        }
        .task {
            await model.loadIfNeeded()
        }
        .task(id: retryRequest) {
            guard retryRequest != nil else {
                return
            }

            await model.retry()
        }
        .task(id: model.requestedNextPage) {
            await model.loadRequestedNextPage()
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView("Loading catalog")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("catalog.loading")
        case let .content(content):
            switch layout {
            case .list:
                CatalogListView(
                    content: content,
                    model: model,
                    selection: $model.selectedMangaID
                )
            case .grid:
                CatalogGridView(
                    content: content,
                    model: model,
                    selection: $model.selectedMangaID,
                    preferredCompactColumn: $preferredCompactColumn
                )
            }
        case .empty:
            ContentUnavailableView(
                "The catalog is empty",
                systemImage: "books.vertical",
                description: Text("No manga were returned for this page.")
            )
            .accessibilityIdentifier("catalog.empty")
        case .failure:
            ContentUnavailableView {
                Label("Couldn't load the catalog", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Retry") {
                    requestRetry()
                }
            }
            .accessibilityIdentifier("catalog.error")
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let manga = model.selectedManga {
            MangaDetailView(manga: manga)
        } else {
            ContentUnavailableView(
                "Select a manga",
                systemImage: "book.pages",
                description: Text("Choose a manga from the catalog to see its details.")
            )
        }
    }

    private func requestRetry() {
        retryRequest = !(retryRequest ?? false)
    }

    private var layoutPicker: some View {
        Picker("Catalog layout", selection: $layout) {
            Label("List", systemImage: "list.bullet")
                .labelStyle(.iconOnly)
                .tag(CatalogLayout.list)
                .accessibilityIdentifier("catalog.layout.list")

            Label("Grid", systemImage: "square.grid.2x2")
                .labelStyle(.iconOnly)
                .tag(CatalogLayout.grid)
                .accessibilityIdentifier("catalog.layout.grid")
        }
        .pickerStyle(.segmented)
        .frame(width: 128)
        .accessibilityIdentifier("catalog.layout")
    }
}

extension CatalogRootView {
    init(client: CatalogAPIClient) {
        model = CatalogModel { request in
            try await client.fetch(request)
        }
        layout = .list
    }

    init(
        model: CatalogModel,
        initialLayout: CatalogLayout = .list
    ) {
        self.model = model
        layout = initialLayout
    }
}

#Preview("Catalog content") {
    CatalogRootView(
        model: CatalogPreviewSupport.model(
            state: .content(
                .init(
                    items: CatalogPreviewSupport.mangas,
                    pagination: .end
                )
            )
        )
    )
}

#Preview("Catalog loading") {
    CatalogRootView(model: CatalogPreviewSupport.model(state: .loading))
}

#Preview("Catalog grid") {
    CatalogRootView(
        model: CatalogPreviewSupport.model(
            state: .content(
                .init(
                    items: CatalogPreviewSupport.mangas,
                    pagination: .end
                )
            )
        ),
        initialLayout: .grid
    )
}

#Preview("Catalog empty") {
    CatalogRootView(model: CatalogPreviewSupport.model(state: .empty))
}

#Preview("Catalog error") {
    CatalogRootView(
        model: CatalogPreviewSupport.model(state: .failure(.unavailable))
    )
}

#Preview("Catalog additional page error") {
    CatalogRootView(
        model: CatalogPreviewSupport.model(
            state: .content(
                .init(
                    items: CatalogPreviewSupport.mangas,
                    pagination: .failure(page: 2, reason: .unavailable)
                )
            )
        )
    )
}
