//
//  FixtureURLProtocol.swift
//  MangaLibraryTests
//

import Foundation

/// A deterministic, session-local transport used by HTTP client tests.
///
/// Each immutable endpoint represents one transport outcome. Tests install the
/// protocol on their own ephemeral session, so parallel execution never shares
/// a mutable handler or registers a process-wide protocol.
final class FixtureURLProtocol: URLProtocol {
    enum Endpoint {
        static let success = requiredURL("https://success.mangalibrary.invalid/data")
        static let nonHTTPResponse = requiredURL("https://non-http.mangalibrary.invalid/data")
        static let notFound = requiredURL("https://not-found.mangalibrary.invalid/data")
        static let transportFailure = requiredURL("https://transport.mangalibrary.invalid/data")
        static let cancellation = requiredURL("https://cancellation.mangalibrary.invalid/data")

        private static func requiredURL(_ value: String) -> URL {
            guard let url = URL(string: value) else {
                preconditionFailure("Invalid fixture URL: \(value)")
            }

            return url
        }
    }

    static let successBody = Data([0x00, 0x7F, 0x80, 0xFF])

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureURLProtocol.self]
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        route(for: request.url) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let route = Self.route(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        switch route {
        case .success:
            sendHTTPResponse(statusCode: 200, body: Self.successBody, url: url)
        case .nonHTTPResponse:
            let body = Data("non-http".utf8)
            let response = URLResponse(
                url: url,
                mimeType: "application/octet-stream",
                expectedContentLength: body.count,
                textEncodingName: nil
            )
            send(response: response, body: body)
        case .notFound:
            sendHTTPResponse(
                statusCode: 404,
                body: Data("body-must-not-reach-the-caller".utf8),
                url: url
            )
        case .transportFailure:
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.notConnectedToInternet)
            )
        case .cancellation:
            // Deliberately left pending until URLSession cancels the request.
            break
        }
    }

    override func stopLoading() {}

    private enum Route {
        case success
        case nonHTTPResponse
        case notFound
        case transportFailure
        case cancellation
    }

    private static func route(for url: URL?) -> Route? {
        guard let url else {
            return nil
        }

        switch url {
        case Endpoint.success:
            return .success
        case Endpoint.nonHTTPResponse:
            return .nonHTTPResponse
        case Endpoint.notFound:
            return .notFound
        case Endpoint.transportFailure:
            return .transportFailure
        case Endpoint.cancellation:
            return .cancellation
        default:
            return nil
        }
    }

    private func sendHTTPResponse(statusCode: Int, body: Data, url: URL) {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/octet-stream"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        send(response: response, body: body)
    }

    private func send(response: URLResponse, body: Data) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}
