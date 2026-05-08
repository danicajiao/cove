//
//  HomeViewModel.swift
//  Cove
//
//  Created by Daniel Cajiao on 12/6/22.
//

import FirebaseFirestore
import FirebaseStorage

@MainActor
class HomeViewModel: ObservableObject {
    @Published var products = [any Product]()
    @Published var brands = [Brand]()

    let categories = ["Music", "Coffee", "Home", "Bevs", "Apparel"]
    let origins = ["Colombia", "Guatemala", "Ethiopia", "Costa Rica", "Kenya"]

    private var lastFetchTime: Date?
    private let cacheTimeout: TimeInterval = 300

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

    /// Fetches products from Firebase and populates the products array used in the HomeView
    func fetchProducts(forceRefresh: Bool = false) async throws {
        let cacheExpired = lastFetchTime.map { Date().timeIntervalSince($0) > cacheTimeout } ?? true
        guard products.isEmpty || forceRefresh || cacheExpired else { return }

        print("Fetching products...")
        let firestore = Firestore.firestore()

        do {
            let snapshot = try await firestore.collection("products").getDocuments()
            let products: [any Product] = snapshot.documents.compactMap { decodeProduct(from: $0) }

            if products.isEmpty {
                print("No products returned from request")
                return
            }

            self.products = products
            lastFetchTime = Date()
        } catch {
            print(error)
            throw error
        }
    }

    func fetchBrands() async throws {
        if !brands.isEmpty { return }

        print("Fetching brands...")
        let firestore = Firestore.firestore()

        do {
            let snapshot = try await firestore.collection("brands").getDocuments()

            let brands: [Brand] = snapshot.documents.compactMap { document in
                do {
                    return try document.data(as: Brand.self)
                } catch {
                    print(error)
                    return nil
                }
            }

            if brands.isEmpty {
                print("No brands returned from request")
                return
            }

            self.brands = brands
        } catch {
            print(error)
            throw error
        }
    }
}
