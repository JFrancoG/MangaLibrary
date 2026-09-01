//
//  CatalogAPIClient.swift
//  MangaLibrary
//

import Foundation

enum CatalogAPIClientError: Error, Equatable {
    case unavailable
    case network(NetworkError)
    case contractDrift
    case duplicateMangaID(Manga.ID)
}

struct CatalogAPIClient {
    typealias DataLoader = @Sendable (URLRequest) async throws -> Data

    let configuration: APIConfiguration
    let loadData: DataLoader

    /// Fetches and maps one catalog page outside the caller's actor isolation.
    ///
    /// Cancellation and safe network categories propagate without losing their
    /// meaning. Missing product fields and pagination metadata that does not
    /// correspond to the request become contract drift; response bodies and
    /// underlying errors are never retained.
    @concurrent
    func fetch(_ pageRequest: CatalogPageRequest) async throws -> CatalogPage {
        let request: URLRequest
        do {
            request = try pageRequest.urlRequest(configuration: configuration)
        } catch {
            throw CatalogAPIClientError.unavailable
        }

        let data: Data
        do {
            data = try await loadData(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as NetworkError {
            throw CatalogAPIClientError.network(error)
        } catch {
            throw CatalogAPIClientError.unavailable
        }

        do {
            let response = try JSONDecoder().decode(CatalogPageDTO.self, from: data)
            let page = try response.catalogPage()
            guard
                page.metadata.page == pageRequest.page,
                page.metadata.per == pageRequest.per,
                page.metadata.total >= Int64(page.items.count)
            else {
                throw CatalogAPIClientError.contractDrift
            }

            return page
        } catch let error as CatalogAPIClientError {
            throw error
        } catch {
            throw CatalogAPIClientError.contractDrift
        }
    }

    /// Loads the exact taxonomies accepted by advanced catalog search.
    ///
    /// The three independent public operations run as structured child tasks.
    /// Parent cancellation propagates through every child and safe transport
    /// categories are preserved; malformed arrays become contract drift.
    @concurrent
    func fetchFilterOptions() async throws -> CatalogFilterOptions {
        async let demographics = fetchFilterValues(path: "list/demographics")
        async let genres = fetchFilterValues(path: "list/genres")
        async let themes = fetchFilterValues(path: "list/themes")

        let (demographicValues, genreValues, themeValues) = try await (demographics, genres, themes)
        return CatalogFilterOptions(demographics: demographicValues, genres: genreValues, themes: themeValues)
    }

    @concurrent
    private func fetchFilterValues(path: String) async throws -> [String] {
        let endpoint = configuration.baseURL.appending(path: path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        let data: Data
        do {
            data = try await loadData(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as NetworkError {
            throw CatalogAPIClientError.network(error)
        } catch {
            throw CatalogAPIClientError.unavailable
        }

        do {
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            throw CatalogAPIClientError.contractDrift
        }
    }
}

extension CatalogAPIClient {
    /// Adapts the production HTTP transport without exposing it to previews or feature tests.
    init(httpClient: HTTPClient, configuration: APIConfiguration) {
        self.init(configuration: configuration) { request in
            try await httpClient.data(for: request)
        }
    }
}
