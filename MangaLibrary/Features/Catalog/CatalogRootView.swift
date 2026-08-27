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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var model: CatalogModel
    @State private var retryRequest: Bool?
    @State private var layout: CatalogLayout
    @State private var searchText: String
    @State private var filtersPresented = false
    @State private var preferredCompactColumn = NavigationSplitViewColumn.sidebar

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredCompactColumn) {
            sidebar
                .navigationTitle("Catalog")
                .toolbarTitleDisplayMode(.large)
                .searchable(text: $searchText, prompt: "Search manga")
                .onSubmit(of: .search) {
                    applySearchText()
                }
                .onChange(of: searchText) { previousText, currentText in
                    guard
                        previousText.isEmpty == false,
                        currentText.isEmpty,
                        model.query != .best
                    else {
                        return
                    }

                    applySearchText()
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if horizontalSizeClass == .regular {
                        HStack {
                            Spacer()
                            layoutPicker
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.bar)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        filtersButton
                        if horizontalSizeClass != .regular {
                            layoutPicker
                        }
                    }
                }
        } detail: {
            detail
        }
        .inspector(isPresented: $filtersPresented) {
            CatalogFiltersView(model: model, searchText: $searchText)
        }
        .task(id: model.query) {
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
            ProgressView("Loading results")
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
            if model.query == .catalog {
                ContentUnavailableView(
                    "The catalog is empty",
                    systemImage: "books.vertical",
                    description: Text("No manga were returned for this page.")
                )
                .accessibilityIdentifier("catalog.empty")
            } else {
                ContentUnavailableView(
                    "No results",
                    systemImage: "magnifyingglass",
                    description: Text("Try changing your search or filters.")
                )
                .accessibilityIdentifier("catalog.empty")
            }
        case let .failure(reason):
            ContentUnavailableView {
                Label("Results unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(reason.errorDescriptionResource)
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

    private func applySearchText() {
        let search = (model.query.advancedSearch ?? CatalogSearch())
            .replacingTitle(searchText)
        model.apply(query: .search(search))
        searchText = search.title ?? ""
    }

    private var filtersButton: some View {
        Button {
            filtersPresented = true
        } label: {
            Label(
                "Filters",
                systemImage: model.query.activeFilterCount == 0
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .labelStyle(.iconOnly)
        .accessibilityValue(
            "Active filters: \(model.query.activeFilterCount)"
        )
        .accessibilityIdentifier("catalog.filters")
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
        .frame(width: 96)
        .accessibilityIdentifier("catalog.layout")
    }
}

extension CatalogRootView {
    init(
        loadPage: @escaping CatalogModel.PageLoader,
        loadFilterOptions: @escaping CatalogModel.FilterOptionsLoader
    ) {
        model = CatalogModel(
            loadFilterOptions: loadFilterOptions,
            loadPage: loadPage
        )
        layout = .list
        searchText = ""
    }

    init(
        model: CatalogModel,
        initialLayout: CatalogLayout = .list
    ) {
        self.model = model
        layout = initialLayout
        searchText = model.query.advancedSearch?.title ?? ""
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

#Preview("Catalog search results") {
    CatalogRootView(
        model: CatalogPreviewSupport.model(
            state: .content(
                .init(
                    items: CatalogPreviewSupport.mangas,
                    pagination: .end
                )
            ),
            query: .advanced(
                CatalogSearch(
                    title: "Monster",
                    genres: ["Drama"],
                    themes: [],
                    demographics: ["Seinen"]
                )
            ),
            filterOptionsState: .content(CatalogPreviewSupport.filterOptions)
        )
    )
}

#Preview("Catalog search empty") {
    CatalogRootView(
        model: CatalogPreviewSupport.model(
            state: .empty,
            query: .advanced(CatalogSearch(title: "Unknown")),
            filterOptionsState: .content(CatalogPreviewSupport.filterOptions)
        )
    )
}
