import SwiftData

/// Retains the dependencies of one successful launch, shared by its windows.
@MainActor
struct AppRuntime {
    let modelContainer: ModelContainer
    let collectionMutation: CollectionMutation
    let collectionSynchronization: CollectionSynchronization
    let collectionBlockedOutcomeResolution: CollectionBlockedOutcomeResolution
    let loadCatalogPage: CatalogModel.PageLoader
    let loadCatalogFilterOptions: CatalogModel.FilterOptionsLoader
    let accountModel: AccountModel
    let readingPublication: ReadingPublicationLifecycle?
#if DEBUG
    var presentsCollectionDetailProjection = false
    var presentsMountedCollectionDetail = false
    var collectionDetailUpdate = CollectionSynchronization.disabled
#endif
}

extension AppRuntime {
    init(composition: AppComposition) {
        let catalogClient = composition.catalogClient
        let account = AccountModel(
            operations: .live(controller: composition.sessionController, register: composition.registerUser)
        )
        let watchConnectivity = composition.watchConnectivity
        let readingPublisher = composition.readingPublication.publisher
        let sessionController = composition.sessionController
        let publication = composition.readingPublication.makePipeline(
            sessionController: composition.sessionController,
            onSessionReconciled: { authority in
                await account.reconcileSession(expectedAuthority: authority)
            },
            onProjectionUnchanged: { authorization in
                try? await readingPublisher.deliverWatchContext(
                    authorization: authorization,
                    send: watchConnectivity.send
                )
            }
        )
        let readingPublication = ReadingPublicationLifecycle(runPipeline: {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try? await watchConnectivity.run { event in
                        if case .activated = event {
                            try? await sessionController.deliverWatchContext(send: watchConnectivity.send)
                        }
                    }
                }
                defer { group.cancelAll() }
                try await publication.run()
            }
        })
        self.init(
            modelContainer: composition.modelContainer,
            collectionMutation: CollectionMutation(
                actor: composition.collectionMutations,
                accountModel: account,
                sessionAuthorization: CollectionSessionAuthorization(sessionController: sessionController)
            ),
            collectionSynchronization: composition.collectionSynchronization,
            collectionBlockedOutcomeResolution: composition.collectionBlockedOutcomeResolution,
            loadCatalogPage: { request in
                try await catalogClient.fetch(request)
            },
            loadCatalogFilterOptions: {
                try await catalogClient.fetchFilterOptions()
            },
            accountModel: account,
            readingPublication: readingPublication
        )
    }
}
