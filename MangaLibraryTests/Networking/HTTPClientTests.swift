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

    @Test(.timeLimit(.minutes(1)))
    func `Cancelling an in-flight request stops its transport and keeps the client usable`() async throws {
        let events = AsyncStream<ObservedCancellationURLProtocol.Event>.makeStream()
        let observation = ObservedCancellationURLProtocol.Observation(events: events.continuation)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ObservedCancellationURLProtocol.self, FixtureURLProtocol.self]
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration)
        let client = HTTPClient(session: session)
        let request = ObservedCancellationURLProtocol.makeRequest(observation: observation)
        let operation = Task {
            try await client.data(for: request)
        }
        defer {
            operation.cancel()
            session.invalidateAndCancel()
            events.continuation.finish()
        }
        var iterator = events.stream.makeAsyncIterator()

        try #require(await iterator.next() == .started)
        operation.cancel()
        try #require(await iterator.next() == .stopped)

        await #expect(throws: CancellationError.self) {
            try await operation.value
        }

        let subsequentRequest = URLRequest(url: FixtureURLProtocol.Endpoint.success)
        let subsequentData = try await client.data(for: subsequentRequest)

        #expect(subsequentData == FixtureURLProtocol.successBody)
    }
}

private final class ObservedCancellationURLProtocol: URLProtocol {
    enum Event: Equatable {
        case started
        case stopped
    }

    final class Observation: Sendable {
        let events: AsyncStream<Event>.Continuation

        init(events: AsyncStream<Event>.Continuation) {
            self.events = events
        }
    }

    private static let observationKey = "MangaLibrary.HTTPClientTests.cancellationObservation"

    private var observation: Observation? {
        Self.property(forKey: Self.observationKey, in: request) as? Observation
    }

    static func makeRequest(observation: Observation) -> URLRequest {
        let request = NSMutableURLRequest(url: FixtureURLProtocol.Endpoint.cancellation)
        setProperty(observation, forKey: observationKey, in: request)
        return request as URLRequest
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url == FixtureURLProtocol.Endpoint.cancellation
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        guard let request = task.currentRequest ?? task.originalRequest else { return false }

        return canInit(with: request)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        observation?.events.yield(.started)
    }

    override func stopLoading() {
        observation?.events.yield(.stopped)
        observation?.events.finish()
    }
}
