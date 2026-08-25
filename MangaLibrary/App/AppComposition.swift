//
//  AppComposition.swift
//  MangaLibrary
//

import Foundation

struct AppComposition {
    enum CreationError: Error, Equatable {
        case invalidCatalogFixture
        case catalogFixtureUnavailable
    }

    let catalogClient: CatalogAPIClient

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) throws -> AppComposition {
        if arguments.contains(CatalogFixtureScenario.launchArgument) {
#if DEBUG
            guard let scenario = CatalogFixtureScenario(arguments: arguments) else {
                throw CreationError.invalidCatalogFixture
            }

            return AppComposition(
                catalogClient: try CatalogPreviewSupport.catalogClient(
                    for: scenario
                )
            )
#else
            throw CreationError.catalogFixtureUnavailable
#endif
        }

        return try live()
    }

    private static func live() throws -> AppComposition {
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

        return AppComposition(
            catalogClient: CatalogAPIClient(
                httpClient: httpClient,
                configuration: apiConfiguration
            )
        )
    }

    private static func requiredURL(_ value: String) -> URL {
        guard let url = URL(string: value) else {
            preconditionFailure("The bundled API endpoint is invalid.")
        }

        return url
    }
}
