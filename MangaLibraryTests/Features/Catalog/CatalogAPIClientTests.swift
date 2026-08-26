//
//  CatalogAPIClientTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite(.tags(.integration))
struct CatalogAPIClientTests {
    @Test
    func initialRequestUsesThePublicFirstPageContract() async throws {
        let (client, session) = try makeClient(host: "valid.catalog.test")
        defer { session.invalidateAndCancel() }

        _ = try await client.fetch(CatalogPageRequest())
    }

    @Test
    func pageRequestDefaultsToPageOneAndTwentyItems() throws {
        let request = try CatalogPageRequest()

        #expect(request.page == 1)
        #expect(request.per == 20)
    }

    @Test
    func pageRequestRejectsValuesOutsideTheApplicationPolicy() {
        #expect(throws: CatalogPageRequest.ValidationError.invalidPage) {
            try CatalogPageRequest(page: 0, per: 20)
        }
        #expect(throws: CatalogPageRequest.ValidationError.invalidItemsPerPage) {
            try CatalogPageRequest(page: 1, per: 0)
        }
        #expect(throws: CatalogPageRequest.ValidationError.invalidItemsPerPage) {
            try CatalogPageRequest(page: 1, per: 101)
        }
    }

    @Test
    func secondPageRequestUsesTheRequestedCursor() async throws {
        let (client, session) = try makeClient(host: "page-two.catalog.test")
        defer { session.invalidateAndCancel() }

        let page = try await client.fetch(CatalogPageRequest(page: 2))

        #expect(page.metadata.page == 2)
        #expect(page.metadata.per == 20)
        #expect(page.metadata.total == 40)
    }

    @Test
    func mismatchedResponseMetadataIsRejectedAsContractDrift() async throws {
        let (client, session) = try makeClient(
            host: "metadata-mismatch.catalog.test"
        )
        defer { session.invalidateAndCancel() }

        await #expect(throws: CatalogAPIClientError.contractDrift) {
            try await client.fetch(CatalogPageRequest())
        }
    }

    @Test
    func validCompleteContractFixtureMapsCatalogValues() async throws {
        let (client, session) = try makeClient(host: "valid.catalog.test")
        defer { session.invalidateAndCancel() }

        let page = try await client.fetch(CatalogPageRequest())
        let manga = try #require(page.items.first)

        #expect(page.items.count == 1)
        #expect(page.metadata.page == 1)
        #expect(page.metadata.per == 20)
        #expect(page.metadata.total == 1)
        #expect(manga.id == 42)
        #expect(manga.title == "Fullmetal Alchemist")
        #expect(manga.titleEnglish == "Fullmetal Alchemist")
        #expect(manga.titleJapanese == "鋼の錬金術師")
        #expect(manga.synopsis == "Two brothers search for the Philosopher's Stone.")
        #expect(manga.score == 9.12)
        #expect(
            manga.coverURL
                == URL(string: "https://images.example.test/fullmetal-alchemist.jpg")
        )
    }

    @Test
    func missingRequiredFieldIsRejectedAsContractDrift() async throws {
        let (client, session) = try makeClient(host: "missing.catalog.test")
        defer { session.invalidateAndCancel() }

        await #expect(throws: CatalogAPIClientError.contractDrift) {
            try await client.fetch(CatalogPageRequest())
        }
    }

    @Test
    func unknownClosedVocabularyIsRejectedAsContractDrift() async throws {
        let (client, session) = try makeClient(host: "unknown-status.catalog.test")
        defer { session.invalidateAndCancel() }

        await #expect(throws: CatalogAPIClientError.contractDrift) {
            try await client.fetch(CatalogPageRequest())
        }
    }

    @Test
    func transportFailureMapsToUnavailableCatalogFailure() async throws {
        let (client, session) = try makeClient(host: "unavailable.catalog.test")
        defer { session.invalidateAndCancel() }

        await #expect(throws: CatalogAPIClientError.unavailable) {
            try await client.fetch(CatalogPageRequest())
        }
    }

    @Test
    func duplicateMangaIdentityRejectsTheWholePage() async throws {
        let (client, session) = try makeClient(host: "duplicate.catalog.test")
        defer { session.invalidateAndCancel() }

        await #expect(throws: CatalogAPIClientError.duplicateMangaID(42)) {
            try await client.fetch(CatalogPageRequest())
        }
    }

    @Test
    func invalidCoverStringMapsToUnavailableCover() async throws {
        let (client, session) = try makeClient(host: "invalid-cover.catalog.test")
        defer { session.invalidateAndCancel() }

        let page = try await client.fetch(CatalogPageRequest())
        let manga = try #require(page.items.first)

        #expect(manga.coverURL == nil)
    }

    @Test
    func embeddedCredentialsInCoverURLMapToUnavailableCover() async throws {
        let (client, session) = try makeClient(host: "credential-cover.catalog.test")
        defer { session.invalidateAndCancel() }

        let page = try await client.fetch(CatalogPageRequest())
        let manga = try #require(page.items.first)

        #expect(manga.coverURL == nil)
    }

    private func makeClient(host: String) throws -> (client: CatalogAPIClient, session: URLSession) {
        let baseURL = try #require(URL(string: "https://\(host)"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeterministicCatalogURLProtocol.self]
        let session = URLSession(configuration: configuration)

        return (
            CatalogAPIClient(
                httpClient: HTTPClient(session: session),
                configuration: try APIConfiguration(baseURL: baseURL)
            ),
            session
        )
    }
}

