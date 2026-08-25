//
//  CatalogAPIClient.swift
//  MangaLibrary
//

import Foundation

enum CatalogAPIClientError: Error, Equatable {
    case unavailable
    case contractDrift
    case duplicateMangaID(Manga.ID)
}

struct CatalogAPIClient {
    let httpClient: HTTPClient
    let configuration: APIConfiguration

    /// Fetches and maps one catalog page outside the caller's actor isolation.
    ///
    /// Cancellation propagates unchanged. Request and transport failures become
    /// a safe unavailable failure. Invalid JSON, unknown closed vocabulary
    /// values, and missing required fields become a safe contract-drift failure;
    /// response bodies and underlying errors are never retained.
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
            data = try await httpClient.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw CatalogAPIClientError.unavailable
        }

        do {
            let response = try JSONDecoder().decode(CatalogPageDTO.self, from: data)
            return try response.catalogPage()
        } catch let error as CatalogAPIClientError {
            throw error
        } catch {
            throw CatalogAPIClientError.contractDrift
        }
    }
}
