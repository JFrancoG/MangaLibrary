//
//  CatalogPageRequest.swift
//  MangaLibrary
//

import Foundation

struct CatalogPageRequest: Equatable {
    enum ValidationError: Error, Equatable {
        case invalidPage
        case invalidItemsPerPage
    }

    enum ConstructionError: Error, Equatable {
        case invalidURL
    }

    private let pageValue: Int64
    private let perValue: Int64

    var page: Int64 { pageValue }
    var per: Int64 { perValue }
}

extension CatalogPageRequest {
    /// Creates a page request that satisfies the pagination policy owned by the app.
    ///
    /// The first valid page is `1`; `per` must remain between `1` and `100`.
    init(page: Int64 = 1, per: Int64 = 20) throws {
        guard page >= 1 else {
            throw ValidationError.invalidPage
        }
        guard (1...100).contains(per) else {
            throw ValidationError.invalidItemsPerPage
        }

        pageValue = page
        perValue = per
    }

    /// Builds the public catalog operation without adding session credentials.
    func urlRequest(configuration: APIConfiguration) throws -> URLRequest {
        let endpoint = configuration.baseURL.appending(path: "list/mangas")
        guard var components = URLComponents(
            url: endpoint,
            resolvingAgainstBaseURL: false
        ) else {
            throw ConstructionError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per", value: String(per))
        ]
        guard let url = components.url else {
            throw ConstructionError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return request
    }
}
