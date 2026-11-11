//
//  SectionHeader.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/21/25.
//

import SwiftUI

struct SectionHeader: View {
    var title: String
    /// The link label on the trailing side. `nil` hides the link, like turning
    /// off the Figma component's Navigation property.
    var navigationText: String? = "See all"

    var body: some View {
        HStack {
            Text(title)
                .textStyle(.bodyLG)
                .foregroundStyle(Color.Colors.Text.primary)
            Spacer()
            if let navigationText {
                Button {
                    // TODO: Navigate to Categories View // swiftlint:disable:this todo
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Text(navigationText)
                            .textStyle(.bodyMD)
                        Image(systemName: "arrow.right")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14)
                    }
                    .foregroundStyle(Color.Colors.Brand.accent)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        SectionHeader(title: "Popular")
        SectionHeader(title: "Similar to this", navigationText: nil)
    }
    .padding()
}
