//
//  HomeViewModel.swift
//  Cove
//
//  Created by Daniel Cajiao on 12/6/22.
//

import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    var items = [any Item]()
    @Published var brands = [Brand]()
    @Published var categories = [Components.Schemas.RecommendedCategory]()
    @Published var categoryImages: [String: UIImage] = [:]
    @Published var isLoadingCategories = false
    @Published var isLoadingCategoryImages = false

    private var lastFetchTime: Date?
    private let cacheTimeout: TimeInterval = 300
    private let itemRepository: ItemRepository
    private let api: CoveAPIClient
    private let imageRepository: ImageRepository

    init(
        itemRepository: ItemRepository = CoveAPIItemRepository(),
        api: CoveAPIClient = .shared,
        imageRepository: ImageRepository = CoveAPIImageRepository()
    ) {
        self.itemRepository = itemRepository
        self.api = api
        self.imageRepository = imageRepository
    }

    /// Fetches the home shelf from `GET /recommendations/categories`: every level 1
    /// category, with the user's picks first, in server order. The cards show right
    /// away and shimmer while every card image downloads, then are revealed
    /// together, including cards off-screen in the lazy stack.
    ///
    /// - Parameter displayScale: Screen scale; images are requested at the card's
    ///   point size times this, so each device downloads only what it shows.
    func fetchCategories(displayScale: CGFloat) async {
        guard categories.isEmpty else { return }
        isLoadingCategories = true
        do {
            categories = try await api.recommendedCategories()
        } catch {
            print("❌ fetchCategories failed: \(error)")
        }
        isLoadingCategories = false
        await prefetchCategoryImages(for: categories, displayScale: displayScale)
    }

    /// Whether a category's card should shimmer. Every card with an image shimmers
    /// until the whole set has downloaded.
    func isLoadingImage(for category: Components.Schemas.RecommendedCategory) -> Bool {
        isLoadingCategoryImages && category.image_key != nil
    }

    private func prefetchCategoryImages(
        for categories: [Components.Schemas.RecommendedCategory],
        displayScale: CGFloat
    ) async {
        let width = Int((CategoryCard.size.width * displayScale).rounded(.up))
        let height = Int((CategoryCard.size.height * displayScale).rounded(.up))
        let keys = categories.reduce(into: [String: String]()) { keys, category in
            keys[category.path] = category.image_key
        }
        isLoadingCategoryImages = true
        let images = await ImagePreloader(imageRepository: imageRepository)
            .load(keys, width: width, height: height)
        withAnimation(.easeOut(duration: 0.25)) {
            categoryImages = images
            isLoadingCategoryImages = false
        }
    }

    /// Records a `category_tap` activity. Fire-and-forget — a failure here
    /// must never block navigation to the category results.
    func recordCategoryTap(_ category: Components.Schemas.RecommendedCategory) {
        Task {
            do {
                try await api.ingestActivity(activityType: .category_tap, categoryId: category.id)
            } catch {
                print("⚠️ category_tap activity failed: \(error)")
            }
        }
    }

    func fetchItems(forceRefresh: Bool = false) async throws {
        let cacheExpired = lastFetchTime.map { Date().timeIntervalSince($0) > cacheTimeout } ?? true
        guard items.isEmpty || forceRefresh || cacheExpired else { return }

        print("Fetching items...")
        let fetched = try await itemRepository.fetchHome()

        if fetched.isEmpty {
            print("No items returned from request")
            return
        }

        items = fetched
        lastFetchTime = Date()
    }

    func fetchBrands() async throws {
        if !brands.isEmpty { return }

        print("Fetching brands...")
        let fetched = try await itemRepository.fetchBrands()

        if fetched.isEmpty {
            print("No brands returned from request")
            return
        }

        brands = fetched
    }
}
