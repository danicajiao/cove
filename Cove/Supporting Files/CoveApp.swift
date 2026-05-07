//
//  CoveApp.swift
//  Cove
//
//  Created by Daniel Cajiao on 2/16/22.
//

import FBSDKCoreKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import SwiftUI
import UIKit

/// no changes in your AppDelegate class
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )

        print("delegate run")
        return true
    }
}

@main
struct CoveApp: App {
    // Inject into SwiftUI life-cycle via adaptor
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState()
    @StateObject var bag = Bag()
    @StateObject var favoritesStore = FavoritesStore()
    @StateObject private var networkMonitor = NetworkMonitor()

    @State private var authPath: [AuthPath] = []

    init() {
        print("init run")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.authState == .loggedIn {
                    MainView()
                        .environmentObject(bag)
                } else {
                    NavigationStack(path: $authPath) {
                        ZStack {
                            if networkMonitor.isConnected {
                                WelcomeView(
                                    onNavigateToLogin: { authPath.append(.login) },
                                    onNavigateToSignup: { authPath.append(.signup) }
                                )
                                .transition(.opacity)
                            } else {
                                SplashView()
                                    .transition(.opacity)
                            }
                        }
                        .animation(.default, value: networkMonitor.isConnected)
                        .navigationDestination(for: AuthPath.self) { path in
                            switch path {
                            case .login:
                                LoginView(onNavigateToSignup: { authPath.append(.signup) })
                            case .signup:
                                SignupView(onNavigateToLogin: { authPath.append(.login) })
                            }
                        }
                    }
                }
            }
            .onChange(of: appState.authState) { _, _ in
                authPath = []
            }
            .environmentObject(appState)
            .environmentObject(favoritesStore)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
                ApplicationDelegate.shared.application(UIApplication.shared, open: url, options: [:])
            }
        }
    }
}
