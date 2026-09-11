//
//  MangaLibraryApp.swift
//  MangaLibrary
//
//  Created by Jesús Franco on 15.08.2026.
//

import SwiftData
import SwiftUI

@main
struct MangaLibraryApp: App {
    private let modelContainer: ModelContainer
    private let collectionMutation: CollectionMutation
    private let collectionSynchronization: CollectionSynchronization
    private let collectionBlockedOutcomeResolution: CollectionBlockedOutcomeResolution
    private let loadCatalogPage: CatalogModel.PageLoader
    private let loadCatalogFilterOptions: CatalogModel.FilterOptionsLoader
    @State private var accountModel: AccountModel
    @State private var readingPublication: ReadingPublicationLifecycle?
#if DEBUG
    private let presentsUITestingCollectionDetailProjection: Bool
    private let presentsUITestingMountedCollectionDetail: Bool
    private let uiTestingCollectionDetailUpdate: CollectionSynchronization
#endif

    var body: some Scene {
        WindowGroup {
            let shell = MainShellView(
                loadCatalogPage: loadCatalogPage,
                loadCatalogFilterOptions: loadCatalogFilterOptions,
                accountModel: accountModel,
                collectionMutation: collectionMutation,
                collectionSynchronization: collectionSynchronization,
                collectionBlockedOutcomeResolution: collectionBlockedOutcomeResolution,
                readingPublication: readingPublication
            )
#if DEBUG
            if presentsUITestingCollectionDetailProjection {
                UITestingCollectionPresentation.uiTestingCollectionDetailProjection(mutation: collectionMutation)
            } else if presentsUITestingMountedCollectionDetail {
                UITestingCollectionPresentation.uiTestingMountedCollectionDetail(
                    mutation: collectionMutation,
                    update: uiTestingCollectionDetailUpdate
                )
            } else {
                shell
            }
#else
            shell
#endif
        }
        .modelContainer(modelContainer)
    }
}

extension MangaLibraryApp {
    init() {
        let processArguments = ProcessInfo.processInfo.arguments
#if DEBUG
        do {
            if let bootstrap = try UITestingBootstrap.makeIfRequested(processArguments: processArguments) {
                modelContainer = bootstrap.modelContainer
                collectionMutation = bootstrap.collectionMutation
                collectionSynchronization = bootstrap.collectionSynchronization
                collectionBlockedOutcomeResolution = bootstrap.collectionBlockedOutcomeResolution
                presentsUITestingCollectionDetailProjection = bootstrap.presentsCollectionDetailProjection
                presentsUITestingMountedCollectionDetail = bootstrap.presentsMountedCollectionDetail
                uiTestingCollectionDetailUpdate = bootstrap.collectionDetailUpdate
                loadCatalogPage = bootstrap.loadCatalogPage
                loadCatalogFilterOptions = bootstrap.loadCatalogFilterOptions
                _accountModel = State(initialValue: bootstrap.accountModel)
                _readingPublication = State(initialValue: bootstrap.readingPublication)
                return
            }
        } catch {
            preconditionFailure("Manga Library could not create its UI testing data store.")
        }
#else
        if processArguments.contains("-ui-testing") {
            preconditionFailure("UI testing data is unavailable in production builds.")
        }
#endif

        do {
            let composition = try AppComposition.live()
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
            _readingPublication = State(initialValue: ReadingPublicationLifecycle(runPipeline: {
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
            }))
            modelContainer = composition.modelContainer
            collectionMutation = CollectionMutation(
                actor: composition.collectionMutations,
                accountModel: account,
                sessionAuthorization: CollectionSessionAuthorization(sessionController: composition.sessionController)
            )
            collectionSynchronization = composition.collectionSynchronization
            collectionBlockedOutcomeResolution = composition.collectionBlockedOutcomeResolution
#if DEBUG
            presentsUITestingCollectionDetailProjection = false
            presentsUITestingMountedCollectionDetail = false
            uiTestingCollectionDetailUpdate = .disabled
#endif
            loadCatalogPage = { request in
                try await catalogClient.fetch(request)
            }
            loadCatalogFilterOptions = {
                try await catalogClient.fetchFilterOptions()
            }
            _accountModel = State(initialValue: account)
        } catch {
            preconditionFailure("Manga Library could not create its app dependencies.")
        }
    }

}
