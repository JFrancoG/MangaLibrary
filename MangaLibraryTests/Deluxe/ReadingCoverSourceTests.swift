import Foundation
import Testing
@testable import MangaLibrary

@Suite("Bounded cover input", .tags(.integration))
struct ReadingCoverSourceTests {
    @Test
    func `returns complete image input without changing its bytes`() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let data = try await ReadingCoverSource(session: session).data(from: url("valid"))

        #expect(data == Data([0, 127, 128, 255]))
    }

    @Test(arguments: ["overstated", "overflow", "404", "206", "nonhttp", "transport"])
    func `unusable input resolves to a placeholder`(route: String) async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let data = try await ReadingCoverSource(session: session).data(from: url(route))

        #expect(data == nil)
    }

    @Test
    func `accepts the inclusive source byte limit`() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let data = try #require(try await ReadingCoverSource(session: session).data(from: url("limit")))

        #expect(data.count == 8_388_608)
        #expect(data.first == 97)
        #expect(data.last == 97)
    }

    @Test(arguments: ["http://covers.example.invalid/valid", "https://user:password@covers.example.invalid/valid"])
    func `rejects insecure or credential bearing source URLs`(address: String) async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let sourceURL = try #require(URL(string: address))

        let data = try await ReadingCoverSource(session: session).data(from: sourceURL)

        #expect(data == nil)
    }

    @Test
    func `cancellation does not become a successful placeholder`() async {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        await #expect(throws: CancellationError.self) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.cancelAll()
                group.addTask {
                    _ = try await ReadingCoverSource(session: session).data(from: url("pending"))
                }
                try await group.waitForAll()
            }
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CoverInputURLProtocol.self]
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        return URLSession(configuration: configuration)
    }

    private func url(_ route: String) throws -> URL {
        try #require(URL(string: "https://covers.example.invalid/\(route)"))
    }
}

private final class CoverInputURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        switch url.lastPathComponent {
        case "transport":
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        case "pending":
            return
        case "nonhttp":
            let response = URLResponse(
                url: url,
                mimeType: "image/jpeg",
                expectedContentLength: 4,
                textEncodingName: nil
            )
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        default:
            var headers = ["Content-Type": "image/jpeg"]
            if url.lastPathComponent == "overstated" {
                headers["Content-Length"] = "8388609"
            }
            let status = Int(url.lastPathComponent) ?? 200
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            ) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if ["limit", "overflow"].contains(url.lastPathComponent) {
            let chunk = Data(repeating: 97, count: 65_536)
            for _ in 0..<128 {
                client?.urlProtocol(self, didLoad: chunk)
            }
            if url.lastPathComponent == "overflow" {
                client?.urlProtocol(self, didLoad: Data([97]))
            }
        } else {
            client?.urlProtocol(self, didLoad: Data([0, 127, 128, 255]))
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
