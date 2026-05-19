//
//  FirebaseProductRepository.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import FirebaseFirestore

/// Firestore-backed implementation of `ProductRepository`.
///
/// All Firestore reads that were previously scattered across `HomeViewModel`,
/// `ProductDetailViewModel`, and `BagViewModel` are consolidated here.
/// ViewModels should not import `FirebaseFirestore` directly after the
/// DI refactor lands in #226.
final class FirebaseProductRepository: ProductRepository {
    // MARK: - Properties

    private let firestore = Firestore.firestore()

    // MARK: - ProductRepository

    func fetchHome() async throws -> [any Product] {
        let snapshot = try await firestore.collection("products").getDocuments()
        return snapshot.documents.compactMap { decodeProduct(from: $0) }
    }

    func fetchProduct(id: String) async throws -> any Product {
        let snapshot = try await firestore.collection("products").document(id).getDocument()

        guard snapshot.exists else {
            throw APIError.notFound
        }

        guard let product = decodeProduct(from: snapshot) else {
            throw APIError.server(statusCode: 422, message: "Unrecognized product category for id \(id)")
        }

        return product
    }

    func fetchDetails(for product: any Product) async throws -> any ProductDetails {
        let snapshot = try await firestore
            .collection("product_details")
            .document(product.productDetailsId)
            .getDocument()

        guard snapshot.exists else {
            throw APIError.notFound
        }

        if product is CoffeeProduct {
            return try snapshot.data(as: CoffeeProductDetails.self)
        } else if product is MusicProduct {
            return try snapshot.data(as: MusicProductDetails.self)
        } else if product is ApparelProduct {
            return try snapshot.data(as: ApparelProductDetails.self)
        } else {
            throw APIError.server(statusCode: 422, message: "Unrecognized product type — cannot decode details")
        }
    }

    func fetchSimilarProducts(categoryId: String, limit: Int) async throws -> [any Product] {
        let snapshot = try await firestore
            .collection("products")
            .whereField("categoryId", isEqualTo: categoryId)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { decodeProduct(from: $0) }
    }

    func fetchProducts(inCategories categoryIds: [String]) async throws -> [any Product] {
        guard !categoryIds.isEmpty else { return [] }

        let snapshot = try await firestore
            .collection("products")
            .whereField("categoryId", in: categoryIds)
            .getDocuments()

        return snapshot.documents.compactMap { decodeProduct(from: $0) }
    }

    func fetchProducts(withIds ids: [String]) async throws -> [any Product] {
        guard !ids.isEmpty else { return [] }

        var products: [any Product] = []

        // Firestore's `in` operator supports up to 30 values — batch if needed.
        for batchStart in stride(from: 0, to: ids.count, by: 30) {
            let batch = Array(ids[batchStart ..< min(batchStart + 30, ids.count)])
            let snapshot = try await firestore
                .collection("products")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments()
            products.append(contentsOf: snapshot.documents.compactMap { decodeProduct(from: $0) })
        }

        return products
    }

    func fetchBrands() async throws -> [Brand] {
        let snapshot = try await firestore.collection("brands").getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Brand.self) }
    }

    // MARK: - Private helpers

    /// Decodes a Firestore document into the correct `Product` concrete type
    /// based on its `categoryId` field. Returns `nil` for unrecognised categories.
    private func decodeProduct(from snapshot: DocumentSnapshot) -> (any Product)? {
        let categoryId = snapshot["categoryId"] as? String
        do {
            switch categoryId {
            case ProductTypes.coffee.rawValue:
                return try snapshot.data(as: CoffeeProduct.self)
            case ProductTypes.music.rawValue:
                return try snapshot.data(as: MusicProduct.self)
            case ProductTypes.apparel.rawValue:
                return try snapshot.data(as: ApparelProduct.self)
            default:
                return nil
            }
        } catch {
            print("FirebaseProductRepository: failed to decode product \(snapshot.documentID): \(error)")
            return nil
        }
    }
}
