//
//  DiscoveryItemDetails.swift
//
//  Created by Daniel Cajiao on 6/8/26.
//

import Foundation

/// Item details sourced from `GET /items/{id}` via cove-api.
///
/// Implements `ItemDetails` for responses backed by `DiscoveryItem`. The API
/// returns a flexible `details` JSON object — common display fields (`description`,
/// `about`) are surfaced here when present; the raw blob can be accessed via
/// `rawDetails` for richer rendering in future iterations.
///
/// `ItemDetailTabs` renders it as a two-tab (Description / About) layout.
struct DiscoveryItemDetails: ItemDetails {
    // MARK: - ItemDetails protocol

    var id: String?
    var categoryId: String
    var createdAt: Date?
    var itemId: String

    // MARK: - Display fields

    var description: String?
    var about: String?

    // MARK: - Init

    init(id: String?, categoryId: String, itemId: String, description: String?, about: String?) {
        self.id = id
        self.categoryId = categoryId
        createdAt = nil
        self.itemId = itemId
        self.description = description
        self.about = about
    }
}
