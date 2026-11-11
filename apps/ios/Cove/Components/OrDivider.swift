//
//  OrDivider.swift
//  Cove
//

import SwiftUI

/// Two rules with "OR" between them, separating email sign-up from the social
/// buttons. Matches the Figma `Divider` (OR Divider) component.
struct OrDivider: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            rule
            Text("OR")
                .textStyle(.caption)
                .foregroundStyle(Color.Colors.Text.quaternary)
            rule
        }
        .padding(.horizontal, Spacing.md)
    }

    private var rule: some View {
        Capsule()
            .fill(Color.Colors.Fills.quaternary)
            .frame(width: 100, height: 2)
    }
}

#Preview {
    OrDivider()
}
