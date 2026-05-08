//
//  FavoritesViewModel.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/18/26.
//

import FirebaseAuth
import FirebaseFirestore

@MainActor
class FavoritesViewModel: ObservableObject {
    @Published var favorites: [any Product] = []
    @Published var isLoading: Bool = false
    @Published var favoriteCount: Int = 0

    private func decodeProduct(from document: DocumentSnapshot) -> (any Product)? {
        let categoryId = document["categoryId"] as? String
        do {
            if categoryId == ProductTypes.coffee.rawValue {
                return try document.data(as: CoffeeProduct.self)
            } else if categoryId == ProductTypes.music.rawValue {
                return try document.data(as: MusicProduct.self)
            } else if categoryId == ProductTypes.apparel.rawValue {
                return try document.data(as: ApparelProduct.self)
            }
        } catch {
            print(error)
        }
        return nil
    }

    func fetchFavorites() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No user signed in")
            return
        }

        isLoading = true
        defer { isLoading = false }

        let firestore = Firestore.firestore()

        do {
            let favoritesSnapshot = try await firestore
                .collection("users")
                .document(uid)
                .collection("favorites")
                .getDocuments()

            let productIds: [String] = favoritesSnapshot.documents.compactMap { document in
                do {
                    return try document.data(as: FavoriteProduct.self).productId
                } catch {
                    print(error)
                    return nil
                }
            }

            guard !productIds.isEmpty else {
                favorites = []
                favoriteCount = 0
                return
            }

            var fetchedProducts: [any Product] = []

            for batchStart in stride(from: 0, to: productIds.count, by: 30) {
                let batchEnd = min(batchStart + 30, productIds.count)
                let batch = Array(productIds[batchStart ..< batchEnd])

                let productsSnapshot = try await firestore
                    .collection("products")
                    .whereField(FieldPath.documentID(), in: batch)
                    .getDocuments()

                let batchProducts: [any Product] = productsSnapshot.documents.compactMap { decodeProduct(from: $0) }
                fetchedProducts.append(contentsOf: batchProducts)
            }

            favorites = fetchedProducts
            favoriteCount = fetchedProducts.count
        } catch {
            print(error)
            throw error
        }
    }
}
