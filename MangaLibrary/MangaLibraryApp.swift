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
    private let loadCatalogPage: CatalogModel.PageLoader
    private let loadCatalogFilterOptions: CatalogModel.FilterOptionsLoader
    @State private var accountModel: AccountModel

    var body: some Scene {
        WindowGroup {
            MainShellView(
                loadCatalogPage: loadCatalogPage,
                loadCatalogFilterOptions: loadCatalogFilterOptions,
                accountModel: accountModel,
                collectionMutation: collectionMutation,
                collectionSynchronization: collectionSynchronization
            )
        }
        .modelContainer(modelContainer)
    }
}

extension MangaLibraryApp {
    init() {
        let processArguments = ProcessInfo.processInfo.arguments
        if processArguments.contains("-ui-testing") {
#if DEBUG
            // UI automation owns one deterministic bootstrap and cannot select
            // fixtures or fall through to production networking.
            do {
                let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
                let account = AccountPreviewSupport.model(state: .signedOut(failure: nil))
                let mutationActor = CollectionMutationActor(modelContainer: container)
                modelContainer = container
                collectionMutation = CollectionMutation(
                    actor: mutationActor,
                    accountModel: account,
                    sessionAuthorization: .deterministic
                )
                if processArguments.contains("-ui-testing-collection-authorization-denied") {
                    collectionSynchronization = Self.uiTestingCollectionAuthorizationFailure()
                } else {
                    collectionSynchronization = Self.uiTestingCollectionSynchronization(actor: mutationActor)
                }
                loadCatalogPage = CatalogPreviewSupport.pageLoader
                loadCatalogFilterOptions = CatalogPreviewSupport.filterOptionsLoader
                _accountModel = State(initialValue: account)
                return
            } catch {
                preconditionFailure("Manga Library could not create its UI testing data store.")
            }
#else
            preconditionFailure("UI testing data is unavailable in production builds.")
#endif
        }

        do {
            let composition = try AppComposition.live()
            let catalogClient = composition.catalogClient
            let account = AccountModel(
                operations: .live(controller: composition.sessionController, register: composition.registerUser)
            )
            modelContainer = composition.modelContainer
            collectionMutation = CollectionMutation(
                actor: composition.collectionMutations,
                accountModel: account,
                sessionAuthorization: CollectionSessionAuthorization(sessionController: composition.sessionController)
            )
            collectionSynchronization = composition.collectionSynchronization
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

#if DEBUG
    private static func uiTestingCollectionSynchronization(
        actor: CollectionMutationActor
    ) -> CollectionSynchronization {
        let authority = AccountPreviewSupport.account.authority
        let commitGate = SessionCommitGate(activeAuthority: authority)
        let remoteEntry = CollectionRemoteEntry(
            remoteID: UUID(uuid: (102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102)),
            manga: CatalogPreviewSupport.mangas[1],
            ownedVolumes: [1],
            readingVolume: nil,
            isComplete: false
        )

        return CollectionSynchronization(operation: {
            try await actor.importRemote([remoteEntry], authorization: commitGate.authorization(for: authority))
        })
    }

    private static func uiTestingCollectionAuthorizationFailure() -> CollectionSynchronization {
        CollectionSynchronization(operation: {
            throw CollectionSyncError.authorizationDenied(origin: .collectionSnapshot(attempt: 1), statusCode: 403)
        })
    }
#endif
}
