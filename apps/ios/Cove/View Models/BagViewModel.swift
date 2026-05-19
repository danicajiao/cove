//
//  BagViewModel.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/24/23.
//

import FirebaseAuth

class BagViewModel: ObservableObject {
    @Published var similarProducts = [any Product]()
    var tempCategories = [String]()
    var fetchedProductIds = [String]()

    private let productRepository: ProductRepository
    private let favoritesRepository: FavoritesRepository

    init(
        productRepository: ProductRepository = FirebaseProductRepository(),
        favoritesRepository: FavoritesRepository = FirebaseFavoritesRepository()
    ) {
        self.productRepository = productRepository
        self.favoritesRepository = favoritesRepository
    }

    /// Fetches similar products and populates the similarProducts array used in BagView
    func fetchSimilarProducts(categories: [String]) async throws {
        if categories.isEmpty {
            await MainActor.run(body: { self.similarProducts = [] })
            return
        }

        if tempCategories == categories { return }

        print("Fetching similar products...")
        fetchedProductIds = [String]()

        var products = try await productRepository.fetchProducts(inCategories: categories)
        fetchedProductIds = products.compactMap(\.id)

        if products.isEmpty {
            print("No products returned from request")
            return
        }

        guard let user = Auth.auth().currentUser else {
            print("Failed to get signed in user to fetch favorites")
            return
        }

        let favorites = try await favoritesRepository.listFavorites(uid: user.uid)
        let favoriteIds = Set(favorites.map(\.productId))

        for index in products.indices {
            if let id = products[index].id, favoriteIds.contains(id) {
                products[index].isFavorite = true
            }
        }

        tempCategories = categories
        let sendableProducts = products
        await MainActor.run(body: { self.similarProducts = sendableProducts })
    }
}
