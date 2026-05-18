//
//  FirebaseFavoritesRepository.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import FirebaseFirestore

/// Firestore-backed implementation of `FavoritesRepository`.
///
/// Reads and writes the `users/{uid}/favorites` subcollection. The logic
/// previously embedded in `FavoritesStore` is lifted here verbatim so
/// `FavoritesStore` can delegate to this repository instead of calling
/// Firestore directly.
final class FirebaseFavoritesRepository: FavoritesRepository {
    // MARK: - Properties

    private let firestore = Firestore.firestore()

    // MARK: - FavoritesRepository

    func listFavorites(uid: String) async throws -> [FavoriteProduct] {
        let snapshot = try await favoritesCollection(uid: uid).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FavoriteProduct.self) }
    }

    func add(productId: String, categoryId: String, uid: String) async throws {
        try favoritesCollection(uid: uid)
            .addDocument(from: FavoriteProduct(productId: productId, categoryId: categoryId))
    }

    func remove(productId: String, uid: String) async throws {
        let snapshot = try await favoritesCollection(uid: uid)
            .whereField("productId", isEqualTo: productId)
            .getDocuments()

        for document in snapshot.documents {
            try await document.reference.delete()
        }
    }

    // MARK: - Private helpers

    private func favoritesCollection(uid: String) -> CollectionReference {
        firestore.collection("users").document(uid).collection("favorites")
    }
}
