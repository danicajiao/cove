//
//  APIError.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/17/26.
//

import Foundation

/// Typed errors surfaced by `APIClient`.
///
/// Every case maps to a distinct failure point in the request pipeline:
///
/// ```
/// tokenUnavailable  — Firebase didn't yield an ID token (user not signed in, or auth error)
/// unauthorized      — Gateway rejected the token (HTTP 401)
/// forbidden         — User is authenticated but not allowed (HTTP 403)
/// notFound          — Resource doesn't exist (HTTP 404)
/// server            — 5xx or other unexpected status code
/// transport         — Network-level failure before a response arrived
/// decoding          — Response arrived but couldn't be parsed into the expected type
/// badURL            — Path + baseURL produced an invalid URL (programming error)
/// ```
///
/// Firebase SDK types are never exposed here. Token fetch failures surface as
/// `.tokenUnavailable`; all transport errors are wrapped as `URLError`.
enum APIError: Error {
    /// Firebase Auth did not return an ID token.
    /// Either no user is signed in, or the token fetch itself failed.
    case tokenUnavailable

    /// The gateway rejected the request — Firebase token invalid or expired (HTTP 401).
    case unauthorized

    /// The user is authenticated but not permitted to access this resource (HTTP 403).
    case forbidden

    /// The requested resource does not exist (HTTP 404).
    case notFound

    /// An unexpected status code was returned.
    /// Covers 5xx server errors and any 4xx not handled by a specific case above.
    /// `message` is parsed from the response body's `"message"` or `"error"` field when present.
    case server(statusCode: Int, message: String?)

    /// A transport-level failure occurred before a response arrived
    /// (e.g. no network connection, TLS failure, request timeout).
    case transport(URLError)

    /// The response arrived but could not be decoded into the expected Swift type.
    case decoding(DecodingError)

    /// A valid URL could not be constructed from the request's path and base URL.
    /// This is a programming error — check that `path` doesn't start with a leading slash
    /// and that `baseURL` is well-formed.
    case badURL
}

// MARK: - LocalizedError

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .tokenUnavailable:
            "Could not obtain a Firebase ID Token — make sure the user is signed in."
        case .unauthorized:
            "Authentication failed (HTTP 401) — token may be invalid or expired."
        case .forbidden:
            "Access denied (HTTP 403) — you don't have permission to perform this action."
        case .notFound:
            "The requested resource was not found (HTTP 404)."
        case let .server(statusCode, message):
            if let message {
                "Server error (HTTP \(statusCode)): \(message)"
            } else {
                "Server error (HTTP \(statusCode))."
            }
        case let .transport(error):
            "Network error: \(error.localizedDescription)"
        case let .decoding(error):
            "Failed to decode server response: \(error.localizedDescription)"
        case .badURL:
            "Could not construct a valid URL for the request."
        }
    }
}
