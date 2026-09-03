//
//  CollectionControlsView.swift
//  MangaLibrary
//

import SwiftData
import SwiftUI

struct CollectionControlsView: View {
    @Query private var entries: [CollectionEntry]

    let manga: Manga
    let access: CollectionAccess
    let mutation: CollectionMutation
    let editAccessibilityIdentifier: String

    var body: some View {
        CollectionControlsContentView(
            manga: manga,
            existingState: entries.first?.state,
            access: access,
            mutation: mutation,
            editAccessibilityIdentifier: editAccessibilityIdentifier
        )
    }
}

extension CollectionControlsView {
    init(
        manga: Manga,
        access: CollectionAccess,
        mutation: CollectionMutation,
        editAccessibilityIdentifier: String? = nil
    ) {
        self.manga = manga
        self.access = access
        self.mutation = mutation
        self.editAccessibilityIdentifier = editAccessibilityIdentifier ?? "collection.edit.\(manga.id)"

        if let userID = access.userID {
            _entries = Query(filter: CollectionEntry.activePredicate(userID: userID, mangaID: manga.id))
        } else {
            _entries = Query(filter: #Predicate<CollectionEntry> { _ in false })
        }
    }
}

#Preview("Collection controls", traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.Controls>())) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.controls(container: modelContext.container)
}

#Preview(
    "Collection controls empty",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.ControlsEmpty>())
) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.controls(container: modelContext.container)
}

#Preview(
    "Collection controls signed out",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.ControlsSignedOut>())
) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.signedOutControls(container: modelContext.container)
}

#Preview(
    "Collection controls read only",
    traits: .modifier(CollectionPreviewModifier<CollectionPreviewScenarios.ControlsReadOnly>())
) {
    @Previewable @Environment(\.modelContext) var modelContext
    CollectionPreviewSupport.readOnlyControls(container: modelContext.container)
}
