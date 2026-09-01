//
//  UserRegistrationClient.swift
//  MangaLibrary
//

import Foundation

enum UserRegistrationFailure: Equatable, Sendable {
    case configurationUnavailable
    case cancelled
    case network(NetworkError)
    case contractDrift
    case unavailable

    var errorDescriptionResource: LocalizedStringResource {
        switch self {
        case .configurationUnavailable, .unavailable:
            "The account service is temporarily unavailable."
        case .cancelled:
            "The registration request was cancelled."
        case let .network(error):
            error.errorDescriptionResource
        case .contractDrift:
            "The server response has an unexpected format."
        }
    }
}

enum UserRegistrationSubmission: Equatable, Sendable {
    case confirmed
    case notSubmitted(UserRegistrationFailure)
    case unconfirmed(UserRegistrationFailure)
}

/// Creates accounts through the registration-only API boundary.
///
/// The App-Token remains scoped to this client and is never forwarded to the
/// session or catalog clients. A missing local value fails before transport.
struct UserRegistrationClient {
    typealias ResponseLoader = @Sendable (URLRequest) async throws(any Error) -> HTTPResponse
    typealias Operation = @Sendable (String, String) async -> UserRegistrationSubmission
}

extension UserRegistrationClient {
    static func operation(
        configuration: APIConfiguration,
        appToken: String?,
        loadResponse: @escaping ResponseLoader
    ) -> Operation {
        guard let appToken = validated(appToken: appToken) else {
            return { _, _ in
                .notSubmitted(.configurationUnavailable)
            }
        }

        let baseURL = configuration.baseURL

        return { email, password in
            do {
                try Task.checkCancellation()
            } catch {
                return .notSubmitted(.cancelled)
            }

            let body: Data

            do {
                body = try JSONEncoder().encode(
                    UserRegistrationRequestDTO(
                        email: email,
                        password: password
                    )
                )
            } catch {
                return .notSubmitted(.unavailable)
            }

            var request = URLRequest(
                url: baseURL.appending(path: "users"),
                cachePolicy: .reloadIgnoringLocalCacheData
            )
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )
            request.setValue(appToken, forHTTPHeaderField: "App-Token")

            let response: HTTPResponse

            do {
                response = try await loadResponse(request)
            } catch is CancellationError {
                return .unconfirmed(.cancelled)
            } catch let error as NetworkError {
                return .unconfirmed(.network(error))
            } catch {
                return .unconfirmed(.unavailable)
            }

            switch response.statusCode {
            case 201:
                return .confirmed
            case 200:
                do {
                    _ = try JSONDecoder().decode(Int64.self, from: response.data)
                    return .confirmed
                } catch {
                    return .unconfirmed(.contractDrift)
                }
            default:
                return .unconfirmed(.network(.statusCode(response.statusCode)))
            }
        }
    }

    static func operation(
        httpClient: HTTPClient,
        configuration: APIConfiguration,
        appToken: String?
    ) -> Operation {
        operation(
            configuration: configuration,
            appToken: appToken,
            loadResponse: { request in
                try await httpClient.response(for: request, accepting: [200, 201])
            }
        )
    }

    private static func validated(appToken: String?) -> String? {
        guard let appToken else { return nil }

        let trimmedToken = appToken.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard
            trimmedToken.isEmpty == false,
            !(trimmedToken.hasPrefix("$(") && trimmedToken.hasSuffix(")"))
        else {
            return nil
        }

        return trimmedToken
    }
}

private struct UserRegistrationRequestDTO: Encodable {
    let email: String
    let password: String
}
