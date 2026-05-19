//
//  CoveAPIProductRepository.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import Foundation

/// Stub implementation of `ProductRepository` backed by `cove-api`.
///
/// Every method throws `APIError.server(statusCode: 501)` — this class is
/// dormant until Phase 3 fleshes it out with real `CoveProductClient` calls.
/// Wiring it in place now means the Phase 3 swap requires only a one-line
/// DI change in `AppState`.
final class CoveAPIProductRepository: ProductRepository {
    func fetchHome() async throws -> [any Product] {
        throw APIError.server(statusCode: 501, message: "fetchHome not implemented in Phase 0")
    }

    func fetchProduct(id: String) async throws -> any Product {
        throw APIError.server(statusCode: 501, message: "fetchProduct not implemented in Phase 0")
    }

    func fetchDetails(for product: any Product) async throws -> any ProductDetails {
        throw APIError.server(statusCode: 501, message: "fetchDetails not implemented in Phase 0")
    }

    func fetchSimilarProducts(categoryId: String, limit: Int) async throws -> [any Product] {
        throw APIError.server(statusCode: 501, message: "fetchSimilarProducts not implemented in Phase 0")
    }

    func fetchProducts(inCategories categoryIds: [String]) async throws -> [any Product] {
        throw APIError.server(statusCode: 501, message: "fetchProducts(inCategories:) not implemented in Phase 0")
    }

    func fetchProducts(withIds ids: [String]) async throws -> [any Product] {
        throw APIError.server(statusCode: 501, message: "fetchProducts(withIds:) not implemented in Phase 0")
    }

    func fetchBrands() async throws -> [Brand] {
        throw APIError.server(statusCode: 501, message: "fetchBrands not implemented in Phase 0")
    }
}
