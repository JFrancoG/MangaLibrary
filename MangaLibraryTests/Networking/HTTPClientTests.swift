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
