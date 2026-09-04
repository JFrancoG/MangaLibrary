//
//  AppComposition.swift
//  MangaLibrary
//

import Foundation
import SwiftData

struct AppComposition {
    let modelContainer: ModelContainer
    let collectionMutations: CollectionMutationActor
    let collectionSynchronization: CollectionSynchronization
    let collectionBlockedOutcomeResolution: CollectionBlockedOutcomeResolution
    let catalogClient: CatalogAPIClient
    let registerUser: UserRegistrationClient.Operation
    let sessionController: SessionController

    /// Builds only the dependencies used by a production launch.
    ///
    /// Previews and tests compose their deterministic loaders outside this root,
    /// so a fixture can never replace the live transport here.
    static func live() throws -> AppComposition {
        let modelContainer = try MangaLibrarySchema.makeContainer()
        let collectionMutations = CollectionMutationActor(modelContainer: modelContainer)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = URLCache(memoryCapacity: 20 * 1_024 * 1_024, diskCapacity: 0)

        let session = URLSession(configuration: configuration)
        let httpClient = HTTPClient(session: session)
        let apiConfiguration = try APIConfiguration(
            baseURL: requiredURL("https://mymanga-acacademy-5607149ebe3d.herokuapp.com")
        )

        let sessionClient = SessionAPIClient(
            httpClient: httpClient,
            configuration: apiConfiguration,
            now: { Date() }
        )
        let sessionController = try SessionController(
            apiClient: sessionClient,
            persistence: .live(),
            now: { Date() },
            makeGeneration: { UUID() },
            logoutPendingChangesObserver: { authorization in
                do {
                    return try await collectionMutations.hasPendingChangesForLogout(authorization: authorization)
                } catch CollectionLogoutError.cancelled {
                    throw CancellationError()
                } catch CollectionLogoutError.sessionChanged {
                    throw SessionControllerError.sessionChanged
                } catch {
                    throw SessionControllerError.pendingCollectionPersistenceUnavailable
                }
            },
            logoutPendingChangesDiscarder: { authorization in
                do {
                    try await collectionMutations.discardPendingChangesForLogout(authorization: authorization)
                } catch CollectionLogoutError.cancelled {
                    throw CancellationError()
                } catch CollectionLogoutError.sessionChanged {
                    throw SessionControllerError.sessionChanged
                } catch {
                    throw SessionControllerError.pendingCollectionPersistenceUnavailable
                }
            },
            authenticationInvalidationObserver: { authorization in
                try await collectionMutations.blockUploadsForAuthentication(authorization: authorization)
            }
        )
        let collectionClient = CollectionAPIClient(httpClient: httpClient, configuration: apiConfiguration)
        let collectionSyncCoordinator = CollectionSyncCoordinator(
            sessionController: sessionController,
            client: collectionClient,
            mutationActor: collectionMutations
        )
        let collectionOutboxCoordinator = CollectionOutboxSyncCoordinator(
            sessionController: sessionController,
            client: collectionClient,
            mutationActor: collectionMutations
        )
        let collectionOutcomeResolutionCoordinator = CollectionOutcomeResolutionCoordinator(
            sessionController: sessionController,
            client: collectionClient,
            mutationActor: collectionMutations
        )

        return AppComposition(
            modelContainer: modelContainer,
            collectionMutations: collectionMutations,
            collectionSynchronization: CollectionSynchronization(
                importCoordinator: collectionSyncCoordinator,
                outboxCoordinator: collectionOutboxCoordinator
            ),
            collectionBlockedOutcomeResolution: CollectionBlockedOutcomeResolution(
                coordinator: collectionOutcomeResolutionCoordinator
            ),
            catalogClient: CatalogAPIClient(httpClient: httpClient, configuration: apiConfiguration),
            registerUser: UserRegistrationClient.operation(
                httpClient: httpClient,
                configuration: apiConfiguration,
                appToken: Bundle.main.object(forInfoDictionaryKey: "MangaLibraryAppToken") as? String
            ),
            sessionController: sessionController
        )
    }

    private static func requiredURL(_ value: String) -> URL {
        guard let url = URL(string: value) else {
            preconditionFailure("The bundled API endpoint is invalid.")
        }

        return url
    }
}
