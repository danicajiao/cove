//
//  APIClient.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/17/26.
//

import FirebaseAuth
import Foundation
import OSLog

// MARK: - APIClient

/// URLSession wrapper that injects a Firebase ID Token as a Bearer credential on every request.
///
/// `APIClient` is thread-safe and can be called from any isolation context without blocking
/// `@MainActor`. Instantiate once and inject wherever needed — ViewModels will receive it
/// through repository protocols introduced in issues #224–#226.
///
/// ```swift
/// let client = APIClient(baseURL: URL(string: "https://api.coveapp.dev")!)
/// let result: MyResponse = try await client.send(APIRequest(path: "health"))
/// ```
///
/// > Note: Use the no-argument `init()` for standard use — it reads `APIEnvironment.current`
/// > automatically. Pass an explicit `baseURL` only in tests or to force a specific environment.
final class APIClient: @unchecked Sendable {
    // MARK: Properties

    /// The base URL prepended to every request path.
    ///
    /// Set automatically from `APIEnvironment.current` by the no-argument convenience
    /// initializer. Pass an explicit URL to override (e.g. in unit tests or to force
    /// a specific environment).
    let baseURL: URL

    private let session: URLSession
    private let decoder: JSONDecoder
    private let tokenCache = TokenCache()

    // MARK: Init

    /// Creates a client pointed at `APIEnvironment.current.baseURL`.
    ///
    /// This is the standard initializer for production and debug use.
    /// Pass an explicit `baseURL` to target a different environment (e.g. in tests).
    convenience init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.init(
            baseURL: APIEnvironment.current.baseURL,
            session: session,
            decoder: decoder
        )
    }

    init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    // MARK: Request execution

    /// Sends an authenticated request and decodes the response body into `T`.
    ///
    /// The Firebase ID Token is fetched from `TokenCache` — a 50-second in-memory cache that
    /// avoids redundant `getIDTokenResult` calls in burst scenarios while ensuring tokens
    /// stay fresh (Firebase rotates them hourly; our TTL is well within that window).
    ///
    /// - Throws: `APIError.tokenUnavailable` when no user is signed in or the token fetch fails,
    ///           `APIError.unauthorized` for HTTP 401,
    ///           `APIError.forbidden` for HTTP 403,
    ///           `APIError.notFound` for HTTP 404,
    ///           `APIError.server` for 5xx and other unexpected status codes,
    ///           `APIError.transport` for network-level failures,
    ///           `APIError.decoding` when the body cannot be decoded into `T`.
    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        let token = try await tokenCache.validToken()

        var urlRequest = try request.urlRequest(baseURL: baseURL)
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        #if DEBUG
            APIClient.logRequest(urlRequest)
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            throw APIError.transport(error)
        } catch {
            throw APIError.transport(URLError(.unknown))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.transport(URLError(.badServerResponse))
        }

        #if DEBUG
            APIClient.logResponse(httpResponse, data: data)
        #endif

        switch httpResponse.statusCode {
        case 200 ..< 300:
            break
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        default:
            throw APIError.server(
                statusCode: httpResponse.statusCode,
                message: APIClient.errorMessage(from: data)
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decoding(error)
        } catch {
            // JSONDecoder should always throw DecodingError; this branch is a safeguard.
            throw APIError.server(statusCode: httpResponse.statusCode, message: error.localizedDescription)
        }
    }
}

// MARK: - TokenCache

/// Actor that caches Firebase ID Tokens for 50 seconds to reduce redundant token fetches
/// during burst request patterns. Firebase manages the underlying token refresh (1-hour TTL);
/// this cache is purely an efficiency layer on top.
private actor TokenCache {
    private struct Entry {
        let value: String
        let expiresAt: Date
    }

    private static let ttl: TimeInterval = 50

    private var cache: [String: Entry] = [:]

    func validToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw APIError.tokenUnavailable
        }

        let now = Date()

        if let entry = cache[user.uid], entry.expiresAt > now {
            return entry.value
        }

        let result: AuthTokenResult
        do {
            result = try await user.getIDTokenResult(forcingRefresh: false)
        } catch {
            // Firebase SDK types are not exposed in APIError — any token fetch failure
            // surfaces as .tokenUnavailable so callers stay decoupled from FirebaseAuth.
            throw APIError.tokenUnavailable
        }

        cache[user.uid] = Entry(
            value: result.token,
            expiresAt: now.addingTimeInterval(Self.ttl)
        )
        return result.token
    }
}

// MARK: - Response helpers

private extension APIClient {
    /// Attempts to extract a human-readable error message from a JSON response body.
    /// Looks for top-level `"message"` or `"error"` string fields.
    static func errorMessage(from data: Data) -> String? {
        guard let json = try? JSONDecoder().decode([String: String].self, from: data) else {
            return nil
        }
        return json["message"] ?? json["error"]
    }
}

// MARK: - Debug logging

#if DEBUG
    private extension APIClient {
        static let logger = Logger(subsystem: "com.danicajiao.cove", category: "APIClient")

        static func logRequest(_ request: URLRequest) {
            let method = request.httpMethod ?? "?"
            let url = request.url?.absoluteString ?? "?"
            logger.debug("→ \(method) \(url)")
        }

        static func logResponse(_ response: HTTPURLResponse, data: Data) {
            let url = response.url?.absoluteString ?? "?"
            logger.debug("← \(response.statusCode) \(url) (\(data.count) bytes)")
        }
    }
#endif
