//
//  HTTPClient.swift
//  MangaLibrary
//

import Foundation

/// An immutable, app-scoped boundary around an injected `URLSession`.
///
/// The client performs transport and HTTP validation only. Decoding, retries,
/// authentication and presentation mapping belong to higher-level owners.
struct HTTPClient {
    private let sessionValue: URLSession

    /// Loads one request and returns its bytes only after validating HTTP status.
    ///
    /// Cancellation is propagated as `CancellationError`. A URL loading
    /// cancellation becomes `CancellationError` only when the calling task is
    /// cancelled; otherwise it remains the safe `.transport(.cancelled)` error.
    ///
    /// - Parameters:
    ///   - request: The fully composed request to load.
    ///   - statusCode: The single HTTP status accepted by the caller.
    /// - Returns: The response bytes without decoding them.
    /// - Throws: `CancellationError`, ``NetworkError``, or
    ///   `.transport(.unknown)` when URL loading produces a non-URL error.
    @concurrent
    func data(for request: URLRequest, expecting statusCode: Int = 200) async throws -> Data {
        let result: (data: Data, response: URLResponse)

        do {
            result = try await sessionValue.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            if error.code == .cancelled, Task.isCancelled {
                throw CancellationError()
            }

            throw NetworkError.transport(error.code)
        } catch {
            throw NetworkError.transport(.unknown)
        }

        try Task.checkCancellation()

        guard let response = result.response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard response.statusCode == statusCode else {
            throw NetworkError.statusCode(response.statusCode)
        }

        return result.data
    }
}

extension HTTPClient {
    init(session: URLSession) {
        sessionValue = session
    }
}
