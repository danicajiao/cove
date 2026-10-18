//
//  CategoryCard.swift
//  Cove
//
//  Created by Daniel Cajiao on 6/12/26.
//

import SwiftUI

/// A homepage category card driven by `GET /recommendations/categories`.
///
/// Renders a card with a background image and the category name. The signed
/// imgproxy URL is pre-fetched by `HomeViewModel` when categories load so the
/// image is ready before the card scrolls into view.
struct CategoryCard: View {
    let category: Components.Schemas.RecommendedCategory
    let imageURL: URL?
    let onTap: () -> Void

    private let width: CGFloat = 130
    private let height: CGFloat = 60

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
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                case .failure:
                    Color.Colors.Fills.quinary
                        .frame(width: width, height: height)
                case .empty:
                    Color.Colors.Fills.quinary
                        .frame(width: width, height: height)
                        .overlay {
                            ProgressView()
                                .tint(Color.Colors.Text.tertiary)
                        }
                @unknown default:
                    Color.Colors.Fills.quinary
                        .frame(width: width, height: height)
                }
            }
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

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: Spacing.md) {
            CategoryCard(
                category: .init(id: "1", name: "Beer", path: "alcohol.beer"),
                imageURL: nil,
                onTap: {}
            )
            CategoryCard(
                category: .init(id: "2", name: "Baked Goods", path: "food.baked_goods"),
                imageURL: nil,
                onTap: {}
            )
            CategoryCard(
                category: .init(id: "3", name: "Food", path: "food"),
                imageURL: nil,
                onTap: {}
            )
            CategoryCard(
                category: .init(id: "4", name: "Accessories", path: "pets.dogs.accessories"),
                imageURL: nil,
                onTap: {}
            )
        }
        .padding()
    }
    .background(Color.Colors.Backgrounds.primary)
}
