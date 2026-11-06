//
//  ProfileLoadErrorView.swift
//  Cove
//

import SwiftUI

/// Shown when a signed-in user's profile couldn't be loaded
/// (`AuthState.profileLoadFailed`), so the app never guesses where they belong.
struct ProfileLoadErrorView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("Cove.")
                    .font(.custom("Gazpacho-Heavy", size: 40))
                    .foregroundStyle(Color.Colors.Text.primary)

                Text("We couldn't load your profile.")
                    .font(.custom("Lato-Bold", size: 18))
                    .foregroundStyle(Color.Colors.Text.primary)

                Text("Check your connection and try again.")
                    .font(.custom("Lato-Regular", size: 14))
                    .foregroundStyle(Color.Colors.Text.tertiary)
            }
            .multilineTextAlignment(.center)

            Button {
                isRetrying = true
                Task {
                    await appState.retryProfileLoad()
                    isRetrying = false
                }
            } label: {
                if isRetrying {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Try again")
                }
            }
            .buttonStyle(PrimaryButton())
            .disabled(isRetrying)

            Button {
                appState.logOut()
            } label: {
                Text("Sign out")
            }
            .buttonStyle(SecondaryButton())

            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Colors.Backgrounds.primary)
    }
}

#Preview {
    ProfileLoadErrorView()
        .environmentObject(AppState())
}
