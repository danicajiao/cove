//
//  ItemDetailTabs.swift
//
//  Created by Daniel Cajiao on 4/12/23.
//

import SwiftUI

struct ItemDetailTabs: View {
    @ObservedObject var viewModel: ItemDetailViewModel
    let stackSpacing = Spacing.lg
    let tabSpacing = Spacing.xs

    var body: some View {
        if let discoveryDetails = viewModel.itemDetails as? DiscoveryItemDetails {
            // Phase 3 API-backed items: two-tab layout (Description / About).
            VStack(spacing: stackSpacing) {
                HStack(spacing: tabSpacing) {
                    tabPill("Description", selection: .description)
                    tabPill("About", selection: .about)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.detailSelection == .description {
                    Text(discoveryDetails.description ?? "No description available.")
                        .font(Font.custom("Lato-Regular", size: 16))
                        .foregroundStyle(Color.Colors.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if viewModel.detailSelection == .about {
                    Text(discoveryDetails.about ?? "")
                        .font(Font.custom("Lato-Regular", size: 16))
                        .foregroundStyle(Color.Colors.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private func tabPill(
        _ label: String,
        selection: ItemDetailViewModel.DetailSelection
    ) -> some View {
        let isSelected = viewModel.detailSelection == selection

        // Bold version is always rendered (opacity 0) to reserve its wider width,
        // preventing siblings from shifting when the font weight changes.
        Text(label)
            .font(Font.custom("Lato-Bold", size: 14))
            .opacity(0)
            .overlay(
                Text(label)
                    .font(Font.custom(isSelected ? "Lato-Bold" : "Lato-Regular", size: 14))
                    .foregroundStyle(isSelected ? Color.Colors.Fills.primary : Color.Colors.Fills.tertiary)
            )
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .overlay(
                Capsule()
                    .strokeBorder(Color.Colors.Strokes.primary, lineWidth: 1)
                    .opacity(isSelected ? 1 : 0)
            )
            .onTapGesture {
                withAnimation {
                    viewModel.detailSelection = selection
                }
            }
    }
}
