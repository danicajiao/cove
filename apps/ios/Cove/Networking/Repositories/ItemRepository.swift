//
//  ItemRepository.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import Foundation

/// Abstraction over all item-catalogue reads.
///
/// ViewModels depend on this protocol rather than on a specific data source.
/// Swap the injected implementation (Firebase, CoveAPI, mock) without touching any ViewModel.
///
/// **Ordering:** `fetchHome()` returns results in insertion order as
/// determined by the backing store. No stable sort is guaranteed
/// across implementations.
///
/// **Polymorphism:** Methods return `[any Item]` or `any Item`. The cove-api
/// implementation always returns `DiscoveryItem`; callers cast with `as?` to
/// read its producer, brand, places and image variants.
protocol ItemRepository {
    /// Fetches the full item catalogue for the home feed.
    func fetchHome() async throws -> [any Item]

    /// Fetches a single item by its unique ID.
    ///
    /// - Throws: `RepositoryError.notFound` when no item exists for the given ID.
    func fetchItem(id: String) async throws -> any Item

    /// Fetches the type-specific detail document for an item.
    ///
    /// The cove-api implementation returns `DiscoveryItemDetails`.
    func fetchDetails(for item: any Item) async throws -> any ItemDetails

    /// Fetches items in the same category as `categoryId`, capped at `limit` results.
    ///
    /// Used by `ItemDetailViewModel` to populate the "similar items" shelf.
    /// Results may include the source item itself — callers are responsible for
    /// filtering it out if needed.
    func fetchSimilarItems(categoryId: String, limit: Int) async throws -> [any Item]

    /// Fetches items whose document IDs are in the provided set.
    ///
    /// Used by `FavoritesViewModel` to hydrate the favourites list from persisted
    /// item IDs. Implementations must batch queries when `ids` exceeds 30 elements
    /// to stay within Firestore's `in` operator limit (or the equivalent backend limit).
    func fetchItems(withIds ids: [String]) async throws -> [any Item]

    /// Fetches all brands.
    func fetchBrands() async throws -> [Brand]
}
