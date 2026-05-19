//
//  FavoritesStore.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/18/26.
//

import FirebaseAuth

/// Global store that tracks which products the signed-in user has favourited.
///
/// `FavoritesStore` owns the in-memory `favoriteIds` set and handles optimistic
/// UI updates (toggling the heart before the write completes). Durable reads and
/// writes are delegated to a `FavoritesRepository` so the backing store can be
/// swapped (Firebase → `cove-user` in Phase 3) without touching this class.
@MainActor
class FavoritesStore: ObservableObject {
    @Published private(set) var favoriteIds: Set<String> = []
    @Published private(set) var isTogglingFavorite: Bool = false

    private var authListener: AuthStateDidChangeListenerHandle?
    private let repository: FavoritesRepository

    init(repository: FavoritesRepository = FirebaseFavoritesRepository()) {
        self.repository = repository
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
        do {
            let favorites = try await repository.listFavorites(uid: user.uid)
            favoriteIds = Set(favorites.map(\.productId))
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

        do {
            if wasFavorite {
                try await repository.remove(productId: productId, uid: user.uid)
            } else {
                try await repository.add(productId: productId, categoryId: categoryId, uid: user.uid)
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
