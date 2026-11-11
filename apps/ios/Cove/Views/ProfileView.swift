//
//  ProfileView.swift
//  Cove
//
//  Created by Daniel Cajiao on 12/17/22.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    @State private var presentAlert = false
    @State private var presentGuestLogOutAlert = false

    private var isGuest: Bool {
        appState.authState == .guest
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                if isGuest {
                    GuestPromptCardView(
                        onCreateAccount: { appState.requireAccount(.createAccount) },
                        onLogIn: { appState.requireAccount(.logIn) }
                    )
                    .padding(.horizontal, Spacing.xl)
                } else {
                    ProfileHeaderView(viewModel: viewModel)

                    StatsRowView(orders: 0, followers: 0, following: 0)
                }

                VStack(spacing: 0) {
                    if !isGuest {
                        Button {} label: {
                            ProfileRowView(systemImage: "person", label: "Profile")
                        }
                    }
                    Button {} label: {
                        ProfileRowView(systemImage: "doc.text", label: "Privacy Policy")
                    }
                    if !isGuest {
                        Button {} label: {
                            ProfileRowView(systemImage: "lock", label: "Security and Logins")
                        }
                    }
                    Button {
                        if isGuest {
                            presentGuestLogOutAlert = true
                        } else {
                            presentAlert = true
                        }
                    } label: {
                        ProfileRowView(
                            systemImage: "rectangle.portrait.and.arrow.right",
                            label: "Log Out",
                            isDestructive: true
                        )
                    }
                }
                .padding(.horizontal, Spacing.xl)
            }
            .padding(.top, Spacing.xxxl)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.Colors.Backgrounds.primary.ignoresSafeArea(.all))
        .task(id: isGuest) {
            // A guest has no profile to show. Keyed on `isGuest` so the profile
            // loads once a guest signs up from the sheet.
            guard !isGuest else { return }
            await viewModel.fetchProfile()
        }
        .confirmationDialog("Confirm Log Out", isPresented: $presentAlert) {
            Button("Log out", role: .destructive) {
                appState.logOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to log out?")
        }
        // A guest can't log back in to the same session, so their interest
        // picks are lost on log out.
        .alert("Log out of guest mode?", isPresented: $presentGuestLogOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                appState.logOut()
            }
        } message: {
            Text("Your interest picks will be lost. Create an account to keep them.")
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AppState())
    }
}
