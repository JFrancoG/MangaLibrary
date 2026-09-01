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

    @Test("Login completes the exact Basic request and returns a refresh credential")
    func loginBuildsExactBasicRequest() async throws(any Error) {
        let recorder = SessionRecordedDataLoader(
            data: Data(
                #"{"token":"fixture-refresh","tokenType":"Bearer","expiresIn":2592000,"tokenUse":"refresh"}"#.utf8
            )
        )
        let client = try makeClient { request in
            await recorder.load(request)
        }

        let credential = try await client.login(email: "reader@example.invalid", password: "synthetic-passphrase")

        let requests = await recorder.requests()
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://session.example.test/users/session/login")
        #expect(
            request.value(forHTTPHeaderField: "Authorization")
                == "Basic cmVhZGVyQGV4YW1wbGUuaW52YWxpZDpzeW50aGV0aWMtcGFzc3BocmFzZQ=="
        )
        #expect(request.httpBody == nil)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(request.value(forHTTPHeaderField: "App-Token") == nil)
        #expect(credential.value == "fixture-refresh")
        #expect(credential.use == .refresh)
        #expect(credential.expiresAt == Self.now.addingTimeInterval(2_592_000))
    }

    @Test("Access exchange uses the refresh credential as Bearer")
    func accessExchangeBuildsExactBearerRequest() async throws(any Error) {
        let recorder = SessionRecordedDataLoader(
            data: Data(#"{"token":"fixture-access","tokenType":"Bearer","expiresIn":3600,"tokenUse":"access"}"#.utf8)
        )
        let client = try makeClient { request in
            await recorder.load(request)
        }

        let credential = try await client.exchangeAccess(refreshToken: "fixture-refresh")

        let requests = await recorder.requests()
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://session.example.test/users/session/access")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-refresh")
        #expect(request.httpBody == nil)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.value(forHTTPHeaderField: "App-Token") == nil)
        #expect(credential.value == "fixture-access")
        #expect(credential.use == .access)
        #expect(credential.expiresAt == Self.now.addingTimeInterval(3_600))
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

        let identity = try await client.fetchIdentity(accessToken: "fixture-access")

        let requests = await recorder.requests()
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://session.example.test/users/session/me")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-access")
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
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
            try await client.exchangeAccess(refreshToken: "fixture-refresh")
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

    private func makeClient(
        loadData: @escaping SessionAPIClient.DataLoader
    ) throws(any Error) -> SessionAPIClient {
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
    case unexpectedTokenUse
    case emptyToken
    case zeroLifetime

    var data: Data {
        let payload: String
        switch self {
        case .missingRequiredField:
            payload = #"{"token":"fixture-refresh","tokenType":"Bearer","expiresIn":2592000}"#
        case .unexpectedTokenType:
            payload = #"{"token":"fixture-refresh","tokenType":"Basic","expiresIn":2592000,"tokenUse":"refresh"}"#
        case .unexpectedTokenUse:
            payload = #"{"token":"fixture-refresh","tokenType":"Bearer","expiresIn":2592000,"tokenUse":"access"}"#
        case .emptyToken:
            payload = #"{"token":"","tokenType":"Bearer","expiresIn":2592000,"tokenUse":"refresh"}"#
        case .zeroLifetime:
            payload = #"{"token":"fixture-refresh","tokenType":"Bearer","expiresIn":0,"tokenUse":"refresh"}"#
        }

        return Data(payload.utf8)
    }

    var testDescription: String {
        switch self {
        case .missingRequiredField: "missing required field"
        case .unexpectedTokenType: "unexpected token type"
        case .unexpectedTokenUse: "unexpected token use"
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

    func requests() -> [URLRequest] {
        recordedRequests
    }
}
