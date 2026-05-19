//
//  FavoritesViewModel.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/18/26.
//

import FirebaseAuth

@MainActor
class FavoritesViewModel: ObservableObject {
    @Published var favorites: [any Product] = []
    @Published var isLoading: Bool = false
    @Published var favoriteCount: Int = 0

    private let favoritesRepository: FavoritesRepository
    private let productRepository: ProductRepository

    init(
        favoritesRepository: FavoritesRepository = FirebaseFavoritesRepository(),
        productRepository: ProductRepository = FirebaseProductRepository()
    ) {
        self.favoritesRepository = favoritesRepository
        self.productRepository = productRepository
    }

    func fetchFavorites() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No user signed in")
            return
        }

        isLoading = true
        defer { isLoading = false }

        let favoriteRefs = try await favoritesRepository.listFavorites(uid: uid)
        let productIds = favoriteRefs.map(\.productId)

        guard !productIds.isEmpty else {
            favorites = []
            favoriteCount = 0
            return
        }

        let fetchedProducts = try await productRepository.fetchProducts(withIds: productIds)
        favorites = fetchedProducts
        favoriteCount = fetchedProducts.count
    }
}
