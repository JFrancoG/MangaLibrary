//
//  CollectionUserRootView.swift
//  MangaLibrary
//

import SwiftData
import SwiftUI

struct CollectionUserRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var entries: [CollectionEntry]

    @State private var selectedMangaID: Manga.ID?

    let scope: CollectionUserScope
    let restriction: CollectionAccess.MutationRestriction?
    let mutation: CollectionMutation

    var body: some View {
        navigation
            .onChange(of: entries.map(\.mangaID)) { _, mangaIDs in
                guard let selectedMangaID, mangaIDs.contains(selectedMangaID) == false else { return }

                self.selectedMangaID = nil
            }
    }

    @ViewBuilder
    private var navigation: some View {
        if horizontalSizeClass == .compact {
            NavigationStack(path: compactNavigationPath) {
                sidebar(navigationMode: .compact)
                    .navigationDestination(for: Manga.ID.self) { mangaID in
                        detail(mangaID: mangaID)
                    }
            }
        } else {
            NavigationSplitView {
                sidebar(navigationMode: .regular)
            } detail: {
                if let selectedMangaID {
                    detail(mangaID: selectedMangaID)
                } else {
                    unselectedDetail
                }
            }
        }
    }

    private func sidebar(navigationMode: CollectionNavigationMode) -> some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Your collection is empty",
                    systemImage: "books.vertical",
                    description: Text("Add manga from Catalog details to keep them available offline.")
                )
                .accessibilityIdentifier("collection.empty")
            } else if navigationMode == .compact {
                List(entries) { entry in
                    NavigationLink(value: entry.mangaID) {
                        CollectionRowView(entry: entry)
                    }
                }
            } else {
                List(entries, selection: $selectedMangaID) { entry in
                    CollectionRowView(entry: entry)
                        .tag(entry.mangaID)
                }
            }
        }
        .navigationTitle("Collection")
        .safeAreaInset(edge: .top, spacing: 0) {
            if let restriction {
                CollectionReadOnlyBanner(restriction: restriction)
            }
        }
        .background(.canvas)
    }

    @ViewBuilder
    private func detail(mangaID: Manga.ID) -> some View {
        if let entry = entries.first(where: { $0.mangaID == mangaID }) {
            CollectionEntryDetailView(
                entry: entry,
                scope: scope,
                restriction: restriction,
                mutation: mutation
            )
            .id(CollectionIdentity(userID: scope.userID, mangaID: mangaID))
        } else {
            ContentUnavailableView(
                "Collection item unavailable",
                systemImage: "books.vertical",
                description: Text("The selected manga is no longer active in this collection.")
            )
        }
    }

    private var unselectedDetail: some View {
        ContentUnavailableView(
            "Select a manga",
            systemImage: "book.pages",
            description: Text("Choose a manga from your collection to see its offline details.")
        )
    }

    private var compactNavigationPath: Binding<[Manga.ID]> {
        Binding {
            selectedMangaID.map { [$0] } ?? []
        } set: { path in
            selectedMangaID = path.last
        }
    }
}

extension CollectionUserRootView {
    init(scope: CollectionUserScope, restriction: CollectionAccess.MutationRestriction?, mutation: CollectionMutation) {
        self.scope = scope
        self.restriction = restriction
        self.mutation = mutation
        _entries = Query(
            filter: CollectionEntry.activePredicate(userID: scope.userID),
            sort: [SortDescriptor(\CollectionEntry.mangaID)]
        )
    }
}

private enum CollectionNavigationMode {
    case compact
    case regular
}

#Preview("Collection user root", traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.UserRoot>())) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.userRoot(container: modelContext.container)
}
