//
//  WelcomeView.swift
//  Cove
//
//  Created by Daniel Cajiao on 12/7/22.
//

import FirebaseAuth
import RiveRuntime
import SwiftUI

struct WelcomeView: View {
    var onNavigateToLogin: () -> Void
    var onNavigateToSignup: () -> Void
    /// Starts a guest session. A placeholder entry point until #435 replaces
    /// "Join for free" with the designed "Get started".
    var onContinueAsGuest: () -> Void

    var riveViewModel = RiveViewModel(
        fileName: "hero",
        alignment: .topCenter
    )

    var body: some View {
        VStack(spacing: Spacing.xl) {
            riveViewModel.view()

            Spacer()

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Shop where it counts.")
                    .textStyle(.headingLG)
                    .foregroundStyle(Color.Colors.Text.primary)
                    .frame(width: 200, alignment: .leading)
//                    .containerRelativeFrame(.horizontal, count: 2, span: 1, spacing: 0)
                Wordmark(size: .large)

                Button {
                    onNavigateToSignup()
                } label: {
                    Text("Join for free")
                }
                .buttonStyle(PrimaryButton())

                Button {
                    onNavigateToLogin()
                } label: {
                    Text("Log in")
                }
                .buttonStyle(SecondaryButton())

                Button {
                    onContinueAsGuest()
                } label: {
                    Text("Browse as a guest")
                        .font(.custom("Lato-Regular", size: 14))
                        .underline()
                        .foregroundStyle(Color.Colors.Text.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(Spacing.xl)
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.Colors.Backgrounds.primary)
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(onNavigateToLogin: {}, onNavigateToSignup: {}, onContinueAsGuest: {})
    }
}
