//
//  FavoritesStore.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/18/26.
//

import FirebaseAuth
import FirebaseFirestore

@MainActor
class FavoritesStore: ObservableObject {
    @Published private(set) var favoriteIds: Set<String> = []
    @Published private(set) var isTogglingFavorite: Bool = false

    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if user != nil {
                    await self?.loadFavorites()
                } else {
                    self?.favoriteIds = []
                }
            }
        }
    }

    deinit {
        if let authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }

    func isFavorite(_ productId: String) -> Bool {
        favoriteIds.contains(productId)
    }

    func loadFavorites() async {
        guard let user = Auth.auth().currentUser else { return }
        let firestore = Firestore.firestore()
        do {
            let snapshot = try await firestore.collection("users").document(user.uid).collection("favorites").getDocuments()
            let ids = snapshot.documents.compactMap { try? $0.data(as: FavoriteProduct.self).productId }
            favoriteIds = Set(ids)
        } catch {
            print("Error loading favorites: \(error)")
        }
    }

    func toggle(_ productId: String, categoryId: String) async {
        guard let user = Auth.auth().currentUser else {
            print("FavoritesStore.toggle: no authenticated user, skipping")
            return
        }

        guard !isTogglingFavorite else { return }
        isTogglingFavorite = true
        defer { isTogglingFavorite = false }

        let wasFavorite = favoriteIds.contains(productId)

        if wasFavorite {
            favoriteIds.remove(productId)
        } else {
            favoriteIds.insert(productId)
        }

        let favoritesRef = Firestore.firestore()
            .collection("users").document(user.uid).collection("favorites")

        do {
            if wasFavorite {
                let snapshot = try await favoritesRef.whereField("productId", isEqualTo: productId).getDocuments()
                for document in snapshot.documents {
                    try await document.reference.delete()
                }
            } else {
                try favoritesRef.addDocument(from: FavoriteProduct(productId: productId, categoryId: categoryId))
            }
        } catch {
            print("Error toggling favorite: \(error)")
            if wasFavorite {
                favoriteIds.insert(productId)
            } else {
                favoriteIds.remove(productId)
            }
        }
    }
}