private final class DeterministicCatalogURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host()?.hasSuffix(".catalog.test") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let client, let url = request.url else {
            return
        }

        let expectedPage = url.host() == "page-two.catalog.test" ? 2 : 1
        let isExpectedRequest = request.httpMethod == "GET"
            && url.path() == "/list/mangas"
            && url.query() == "page=\(expectedPage)&per=20"
            && request.value(forHTTPHeaderField: "Authorization") == nil
            && request.value(forHTTPHeaderField: "App-Token") == nil

        let statusCode: Int
        if !isExpectedRequest {
            statusCode = 418
        } else if url.host() == "unavailable.catalog.test" {
            statusCode = 503
        } else {
            statusCode = 200
        }
        let body = isExpectedRequest ? fixture(for: url.host()) : Data()
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client.urlProtocol(self, didLoad: body)
        client.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func fixture(for host: String?) -> Data {
        let validItem = Self.mangaFixture(id: 42, includesTitle: true)

        switch host {
        case "valid.catalog.test":
            return Self.pageFixture(items: [validItem], total: 1)
        case "page-two.catalog.test":
            return Self.pageFixture(page: 2, items: [validItem], total: 40)
        case "metadata-mismatch.catalog.test":
            return Self.pageFixture(page: 2, items: [validItem], total: 1)
        case "missing.catalog.test":
            return Self.pageFixture(
                items: [Self.mangaFixture(id: 42, includesTitle: false)],
                total: 1
            )
        case "unknown-status.catalog.test":
            return Self.pageFixture(
                items: [
                    validItem.replacingOccurrences(
                        of: #""status": "finished""#,
                        with: #""status": "future_status""#
                    )
                ],
                total: 1
            )
        case "duplicate.catalog.test":
            return Self.pageFixture(items: [validItem, validItem], total: 2)
        case "invalid-cover.catalog.test":
            return Self.pageFixture(
                items: [
                    validItem.replacingOccurrences(
                        of: "https://images.example.test/fullmetal-alchemist.jpg",
                        with: "not a URL"
                    )
                ],
                total: 1
            )
        case "credential-cover.catalog.test":
            return Self.pageFixture(
                items: [
                    validItem.replacingOccurrences(
                        of: "https://images.example.test/fullmetal-alchemist.jpg",
                        with: "https://reader:secret@images.example.test/cover.jpg"
                    )
                ],
                total: 1
            )
        default:
            return Data()
        }
    }

    private static func pageFixture(
        page: Int64 = 1,
        items: [String],
        total: Int64
    ) -> Data {
        Data(
            #"{"items":[\#(items.joined(separator: ","))],"metadata":{"page":\#(page),"per":20,"total":\#(total)}}"#.utf8
        )
    }

    private static func mangaFixture(id: Int64, includesTitle: Bool) -> String {
        let title = includesTitle ? #", "title": "Fullmetal Alchemist""# : ""

        return #"""
        {
          "authors": [
            {
              "firstName": "Hiromu",
              "id": "19bcb3f8-f755-4dc9-b55b-fc86d206af1f",
              "lastName": "Arakawa",
              "role": "Story & Art"
            }
          ],
          "background": null,
          "chapters": 116,
          "demographics": [
            {
              "demographic": "Shounen",
              "id": "8f237731-f5de-4ca4-9ad8-721f0285026e"
            }
          ],
          "endDate": "2010-07-12T00:00:00Z",
          "genres": [
            {
              "genre": "Adventure",
              "id": "fb743fc5-288c-473a-89ee-73bc4c8a1e53"
            }
          ],
          "id": \#(id),
          "mainPicture": "https://images.example.test/fullmetal-alchemist.jpg",
          "score": 9.12,
          "startDate": "2001-07-12T00:00:00Z",
          "status": "finished",
          "sypnosis": "Two brothers search for the Philosopher's Stone.",
          "themes": [
            {
              "id": "3eca0fd4-c771-4e5e-bd7d-71f61ae2f47c",
              "theme": "Military"
            }
          ],
          "titleEnglish": "Fullmetal Alchemist",
          "titleJapanese": "鋼の錬金術師",
          "url": "https://example.test/manga/42",
          "volumes": 27\#(title)
        }
        """#
    }
}
