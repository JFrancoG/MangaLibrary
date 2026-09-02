//
//  CollectionRemotePipelineTests.swift
//  MangaLibraryTests
//

import Foundation
import SwiftData
import Testing
@testable import MangaLibrary

@Suite("Remote Collection pipeline", .tags(.integration))
struct CollectionRemotePipelineTests {
    @Test("The exact authenticated request imports a confirmed offline entry without creating outbox work")
    func exactRequestImportsFixtureIntoSwiftData() async throws(any Error) {
        let loader = ExactCollectionRequestLoader(fixture: Self.collectionFixture)
        let baseURL = try #require(URL(string: "https://collection.example.test/api"))
        let client = CollectionAPIClient(
            configuration: try APIConfiguration(baseURL: baseURL),
            loadData: { request in
                try await loader.load(request)
            }
        )
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let actor = CollectionMutationActor(modelContainer: container)

        let remoteEntries = try await client.fetch(accessToken: "fixture-access")
        let authority = SessionAuthority(userID: Self.userID, generation: UUID())
        let gate = SessionCommitGate(activeAuthority: authority)
        try await actor.importRemote(
            remoteEntries,
            authorization: gate.authorization(for: authority)
        )

        let context = ModelContext(container)
        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        let operations = try context.fetch(FetchDescriptor<CollectionOutboxOperation>())
        let entry = try #require(entries.first)
        let expectedState = CollectionSnapshot(
            ownedVolumes: [1, 3],
            readingVolume: nil,
            isComplete: false,
            knownTotalVolumes: 3,
            isTombstone: false
        )

        #expect(await loader.loadedRequestCount() == 1)
        #expect(entries.count == 1)
        #expect(entry.userID == Self.userID)
        #expect(entry.mangaID == 42)
        #expect(entry.state == expectedState)
        #expect(entry.confirmedState == expectedState)
        #expect(entry.mangaSnapshot?.title == "Remote Forty-Two")
        #expect(entry.mangaSnapshot?.coverURL == URL(string: "https://images.example.test/42.jpg"))
        #expect(operations.isEmpty)
    }

