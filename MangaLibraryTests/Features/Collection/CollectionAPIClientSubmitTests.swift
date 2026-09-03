//
//  CollectionAPIClientSubmitTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("Collection POST transport", .tags(.integration))
struct CollectionAPIClientSubmitTests {
    @Test("Submit sends the exact authenticated JSON request and accepts an opaque Int64 response")
    func submitBuildsExactRequest() async throws(any Error) {
        let recorder = CollectionSubmitRequestRecorder(data: Data("9223372036854775807".utf8))
        let client = try makeClient { request in
            await recorder.load(request)
        }

        let response = try await client.submit(
            mangaID: 4_294_967_296,
            ownedVolumes: [1, 3],
            readingVolume: 2,
            isComplete: false,
            accessToken: "fixture-access"
        )

        let requests = await recorder.requests()
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let payload = try payload(from: request)

        #expect(request.httpMethod == "POST")
        #expect(components.scheme == "https")
        #expect(components.host == "collection.example.test")
        #expect(components.port == nil)
        #expect(components.path == "/api/collection/manga")
        #expect(components.query == nil)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-access")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "App-Token") == nil)
        #expect(payload.keys == ["manga", "completeCollection", "volumesOwned", "readingVolume"])
        #expect(payload.manga == 4_294_967_296)
        #expect(payload.completeCollection == false)
        #expect(payload.volumesOwned == [1, 3])
        #expect(payload.readingVolume == 2)
        #expect(response == Int64.max)
    }

    @Test("Submit encodes an absent reading volume as explicit JSON null")
    func submitEncodesNilReadingVolumeAsNull() async throws(any Error) {
        let recorder = CollectionSubmitRequestRecorder(data: Data("42".utf8))
        let client = try makeClient { request in
            await recorder.load(request)
        }

        _ = try await client.submit(
            mangaID: 42,
            ownedVolumes: [],
            readingVolume: nil,
            isComplete: true,
            accessToken: "fixture-access"
        )

        let request = try #require(await recorder.requests().first)
        let body = try payload(from: request)
        #expect(body.hasReadingVolumeKey)
        #expect(body.readingVolume == nil)
    }

    @Test("An empty access token fails before transport")
    func emptyAccessTokenDoesNotLoadData() async throws(any Error) {
        let recorder = CollectionSubmitRequestRecorder(data: Data("42".utf8))
        let client = try makeClient { request in
            await recorder.load(request)
        }

        await #expect(throws: CollectionAPIClientError.unavailable) {
            _ = try await client.submit(
                mangaID: 42,
                ownedVolumes: [1],
                readingVolume: nil,
                isComplete: false,
                accessToken: ""
            )
        }

        #expect(await recorder.requests().isEmpty)
    }

    @Test("A malformed successful response is contract drift")
    func malformedSuccessBodyIsContractDrift() async throws(any Error) {
        let client = try makeClient(returning: Data(#"{"id":42}"#.utf8))

        await #expect(throws: CollectionAPIClientError.contractDrift) {
            _ = try await client.submit(
                mangaID: 42,
                ownedVolumes: [1],
                readingVolume: nil,
                isComplete: false,
                accessToken: "fixture-access"
            )
        }
    }

    @Test("An unexpected HTTP status retains its safe network category")
    func unexpectedStatusRemainsNetworkFailure() async throws(any Error) {
        let client = try makeClient { _ in
            throw NetworkError.statusCode(409)
        }

        await #expect(throws: CollectionAPIClientError.network(.statusCode(409))) {
            _ = try await client.submit(
                mangaID: 42,
                ownedVolumes: [1],
                readingVolume: nil,
                isComplete: false,
                accessToken: "fixture-access"
            )
        }
    }

    @Test("Cancellation crosses the POST client unchanged")
    func cancellationPropagates() async throws(any Error) {
        let client = try makeClient { _ in
            throw CancellationError()
        }

        await #expect(throws: CancellationError.self) {
            _ = try await client.submit(
                mangaID: 42,
                ownedVolumes: [1],
                readingVolume: nil,
                isComplete: false,
                accessToken: "fixture-access"
            )
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

    private func payload(from request: URLRequest) throws(any Error) -> CollectionSubmitPayload {
        let data = try #require(request.httpBody)
        return try JSONDecoder().decode(CollectionSubmitPayload.self, from: data)
    }
}

private struct CollectionSubmitPayload: Decodable {
    let keys: Set<String>
    let manga: Int64
    let completeCollection: Bool
    let volumesOwned: [Int64]
    let readingVolume: Int64?
    let hasReadingVolumeKey: Bool

    private enum CodingKeys: String, CodingKey {
        case manga
        case completeCollection
        case volumesOwned
        case readingVolume
    }
}

private extension CollectionSubmitPayload {
    init(from decoder: any Decoder) throws {
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        keys = Set(dynamicContainer.allKeys.map(\.stringValue))

        let container = try decoder.container(keyedBy: CodingKeys.self)
        manga = try container.decode(Int64.self, forKey: .manga)
        completeCollection = try container.decode(Bool.self, forKey: .completeCollection)
        volumesOwned = try container.decode([Int64].self, forKey: .volumesOwned)
        readingVolume = try container.decodeIfPresent(Int64.self, forKey: .readingVolume)
        hasReadingVolumeKey = container.contains(.readingVolume)
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
}

private extension DynamicCodingKey {
    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private actor CollectionSubmitRequestRecorder {
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
