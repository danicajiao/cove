//
//  APIRequest.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/17/26.
//

import Foundation

/// A value type that describes an outbound HTTP request.
///
/// Use the plain initializer for GET requests with optional query params,
/// or the generic `jsonBody:` initializer for POST/PUT/PATCH requests:
///
/// ```swift
/// // GET /health
/// let ping = APIRequest(path: "health")
///
/// // POST /images with a JSON body
/// let upload = try APIRequest(path: "images", method: .post, jsonBody: metadata)
/// ```
struct APIRequest {
    // MARK: - HTTPMethod

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    // MARK: - Properties

    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let body: Data?
    let additionalHeaders: [String: String]

    // MARK: - Init

    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        additionalHeaders: [String: String] = [:]
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.additionalHeaders = additionalHeaders
    }
}

// MARK: - JSON body convenience

extension APIRequest {
    /// Creates a request with a JSON-encoded body.
    /// Sets `Content-Type: application/json` automatically.
    init(
        path: String,
        method: HTTPMethod = .post,
        queryItems: [URLQueryItem] = [],
        jsonBody: some Encodable,
        encoder: JSONEncoder = JSONEncoder(),
        additionalHeaders: [String: String] = [:]
    ) throws {
        var headers = additionalHeaders
        headers["Content-Type"] = "application/json"
        try self.init(
            path: path,
            method: method,
            queryItems: queryItems,
            body: encoder.encode(jsonBody),
            additionalHeaders: headers
        )
    }
}

// MARK: - URLRequest construction

extension APIRequest {
    /// Builds a `URLRequest` by appending `path` to `baseURL` and applying all fields.
    ///
    /// - Throws: `APIError.badURL` if the resulting URL cannot be constructed.
    func urlRequest(baseURL: URL) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: true
        ) else {
            throw APIError.badURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }
}
