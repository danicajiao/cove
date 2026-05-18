//
//  HomeViewModel.swift
//  Cove
//
//  Created by Daniel Cajiao on 12/6/22.
//

import Foundation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var products = [any Product]()
    @Published var brands = [Brand]()

    let categories = ["Music", "Coffee", "Home", "Bevs", "Apparel"]
    let origins = ["Colombia", "Guatemala", "Ethiopia", "Costa Rica", "Kenya"]

    private var lastFetchTime: Date?
    private let cacheTimeout: TimeInterval = 300
    private let productRepository: ProductRepository

    init(productRepository: ProductRepository = FirebaseProductRepository()) {
        self.productRepository = productRepository
    }

    func fetchProducts(forceRefresh: Bool = false) async throws {
        let cacheExpired = lastFetchTime.map { Date().timeIntervalSince($0) > cacheTimeout } ?? true
        guard products.isEmpty || forceRefresh || cacheExpired else { return }

        print("Fetching products...")
        let fetched = try await productRepository.fetchHome()

        if fetched.isEmpty {
            print("No products returned from request")
            return
        }

        products = fetched
        lastFetchTime = Date()
    }

    func fetchBrands() async throws {
        if !brands.isEmpty { return }

        print("Fetching brands...")
        let fetched = try await productRepository.fetchBrands()

        if fetched.isEmpty {
            print("No brands returned from request")
            return
        }

        brands = fetched
    }
}
