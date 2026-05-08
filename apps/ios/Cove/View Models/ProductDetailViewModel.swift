//
//  ProductDetailViewModel.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/9/23.
//

import FirebaseFirestore

class ProductDetailViewModel: ObservableObject {
    @Published var product: (any Product)?
    @Published var productDetails: ProductDetails?
    @Published var detailSelection: DetailSelection
    @Published var similarProducts: [any Product]

    enum DetailSelection {
        case description
        case about

        case specifications
        case origin
        case tracklist
    }

    init(productId: String) {
        product = nil
        detailSelection = .description
        similarProducts = [any Product]()

        Task {
            await fetchProduct(productId)
            if self.product != nil {
                do {
                    try await fetchProductDetails()
                    try await fetchSimilarProducts()
                } catch {
                    print("Error fetching product details or similar products: \(error)")
                }
            }
        }
    }

    func fetchProduct(_ id: String) async {
        print("Fetching product with id: \(id)")
        let firestore = Firestore.firestore()

        do {
            let snapshot = try await firestore.collection("products").document(id).getDocument()

            guard snapshot.exists else {
                print("Product with id \(id) does not exist")
                return
            }

            guard let categoryId = snapshot["categoryId"] as? String else {
                print("Product document missing categoryId field")
                return
            }

            if categoryId == ProductTypes.coffee.rawValue {
                let coffeeProduct = try snapshot.data(as: CoffeeProduct.self)
                await MainActor.run { self.product = coffeeProduct }
            } else if categoryId == ProductTypes.music.rawValue {
                let musicProduct = try snapshot.data(as: MusicProduct.self)
                await MainActor.run { self.product = musicProduct }
            } else if categoryId == ProductTypes.apparel.rawValue {
                let apparelProduct = try snapshot.data(as: ApparelProduct.self)
                await MainActor.run { self.product = apparelProduct }
            } else {
                print("Unknown product category: \(categoryId)")
            }
        } catch {
            print("Error fetching product: \(error)")
        }
    }

    func fetchProductDetails() async throws {
        // Check if product have already been fetched
        guard let product else {
            return
        }

        // Get a reference to Firestore
        print("Fetching product details...")
        let firestore = Firestore.firestore()

        do {
            // Fetch 'product detail' document from the 'product_details' collection
            let snapshot = try await firestore.collection("product_details").document(product.productDetailsId).getDocument()

            if product is MusicProduct {
                let productDetails = try snapshot.data(as: MusicProductDetails.self)

                await MainActor.run(body: {
                    self.productDetails = productDetails
                })
            } else if product is CoffeeProduct {
                let productDetails = try snapshot.data(as: CoffeeProductDetails.self)

                await MainActor.run(body: {
                    self.productDetails = productDetails
                })
            } else if product is ApparelProduct {
                let productDetails = try snapshot.data(as: ApparelProductDetails.self)

                await MainActor.run(body: {
                    self.productDetails = productDetails
                })
            }
        } catch {
            print(error)
            throw error
        }
    }

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

    func fetchSimilarProducts() async throws {
        if !similarProducts.isEmpty { return }
        guard let product else { return }

        print("Fetching similar products...")
        let firestore = Firestore.firestore()

        do {
            let snapshot = try await firestore.collection("products")
                .whereField("categoryId", isEqualTo: product.categoryId)
                .limit(to: 5)
                .getDocuments()

            let products: [any Product] = snapshot.documents.compactMap { decodeProduct(from: $0) }

            if products.isEmpty {
                print("No products returned from request")
                return
            }

            await MainActor.run { self.similarProducts = products }
        } catch {
            print(error)
            throw error
        }
    }
}
