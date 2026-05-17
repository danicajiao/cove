//
//  APIError.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/17/26.
//

import Foundation

/// Typed errors surfaced by `APIClient`.
///
/// > Note: This is the initial set for Phase 0. Issue #223 will expand these
/// > with additional cases and a dedicated `.authError` for Firebase token failures.
enum APIError: Error {
    /// No Firebase user is signed in — request cannot be authenticated.
    case unauthenticated
    /// The server returned a non-2xx status code.
    case httpError(statusCode: Int, data: Data)
    /// The response body could not be decoded into the expected type.
    case decodingError(Error)
    /// A transport-level error occurred (e.g. no network, TLS failure).
    case networkError(Error)
    /// A valid URL could not be constructed from the provided path and base URL.
    case badURL
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            "No authenticated user — sign in before making requests."
        case let .httpError(statusCode, _):
            "Server returned HTTP \(statusCode)."
        case let .decodingError(error):
            "Failed to decode response: \(error.localizedDescription)"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case .badURL:
            "Could not construct a valid URL for the request."
        }
    }
}
