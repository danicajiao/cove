//
//  ProductDetailViewModel.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/9/23.
//

import Foundation

class ProductDetailViewModel: ObservableObject {
    @Published var product: (any Product)?
    @Published var productDetails: ProductDetails?
    @Published var detailSelection: DetailSelection
    @Published var similarProducts: [any Product]

    private let productRepository: ProductRepository

    enum DetailSelection {
        case description
        case about

        case specifications
        case origin
        case tracklist
    }

    init(
        productId: String,
        productRepository: ProductRepository = FirebaseProductRepository()
    ) {
        self.productRepository = productRepository
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
        do {
            let fetched = try await productRepository.fetchProduct(id: id)
            await MainActor.run { self.product = fetched }
        } catch {
            print("Error fetching product: \(error)")
        }
    }

    func fetchProductDetails() async throws {
        guard let product else { return }

        print("Fetching product details...")
        let details = try await productRepository.fetchDetails(for: product)
        await MainActor.run { self.productDetails = details }
    }

    func fetchSimilarProducts() async throws {
        if !similarProducts.isEmpty { return }
        guard let product else { return }

        print("Fetching similar products...")
        let fetched = try await productRepository.fetchSimilarProducts(categoryId: product.categoryId, limit: 5)

        if fetched.isEmpty {
            print("No products returned from request")
            return
        }

        await MainActor.run { self.similarProducts = fetched }
    }
}
