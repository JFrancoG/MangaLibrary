//
//  CollectionAPIClientIndividualTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("Collection individual transport", .tags(.integration))
struct CollectionAPIClientIndividualTests {
    @Test("Individual GET sends the decimal Manga ID and decodes only that entry")
    func individualGetBuildsExactRequest() async throws(any Error) {
        let recorder = CollectionIndividualRequestRecorder(data: Self.entry(mangaID: 4_294_967_296))
        let client = try makeClient { request in
            await recorder.load(request)
        }

        let entry = try #require(try await client.fetch(mangaID: 4_294_967_296, accessToken: "fixture-access"))

        let request = try #require(await recorder.requests().first)
        let components = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
        #expect(request.httpMethod == "GET")
        #expect(components.path == "/api/collection/manga/4294967296")
        #expect(components.query == nil)
        #expect(request.httpBody == nil)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-access")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(request.value(forHTTPHeaderField: "App-Token") == nil)
        #expect(entry.manga.id == 4_294_967_296)
        #expect(entry.remoteID == Self.remoteID)
        #expect(entry.ownedVolumes == [1, 3])
        #expect(entry.readingVolume == 2)
        #expect(entry.isComplete == false)
    }

    @Test("The documented individual GET 404 is represented as remote absence")
    func individualGetNotFoundIsAbsence() async throws(any Error) {
        let client = try makeClient { _ in
            HTTPResponse(data: Data("not interpreted".utf8), statusCode: 404)
        }

        let entry = try await client.fetch(mangaID: 42, accessToken: "fixture-access")

        #expect(entry == nil)
    }

    @Test("Production transport admits only the documented individual 404 as absence")
    func productionAdapterAcceptsIndividualNotFound() async throws(any Error) {
        let session = FixtureURLProtocol.makeSession()
        defer { session.invalidateAndCancel() }
        let configuration = try APIConfiguration(baseURL: FixtureURLProtocol.Endpoint.collectionNotFoundBase)
        let client = CollectionAPIClient(httpClient: HTTPClient(session: session), configuration: configuration)

        let entry = try await client.fetch(mangaID: 42, accessToken: "fixture-access")

        #expect(entry == nil)
    }

    @Test("Individual GET rejects a response for a different Manga ID")
    func individualGetRequiresRequestedIdentity() async throws(any Error) {
        let client = try makeClient(returning: Self.entry(mangaID: 84))

        await #expect(throws: CollectionAPIClientError.contractDrift) {
            _ = try await client.fetch(mangaID: 42, accessToken: "fixture-access")
        }
    }

    @Test("A malformed individual GET success body is contract drift")
    func malformedIndividualGetSuccessBodyIsContractDrift() async throws(any Error) {
        let client = try makeClient(loadResponse: { _ in
            HTTPResponse(data: Data(#"{"id":42}"#.utf8), statusCode: 200)
        })

        await #expect(throws: CollectionAPIClientError.contractDrift) {
            _ = try await client.fetch(mangaID: 42, accessToken: "fixture-access")
        }
    }

    @Test("Individual GET preserves task cancellation")
    func individualGetPropagatesCancellation() async throws(any Error) {
        let client = try makeClient(
            loadResponse: { _ in
                throw CancellationError()
            }
        )

        await #expect(throws: CancellationError.self) {
            _ = try await client.fetch(mangaID: 42, accessToken: "fixture-access")
        }
    }

    @Test("An undocumented individual GET status retains its safe network category")
    func individualGetUnexpectedStatusRemainsNetworkFailure() async throws(any Error) {
        let client = try makeClient(loadData: { _ in
            throw NetworkError.statusCode(409)
        })

        await #expect(throws: CollectionAPIClientError.network(.statusCode(409))) {
            _ = try await client.fetch(mangaID: 42, accessToken: "fixture-access")
        }
    }

    @Test("DELETE sends the decimal Manga ID without a body and accepts an opaque Int64")
    func deleteBuildsExactRequest() async throws(any Error) {
        let recorder = CollectionIndividualRequestRecorder(data: Data("9223372036854775807".utf8))
        let client = try makeClient { request in
            await recorder.load(request)
        }

        let response = try await client.remove(mangaID: 4_294_967_296, accessToken: "fixture-access")

        let request = try #require(await recorder.requests().first)
        let components = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
        #expect(request.httpMethod == "DELETE")
        #expect(components.path == "/api/collection/manga/4294967296")
        #expect(components.query == nil)
        #expect(request.httpBody == nil)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-access")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(request.value(forHTTPHeaderField: "App-Token") == nil)
        #expect(response == Int64.max)
    }

    @Test("DELETE keeps 404 as an uncertain transport result for later GET reconciliation")
    func deleteNotFoundRequiresReconciliation() async throws(any Error) {
        let client = try makeClient(loadData: { _ in
            throw NetworkError.statusCode(404)
        })

        await #expect(throws: CollectionAPIClientError.network(.statusCode(404))) {
            _ = try await client.remove(mangaID: 42, accessToken: "fixture-access")
        }
    }

    @Test("A malformed DELETE success body is contract drift")
    func malformedDeleteSuccessBodyIsContractDrift() async throws(any Error) {
        let client = try makeClient(returning: Data(#"{"id":42}"#.utf8))

        await #expect(throws: CollectionAPIClientError.contractDrift) {
            _ = try await client.remove(mangaID: 42, accessToken: "fixture-access")
        }
    }

    @Test("DELETE preserves task cancellation")
    func deletePropagatesCancellation() async throws(any Error) {
        let client = try makeClient(
            loadData: { _ in
                throw CancellationError()
            }
        )

        await #expect(throws: CancellationError.self) {
            _ = try await client.remove(mangaID: 42, accessToken: "fixture-access")
        }
    }

    private func makeClient(returning data: Data) throws(any Error) -> CollectionAPIClient {
        try makeClient { _ in data }
    }

    private func makeClient(
        loadData: @escaping CollectionAPIClient.DataLoader
    ) throws(any Error) -> CollectionAPIClient {
        let baseURL = try #require(URL(string: "https://collection.example.test/api"))
        return CollectionAPIClient(configuration: try APIConfiguration(baseURL: baseURL), loadData: loadData)
    }

    private func makeClient(
        loadResponse: @escaping CollectionAPIClient.ResponseLoader
    ) throws(any Error) -> CollectionAPIClient {
        let baseURL = try #require(URL(string: "https://collection.example.test/api"))
        return CollectionAPIClient(
            configuration: try APIConfiguration(baseURL: baseURL),
            loadData: { _ in
                throw CollectionAPIClientError.unavailable
            },
            loadResponse: loadResponse
        )
    }

    private static func entry(mangaID: Manga.ID) -> Data {
        Data(
            #"""
            {
              "id": "\#(remoteID.uuidString)",
              "manga": {
                "authors": [],
                "demographics": [],
                "genres": [],
                "id": \#(mangaID),
                "mainPicture": null,
                "score": 8,
                "status": "currently_publishing",
                "sypnosis": null,
                "themes": [],
                "title": "Fixture",
                "titleEnglish": null,
                "titleJapanese": null,
                "volumes": 3
              },
              "completeCollection": false,
              "volumesOwned": [1, 3],
              "readingVolume": 2
            }
            """#.utf8
        )
    }

    private static let remoteID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
}

private actor CollectionIndividualRequestRecorder {
    private let data: Data
    private var recordedRequests: [URLRequest] = []

    init(data: Data) {
        self.data = data
    }

    func load(_ request: URLRequest) -> Data {
        recordedRequests.append(request)
        return data
    }

    func requests() -> [URLRequest] { recordedRequests }
}
