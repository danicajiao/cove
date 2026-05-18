//
//  ImageRepository.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import Foundation

/// Abstraction over product image resolution.
///
/// Returns a `URL` the caller can hand directly to `AsyncImage` or use to
/// fetch raw data. Implementations decide whether the URL points to a
/// Firebase Storage download link, a cove-image endpoint, or a local asset.
///
/// **Caching:** Implementations are not required to cache URLs. If caching
/// is needed, wrap the repository or handle it at the view layer via `AsyncImage`.
protocol ImageRepository {
    /// Returns a URL for the default image of the product with the given ID.
    ///
    /// - Parameter productId: The unique product identifier whose image is needed.
    /// - Returns: A `URL` suitable for passing to `AsyncImage(url:)`.
    /// - Throws: `APIError.notFound` when no image is registered for `productId`,
    ///   or a transport/auth error if the URL must be fetched from a remote source.
    func imageURL(for productId: String) async throws -> URL
}
