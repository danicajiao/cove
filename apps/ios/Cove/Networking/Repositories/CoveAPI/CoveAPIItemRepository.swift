//
//  CoveAPIItemRepository.swift
//
//  Created by Daniel Cajiao on 5/18/26.
//

import Foundation

/// `ItemRepository` implementation backed by the cove-api gateway.
///
/// Calls `GET /discovery` for list feeds and `GET /items/{id}` for detail.
/// Every method returns `DiscoveryItem` instances — views and ViewModels receive
/// pre-signed image URLs in the same payload and never need to call the image
/// repository separately for item images.
final class CoveAPIItemRepository: ItemRepository {
    // MARK: - Properties

    private let api: CoveAPIClient

    // MARK: - Init

    init(api: CoveAPIClient = .shared) {
        self.api = api
    }

    // MARK: - ItemRepository

    func fetchHome() async throws -> [any Item] {
        let results = try await api.discovery()
        return results.map { DiscoveryItem(discovery: $0) }
    }

    func fetchItem(id: String) async throws -> any Item {
        do {
            let detail = try await api.item(id: id)
            return DiscoveryItem(detail: detail)
        } catch CoveAPIError.unexpectedStatus(404) {
            throw RepositoryError.notFound
        }
    }

    /// Returns a `DiscoveryItemDetails` built from the same `GET /items/{id}` call.
    ///
    /// Re-fetches the item to extract the `details` blob. The API round-trip is
    /// cheap (the gateway caches at Cloudflare); a local cache can be added if
    /// the extra request becomes measurable.
    func fetchDetails(for item: any Item) async throws -> any ItemDetails {
        guard let id = item.id else {
            throw RepositoryError.notFound
        }

        do {
            let detail = try await api.item(id: id)
            return DiscoveryItemDetails(
                id: detail.id,
                categoryId: detail.category_id,
                itemId: detail.id,
                description: detail.description,
                about: nil
            )
        } catch CoveAPIError.unexpectedStatus(404) {
            throw RepositoryError.notFound
        }
    }

    /// Returns items from the general discovery feed.
    ///
    /// The cove-api discovery endpoint does not yet support UUID-based category
    /// filtering (it accepts ltree path strings, not UUIDs). Until category
    /// path lookup is added, this returns top-scored items from the full feed —
    /// a reasonable fallback for the "similar items" shelf.
    func fetchSimilarItems(categoryId: String, limit: Int) async throws -> [any Item] {
        let results = try await api.discovery()
        return Array(results.prefix(limit).map { DiscoveryItem(discovery: $0) })
    }

    /// Fetches items by ID in parallel, one `GET /items/{id}` call per ID.
    ///
    /// Used by `FavoritesViewModel` to hydrate the favorites list. Errors for
    /// individual items are swallowed so one missing item does not abort the
    /// entire batch.
    func fetchItems(withIds ids: [String]) async throws -> [any Item] {
        guard !ids.isEmpty else { return [] }
        return try await withThrowingTaskGroup(of: (any Item)?.self) { group in
            for id in ids {
                group.addTask {
                    do {
                        let detail = try await self.api.item(id: id)
                        return DiscoveryItem(detail: detail)
                    } catch {
                        return nil
                    }
                }
            }
            var items: [any Item] = []
            for try await item in group {
                if let item { items.append(item) }
            }
            return items
        }
    }

    /// Returns unique places from the discovery feed as `Brand` stubs.
    ///
    /// cove-api does not have a dedicated "list all places" endpoint yet.
    /// Until one is added the home screen's stores shelf is populated from
    /// the nearest places that appear in the discovery response.
    func fetchBrands() async throws -> [Brand] {
        let results = try await api.discovery()
        var seen = Set<String>()
        var brands: [Brand] = []
        for result in results {
            let place = result.nearest_place
            guard seen.insert(place.id).inserted else { continue }
            brands.append(Brand(id: place.id, createdAt: nil, name: place.name, imageURL: ""))
        }
        return brands
    }
}
