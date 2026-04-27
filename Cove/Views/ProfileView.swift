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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                ProfileHeaderView(viewModel: viewModel)

                StatsRowView(orders: 0, followers: 0, following: 0)

                VStack(spacing: 0) {
                    Button {} label: {
                        ProfileRowView(systemImage: "person", label: "Profile")
                    }
                    Button {} label: {
                        ProfileRowView(systemImage: "doc.text", label: "Privacy Policy")
                    }
                    Button {} label: {
                        ProfileRowView(systemImage: "lock", label: "Security and Logins")
                    }
                    Button {
                        presentAlert = true
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
        .confirmationDialog("Confirm Log Out", isPresented: $presentAlert) {
            Button("Log out", role: .destructive) {
                appState.logOut()
                appState.path.removeAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to log out?")
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
