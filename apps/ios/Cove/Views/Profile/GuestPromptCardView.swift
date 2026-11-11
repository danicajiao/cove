//
//  GuestPromptCardView.swift
//  Cove
//

import SwiftUI

/// Shown on the Profile tab in place of the profile while browsing as a guest.
struct GuestPromptCardView: View {
    let onCreateAccount: () -> Void
    let onLogIn: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "person")
                .font(.system(size: 28))
                .foregroundStyle(Color.Colors.Fills.primary)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color.Colors.Fills.quinary))

            Text("You're browsing as a guest")
                .font(.custom("Gazpacho-Black", size: 24))
                .tracking(-1.2) // Figma letter spacing -5% × 24pt
                .foregroundStyle(Color.Colors.Text.primary)

            Text("Create a free account to save favorites, follow places and keep your picks.")
                .font(.custom("Lato-Regular", size: 14))
                .foregroundStyle(Color.Colors.Text.tertiary)

            VStack(spacing: Spacing.sm) {
                Button("Create account", action: onCreateAccount)
                    .buttonStyle(PrimaryButton())
                Button("Log in", action: onLogIn)
                    .buttonStyle(SecondaryButton())
            }
            .padding(.top, Spacing.sm)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.xxl)
        .background(Color.Colors.Backgrounds.secondary, in: RoundedRectangle(cornerRadius: Radius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.xl)
                .strokeBorder(Color.Colors.Strokes.primary, lineWidth: 1)
        }
    }
}

#Preview {
    GuestPromptCardView(onCreateAccount: {}, onLogIn: {})
        .padding(Spacing.xl)
        .background(Color.Colors.Backgrounds.primary)
}
