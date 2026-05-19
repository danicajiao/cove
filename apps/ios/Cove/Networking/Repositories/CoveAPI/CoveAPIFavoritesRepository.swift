//
//  CoveAPIFavoritesRepository.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import Foundation

/// Stub implementation of `FavoritesRepository` backed by `cove-api`.
///
/// Throws `APIError.server(statusCode: 501)` until Phase 3 fleshes it
/// out with real `CoveUserClient` calls (favorites live under the user service).
final class CoveAPIFavoritesRepository: FavoritesRepository {
    func listFavorites(uid: String) async throws -> [FavoriteProduct] {
        throw APIError.server(statusCode: 501, message: "listFavorites not implemented in Phase 0")
    }

    func add(productId: String, categoryId: String, uid: String) async throws {
        throw APIError.server(statusCode: 501, message: "add not implemented in Phase 0")
    }

    func remove(productId: String, uid: String) async throws {
        throw APIError.server(statusCode: 501, message: "remove not implemented in Phase 0")
    }
}
