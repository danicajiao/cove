//
//  LikeButton.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/9/22.
//

import SwiftUI

struct LikeButton: View {
    let productId: String
    let categoryId: String
    var size: CGFloat = 26
    var outlined: Bool = false

    @EnvironmentObject private var favoritesStore: FavoritesStore
    @State private var pressed = false
    @State private var scale = 1.0

    private var iconSize: CGFloat {
        size * (14.0 / 26.0)
    }

    private var isFavorited: Bool {
        favoritesStore.isFavorite(productId)
    }

    func haptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    var body: some View {
        ZStack {
            Circle()
                .frame(width: size, height: size)
                .foregroundStyle(Color.Colors.Fills.secondary)
                .overlay(Circle().strokeBorder(Color.Colors.Strokes.primary, lineWidth: 1).opacity(outlined ? 1 : 0))
            Image(systemName: isFavorited ? "heart.fill" : "heart")
                .font(.system(size: iconSize))
                .foregroundStyle(isFavorited ? Color.Colors.Brand.Palette.red : Color.Colors.Strokes.primary)
        }
        .scaleEffect(scale)
        .allowsHitTesting(!favoritesStore.isTogglingFavorite)
        .onLongPressGesture(minimumDuration: 2.5, maximumDistance: .infinity, pressing: { pressing in
            pressed = pressing
            if pressing {
                haptic()
                withAnimation(.linear(duration: 0.1)) {
                    scale = 1.5
                }
            } else {
                haptic()
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                }
                Task { await favoritesStore.toggle(productId, categoryId: categoryId) }
            }
        }, perform: {})
    }
}
