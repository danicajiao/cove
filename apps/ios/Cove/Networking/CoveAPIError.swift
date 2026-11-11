//
//  CoveAPIError.swift
//  Cove
//

import Foundation

// MARK: - CoveAPIError

/// Errors surfaced by `CoveAPIClient` for cases outside the documented API contract.
enum CoveAPIError: Error {
    /// The server returned an HTTP status code not defined in `openapi.yaml`.
    case unexpectedStatus(Int)
    /// The server returned a documented 2xx response whose body could not be interpreted.
    /// The associated string describes what was wrong (e.g. a URL field that failed to parse).
    case invalidResponseBody(String)
    /// The caller is a guest and the route needs a signed-up account
    /// (403 `account_required`). The UI should offer sign-up.
    case accountRequired
}

// MARK: - LocalizedError

extension CoveAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .unexpectedStatus(code):
            "Unexpected HTTP status code \(code) — not defined in the API contract."
        case let .invalidResponseBody(detail):
            "API response body could not be interpreted: \(detail)"
        case .accountRequired:
            "You need an account to do that."
        }
    }
}
