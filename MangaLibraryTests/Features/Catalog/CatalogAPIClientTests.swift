//
//  CatalogAPIClientTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("Catalog API client", .tags(.fast))
struct CatalogAPIClientTests {
    @Test("A page request defaults to the first twenty items")
    func pageRequestDefaultsToFirstPage() throws {
        let request = try CatalogPageRequest()

        #expect(request.page == 1)
        #expect(request.per == 20)
    }

    @Test("A page request rejects an invalid page", arguments: [Int64(-1), 0])
    func pageRequestRejectsInvalidPage(_ page: Int64) {
        #expect(throws: CatalogPageRequest.ValidationError.invalidPage) {
            try CatalogPageRequest(page: page)
        }
    }

    @Test("A page request rejects an invalid page size", arguments: [Int64(0), 101])
    func pageRequestRejectsInvalidPageSize(_ per: Int64) {
        #expect(throws: CatalogPageRequest.ValidationError.invalidItemsPerPage) {
            try CatalogPageRequest(per: per)
        }
    }

    @Test("Fetch builds the exact public request", arguments: [Int64(1), 2])
    func fetchBuildsExactPublicRequest(page: Int64) async throws {
        let recorder = RecordedDataLoader(
            data: CatalogJSONFixtures.page(page: page, total: 40)
        )
        let client = try makeClient { request in
            await recorder.load(request)
        }

        _ = try await client.fetch(CatalogPageRequest(page: page))

        let request = try #require(await recorder.requests().first)
        let url = try #require(request.url)
        let components = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)
        )
        #expect(request.httpMethod == "GET")
        #expect(components.scheme == "https")
        #expect(components.host == "catalog.example.test")
        #expect(components.port == nil)
        #expect(components.path == "/list/mangas")
        #expect(
            components.queryItems == [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per", value: "20")
            ]
        )
        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "App-Token") == nil)
    }

    @Test("A contract-valid payload maps every product field and ignores remote additions")
    func validMinimalPayloadMapsCatalogValues() async throws {
        let client = try makeClient(returning: CatalogJSONFixtures.page())

        let page = try await client.fetch(CatalogPageRequest())
        let manga = try #require(page.items.first)

        #expect(page.items.count == 1)
        #expect(page.metadata == .init(page: 1, per: 20, total: 1))
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

    @Test("Incoherent metadata is contract drift", arguments: MetadataMismatch.allCases)
    func rejectsIncoherentMetadata(_ mismatch: MetadataMismatch) async throws {
        let metadata = mismatch.values
        let client = try makeClient(
            returning: CatalogJSONFixtures.page(
                page: metadata.page,
                per: metadata.per,
                total: metadata.total
            )
        )

        await #expect(throws: CatalogAPIClientError.contractDrift) {
            try await client.fetch(CatalogPageRequest())
        }
    }

    @Test("A missing product field is contract drift")
    func missingConsumedFieldIsContractDrift() async throws {
        let item = CatalogJSONFixtures.manga(includesTitle: false)
        let client = try makeClient(
            returning: CatalogJSONFixtures.page(items: [item])
        )

        await #expect(throws: CatalogAPIClientError.contractDrift) {
            try await client.fetch(CatalogPageRequest())
        }
    }

    @Test(
        "Network failures preserve their safe category",
        arguments: [
            NetworkError.invalidResponse,
            .statusCode(503),
            .transport(.timedOut)
        ]
    )
    func mapsNetworkFailure(_ error: NetworkError) async throws {
        let client = try makeClient { _ in
            throw error
        }

        await #expect(throws: CatalogAPIClientError.network(error)) {
            try await client.fetch(CatalogPageRequest())
        }
    }

    @Test("Cancellation crosses the typed client unchanged")
    func propagatesCancellation() async throws {
        let client = try makeClient { _ in
            throw CancellationError()
        }

        await #expect(throws: CancellationError.self) {
            try await client.fetch(CatalogPageRequest())
        }
    }

    @Test("A duplicate identity rejects the whole page")
    func rejectsDuplicateMangaIdentity() async throws {
        let item = CatalogJSONFixtures.manga()
        let client = try makeClient(
            returning: CatalogJSONFixtures.page(total: 2, items: [item, item])
        )

        await #expect(throws: CatalogAPIClientError.duplicateMangaID(42)) {
            try await client.fetch(CatalogPageRequest())
        }
    }

    @Test(
        "An unsafe cover is unavailable",
        arguments: [
            "not a URL",
            "https://reader:secret@images.example.test/cover.jpg",
            "ftp://images.example.test/cover.jpg"
        ]
    )
    func rejectsUnsafeCover(_ cover: String) async throws {
        let item = CatalogJSONFixtures.manga(cover: cover)
        let client = try makeClient(
            returning: CatalogJSONFixtures.page(items: [item])
        )

        let page = try await client.fetch(CatalogPageRequest())

        #expect(page.items.first?.coverURL == nil)
    }

    private func makeClient(returning data: Data) throws -> CatalogAPIClient {
        try makeClient { _ in data }
    }

    private func makeClient(
        loadData: @escaping CatalogAPIClient.DataLoader
    ) throws -> CatalogAPIClient {
        let baseURL = try #require(URL(string: "https://catalog.example.test"))

        return CatalogAPIClient(
            configuration: try APIConfiguration(baseURL: baseURL),
            loadData: loadData
        )
    }
}

private actor RecordedDataLoader {
    private let data: Data
    private var recordedRequests: [URLRequest] = []

    init(data: Data) {
        self.data = data
    }

    func load(_ request: URLRequest) -> Data {
        recordedRequests.append(request)
        return data
    }

    func requests() -> [URLRequest] {
        recordedRequests
    }
}

enum MetadataMismatch: CaseIterable, CustomTestStringConvertible {
    case page
    case per
    case total

    var testDescription: String {
        switch self {
        case .page: "page"
        case .per: "per"
        case .total: "total"
        }
    }

    var values: (page: Int64, per: Int64, total: Int64) {
        switch self {
        case .page: (page: 2, per: 20, total: 1)
        case .per: (page: 1, per: 10, total: 1)
        case .total: (page: 1, per: 20, total: 0)
        }
    }
}
