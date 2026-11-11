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
    @EnvironmentObject private var appState: AppState

    var onNavigateToLogin: () -> Void

    @State private var startingGuestSession = false
    @State private var guestSessionError: String?

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
                    .font(.custom("Gazpacho-Black", size: 28))
                    .foregroundStyle(Color.Colors.Text.primary)
                    .frame(width: 200, alignment: .leading)
//                    .containerRelativeFrame(.horizontal, count: 2, span: 1, spacing: 0)
                Text("Cove.")
                    .font(.custom("Gazpacho-Heavy", size: 60))
                    .foregroundStyle(Color.Colors.Text.primary)

                Button {
                    startGuestSession()
                } label: {
                    if startingGuestSession {
                        ProgressView()
                            .tint(Color.Colors.Fills.inverse)
                    } else {
                        Text("Get started")
                    }
                }
                .buttonStyle(PrimaryButton())
                .disabled(startingGuestSession)

                Button {
                    onNavigateToLogin()
                } label: {
                    Text("Log in")
                }
                .buttonStyle(SecondaryButton())
            }
            .padding(Spacing.xl)
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.Colors.Backgrounds.primary)
        .alert(
            "Couldn't get started",
            isPresented: Binding(get: { guestSessionError != nil }, set: { if !$0 { guestSessionError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(guestSessionError ?? "")
        }
    }

    /// Starts a guest session. The auth listener in `AppState` then creates the
    /// guest profile and routes to interest picks, which replaces this screen.
    private func startGuestSession() {
        guard !startingGuestSession else { return }
        startingGuestSession = true
        appState.startGuestSession { error in
            startingGuestSession = false
            guestSessionError = error.localizedDescription
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(onNavigateToLogin: {})
            .environmentObject(AppState())
    }
}
