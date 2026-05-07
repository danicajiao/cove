//
//  MainView.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/10/22.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var bag: Bag
    @StateObject private var tabState = TabState()
    // @State private var opacity: Double = 0

    var body: some View {
        TabView(selection: $tabState.currentTab) {
            TabNavigationStack {
                HomeView()
            }
            .onTapGesture {
                tabState.currentTab = "home"
            }
            .tabItem {
                Label("Home", systemImage: tabState.currentTab == "home" ? "house.fill" : "house")
                    .environment(\.symbolVariants, .none)
            }
            .tag("home")

            TabNavigationStack {
                Text("Browse View")
            }
            .onTapGesture {
                tabState.currentTab = "browse"
            }
            .tabItem {
                Label("Browse", systemImage: tabState.currentTab == "browse" ? "magnifyingglass" : "magnifyingglass")
                    .environment(\.symbolVariants, .none)
            }
            .tag("browse")

            TabNavigationStack {
                BagView()
            }
            .onTapGesture {
                tabState.currentTab = "bag"
            }
            .tabItem {
                Label("Bag", systemImage: tabState.currentTab == "bag" ? "bag.fill" : "bag")
                    .environment(\.symbolVariants, .none)
            }
            .badge(bag.totalItems)
            .tag("bag")

            TabNavigationStack {
                FavoritesView()
            }
            .onTapGesture {
                tabState.currentTab = "favorites"
            }
            .tabItem {
                Label("Favorites", systemImage: tabState.currentTab == "favorites" ? "heart.fill" : "heart")
                    .environment(\.symbolVariants, .none)
            }
            .tag("favorites")

            TabNavigationStack {
                ProfileView()
            }
            .onTapGesture {
                tabState.currentTab = "profile"
            }
            .tabItem {
                Label("Profile", systemImage: tabState.currentTab == "profile" ? "person.crop.circle.fill" : "person.crop.circle")
                    .environment(\.symbolVariants, .none)
            }
            .tag("profile")
        }
        .environmentObject(tabState)
        // .opacity(opacity)
        .background(Color.Colors.Backgrounds.primary)
        .onAppear {
            // withAnimation(.easeIn(duration: 1)) {
            //     opacity = 1
            // }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
