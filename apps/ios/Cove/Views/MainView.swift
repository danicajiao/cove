//
//  MainView.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/10/22.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @StateObject private var tabState = TabState()

    var body: some View {
        TabView(selection: $tabState.currentTab) {
            Tab("", systemImage: "house", value: AppTab.home) {
                TabNavigationStack {
                    HomeView()
                }
            }

            Tab("", systemImage: "safari", value: AppTab.browse) {
                TabNavigationStack {
                    Text("Browse View")
                }
            }

            Tab("", systemImage: "heart", value: AppTab.favorites) {
                TabNavigationStack {
                    FavoritesView()
                }
            }

            Tab("", systemImage: "person.crop.circle", value: AppTab.profile) {
                TabNavigationStack {
                    ProfileView()
                }
            }
        }
        .environmentObject(tabState)
        .background(Color.Colors.Backgrounds.primary)
        .sheet(item: $appState.accountPrompt, onDismiss: appState.cancelAccountPrompt) { prompt in
            AccountSheetView(prompt: prompt)
                .environmentObject(appState)
                .environmentObject(favoritesStore)
        }
        .onChange(of: favoritesStore.accountRequired) { _, required in
            // The gateway refused a favorite with `account_required`. Ask for
            // an account; the item isn't saved automatically in this case.
            guard required else { return }
            favoritesStore.accountRequired = false
            appState.requireAccount(.favorite)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(AppState())
            .environmentObject(FavoritesStore())
    }
}
