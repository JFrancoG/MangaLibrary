//
//  CollectionEntryDetailView.swift
//  MangaLibrary
//

import SwiftData
import SwiftUI

struct CollectionEntryDetailView: View {
    @State private var editorSeed: CollectionEditorSeed?

    let entry: CollectionEntry
    let scope: CollectionUserScope
    let restriction: CollectionAccess.MutationRestriction?
    let mutation: CollectionMutation

    var body: some View {
        if let mangaSnapshot = entry.mangaSnapshot {
            let manga = mangaSnapshot.manga(knownTotalVolumes: entry.knownTotalVolumes)
            MangaDetailView(manga: manga) {
                CollectionControlsView(
                    manga: manga,
                    access: .user(scope, restriction: restriction),
                    mutation: mutation,
                    editAccessibilityIdentifier: "collection.entry.edit.\(manga.id)"
                )
                    .id(CollectionIdentity(userID: scope.userID, mangaID: manga.id))
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Manga #\(entry.mangaID)")
                        .font(.title2.bold())
                        .foregroundStyle(.textPrimary)

                    ContentUnavailableView(
                        "Offline details unavailable",
                        systemImage: "book.closed",
                        description: Text(
                            "This item predates offline manga details. Its collection state remains intact."
                        )
                    )

                    CollectionStateSummary(state: entry.state)

                    if let restriction {
                        CollectionReadOnlyBanner(restriction: restriction)
                    } else if let authority = scope.authority {
                        Button("Edit Collection", systemImage: "pencil") {
                            editorSeed = seed(authority: authority)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("collection.edit.\(entry.mangaID)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(.canvas)
            .navigationTitle("Collection item")
            .sheet(item: $editorSeed) { editorSeed in
                CollectionEditorView(seed: editorSeed, mutation: mutation)
            }
            .onChange(of: restriction) { _, restriction in
                if restriction != nil {
                    editorSeed = nil
                }
            }
            .onChange(of: scope.authority) { _, _ in
                editorSeed = nil
            }
            .accessibilityIdentifier("collection.missing-details.\(entry.mangaID)")
        }
    }

    private func seed(authority: SessionAuthority) -> CollectionEditorSeed {
        CollectionEditorSeed(
            identity: CollectionIdentity(userID: scope.userID, mangaID: entry.mangaID),
            authority: authority,
            title: nil,
            mangaSnapshot: nil,
            state: entry.state,
            isExistingEntry: true
        )
    }
}

#Preview(
    "Collection entry detail",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.EntryDetail>())
) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.entryDetail(container: modelContext.container)
}

#Preview(
    "Migrated collection entry",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.MigratedEntryDetail>())
) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.migratedEntryDetail(container: modelContext.container)
}
