//
//  Chip.swift
//  Cove
//

import SwiftUI

/// A rounded pill label, filled with a brand color when selected.
/// Matches the Figma "Chip" component.
struct Chip: View {
    let name: String
    let isSelected: Bool
    let selectedFill: Color

    var body: some View {
        // Text.primary on every fill: white fails WCAG contrast on all six brand colors.
        Text(name)
            .textStyle(.bodySM)
            .foregroundStyle(Color.Colors.Text.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(isSelected ? selectedFill : Color.Colors.Fills.quinary)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule().stroke(Color.Colors.Strokes.primary.opacity(0.3), lineWidth: 1)
                }
            }
            .contentShape(Capsule())
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    VStack(spacing: Spacing.sm) {
        Chip(name: "Chip Text", isSelected: false, selectedFill: Color.Colors.Brand.coral)
        Chip(name: "Chip Text", isSelected: true, selectedFill: Color.Colors.Brand.coral)
        Chip(name: "Chip Text", isSelected: true, selectedFill: Color.Colors.Brand.sage)
    }
    .padding()
    .background(Color.Colors.Backgrounds.primary)
}
