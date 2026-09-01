//
//  APIConfiguration.swift
//  MangaLibrary
//

import Foundation

/// A validated base endpoint used to compose API requests.
///
/// Configuration accepts only absolute HTTP or HTTPS URLs with a host. It does
/// not carry authentication or other request policy; embedded user information
/// is rejected before the endpoint enters the dependency graph.
struct APIConfiguration: Equatable {
    private let baseURLValue: URL

    var baseURL: URL { baseURLValue }
}

extension APIConfiguration {
    init(baseURL: URL) throws {
        guard
            let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host,
            !host.isEmpty,
            components.user == nil,
            components.password == nil
        else {
            throw APIConfigurationError.invalidBaseURL
        }

        baseURLValue = baseURL
    }
}

/// Failures raised before an invalid endpoint can enter the dependency graph.
enum APIConfigurationError: Error, Equatable {
    /// The URL is not an absolute HTTP or HTTPS endpoint with a host, or it embeds user information.
    case invalidBaseURL
}
