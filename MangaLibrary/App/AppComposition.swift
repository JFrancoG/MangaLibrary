//
//  AppComposition.swift
//  MangaLibrary
//

import Foundation
import SwiftData
import WidgetKit

struct AppComposition {
    let modelContainer: ModelContainer
    let collectionMutations: CollectionMutationActor
    let collectionSynchronization: CollectionSynchronization
    let collectionBlockedOutcomeResolution: CollectionBlockedOutcomeResolution
    let catalogClient: CatalogAPIClient
    let registerUser: UserRegistrationClient.Operation
    let sessionController: SessionController
    let readingPublication: ReadingPublicationComposition

    /// Builds only the dependencies used by a production launch.
    ///
    /// Previews and tests compose their deterministic loaders outside this root,
    /// so a fixture can never replace the live transport here.
    static func live() throws -> AppComposition {
        let modelContainer = try MangaLibrarySchema.makeContainer()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = URLCache(memoryCapacity: 20 * 1_024 * 1_024, diskCapacity: 0)

        let session = URLSession(configuration: configuration)
        let coverSource = ReadingCoverSource(session: session)
        let reading = makeLiveReadingPublication(modelContainer: modelContainer, loadCover: coverSource.data)
        let collectionMutations = reading.mutations
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
            deluxePublisher: reading.publisher,
            readingEvents: reading.events,
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
            sessionController: sessionController,
            readingPublication: reading
        )
    }

    private static func makeLiveReadingPublication(
        modelContainer: ModelContainer,
        loadCover: @escaping @Sendable (URL) async throws -> Data?
    ) -> ReadingPublicationComposition {
        let events = ReadingPublicationEvents()
        let publisherDirectory = URL.applicationSupportDirectory
            .appending(path: "ReadingPublisher", directoryHint: .isDirectory)
        let storage = ReadingSnapshotStorage(
            resolvingSharedDirectory: ReadingWidgetBridge.sharedDirectory,
            publisherDirectory: publisherDirectory
        )
        let covers = ReadingWidgetBridge.sharedDirectory().flatMap { sharedDirectory in
            try? ReadingCoverStorage(sharedDirectory: sharedDirectory, publisherDirectory: publisherDirectory)
        }
        let publisher = ReadingSnapshotPublisher(
            storage: storage,
            now: { Date() },
            makeGeneration: { UUID() },
            requestReload: { _ in
                WidgetCenter.shared.reloadTimelines(ofKind: ReadingWidgetBridge.kind)
            },
            coverStorage: covers
        )
        return ReadingPublicationComposition(
            mutations: CollectionMutationActor(modelContainer: modelContainer, readingEvents: events),
            publisher: publisher,
            events: events,
            loadCover: loadCover
        )
    }

    private static func requiredURL(_ value: String) -> URL {
        guard let url = URL(string: value) else {
            preconditionFailure("The bundled API endpoint is invalid.")
        }

        return url
    }
}
