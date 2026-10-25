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
import OSLog
import SwiftUI
import UIKit

// MARK: - Gateway smoke test

#if DEBUG
    private extension CoveApp {
        /// Calls `GET /health` once at launch and logs the result.
        ///
        /// Exercises the full path: iOS → Cloudflare Tunnel → cove-api gateway.
        /// `/health` is unauthenticated so this runs before the user signs in.
        /// Failure is logged but never surfaces to the user — it must not block
        /// or alter app launch in any way.
        func runGatewaySmokeTest() async {
            let logger = Logger(subsystem: "com.danicajiao.cove", category: "SmokeTest")
            do {
                let health = try await CoveAPIClient.shared.health()
                logger.info("✓ cove-api reachable — service: \(health.service), status: \(health.status), commit: \(health.commit)")
            } catch {
                logger.warning("✗ cove-api smoke test failed: \(error.localizedDescription)")
            }
        }
    }
#endif

// MARK: - AppDelegate

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
    @StateObject var favoritesStore = FavoritesStore()
    @StateObject private var networkMonitor = NetworkMonitor()

    @State private var authScreen: Path?

    init() {
        print("init run")
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .animation(.default, value: appState.authState)
                .task {
                    #if DEBUG
                        await runGatewaySmokeTest()
                    #endif
                }
                .onChange(of: appState.authState) { _, newState in
                    if newState == .loggedOut { authScreen = nil }
                }
                .environmentObject(appState)
                .environmentObject(favoritesStore)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                    ApplicationDelegate.shared.application(UIApplication.shared, open: url, options: [:])
                }
        }
    }

    private var rootView: some View {
        ZStack {
            switch appState.authState {
            case .loggedIn:
                MainView()
                    .environment(\.imageRepository, CoveAPIImageRepository())
                    .transition(.opacity)
            case .needsUsernameOnboarding:
                UsernameOnboardingView(appState: appState)
                    .transition(.opacity)
            case .needsInterestOnboarding:
                InterestOnboardingView(appState: appState)
                    .transition(.opacity)
            case .loggedOut:
                authFlowView
                    .animation(.default, value: networkMonitor.isConnected)
                    .animation(.default, value: authScreen)
                    .transition(.opacity)
            }
        }
    }

    private var authFlowView: some View {
        ZStack {
            if !networkMonitor.isConnected {
                SplashView()
                    .transition(.opacity)
            } else {
                switch authScreen {
                case .login:
                    LoginView(onBack: { authScreen = nil }, onNavigateToSignup: { authScreen = .signup })
                        .transition(.opacity)
                case .signup:
                    SignupView(onBack: { authScreen = nil }, onNavigateToLogin: { authScreen = .login })
                        .transition(.opacity)
                default:
                    WelcomeView(
                        onNavigateToLogin: { authScreen = .login },
                        onNavigateToSignup: { authScreen = .signup }
                    )
                    .transition(.opacity)
                }
            }
        }
    }
}
