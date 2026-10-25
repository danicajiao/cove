//
//  CoveAPIClient.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/20/26.
//

import FirebaseAuth
import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

// MARK: - CoveAPIClient

/// Typed HTTP client for the cove-api gateway.
///
/// Built on top of the Swift OpenAPI Generator–generated `Client` from the
/// gateway's `openapi.yaml` spec. `CoveAPIClient` adds:
/// - `APIEnvironment`-aware server URL selection (staging in Debug, prod in Release)
/// - Firebase ID Token injection via `FirebaseAuthMiddleware`
///
/// Construct via `CoveAPIClient.shared` for standard use, or pass explicit
/// `serverURL` and `session` parameters in unit tests.
///
/// ```swift
/// let health = try await CoveAPIClient.shared.health()
/// print(health.status) // "ok"
/// ```
final class CoveAPIClient: @unchecked Sendable {
    // MARK: Shared instance

    static let shared = CoveAPIClient()

    // MARK: Private

    private let client: Client

    // MARK: Init

    init(
        serverURL: URL = APIEnvironment.current.baseURL,
        session: URLSession = .shared
    ) {
        let transport = URLSessionTransport(configuration: .init(session: session))
        let middleware = FirebaseAuthMiddleware()
        client = Client(
            serverURL: serverURL,
            configuration: .init(dateTranscoder: FractionalSecondsDateTranscoder()),
            transport: transport,
            middlewares: [middleware]
        )
    }

    // MARK: - Image

