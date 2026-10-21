//
//  InterestCategoryCard.swift
//  Cove
//

import SwiftUI

/// A full-width level 1 category card for interest onboarding.
///
/// Shows the category's wide image (`wide_image_key`) with its name on top, and a
/// sage checkmark badge when selected. The signed image URL is pre-fetched by
/// `InterestOnboardingViewModel` so the image is ready when the card appears.
struct InterestCategoryCard: View {
    let name: String
    let imageURL: URL?
    let isSelected: Bool
    let onTap: () -> Void

    private let height: CGFloat = 90
    private let badgeSize: CGFloat = 32

    var body: some View {
        Button(action: onTap) {
            // The image is an overlay on a fixed-size base so its fill size can't
            // widen the card past the parent's padding.
            Color.Colors.Fills.quinary
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .overlay { imageLayer }
                .overlay(alignment: .topLeading) {
                    Text(name)
                        .font(.custom("Gazpacho-Black", size: 24))
                        .foregroundStyle(Color.Colors.Text.primary)
                        .lineLimit(1)
                        .padding(.vertical, Spacing.xs)
                        .padding(.horizontal, Spacing.sm)
                }
                .overlay(alignment: .trailing) {
                    if isSelected {
                        badge
                            .padding(.trailing, Spacing.md)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(NoPressFeedbackButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var imageLayer: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                if case let .success(image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                }
            }
        }
    }

    private var badge: some View {
        Circle()
            .fill(Color.Colors.Brand.sage)
            .frame(width: badgeSize, height: badgeSize)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.Colors.Fills.inverse)
            }
    }
}

/// Draws the label as-is in every state. `PlainButtonStyle` dims its label while
/// pressed; the selection badge is the only feedback these cards need.
private struct NoPressFeedbackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// Bundled 390×180 copy of the Food card image, from `Preview Content` (development-only, not shipped).
private let previewImageURL = Bundle.main.url(forResource: "category-preview-food", withExtension: "jpg")

#Preview {
    VStack(spacing: Spacing.lg) {
        InterestCategoryCard(name: "Food", imageURL: previewImageURL, isSelected: false, onTap: {})
        InterestCategoryCard(name: "Food", imageURL: previewImageURL, isSelected: true, onTap: {})
        // Fallback without an image
        InterestCategoryCard(name: "Music", imageURL: nil, isSelected: false, onTap: {})
    }
    .padding(.horizontal, Spacing.xl)
    .background(Color.Colors.Backgrounds.primary)
}
