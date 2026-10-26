//
//  DiscoveryItem.swift
//
//  Created by Daniel Cajiao on 6/8/26.
//

import Foundation
import UIKit

/// An item sourced from the cove-api gateway.
///
/// Created from `GET /discovery` (list view) and `GET /items/{id}` (detail view).
/// Image URLs are pre-signed and arrive in the same payload as the item data —
/// no separate `ImageRepository.imageURL(for:)` call is required.
///
/// `CoveAPIItemRepository` returns this type from every protocol method.
/// Views that need the item name, producer, or image can read fields directly
/// rather than downcasting to a category-specific type.
struct DiscoveryItem: Item {
    // MARK: - Item protocol

    var id: String?
    var createdAt: Date?

    /// Category UUID from `ItemDetail.category_id`, or `""` for discovery-list items.
    var categoryId: String

    /// `price_cents / 100`, or `0` when the API omits `price_cents`.
    var defaultPrice: Float

    /// The `md` variant signed URL for the primary image, or `""` when absent.
    /// Prefer `primaryImage.url(forTargetPointSize:scale:)` where available.
    var defaultImageURL: String

    var isFavorite: Bool?

    /// Same as `id` — items from cove-api carry all detail in one response.
    var itemDetailsId: String

    // MARK: - Display

    var name: String
    /// Absent for brand-only and secondhand items, which have no producer.
    var producerName: String?
    var producerID: String?
    /// Plain brand name, set when the item's brand isn't a producer.
    var brand: String?
    var itemDescription: String?

    /// "Made by" line: the producer when there is one, otherwise the brand.
    var madeBy: String {
        producerName ?? brand ?? ""
    }

    /// Places that sell this item ("Where to find it"), nearest first for discovery results.
    var places: [Place]

    // MARK: - Pre-signed image variants

    /// Signed imgproxy URLs for list-view sizes (thumb / sm / md).
    /// Populated from `DiscoveryResult.primary_image` or derived from the
    /// primary `ItemMedia` in an `ItemDetail` response.
    var primaryImage: Components.Schemas.ImageVariants?

    /// Full gallery with all five variant sizes. Non-empty only for detail responses.
    var media: [Components.Schemas.ItemMedia]

    // MARK: - Hashable / Equatable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DiscoveryItem, rhs: DiscoveryItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Factory

extension DiscoveryItem {
    /// Creates a `DiscoveryItem` from a `GET /discovery` result.
    init(discovery: Components.Schemas.DiscoveryResult) {
        id = discovery.id
        createdAt = nil
        categoryId = ""
        defaultPrice = Float(discovery.price_cents ?? 0) / 100
        defaultImageURL = discovery.primary_image?.md ?? ""
        isFavorite = nil
        itemDetailsId = discovery.id

        name = discovery.name
        producerName = discovery.producer?.name
        producerID = discovery.producer?.id
        brand = discovery.brand
        itemDescription = discovery.description
        places = discovery.places.map {
            Place(id: $0.id, name: $0.name, type: $0._type.rawValue, listingURL: $0.listing_url)
        }

        primaryImage = discovery.primary_image
        media = []
    }

    /// Creates a `DiscoveryItem` from a `GET /items/{id}` response.
    init(detail: Components.Schemas.ItemDetail) {
        id = detail.id
        createdAt = nil
        categoryId = detail.category_id
        defaultPrice = Float(detail.price_cents ?? 0) / 100
        isFavorite = nil
        itemDetailsId = detail.id

        name = detail.name
        producerName = detail.producer?.name
        producerID = detail.producer?.id
        brand = detail.brand
        itemDescription = detail.description
        places = (detail.places ?? []).map {
            Place(id: $0.id, name: $0.name, type: $0._type, listingURL: $0.listing_url)
        }

        media = detail.media

        // Build the primary_image variants from the first primary media item
        let primaryMedia = detail.media.first(where: { $0.role == .primary })
        if let primaryMediaItem = primaryMedia {
            primaryImage = .init(
                width: primaryMediaItem.width,
                height: primaryMediaItem.height,
                thumb: primaryMediaItem.thumb,
                sm: primaryMediaItem.sm,
                md: primaryMediaItem.md
            )
            defaultImageURL = primaryMediaItem.md
        } else {
            primaryImage = nil
            defaultImageURL = ""
        }
    }
}

// MARK: - Place

extension DiscoveryItem {
    /// A place that sells the item, from `DiscoveryResult.places` or `ItemDetail.places`.
    struct Place: Codable, Hashable, Identifiable {
        var id: String
        var name: String
        /// Place type code, e.g. `cafe` or `dessert_shop`.
        var type: String
        var listingURL: String?

        /// Display label for `type`, e.g. `dessert_shop` → "Dessert shop".
        var typeLabel: String {
            let words = type.replacingOccurrences(of: "_", with: " ")
            return words.prefix(1).uppercased() + words.dropFirst()
        }
    }
}

// MARK: - ImageVariants variant selection

extension Components.Schemas.ImageVariants {
    /// Picks the smallest variant whose pixel width meets or exceeds the target.
    ///
    /// Based on `docs/MEDIA_ARCHITECTURE.md § Picking variants on iOS`.
    ///
    /// - Parameters:
    ///   - size: Target render size in SwiftUI points.
    ///   - scale: Device pixel scale (defaults to the main screen scale).
    /// - Returns: A signed URL, or `nil` when no variant string is a valid URL.
    func url(forTargetPointSize size: CGFloat, scale: CGFloat = UITraitCollection.current.displayScale) -> URL? {
        let target = size * scale
        let candidate: String = switch target {
        case ..<300: thumb
        case ..<600: sm
        default: md
        }
        return URL(string: candidate)
    }
}
