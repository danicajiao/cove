//
//  Shimmer.swift
//  Cove
//

import SwiftUI

/// Sweeps a soft highlight left to right across the view, repeating, to mark
/// content that is still loading. Static when Reduce Motion is on.
struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSweeping = false

    /// Highlight width as a fraction of the view's width.
    private let bandWidth: CGFloat = 0.6
    private let duration: Double = 1.2

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        LinearGradient(
                            colors: [.clear, Color.Colors.Fills.inverse.opacity(0.6), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width * bandWidth)
                        // Starts fully off the leading edge, ends fully off the trailing edge.
                        .offset(x: isSweeping ? width : -width * bandWidth)
                        .animation(
                            .linear(duration: duration).repeatForever(autoreverses: false),
                            value: isSweeping
                        )
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipped()
            .onAppear { isSweeping = true }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

#Preview {
    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        .fill(Color.Colors.Fills.quinary)
        .frame(height: 90)
        .shimmer()
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .padding(.horizontal, Spacing.xl)
        .background(Color.Colors.Backgrounds.primary)
}
