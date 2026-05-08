//
//  BagViewModel.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/24/23.
//

import FirebaseAuth
import FirebaseFirestore

class BagViewModel: ObservableObject {
    @Published var similarProducts = [any Product]()
    var tempCategories = [String]()
    var fetchedProductIds = [String]()

    private func decodeProduct(from document: QueryDocumentSnapshot) -> (any Product)? {
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

    private func applyFavorites(to products: inout [any Product], snapshot: QuerySnapshot) throws {
        for document in snapshot.documents {
            do {
                let favoriteProduct = try document.data(as: FavoriteProduct.self)
                guard let index = products.firstIndex(where: { $0.id == favoriteProduct.productId }) else {
                    print("Failed to get local index of favorite product")
                    return
                }
                products[index].isFavorite = true
            } catch {
                print(error)
                throw error
            }
        }
    }

    /// Fetches similar products from Firebase and populates the similarProducts array used in the HomeView
    func fetchSimilarProducts(categories: [String]) async throws {
        if categories.isEmpty {
            await MainActor.run(body: { self.similarProducts = [] })
            return
        }

        if tempCategories == categories { return }

        print("Fetching similar products...")
        fetchedProductIds = [String]()
        let firestore = Firestore.firestore()

        do {
            var snapshot = try await firestore.collection("products").whereField("categoryId", in: categories).getDocuments()

            var products: [any Product] = snapshot.documents.compactMap { document in
                guard let product = decodeProduct(from: document) else { return nil }
                fetchedProductIds.append(document.documentID)
                return product
            }

            if products.isEmpty {
                print("No products returned from request")
                return
            }

            guard let user = Auth.auth().currentUser else {
                print("Failed to get signed in user to fetch favorites")
                return
            }

            snapshot = try await firestore.collection("users").document(user.uid).collection("favorites")
                .whereField("productId", in: fetchedProductIds)
                .getDocuments()

            try applyFavorites(to: &products, snapshot: snapshot)

            tempCategories = categories
            let sendableProducts = products
            await MainActor.run(body: { self.similarProducts = sendableProducts })
        } catch {
            print(error)
            throw error
        }
    }
}
