//
//  PromotionalBanner.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/9/22.
//

import SwiftUI

/// A Home promo banner. Matches the Figma "Promotional Banner" component and
/// its two variants.
struct PromotionalBanner: View {
    enum Variant {
        /// Photo with an inset discount card.
        case promo1
        /// Product callout with a photo on the right.
        case promo2
    }

    let variant: Variant

    var body: some View {
        switch variant {
        case .promo1: promo1
        case .promo2: promo2
        }
    }

    private var promo1: some View {
        Image("coffee-subscription-2048px-3198-3x2-1")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 148)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Select craft roasters")
                        .textStyle(.captionBold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .center, spacing: Spacing.xs) {
                        Text("40%")
                            .textStyle(.headingXL)
                        Text("off")
                            .textStyle(.headingSM)
                    }

                    HStack(spacing: Spacing.sm) {
                        Text("See all items")
                            .textStyle(.caption)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                    }
                }
                .foregroundStyle(Color.Colors.Text.primary)
                .padding(Spacing.lg)
                .frame(width: 126, height: 126, alignment: .topLeading)
                .background(Color.Colors.Fills.inverse)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .padding(11)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            .customShadow()
    }

    private var promo2: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("New")
                    .textStyle(.headingXL)
                    .foregroundStyle(Color.Colors.Text.primary)
                Text("Stumpton Huye Mountain")
                    .textStyle(.bodySM)
                    .foregroundStyle(Color.Colors.Text.secondary)
                Text("View Stumpton Roasters")
                    .textStyle(.caption)
                    .foregroundStyle(Color.Colors.Text.inverse)
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.sm)
                    .background(Color.Colors.Fills.primary, in: Capsule())
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.Colors.Fills.inverse)

            Image("How-To-Store-Coffee-Beans-Gear-Patrol-Lead-Full")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 164)
                .clipped()
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .customShadow()
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        PromotionalBanner(variant: .promo1)
        PromotionalBanner(variant: .promo2)
    }
    .padding(.horizontal, Spacing.xl)
    .background(Color.Colors.Backgrounds.primary)
}
