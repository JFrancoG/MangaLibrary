import SwiftData
import SwiftUI

struct AppReadyView: View {
    let runtime: AppRuntime

    var body: some View {
        Group {
            let shell = MainShellView(
                loadCatalogPage: runtime.loadCatalogPage,
                loadCatalogFilterOptions: runtime.loadCatalogFilterOptions,
                accountModel: runtime.accountModel,
                collectionMutation: runtime.collectionMutation,
                collectionSynchronization: runtime.collectionSynchronization,
                collectionBlockedOutcomeResolution: runtime.collectionBlockedOutcomeResolution,
                readingPublication: runtime.readingPublication
            )
#if DEBUG
            if runtime.presentsCollectionDetailProjection {
                UITestingCollectionPresentation.uiTestingCollectionDetailProjection(
                    mutation: runtime.collectionMutation
                )
            } else if runtime.presentsMountedCollectionDetail {
                UITestingCollectionPresentation.uiTestingMountedCollectionDetail(
                    mutation: runtime.collectionMutation,
                    update: runtime.collectionDetailUpdate
                )
            } else {
                shell
            }
#else
            shell
#endif
        }
        .modelContainer(runtime.modelContainer)
    }
}

#if DEBUG
#Preview("Ready app") {
    AppReadyView(runtime: UITestingBootstrap.previewRuntime())
}
#endif
