//
//  CatalogRootView.swift
//  MangaLibrary
//

import SwiftUI

struct CatalogRootView: View {
    @State private var model: CatalogModel
    @State private var retryRequest: Bool?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("Catalog")
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
    }

    @ViewBuilder
    private var sidebar: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView("Loading catalog")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("catalog.loading")
        case let .content(items):
            CatalogListView(
                items: items,
                selection: $model.selectedMangaID
            )
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
}

extension CatalogRootView {
    init(client: CatalogAPIClient) {
        model = CatalogModel { request in
            try await client.fetch(request)
        }
    }

    init(model: CatalogModel) {
        self.model = model
    }
}

#Preview("Catalog content") {
    CatalogRootView(
        model: CatalogPreviewSupport.model(
            state: .content(CatalogPreviewSupport.mangas)
        )
    )
}

#Preview("Catalog loading") {
    CatalogRootView(model: CatalogPreviewSupport.model(state: .loading))
}

#Preview("Catalog empty") {
    CatalogRootView(model: CatalogPreviewSupport.model(state: .empty))
}

#Preview("Catalog error") {
    CatalogRootView(
        model: CatalogPreviewSupport.model(state: .failure(.unavailable))
    )
}
