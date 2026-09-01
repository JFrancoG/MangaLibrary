//
//  SessionAPIClient.swift
//  MangaLibrary
//

import Foundation

enum SessionAPIClientError: Error, Equatable {
    case unavailable
    case network(NetworkError)
    case contractDrift
}

struct SessionAPIClient {
    typealias DataLoader = @Sendable (URLRequest) async throws(any Error) -> Data
    typealias Clock = @Sendable () -> Date

    let configuration: APIConfiguration
    let loadData: DataLoader
    let now: Clock

    /// Authenticates Basic credentials and returns only a validated refresh credential.
    ///
    /// The password exists only for this suspended operation. It is never
    /// retained by the client or included in any error.
    @concurrent
    func login(email: String, password: String) async throws(any Error) -> SessionCredential {
        let basicValue = Data("\(email):\(password)".utf8).base64EncodedString()
        let request = request(path: "users/session/login", method: "POST", authorization: "Basic \(basicValue)")

        return try await fetchCredential(request: request, expectedUse: .refresh)
    }

    /// Exchanges the current refresh credential for a validated access credential.
    @concurrent
    func exchangeAccess(refreshToken: String) async throws(any Error) -> SessionCredential {
        let request = request(path: "users/session/access", method: "GET", authorization: "Bearer \(refreshToken)")

        return try await fetchCredential(request: request, expectedUse: .access)
    }

    /// Resolves the stable account identity authorized by an access credential.
    @concurrent
    func fetchIdentity(accessToken: String) async throws(any Error) -> SessionIdentity {
        let request = request(path: "users/session/me", method: "GET", authorization: "Bearer \(accessToken)")
        let data = try await data(for: request)

        do {
            let response = try JSONDecoder().decode(UserResponseDTO.self, from: data)
            return SessionIdentity(
                id: response.id,
                email: response.email,
                isActive: response.isActive,
                isAdmin: response.isAdmin,
                role: response.role
            )
        } catch {
            throw SessionAPIClientError.contractDrift
        }
    }

    @concurrent
    private func fetchCredential(
        request: URLRequest,
        expectedUse: SessionCredentialUse
    ) async throws(any Error) -> SessionCredential {
        let data = try await data(for: request)

        do {
            let response = try JSONDecoder().decode(DualSessionTokenResponseDTO.self, from: data)
            guard
                response.token.isEmpty == false,
                response.tokenType == "Bearer",
                response.tokenUse == expectedUse.rawValue,
                response.expiresIn > 0
            else {
                throw SessionAPIClientError.contractDrift
            }

            let issuedAt = now()
            let expiresAt = issuedAt.addingTimeInterval(TimeInterval(response.expiresIn))
            guard expiresAt > issuedAt else { throw SessionAPIClientError.contractDrift }

            return SessionCredential(value: response.token, use: expectedUse, expiresAt: expiresAt)
        } catch let error as SessionAPIClientError {
            throw error
        } catch {
            throw SessionAPIClientError.contractDrift
        }
    }

    @concurrent
    private func data(for request: URLRequest) async throws(any Error) -> Data {
        do {
            return try await loadData(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as NetworkError {
            throw SessionAPIClientError.network(error)
        } catch {
            throw SessionAPIClientError.unavailable
        }
    }

    private func request(path: String, method: String, authorization: String) -> URLRequest {
        var request = URLRequest(
            url: configuration.baseURL.appending(path: path),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.httpMethod = method
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        return request
    }
}

extension SessionAPIClient {
    /// Adapts the shared production transport without exposing it to previews or feature tests.
    init(
        httpClient: HTTPClient,
        configuration: APIConfiguration,
        now: @escaping Clock
    ) {
        self.init(
            configuration: configuration,
            loadData: { request in
                try await httpClient.data(for: request)
            },
            now: now
        )
    }
}

private struct DualSessionTokenResponseDTO: Decodable {
    let token: String
    let tokenType: String
    let expiresIn: Int64
    let tokenUse: String
}

private struct UserResponseDTO: Decodable {
    let email: String
    let id: UUID
    let isActive: Bool
    let isAdmin: Bool
    let role: String
}
