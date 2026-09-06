import Foundation

/// Reads optional image input with a byte ceiling, independently of authenticated API traffic.
///
/// Composition supplies a session without credentials. The request does not handle cookies or add
/// authentication. Non-200, unavailable or oversized sources become placeholders; task cancellation
/// remains cancellation. The underlying transfer is cancelled whenever reading stops early.
struct ReadingCoverSource {
    let session: URLSession

    @concurrent
    func data(from url: URL) async throws -> Data? {
        try Task.checkCancellation()
        guard url.scheme?.lowercased() == "https", url.user == nil, url.password == nil else { return nil }
        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = false
        do {
            let (bytes, response) = try await session.bytes(for: request)
            defer { bytes.task.cancel() }
            try Task.checkCancellation()
            guard
                let response = response as? HTTPURLResponse,
                response.statusCode == 200,
                response.expectedContentLength <= ReadingCoverPreparation.maximumSourceByteCount
            else { return nil }
            return try await withTaskCancellationHandler {
                var data = Data()
                for try await byte in bytes {
                    try Task.checkCancellation()
                    guard data.count < ReadingCoverPreparation.maximumSourceByteCount else { return nil }
                    data.append(byte)
                }
                try Task.checkCancellation()
                return data
            } onCancel: {
                bytes.task.cancel()
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            return nil
        }
    }
}