    private static let userID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    private static let collectionFixture = Data(
        #"""
        [
          {
            "id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            "manga": {
              "authors": [
                {
                  "id": "10000000-0000-0000-0000-000000000001",
                  "firstName": "Fixture",
                  "lastName": "Author",
                  "role": "Story & Art"
                }
              ],
              "demographics": [],
              "genres": [],
              "id": 42,
              "mainPicture": "https://images.example.test/42.jpg",
              "score": 8.75,
              "status": "currently_publishing",
              "sypnosis": "A fixture that crosses the complete remote import pipeline.",
              "themes": [],
              "title": "Remote Forty-Two",
              "titleEnglish": null,
              "titleJapanese": null,
              "volumes": 3
            },
            "completeCollection": false,
            "volumesOwned": [3, 1, 3],
            "readingVolume": null
          }
        ]
        """#.utf8
    )
}

@Suite("Collection API client", .tags(.integration))
struct CollectionAPIClientTests {
    private static let userID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    @Test("A repeated backend UUID rejects the complete snapshot")
    func duplicateRemoteIdentityIsContractDrift() async throws(any Error) {
        let remoteID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let client = try makeClient(
            data: Self.snapshot(
                Self.entry(remoteID: remoteID, mangaID: 42),
                Self.entry(remoteID: remoteID, mangaID: 84)
            )
        )

        await #expect(throws: CollectionAPIClientError.duplicateRemoteID(remoteID)) {
            try await client.fetch(accessToken: "fixture-access")
        }
    }

    @Test("A repeated manga identity rejects the complete snapshot")
    func duplicateMangaIdentityIsContractDrift() async throws(any Error) {
        let client = try makeClient(
            data: Self.snapshot(
                Self.entry(remoteID: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, mangaID: 42),
                Self.entry(remoteID: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, mangaID: 42)
            )
        )

        await #expect(throws: CollectionAPIClientError.duplicateMangaID(42)) {
            try await client.fetch(accessToken: "fixture-access")
        }
    }

    @Test("An unknown closed manga value maps to contract drift")
    func malformedNestedMangaIsContractDrift() async throws(any Error) {
        let client = try makeClient(
            data: Self.snapshot(
                Self.entry(
                    remoteID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
                    mangaID: 42,
                    status: "future_status"
                )
            )
        )

        await #expect(throws: CollectionAPIClientError.contractDrift) {
            try await client.fetch(accessToken: "fixture-access")
        }
    }

    @Test("A malformed backend UUID maps to contract drift")
    func malformedRemoteIdentityIsContractDrift() async throws(any Error) {
        let remoteID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let malformedEntry = Self.entry(remoteID: remoteID, mangaID: 42)
            .replacingOccurrences(of: remoteID.uuidString, with: "not-a-uuid")
        let client = try makeClient(data: Self.snapshot(malformedEntry))

        await #expect(throws: CollectionAPIClientError.contractDrift) {
            try await client.fetch(accessToken: "fixture-access")
        }
    }

    @Test("An omitted nullable reading volume decodes as no active volume")
    func omittedReadingVolumeDecodesAsNil() async throws(any Error) {
        let remoteID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let entryWithoutReadingVolume = Self.entry(
            remoteID: remoteID,
            mangaID: 42,
            includesReadingVolume: false
        )
        let client = try makeClient(data: Self.snapshot(entryWithoutReadingVolume))

        let entries = try await client.fetch(accessToken: "fixture-access")

        #expect(entryWithoutReadingVolume.contains("\"readingVolume\"") == false)
        #expect(entries.count == 1)
        #expect(entries.first?.readingVolume == nil)
    }

    @Test("A nonpositive reported total fails the DTO to SwiftData pipeline", arguments: [Int64(0), -1])
    func nonpositiveReportedTotalRejectsImport(_ reportedTotal: Int64) async throws(any Error) {
        let remoteID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let client = try makeClient(
            data: Self.snapshot(
                Self.entry(remoteID: remoteID, mangaID: 42, volumes: reportedTotal)
            )
        )
        let remoteEntries = try await client.fetch(accessToken: "fixture-access")
        let container = try MangaLibrarySchema.makeContainer(isStoredInMemoryOnly: true)
        let actor = CollectionMutationActor(modelContainer: container)
        let authority = SessionAuthority(userID: Self.userID, generation: UUID())
        let commitGate = SessionCommitGate(activeAuthority: authority)

        await #expect(throws: CollectionRemoteImportError.nonPositiveKnownTotal(reportedTotal)) {
            try await actor.importRemote(
                remoteEntries,
                authorization: commitGate.authorization(for: authority)
            )
        }

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<CollectionEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CollectionOutboxOperation>()) == 0)
    }

    @Test("An unexpected HTTP status retains its safe network category")
    func unexpectedStatusRemainsNetworkFailure() async throws(any Error) {
        let baseURL = try #require(URL(string: "https://collection.example.test"))
        let client = CollectionAPIClient(configuration: try APIConfiguration(baseURL: baseURL)) { _ in
            throw NetworkError.statusCode(201)
        }

        await #expect(throws: CollectionAPIClientError.network(.statusCode(201))) {
            try await client.fetch(accessToken: "fixture-access")
        }
    }

    private func makeClient(data: Data) throws(any Error) -> CollectionAPIClient {
        let baseURL = try #require(URL(string: "https://collection.example.test"))
        return CollectionAPIClient(configuration: try APIConfiguration(baseURL: baseURL)) { _ in data }
    }

    private static func snapshot(_ entries: String...) -> Data {
        Data("[\(entries.joined(separator: ","))]".utf8)
    }

    private static func entry(
        remoteID: UUID,
        mangaID: Manga.ID,
        status: String = "currently_publishing",
        volumes: Int64 = 3,
        includesReadingVolume: Bool = true
    ) -> String {
        let readingVolume = includesReadingVolume ? ",\n          \"readingVolume\": null" : ""
        return #"""
        {
          "id": "\#(remoteID.uuidString)",
          "manga": {
            "authors": [],
            "demographics": [],
            "genres": [],
            "id": \#(mangaID),
            "mainPicture": null,
            "score": 8,
            "status": "\#(status)",
            "sypnosis": null,
            "themes": [],
            "title": "Fixture",
            "titleEnglish": null,
            "titleJapanese": null,
            "volumes": \#(volumes)
          },
          "completeCollection": false,
          "volumesOwned": [1]\#(readingVolume)
        }
        """#
    }
}

private actor ExactCollectionRequestLoader {
    enum RequestContractError: Error {
        case mismatch
    }

    private let fixture: Data
    private var requestCount = 0

    init(fixture: Data) {
        self.fixture = fixture
    }

    func load(_ request: URLRequest) throws -> Data {
        guard
            let url = request.url,
            request.httpMethod == "GET",
            url.absoluteString == "https://collection.example.test/api/collection/manga",
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.query == nil,
            request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-access",
            request.value(forHTTPHeaderField: "App-Token") == nil,
            request.value(forHTTPHeaderField: "Content-Type") == nil,
            request.httpBody == nil
        else { throw RequestContractError.mismatch }

        requestCount += 1
        return fixture
    }

    func loadedRequestCount() -> Int {
        requestCount
    }
}