    /// Returns a signed imgproxy URL for the image stored at `filename` in Garage.
    ///
    /// The URL is valid for 1 hour (configurable via `IMGPROXY_URL_TTL` on cove-media)
    /// and can be passed directly to `AsyncImage(url:)`. imgproxy resizes the image to
    /// the requested dimensions on first fetch; Cloudflare caches the transform at the edge.
    ///
    /// - Parameters:
    ///   - filename: Filename segment of the Garage key — strip the `images/` prefix before
    ///     passing (e.g. `"5069...webp"`, not `"images/5069...webp"`).
    ///   - width: Output width in pixels (1–4096). Defaults to 800.
    ///   - height: Output height in pixels (1–4096). Defaults to 800.
    /// - Returns: A signed `URL` suitable for `AsyncImage(url:)`.
    /// - Throws: `CoveAPIError.unexpectedStatus` for non-200 responses, or
    ///   `CoveAPIError.invalidResponseBody` if the server returns a malformed URL string.
    func imageURL(filename: String, width: Int = 800, height: Int = 800) async throws -> URL {
        let response = try await client.getImageURL(
            path: .init(filename: filename),
            query: .init(w: width, h: height)
        )
        switch response {
        case let .ok(okResponse):
            let body = try okResponse.body.json
            guard let url = URL(string: body.url) else {
                throw CoveAPIError.invalidResponseBody("ImageURLResponse.url is not a valid URL: \(body.url)")
            }
            return url
        case .badRequest:
            throw CoveAPIError.unexpectedStatus(400)
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case .notFound:
            throw CoveAPIError.unexpectedStatus(404)
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    // MARK: - Discovery

    /// Fetches the discovery feed from `GET /discovery`.
    ///
    /// All parameters are optional. When none are provided the gateway returns
    /// up to 25 active items ranked by trust score descending.
    ///
    /// - Parameters:
    ///   - query: Free-text search term (PostgreSQL `websearch_to_tsquery`).
    ///   - category: ltree path to scope results (e.g. `"food.coffee"`).
    ///   - lat: Latitude in decimal degrees. Must be paired with `lon` for proximity scoring.
    ///   - lon: Longitude in decimal degrees. Must be paired with `lat`.
    ///   - radius: Search radius in metres. Applies only when `lat`/`lon` are present; defaults to 50 km server-side.
    /// - Returns: An array of `DiscoveryResult` items ordered by blended score.
    func discovery(
        query: String? = nil,
        category: String? = nil,
        lat: Double? = nil,
        lon: Double? = nil,
        radius: Double? = nil
    ) async throws -> [Components.Schemas.DiscoveryResult] {
        let response = try await client.getDiscovery(
            query: .init(q: query, lat: lat, lon: lon, radius: radius, category: category)
        )
        switch response {
        case let .ok(okResult):
            return try okResult.body.json.results
        case .badRequest:
            throw CoveAPIError.unexpectedStatus(400)
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    // MARK: - Items

    /// Fetches full item detail from `GET /items/{id}`.
    ///
    /// Returns all item fields including trust signals, places, and
    /// signed imgproxy URLs for all five image variants across every media row.
    ///
    /// - Parameter id: Item UUID string.
    /// - Returns: `ItemDetail` with pre-signed media URLs.
    /// - Throws: `CoveAPIError.unexpectedStatus(404)` when the item is not found
    ///   or inactive, `CoveAPIError.unexpectedStatus(401)` for auth failures.
    func item(id: String) async throws -> Components.Schemas.ItemDetail {
        let response = try await client.getItem(path: .init(id: id))
        switch response {
        case let .ok(okResult):
            return try okResult.body.json
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case .notFound:
            throw CoveAPIError.unexpectedStatus(404)
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    // MARK: - Producers

    /// Fetches producer detail from `GET /producers/{id}`.
    ///
    /// Returns producer profile fields, trust signals, and the list of places
    /// run by this producer.
    ///
    /// - Parameter id: Producer UUID string.
    func producer(id: String) async throws -> Components.Schemas.ProducerDetail {
        let response = try await client.getProducer(path: .init(id: id))
        switch response {
        case let .ok(okResult):
            return try okResult.body.json
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case .notFound:
            throw CoveAPIError.unexpectedStatus(404)
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    // MARK: - Places

    /// Fetches place detail from `GET /places/{id}`.
    ///
    /// Returns location, trust signals, and items sold at this place.
    ///
    /// - Parameter id: Place UUID string.
    func place(id: String) async throws -> Components.Schemas.PlaceDetail {
        let response = try await client.getPlace(path: .init(id: id))
        switch response {
        case let .ok(okResult):
            return try okResult.body.json
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case .notFound:
            throw CoveAPIError.unexpectedStatus(404)
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    // MARK: - User profile

    /// Fetches the authenticated user's profile from `GET /users/me`.
    ///
    /// - Throws: `CoveAPIError.unexpectedStatus(404)` when no profile exists yet.
    ///   Call `createMe(username:)` to create one.
    func me() async throws -> Components.Schemas.UserProfile {
        let response = try await client.getMe()
        switch response {
        case let .ok(okResult):
            return try okResult.body.json
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case .notFound:
            throw CoveAPIError.unexpectedStatus(404)
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    /// Creates a profile for the authenticated user via `POST /users/me`.
    ///
    /// The Firebase UID is taken from the token — only the username is supplied.
    /// Returns `CoveAPIError.unexpectedStatus(409)` when a profile already exists;
    /// callers can treat 409 as a success (safe to retry).
    ///
    /// - Parameter username: Desired display username (non-empty after trimming).
    func createMe(username: String) async throws -> Components.Schemas.UserProfile {
        let body = Components.Schemas.CreateUserRequest(username: username)
        let response = try await client.createMe(body: .json(body))
        switch response {
        case let .created(created):
            return try created.body.json
        case .badRequest:
            throw CoveAPIError.unexpectedStatus(400)
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case .conflict:
            throw CoveAPIError.unexpectedStatus(409)
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    // MARK: - Categories

    /// Fetches the full category tree from `GET /categories`.
    ///
    /// Used by the interest-picker onboarding screen and the browse surface.
    func categories() async throws -> [Components.Schemas.CategoryNode] {
        let response = try await client.getCategories()
        switch response {
        case let .ok(okResult):
            return try okResult.body.json.categories
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    // MARK: - Recommendations

    /// Fetches personalized category cards from `GET /recommendations/categories`.
    ///
    /// Ordering is determined server-side by the user's interests and recent
    /// engagement; the client renders them in the returned order.
    ///
    /// - Parameter limit: Maximum number of cards to return (1–100). When `nil`
    ///   the gateway applies its default of 25.
    func recommendedCategories(limit: Int? = nil) async throws -> [Components.Schemas.RecommendedCategory] {
        let response = try await client.getRecommendedCategories(query: .init(limit: limit))
        switch response {
        case let .ok(okResult):
            return try okResult.body.json.categories
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    // MARK: - Activity

    /// Records a behavioral activity via `POST /users/me/activity`.
    ///
    /// Fire-and-forget signal input for personalized recommendations. Returns on 204.
    ///
    /// - Parameters:
    ///   - activityType: The kind of activity (e.g. `.category_tap`).
    ///   - categoryId: UUID of the category involved, when applicable.
    ///   - itemId: UUID of the item involved, when applicable.
    func ingestActivity(
        activityType: Components.Schemas.IngestActivityRequest.activity_typePayload,
        categoryId: String? = nil,
        itemId: String? = nil
    ) async throws {
        let body = Components.Schemas.IngestActivityRequest(
            activity_type: activityType,
            category_id: categoryId,
            item_id: itemId
        )
        let response = try await client.ingestActivity(body: .json(body))
        switch response {
        case .noContent:
            return
        case .badRequest:
            throw CoveAPIError.unexpectedStatus(400)
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case .notFound:
            throw CoveAPIError.unexpectedStatus(404)
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    // MARK: - Interests

    /// Replaces the authenticated user's interest categories via `PUT /users/me/interests`.
    ///
    /// Passing an empty array clears all interests. Returns on 204.
    ///
    /// - Parameter categoryIds: UUID strings of the selected leaf categories.
    func replaceInterests(categoryIds: [String]) async throws {
        let body = Components.Schemas.ReplaceInterestsRequest(category_ids: categoryIds)
        let response = try await client.replaceInterests(body: .json(body))
        switch response {
        case .noContent:
            return
        case .badRequest:
            throw CoveAPIError.unexpectedStatus(400)
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case .notFound:
            throw CoveAPIError.unexpectedStatus(404)
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    // MARK: - Favorites

    /// Lists the authenticated user's favorited items from `GET /users/me/favorites`.
    ///
    /// - Parameters:
    ///   - limit: Maximum results (defaults to 25, max 100).
    ///   - offset: Pagination offset (defaults to 0).
    func favorites(limit: Int? = nil, offset: Int? = nil) async throws -> Components.Schemas.FavoritesResponse {
        let response = try await client.getFavorites(query: .init(limit: limit, offset: offset))
        switch response {
        case let .ok(okResult):
            return try okResult.body.json
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case .notFound:
            throw CoveAPIError.unexpectedStatus(404)
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    /// Adds an item to favorites via `POST /users/me/favorites/{itemId}`.
    ///
    /// Idempotent — a 409 (already favorited) is treated as success.
    ///
    /// - Parameter itemId: Item UUID string.
    func addFavorite(itemId: String) async throws {
        let response = try await client.addFavorite(path: .init(itemId: itemId))
        switch response {
        case .noContent:
            return
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case .notFound:
            throw CoveAPIError.unexpectedStatus(404)
        case .conflict:
            // Already favorited — treat as success.
            return
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    /// Removes an item from favorites via `DELETE /users/me/favorites/{itemId}`.
    ///
    /// Idempotent — a 404 (not favorited) is treated as success.
    ///
    /// - Parameter itemId: Item UUID string.
    func removeFavorite(itemId: String) async throws {
        let response = try await client.removeFavorite(path: .init(itemId: itemId))
        switch response {
        case .noContent:
            return
        case .unauthorized:
            throw CoveAPIError.unexpectedStatus(401)
        case .notFound:
            // Already removed — treat as success.
            return
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }

    // MARK: - Health

    /// Calls `GET /health` and returns the gateway health payload.
    ///
    /// This endpoint is unauthenticated — the Firebase Bearer header is forwarded
    /// by `FirebaseAuthMiddleware` but ignored by the gateway for this route.
    /// Used by the iOS launch smoke test (danicajiao/cove#236) to verify tunnel
    /// and gateway reachability before the first user interaction.
    ///
    /// - Returns: A `HealthResponse` with `service`, `status`, and `commit` fields.
    /// - Throws: `CoveAPIError.unexpectedStatus` for undocumented HTTP status codes,
    ///           or any transport error from the underlying `URLSession`.
    func health() async throws -> Components.Schemas.HealthResponse {
        let response = try await client.getHealth()
        switch response {
        case let .ok(okResponse):
            return try okResponse.body.json
        case let .serviceUnavailable(unavailable):
            return try unavailable.body.json
        case let .undocumented(statusCode, _):
            throw CoveAPIError.unexpectedStatus(statusCode)
        }
    }
}

// MARK: - FirebaseAuthMiddleware

/// OpenAPI client middleware that injects a Firebase ID Token as a Bearer
/// credential on every outgoing request.
///
/// Routes that opt out of authentication (e.g. `GET /health`) receive the
/// header anyway — the gateway ignores it for unauthenticated routes.
/// This keeps the middleware unconditional: one path, no per-route branching.
///
/// If no user is currently signed in the request is forwarded without an
/// `Authorization` header. Unauthenticated routes continue to work; protected
/// routes will receive a 401 from the gateway.
private struct FirebaseAuthMiddleware: ClientMiddleware {
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard let user = Auth.auth().currentUser else {
            return try await next(request, body, baseURL)
        }

        let result = try await user.getIDTokenResult(forcingRefresh: false)
        var authenticated = request
        authenticated.headerFields[.authorization] = "Bearer \(result.token)"
        return try await next(authenticated, body, baseURL)
    }
}

// MARK: - CoveAPIError

/// Errors surfaced by `CoveAPIClient` for cases outside the documented API contract.
enum CoveAPIError: Error {
    /// The server returned an HTTP status code not defined in `openapi.yaml`.
    case unexpectedStatus(Int)
    /// The server returned a documented 2xx response whose body could not be interpreted.
    /// The associated string describes what was wrong (e.g. a URL field that failed to parse).
    case invalidResponseBody(String)
}

// MARK: - LocalizedError

extension CoveAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .unexpectedStatus(code):
            "Unexpected HTTP status code \(code) — not defined in the API contract."
        case let .invalidResponseBody(detail):
            "API response body could not be interpreted: \(detail)"
        }
    }
}
