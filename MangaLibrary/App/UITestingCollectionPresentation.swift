#if DEBUG
import SwiftUI

@MainActor
enum UITestingCollectionPresentation {
    static func uiTestingCollectionDetailProjection(mutation: CollectionMutation) -> some View {
        let manga = CatalogPreviewSupport.mangas[1]
        let state = CollectionSnapshot(
            ownedVolumes: [1, 12],
            readingVolume: 8,
            isComplete: false,
            knownTotalVolumes: manga.totalVolumes,
            isTombstone: false
        )

        return NavigationStack {
            CollectionEntryDetailView(
                mangaID: manga.id,
                mangaSnapshot: CollectionMangaSnapshot(manga: manga),
                state: state,
                scope: CollectionUserScope(
                    userID: AccountPreviewSupport.account.id,
                    authority: AccountPreviewSupport.account.authority
                ),
                restriction: nil,
                mutation: mutation
            )
        }
    }

    static func uiTestingMountedCollectionDetail(
        mutation: CollectionMutation,
        update: CollectionSynchronization
    ) -> some View {
        CollectionUserRootView(
            scope: CollectionUserScope(
                userID: AccountPreviewSupport.account.id,
                authority: AccountPreviewSupport.account.authority
            ),
            restriction: nil,
            mutation: mutation
        )
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    do {
                        try await update()
                    } catch {
                        preconditionFailure("The deterministic Collection update failed.")
                    }
                }
            } label: {
                Text(verbatim: "Apply synchronized state")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("ui-testing.collection.apply-synchronized-state")
            .padding()
        }
    }
}
#endif
