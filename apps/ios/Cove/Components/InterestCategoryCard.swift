//
//  InterestCategoryCard.swift
//  Cove
//

import SwiftUI

/// A full-width level 1 category card for interest onboarding.
///
/// Shows the category's wide image (`wide_image_key`) with its name on top, and a
/// sage checkmark badge when selected. The image is downloaded up front by
/// `InterestOnboardingViewModel`; the card shimmers while `isLoadingImage` is
/// true and falls back to a plain fill if there's no image.
struct InterestCategoryCard: View {
    let name: String
    let image: UIImage?
    var isLoadingImage: Bool = false
    let isSelected: Bool
    let onTap: () -> Void

    /// Fixed card height; the width fills the parent.
    static let height: CGFloat = 90
    private var height: CGFloat {
        Self.height
    }

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
        if isLoadingImage {
            Color.clear.shimmer()
        } else if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .transition(.opacity)
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
private let previewImage = Bundle.main.path(forResource: "category-preview-food", ofType: "jpg").flatMap(UIImage.init(contentsOfFile:))

#Preview {
    VStack(spacing: Spacing.lg) {
        InterestCategoryCard(name: "Food", image: previewImage, isSelected: false, onTap: {})
        InterestCategoryCard(name: "Food", image: previewImage, isSelected: true, onTap: {})
        // Still loading
        InterestCategoryCard(name: "Apparel", image: nil, isLoadingImage: true, isSelected: false, onTap: {})
        // Fallback without an image
        InterestCategoryCard(name: "Music", image: nil, isSelected: false, onTap: {})
    }
    .padding(.horizontal, Spacing.xl)
    .background(Color.Colors.Backgrounds.primary)
}
