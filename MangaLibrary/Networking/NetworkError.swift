//
//  NetworkError.swift
//  MangaLibrary
//

import Foundation

/// Safe failures that can leave the shared HTTP transport boundary.
///
/// The error retains only information useful for recovery and diagnostics.
/// Response bodies, URLs, credentials and underlying errors never cross the
/// boundary. Task cancellation remains `CancellationError` because it is not a
/// user-visible network failure.
enum NetworkError: Error, Equatable {
    /// URL loading completed with a response that was not HTTP.
    case invalidResponse

    /// The server returned a status other than the one required by the caller.
    case statusCode(Int)

    /// URL loading failed with a Foundation transport category.
    case transport(URLError.Code)

    /// A deferred resource that SwiftUI can resolve using its current locale.
    var errorDescriptionResource: LocalizedStringResource {
        switch self {
        case .invalidResponse:
            "The server returned an invalid response."
        case let .statusCode(code):
            "The server returned status code \(code)."
        case .transport(.notConnectedToInternet):
            "There is no internet connection."
        case .transport(.timedOut):
            "The network request timed out."
        case .transport:
            "A network connection error occurred."
        }
    }
}

extension NetworkError: LocalizedError {
    var errorDescription: String? { String(localized: errorDescriptionResource) }
}
