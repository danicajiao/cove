//
//  CategoryCard.swift
//  Cove
//
//  Created by Daniel Cajiao on 6/12/26.
//

import SwiftUI

/// A homepage category card driven by `GET /recommendations/categories`.
///
/// Renders a card with a background image and the category name. The image is
/// downloaded up front by `HomeViewModel`, so it's ready before the card scrolls
/// into view. The card shimmers while `isLoadingImage` is true and falls back to
/// a plain fill if there's no image.
struct CategoryCard: View {
    let category: Components.Schemas.RecommendedCategory
    let image: UIImage?
    var isLoadingImage: Bool = false
    let onTap: () -> Void

    /// Fixed card size in points; images are requested at this times the display scale.
    static let size = CGSize(width: 130, height: 60)
    private var width: CGFloat {
        Self.size.width
    }

    private var height: CGFloat {
        Self.size.height
    }

    var body: some View {
        NavigationLink(value: Path.categoryResults(path: category.path, name: category.name)) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(TapGesture().onEnded { onTap() })
    }

    private var parentLabel: String? {
        let segments = category.path.split(separator: ".").map(String.init)
        guard segments.count >= 2 else { return nil }
        return segments[segments.count - 2].replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var cardContent: some View {
        ZStack(alignment: .topLeading) {
            backgroundLayer
            foregroundContent
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .customShadow()
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if isLoadingImage {
            Color.Colors.Fills.quinary
                .frame(width: width, height: height)
                .shimmer()
        } else if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
                .transition(.opacity)
        } else {
            Color.Colors.Fills.quinary
                .frame(width: width, height: height)
        }
    }

    private var foregroundContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let parent = parentLabel {
                Text(parent)
                    .font(Font.custom("Lato-Regular", size: 10))
                    .foregroundStyle(Color.Colors.Text.tertiary)
                    .lineLimit(1)
            }

            Text(category.name)
                .font(Font.custom("Gazpacho-Black", size: 14))
                .foregroundStyle(Color.Colors.Text.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .frame(width: width, height: height, alignment: .topLeading)
    }
}

/// Bundled 390×180 copies of real category images, from `Preview Content` (development-only, not shipped).
private func previewImage(_ name: String) -> UIImage? {
    Bundle.main.path(forResource: "category-preview-\(name)", ofType: "jpg").flatMap(UIImage.init(contentsOfFile:))
}

#Preview {
    // NavigationLink(value:) is disabled (and drawn dimmed) outside a NavigationStack.
    NavigationStack {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.md) {
                // Level 1 categories, as on the home shelf (no parent label)
                CategoryCard(
                    category: .init(id: "1", name: "Food", path: "food"),
                    image: previewImage("food"),
                    onTap: {}
                )
                CategoryCard(
                    category: .init(id: "2", name: "Alcohol", path: "alcohol"),
                    image: previewImage("alcohol"),
                    onTap: {}
                )
                // Still loading
                CategoryCard(
                    category: .init(id: "4", name: "Apparel", path: "apparel"),
                    image: nil,
                    isLoadingImage: true,
                    onTap: {}
                )
                // Text-only fallback (no image_key)
                CategoryCard(
                    category: .init(id: "3", name: "Music", path: "music"),
                    image: nil,
                    onTap: {}
                )
            }
            .padding()
        }
        .background(Color.Colors.Backgrounds.primary)
    }
}
