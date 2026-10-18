//
//  ImageRepository.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import Foundation
import SwiftUI

/// Abstraction over item image resolution.
///
/// Returns a `URL` the caller can hand directly to `AsyncImage` or use to
/// fetch raw data. Implementations decide whether the URL points to a
/// signed imgproxy endpoint, Firebase Storage, or a local asset.
///
/// **Caching:** Implementations are not required to cache URLs. If caching
/// is needed, wrap the repository or handle it at the view layer via `AsyncImage`.
protocol ImageRepository: Sendable {
    /// Returns a signed URL for the image at the given Garage object key.
    ///
    /// - Parameter key: The Garage object key, e.g. `"images/<sha256>.webp"`.
    ///   Callers pass the value stored in the Firestore model field directly
    ///   (the `defaultImageURL` item field or `imageURL` brand field) —
    ///   no stripping or transformation is needed before calling.
    /// - Returns: A `URL` suitable for passing to `AsyncImage(url:)`.
    /// - Throws: `RepositoryError.notFound` when no image exists for `key`,
    ///   or a transport error if the URL must be fetched from a remote source.
    func imageURL(for key: String) async throws -> URL
    func imageURL(for key: String, width: Int, height: Int) async throws -> URL
}

extension ImageRepository {
    func imageURL(for key: String, width: Int, height: Int) async throws -> URL {
        try await imageURL(for: key)
    }
}

// MARK: - Environment

private struct ImageRepositoryKey: EnvironmentKey {
    static let defaultValue: any ImageRepository = CoveAPIImageRepository()
}

extension EnvironmentValues {
    /// The active `ImageRepository` for resolving Garage object keys to signed URLs.
    ///
    /// Defaults to `CoveAPIImageRepository`. Override in tests or Previews by
    /// passing a custom implementation via `.environment(\.imageRepository, mock)`.
    var imageRepository: any ImageRepository {
        get { self[ImageRepositoryKey.self] }
        set { self[ImageRepositoryKey.self] = newValue }
    }
}
