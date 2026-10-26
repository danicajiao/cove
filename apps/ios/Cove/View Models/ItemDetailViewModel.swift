//
//  ItemDetailViewModel.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/9/23.
//

import Foundation

class ItemDetailViewModel: ObservableObject {
    @Published var item: (any Item)?
    @Published var itemDetails: (any ItemDetails)?
    @Published var detailSelection: DetailSelection
    @Published var similarItems: [any Item]

    private let itemRepository: ItemRepository

    enum DetailSelection {
        case description
        case about
    }

    init(
        itemId: String,
        itemRepository: ItemRepository = CoveAPIItemRepository()
    ) {
        self.itemRepository = itemRepository
        item = nil
        detailSelection = .description
        similarItems = [any Item]()

        Task {
            await fetchItem(itemId)
            if self.item != nil {
                do {
                    try await fetchItemDetails()
                    try await fetchSimilarItems()
                } catch {
                    print("Error fetching item details or similar items: \(error)")
                }
            }
        }
    }

    func fetchItem(_ id: String) async {
        print("Fetching item with id: \(id)")
        do {
            let fetched = try await itemRepository.fetchItem(id: id)
            await MainActor.run { self.item = fetched }
        } catch {
            print("Error fetching item: \(error)")
        }
    }

    func fetchItemDetails() async throws {
        guard let item else { return }

        print("Fetching item details...")
        let details = try await itemRepository.fetchDetails(for: item)
        await MainActor.run { self.itemDetails = details }
    }

    func fetchSimilarItems() async throws {
        if !similarItems.isEmpty { return }
        guard let item else { return }

        print("Fetching similar items...")
        let fetched = try await itemRepository.fetchSimilarItems(categoryId: item.categoryId, limit: 5)

        if fetched.isEmpty {
            print("No items returned from request")
            return
        }

        await MainActor.run { self.similarItems = fetched }
    }
}
