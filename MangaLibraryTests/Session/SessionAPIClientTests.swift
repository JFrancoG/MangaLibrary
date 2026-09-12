//
//  SessionAPIClientTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("Session API client", .tags(.fast))
struct SessionAPIClientTests {
    private static let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("JWT login completes the exact Basic request and returns one session credential")
    func loginBuildsExactBasicRequest() async throws(any Error) {
        let recorder = SessionRecordedDataLoader(
            data: Data(#"{"token":"fixture-jwt","tokenType":"Bearer","expiresIn":86400}"#.utf8)
        )
        let client = try makeClient { request in
            await recorder.load(request)
        }

        let credential = try await client.login(email: "reader@example.invalid", password: "synthetic-passphrase")

        let requests = await recorder.requests()
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://session.example.test/users/jwt/login")
        #expect(
            request.value(forHTTPHeaderField: "Authorization")
                == "Basic cmVhZGVyQGV4YW1wbGUuaW52YWxpZDpzeW50aGV0aWMtcGFzc3BocmFzZQ=="
        )
        #expect(request.httpBody == nil)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(request.value(forHTTPHeaderField: "App-Token") == nil)
        #expect(credential.value == "fixture-jwt")
        #expect(credential.expiresAt == Self.now.addingTimeInterval(86_400))
    }

    @Test("JWT refresh uses the current session credential as Bearer")
    func jwtRefreshBuildsExactBearerRequest() async throws(any Error) {
        let recorder = SessionRecordedDataLoader(
            data: Data(#"{"token":"fixture-renewed-jwt","tokenType":"Bearer","expiresIn":86400}"#.utf8)
        )
        let client = try makeClient { request in
            await recorder.load(request)
        }

        let credential = try await client.refresh(token: "fixture-jwt")

        let requests = await recorder.requests()
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://session.example.test/users/jwt/refresh")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-jwt")
        #expect(request.httpBody == nil)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(request.value(forHTTPHeaderField: "App-Token") == nil)
        #expect(credential.value == "fixture-renewed-jwt")
        #expect(credential.expiresAt == Self.now.addingTimeInterval(86_400))
    }

    @Test("Current-user lookup maps the required remote identity")
    func currentUserBuildsExactBearerRequest() async throws(any Error) {
        let recorder = SessionRecordedDataLoader(
            data: Data(
                #"""
                {
                  "email": "reader@example.invalid",
                  "id": "11111111-2222-3333-4444-555555555555",
                  "isActive": true,
                  "isAdmin": false,
                  "role": "user"
                }
                """#.utf8
            )
        )
        let client = try makeClient { request in
            await recorder.load(request)
        }

        let identity = try await client.fetchIdentity(accessToken: "fixture-jwt")

        let requests = await recorder.requests()
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://session.example.test/users/jwt/me")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-jwt")
        #expect(request.httpBody == nil)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(request.value(forHTTPHeaderField: "App-Token") == nil)
        #expect(identity.id == UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        #expect(identity.email == "reader@example.invalid")
        #expect(identity.isActive)
        #expect(identity.isAdmin == false)
        #expect(identity.role == "user")
    }

    @Test("Invalid token responses are contract drift", arguments: InvalidSessionTokenResponse.allCases)
    func invalidTokenResponseIsContractDrift(_ response: InvalidSessionTokenResponse) async throws(any Error) {
        let client = try makeClient(returning: response.data)

        await #expect(throws: SessionAPIClientError.contractDrift) {
            try await client.login(email: "reader@example.invalid", password: "synthetic-passphrase")
        }
    }

    @Test("An invalid stable identity is contract drift")
    func invalidIdentityIsContractDrift() async throws(any Error) {
        let client = try makeClient(
            returning: Data(
                #"""
                {
                  "email": "reader@example.invalid",
                  "id": "not-a-uuid",
                  "isActive": true,
                  "isAdmin": false,
                  "role": "user"
                }
                """#.utf8
            )
        )

        await #expect(throws: SessionAPIClientError.contractDrift) {
            try await client.fetchIdentity(accessToken: "fixture-access")
        }
    }

    @Test(
        "Network failures preserve their safe category",
        arguments: [
            NetworkError.statusCode(401),
            .statusCode(503),
            .transport(.notConnectedToInternet)
        ]
    )
    func networkFailurePreservesSafeCategory(_ error: NetworkError) async throws(any Error) {
        let client = try makeClient { _ in
            throw error
        }

        await #expect(throws: SessionAPIClientError.network(error)) {
            try await client.refresh(token: "fixture-jwt")
        }
    }

    @Test("Cancellation crosses the typed client unchanged")
    func cancellationPropagates() async throws(any Error) {
        let client = try makeClient { _ in
            throw CancellationError()
        }

        await #expect(throws: CancellationError.self) {
            try await client.fetchIdentity(accessToken: "fixture-access")
        }
    }

    private func makeClient(returning data: Data) throws(any Error) -> SessionAPIClient {
        try makeClient { _ in data }
    }

    private func makeClient(loadData: @escaping SessionAPIClient.DataLoader) throws(any Error) -> SessionAPIClient {
        let baseURL = try #require(URL(string: "https://session.example.test"))

        return SessionAPIClient(
            configuration: try APIConfiguration(baseURL: baseURL),
            loadData: loadData,
            now: { Self.now }
        )
    }
}

enum InvalidSessionTokenResponse: CaseIterable, CustomTestStringConvertible {
    case missingRequiredField
    case unexpectedTokenType
    case emptyToken
    case zeroLifetime

    var data: Data {
        let payload: String
        switch self {
        case .missingRequiredField:
            payload = #"{"token":"fixture-jwt","tokenType":"Bearer"}"#
        case .unexpectedTokenType:
            payload = #"{"token":"fixture-jwt","tokenType":"Basic","expiresIn":86400}"#
        case .emptyToken:
            payload = #"{"token":"","tokenType":"Bearer","expiresIn":86400}"#
        case .zeroLifetime:
            payload = #"{"token":"fixture-jwt","tokenType":"Bearer","expiresIn":0}"#
        }

        return Data(payload.utf8)
    }

    var testDescription: String {
        switch self {
        case .missingRequiredField: "missing required field"
        case .unexpectedTokenType: "unexpected token type"
        case .emptyToken: "empty token"
        case .zeroLifetime: "zero lifetime"
        }
    }
}

private actor SessionRecordedDataLoader {
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
