//
//  AppComposition.swift
//  MangaLibrary
//

import Foundation

struct AppComposition {
    let catalogClient: CatalogAPIClient
    let registerUser: UserRegistrationClient.Operation
    let sessionController: SessionController

    /// Builds only the dependencies used by a production launch.
    ///
    /// Previews and tests compose their deterministic loaders outside this root,
    /// so a fixture can never replace the live transport here.
    static func live() throws -> AppComposition {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1_024 * 1_024,
            diskCapacity: 0
        )

        let session = URLSession(configuration: configuration)
        let httpClient = HTTPClient(session: session)
        let apiConfiguration = try APIConfiguration(
            baseURL: requiredURL(
                "https://mymanga-acacademy-5607149ebe3d.herokuapp.com"
            )
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
            makeGeneration: { UUID() }
        )

        return AppComposition(
            catalogClient: CatalogAPIClient(
                httpClient: httpClient,
                configuration: apiConfiguration
            ),
            registerUser: UserRegistrationClient.operation(
                httpClient: httpClient,
                configuration: apiConfiguration,
                appToken: Bundle.main.object(
                    forInfoDictionaryKey: "MangaLibraryAppToken"
                ) as? String
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
