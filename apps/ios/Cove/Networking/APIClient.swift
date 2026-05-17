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
/// > Note: Environment switching (staging vs. prod base URLs) is handled in issue #223.
final class APIClient: @unchecked Sendable {
    // MARK: Properties

    /// The base URL prepended to every request path.
    ///
    /// Inject a staging URL during testing; prod URL in release builds.
    /// Issue #223 will provide convenience factory properties for both environments.
    let baseURL: URL

    private let session: URLSession
    private let decoder: JSONDecoder
    private let tokenCache = TokenCache()

    // MARK: Init

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
    /// - Throws: `APIError.unauthenticated` when no user is signed in,
    ///           `APIError.httpError` for non-2xx responses,
    ///           `APIError.decodingError` when the body cannot be decoded into `T`,
    ///           `APIError.networkError` for transport failures.
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
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        #if DEBUG
            APIClient.logResponse(httpResponse, data: data)
        #endif

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
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
            throw APIError.unauthenticated
        }

        let now = Date()

        if let entry = cache[user.uid], entry.expiresAt > now {
            return entry.value
        }

        let result: AuthTokenResult
        do {
            result = try await user.getIDTokenResult(forcingRefresh: false)
        } catch {
            // #223 will add a dedicated .authError case; for now wrap as networkError
            // so callers always receive an APIError.
            throw APIError.networkError(error)
        }

        cache[user.uid] = Entry(
            value: result.token,
            expiresAt: now.addingTimeInterval(Self.ttl)
        )
        return result.token
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
