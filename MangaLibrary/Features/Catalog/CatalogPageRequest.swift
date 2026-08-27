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

    private let queryValue: CatalogQuery
    private let pageValue: Int64
    private let perValue: Int64

    var query: CatalogQuery { queryValue }
    var page: Int64 { pageValue }
    var per: Int64 { perValue }
}

extension CatalogPageRequest {
    /// Creates a page request that satisfies the pagination policy owned by the app.
    ///
    /// The first valid page is `1`; `per` must remain between `1` and `100`.
    init(
        query: CatalogQuery = .catalog,
        page: Int64 = 1,
        per: Int64 = 20
    ) throws {
        guard page >= 1 else {
            throw ValidationError.invalidPage
        }
        guard (1...100).contains(per) else {
            throw ValidationError.invalidItemsPerPage
        }

        queryValue = query
        pageValue = page
        perValue = per
    }

    /// Builds the exact public operation represented by the query identity.
    ///
    /// Catalog and best-manga queries are bodyless `GET` requests. Advanced
    /// queries are `POST` requests whose optional body fields are omitted when
    /// the corresponding search value is absent. No session credential is
    /// added at this boundary.
    func urlRequest(configuration: APIConfiguration) throws -> URLRequest {
        let endpoint = configuration.baseURL.appending(path: endpointPath)
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
        switch query {
        case .catalog, .best:
            request.httpMethod = "GET"
        case let .advanced(search):
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            request.httpMethod = "POST"
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )
            request.httpBody = try encoder.encode(
                CustomSearchRequestBody(search: search)
            )
        }
        return request
    }

    private var endpointPath: String {
        switch query {
        case .catalog:
            "list/mangas"
        case .best:
            "list/bestMangas"
        case .advanced:
            "search/manga"
        }
    }
}

private struct CustomSearchRequestBody: Encodable {
    let searchContains: Bool
    let searchTitle: String?
    let searchAuthorFirstName: String?
    let searchAuthorLastName: String?
    let searchGenres: [String]?
    let searchThemes: [String]?
    let searchDemographics: [String]?
}

extension CustomSearchRequestBody {
    init(search: CatalogSearch) {
        searchContains = search.matchMode.searchContains
        searchTitle = search.title
        searchAuthorFirstName = search.authorFirstName
        searchAuthorLastName = search.authorLastName
        searchGenres = search.genres.isEmpty ? nil : search.genres
        searchThemes = search.themes.isEmpty ? nil : search.themes
        searchDemographics = search.demographics.isEmpty
            ? nil
            : search.demographics
    }
}
