import SwiftData
@testable import MangaLibrary

enum AppStartupTestSupport {
    @MainActor
    static func runtime(modelContainer: ModelContainer) -> AppRuntime {
        let account = AccountPreviewSupport.model(state: .signedOut(failure: nil))
        return AppRuntime(
            modelContainer: modelContainer,
            collectionMutation: CollectionMutation(
                actor: CollectionMutationActor(modelContainer: modelContainer),
                accountModel: account,
                sessionAuthorization: .deterministic
            ),
            collectionSynchronization: .disabled,
            collectionBlockedOutcomeResolution: .disabled,
            loadCatalogPage: CatalogPreviewSupport.pageLoader,
            loadCatalogFilterOptions: CatalogPreviewSupport.filterOptionsLoader,
            accountModel: account,
            readingPublication: nil
        )
    }
}
