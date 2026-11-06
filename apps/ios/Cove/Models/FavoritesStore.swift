//
//  FavoritesStore.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/18/26.
//

import FirebaseAuth

/// Global store that tracks which items the signed-in user has favourited.
///
/// `FavoritesStore` owns the in-memory `favoriteIds` set and handles optimistic
/// UI updates (toggling the heart before the write completes). Durable reads and
/// writes are delegated to a `FavoritesRepository` so the backing store can be
/// swapped (Firebase → `cove-user` in Phase 3) without touching this class.
@MainActor
class FavoritesStore: ObservableObject {
    @Published private(set) var favoriteIds: Set<String> = []
    @Published private(set) var isTogglingFavorite: Bool = false
    /// Set when a favorite was refused because the user is a guest
    /// (`CoveAPIError.accountRequired`). The UI can show sign-up and reset it.
    @Published var accountRequired: Bool = false

    private var authListener: AuthStateDidChangeListenerHandle?
    private let repository: FavoritesRepository

    init(repository: FavoritesRepository = CoveAPIFavoritesRepository()) {
        self.repository = repository
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user, !user.isAnonymous {
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

    func isFavorite(_ itemId: String) -> Bool {
        favoriteIds.contains(itemId)
    }

    func loadFavorites() async {
        // Guests can't have favorites; the gateway would answer 403.
        guard let user = Auth.auth().currentUser, !user.isAnonymous else {
            favoriteIds = []
            return
        }
        do {
            let favorites = try await repository.listFavorites(uid: user.uid)
            favoriteIds = Set(favorites.map(\.itemId))
        } catch {
            print("Error loading favorites: \(error)")
        }
    }

    func toggle(_ itemId: String, categoryId: String) async {
        guard let user = Auth.auth().currentUser else {
            print("FavoritesStore.toggle: no authenticated user, skipping")
            return
        }

        guard !isTogglingFavorite else { return }
        isTogglingFavorite = true
        defer { isTogglingFavorite = false }

        let wasFavorite = favoriteIds.contains(itemId)

        if wasFavorite {
            favoriteIds.remove(itemId)
        } else {
            favoriteIds.insert(itemId)
        }

        do {
            if wasFavorite {
                try await repository.remove(itemId: itemId, uid: user.uid)
            } else {
                try await repository.add(itemId: itemId, categoryId: categoryId, uid: user.uid)
            }
        } catch {
            if case CoveAPIError.accountRequired = error {
                accountRequired = true
            } else {
                print("Error toggling favorite: \(error)")
            }
            if wasFavorite {
                favoriteIds.insert(itemId)
            } else {
                favoriteIds.remove(itemId)
            }
        }
    }
}
