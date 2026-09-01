//
//  HTTPClientTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("HTTP client", .tags(.integration))
struct HTTPClientTests {
    @Test("Returns the exact response bytes for the expected status")
    func returnsExactResponseBytes() async throws {
        let session = FixtureURLProtocol.makeSession()
        defer { session.invalidateAndCancel() }
        let client = HTTPClient(session: session)
        let request = URLRequest(url: FixtureURLProtocol.Endpoint.success)

        let data = try await client.data(for: request)

        #expect(data == FixtureURLProtocol.successBody)
    }

    @Test("Registration accepts the declared 200 integer through the live adapter")
    func registrationAcceptsDeclaredOKInteger() async throws {
        let session = FixtureURLProtocol.makeSession()
        defer { session.invalidateAndCancel() }
        let client = HTTPClient(session: session)
        let configuration = try APIConfiguration(baseURL: FixtureURLProtocol.Endpoint.registrationOKBase)
        let register = UserRegistrationClient.operation(
            httpClient: client,
            configuration: configuration,
            appToken: "synthetic-app-token"
        )

        let submission = await register("reader@example.invalid", "synthetic-passphrase")

        #expect(submission == .confirmed)
    }

    @Test("Registration accepts the observed 201 Created without requiring a body")
    func registrationAcceptsCreatedWithoutBody() async throws {
        let session = FixtureURLProtocol.makeSession()
        defer { session.invalidateAndCancel() }
        let client = HTTPClient(session: session)
        let configuration = try APIConfiguration(baseURL: FixtureURLProtocol.Endpoint.registrationCreatedBase)
        let register = UserRegistrationClient.operation(
            httpClient: client,
            configuration: configuration,
            appToken: "synthetic-app-token"
        )

        let submission = await register("reader@example.invalid", "synthetic-passphrase")

        #expect(submission == .confirmed)
    }

    @Test("Registration does not generalize success to an undeclared 202")
    func registrationRejectsAcceptedStatus() async throws {
        let session = FixtureURLProtocol.makeSession()
        defer { session.invalidateAndCancel() }
        let client = HTTPClient(session: session)
        let configuration = try APIConfiguration(baseURL: FixtureURLProtocol.Endpoint.registrationAcceptedBase)
        let register = UserRegistrationClient.operation(
            httpClient: client,
            configuration: configuration,
            appToken: "synthetic-app-token"
        )

        let submission = await register("reader@example.invalid", "synthetic-passphrase")

        #expect(submission == .unconfirmed(.network(.statusCode(202))))
    }

    @Test("Rejects a non-HTTP response")
    func rejectsNonHTTPResponse() async {
        let session = FixtureURLProtocol.makeSession()
        defer { session.invalidateAndCancel() }
        let client = HTTPClient(session: session)
        let request = URLRequest(url: FixtureURLProtocol.Endpoint.nonHTTPResponse)

        await #expect(throws: NetworkError.invalidResponse) {
            try await client.data(for: request)
        }
    }

    @Test("Rejects an unexpected status before exposing its body")
    func rejectsUnexpectedStatusCode() async {
        let session = FixtureURLProtocol.makeSession()
        defer { session.invalidateAndCancel() }
        let client = HTTPClient(session: session)
        let request = URLRequest(url: FixtureURLProtocol.Endpoint.notFound)

        await #expect(throws: NetworkError.statusCode(404)) {
            try await client.data(for: request)
        }
    }

    @Test("Maps transport failures to a safe error code")
    func mapsTransportFailure() async {
        let session = FixtureURLProtocol.makeSession()
        defer { session.invalidateAndCancel() }
        let client = HTTPClient(session: session)
        let request = URLRequest(url: FixtureURLProtocol.Endpoint.transportFailure)

        await #expect(throws: NetworkError.transport(.notConnectedToInternet)) {
            try await client.data(for: request)
        }
    }

    @Test("Propagates task cancellation as CancellationError")
    func propagatesCancellation() async {
        let session = FixtureURLProtocol.makeSession()
        defer { session.invalidateAndCancel() }
        let client = HTTPClient(session: session)
        let request = URLRequest(url: FixtureURLProtocol.Endpoint.cancellation)
        let operation = Task {
            try await client.data(for: request)
        }

        operation.cancel()

        await #expect(throws: CancellationError.self) {
            try await operation.value
        }
    }
}
