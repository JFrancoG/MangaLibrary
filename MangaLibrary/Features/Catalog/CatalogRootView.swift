//
//  CatalogRootView.swift
//  MangaLibrary
//

import Foundation
import SwiftUI

enum CatalogLayout: Hashable {
    case list
    case grid
}

enum CatalogNavigationMode {
    case compactStack
    case regularSplit
}

struct CatalogRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var model: CatalogModel
    @State private var retryRequest: Bool?
    @State private var layout: CatalogLayout
    @State private var searchText: String
    @State private var filtersPresented = false

    let collectionAccess: CollectionAccess
    let collectionMutation: CollectionMutation?

    var body: some View {
        filterPresentation
            .onChange(of: horizontalSizeClass) {
                filtersPresented = false
            }
            .task(id: model.query) {
                await model.loadIfNeeded()
            }
            .task(id: retryRequest) {
                guard retryRequest != nil else { return }

                await model.retry()
            }
            .task(id: model.requestedNextPage) {
                await model.loadRequestedNextPage()
            }
    }

    @ViewBuilder
    private var filterPresentation: some View {
        if horizontalSizeClass == .compact {
            navigation
                .sheet(isPresented: $filtersPresented) {
                    filters
                }
        } else {
            navigation
                .inspector(isPresented: $filtersPresented) {
                    filters
                }
        }
    }

    private var filters: some View {
        CatalogFiltersView(model: model, searchText: $searchText)
    }

    @ViewBuilder
    private var navigation: some View {
        if horizontalSizeClass == .compact {
            NavigationStack(path: compactNavigationPath) {
                catalogSidebar(for: .compactStack)
                    .navigationDestination(for: Manga.ID.self) { mangaID in
                        compactDetail(for: mangaID)
                    }
            }
        } else {
            NavigationSplitView {
                catalogSidebar(for: .regularSplit)
            } detail: {
                detail
            }
        }
    }

    private func catalogSidebar(for navigationMode: CatalogNavigationMode) -> some View {
        sidebar(for: navigationMode)
            .navigationTitle("Catalog")
            .toolbarTitleDisplayMode(navigationMode == .regularSplit ? .inline : .large)
            .searchable(text: $searchText, prompt: "Search manga")
            .onSubmit(of: .search) {
                applySearchText()
            }
            .onChange(of: searchText) { previousText, currentText in
                guard previousText.isEmpty == false, currentText.isEmpty, model.query != .best else { return }

                applySearchText()
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if navigationMode == .regularSplit {
                    HStack(spacing: 8) {
                        Spacer()
                        listLayoutAction
                        gridLayoutAction
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.backgroundElevated)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    filtersAction
                }

                if navigationMode == .compactStack {
                    ToolbarSpacer(.fixed, placement: .primaryAction)

                    ToolbarItemGroup(placement: .primaryAction) {
                        listLayoutAction
                        gridLayoutAction
                    }
                }
            }
            .background(.canvas)
    }

    @ViewBuilder
    private func sidebar(for navigationMode: CatalogNavigationMode) -> some View {
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
                    selection: $model.selectedMangaID,
                    navigationMode: navigationMode
                )
            case .grid:
                CatalogGridView(
                    content: content,
                    model: model,
                    selection: $model.selectedMangaID,
                    navigationMode: navigationMode
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

    private var compactNavigationPath: Binding<[Manga.ID]> {
        Binding {
            model.selectedMangaID.map { [$0] } ?? []
        } set: { path in
            model.selectedMangaID = path.last
        }
    }

    @ViewBuilder
    private func compactDetail(for mangaID: Manga.ID) -> some View {
        if let manga = model.manga(id: mangaID) {
            mangaDetail(manga)
        } else {
            unavailableDetail
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let manga = model.selectedManga {
            mangaDetail(manga)
        } else {
            unavailableDetail
        }
    }

    private func mangaDetail(_ manga: Manga) -> some View {
        MangaDetailView(manga: manga) {
            if let collectionMutation {
                CollectionControlsView(manga: manga, access: collectionAccess, mutation: collectionMutation)
                    .id(CatalogCollectionControlIdentity(userID: collectionAccess.userID, mangaID: manga.id))
            }
        }
    }

    private var unavailableDetail: some View {
        ContentUnavailableView(
            "Select a manga",
            systemImage: "book.pages",
            description: Text("Choose a manga from the catalog to see its details.")
        )
    }

    private func requestRetry() {
        retryRequest = !(retryRequest ?? false)
    }

    private func applySearchText() {
        let search = (model.query.advancedSearch ?? CatalogSearch()).replacingTitle(searchText)
        model.apply(query: .search(search))
        searchText = search.title ?? ""
    }

    private var filtersAction: some View {
        Button {
            filtersPresented = true
        } label: {
            Label(
                "Filters",
                systemImage: model.query.activeFilterCount == 0
                    ? "line.3.horizontal.decrease"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .labelStyle(.iconOnly)
        .accessibilityValue("Active filters: \(model.query.activeFilterCount)")
        .accessibilityIdentifier("catalog.filters")
    }

    private var listLayoutAction: some View {
        layoutAction(
            .list,
            title: "List",
            systemImage: layout == .list ? "list.bullet.circle.fill" : "list.bullet",
            accessibilityIdentifier: "catalog.layout.list"
        )
    }

    private var gridLayoutAction: some View {
        layoutAction(
            .grid,
            title: "Grid",
            systemImage: layout == .grid ? "square.grid.2x2.fill" : "square.grid.2x2",
            accessibilityIdentifier: "catalog.layout.grid"
        )
    }

    private func layoutAction(
        _ targetLayout: CatalogLayout,
        title: LocalizedStringKey,
        systemImage: String,
        accessibilityIdentifier: String
    ) -> some View {
        Button {
            layout = targetLayout
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
        }
        .accessibilityAddTraits(layout == targetLayout ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct CatalogCollectionControlIdentity: Hashable {
    let userID: UUID?
    let mangaID: Manga.ID
}

extension CatalogRootView {
    init(
        loadPage: @escaping CatalogModel.PageLoader,
        loadFilterOptions: @escaping CatalogModel.FilterOptionsLoader,
        collectionAccess: CollectionAccess,
        collectionMutation: CollectionMutation
    ) {
        model = CatalogModel(loadFilterOptions: loadFilterOptions, loadPage: loadPage)
        layout = .list
        searchText = ""
        self.collectionAccess = collectionAccess
        self.collectionMutation = collectionMutation
    }

    init(model: CatalogModel, initialLayout: CatalogLayout = .list) {
        self.model = model
        layout = initialLayout
        searchText = model.query.advancedSearch?.title ?? ""
        collectionAccess = .unavailable(.signedOut)
        collectionMutation = nil
    }
}

#Preview("Catalog content") {
    CatalogRootView(
        model: CatalogPreviewSupport.model(
            state: .content(.init(items: CatalogPreviewSupport.mangas, pagination: .end))
        )
    )
}

#Preview("Catalog loading") {
    CatalogRootView(model: CatalogPreviewSupport.model(state: .loading))
}

#Preview("Catalog grid") {
    CatalogRootView(
        model: CatalogPreviewSupport.model(
            state: .content(.init(items: CatalogPreviewSupport.mangas, pagination: .end))
        ),
        initialLayout: .grid
    )
}

#Preview("Catalog empty") {
    CatalogRootView(model: CatalogPreviewSupport.model(state: .empty))
}

#Preview("Catalog error") {
    CatalogRootView(model: CatalogPreviewSupport.model(state: .failure(.unavailable)))
}

#Preview("Catalog additional page error") {
    CatalogRootView(
        model: CatalogPreviewSupport.model(
            state: .content(
                .init(items: CatalogPreviewSupport.mangas, pagination: .failure(page: 2, reason: .unavailable))
            )
        )
    )
}

#Preview("Catalog search results") {
    CatalogRootView(
        model: CatalogPreviewSupport.model(
            state: .content(.init(items: CatalogPreviewSupport.mangas, pagination: .end)),
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
