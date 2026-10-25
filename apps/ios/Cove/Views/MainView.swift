//
//  MainView.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/10/22.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
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
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
