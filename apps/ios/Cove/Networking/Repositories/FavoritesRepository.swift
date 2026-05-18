//
//  FavoritesRepository.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import Foundation

/// Abstraction over favorites list persistence.
///
/// This protocol handles only the durable read/write operations.
/// Optimistic UI updates (toggling the heart icon before the write completes)
/// remain the responsibility of `FavoritesStore`, which coordinates between
/// in-memory state and this repository.
///
/// **Ordering:** `listFavorites(uid:)` returns items in insertion order
/// (most recently favorited last). Implementations should preserve this order
/// where the backing store allows it.
protocol FavoritesRepository {
    /// Returns all favorited product references for the given user.
    ///
    /// Returns an empty array when the user has no favorites — never throws
    /// for an empty list.
    ///
    /// - Parameter uid: The Firebase Auth UID of the user whose favorites to fetch.
    func listFavorites(uid: String) async throws -> [FavoriteProduct]

    /// Records a product as a favourite for the given user.
    ///
    /// Implementations should be idempotent — calling `add` for an already-favorited
    /// product should succeed without creating a duplicate record.
    ///
    /// - Parameters:
    ///   - productId: The ID of the product to favourite.
    ///   - categoryId: The category the product belongs to (required for hydration queries).
    ///   - uid: The Firebase Auth UID of the user favouriting the product.
    func add(productId: String, categoryId: String, uid: String) async throws

    /// Removes a product from the given user's favourites.
    ///
    /// Implementations should be idempotent — calling `remove` for a product that is
    /// not currently favourited should succeed silently.
    ///
    /// - Parameters:
    ///   - productId: The ID of the product to un-favourite.
    ///   - uid: The Firebase Auth UID of the user un-favouriting the product.
    func remove(productId: String, uid: String) async throws
}
