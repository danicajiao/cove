//
//  AppState.swift
//  Cove
//
//  Created by Daniel Cajiao on 12/16/22.
//

import FBSDKLoginKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import SwiftUI

enum Path: Hashable {
    case welcome
    case login
    case signup
    case main
    case home
    case product(id: String)
}

enum AuthState {
    case loggedIn
    case loggedOut
}

enum AuthMethod: String {
    case email = "password"
    case apple = "apple.com"
    case facebook = "facebook.com"
    case google = "google.com"
}

class AppState: ObservableObject {
    @Published var authState: AuthState = .loggedOut
    var authMethod: AuthMethod?

    func emailSignUp(email: String, password: String, onFailure: @escaping (Error?) -> Void, onSuccess: @escaping () -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { _, error in
            if error != nil {
                onFailure(error)
            } else {
                DispatchQueue.main.async {
                    self.authState = .loggedIn
                    self.authMethod = .email
                }
                onSuccess()
            }
        }
    }

    func emailLogIn(email: String, password: String, onFailure: @escaping (Error?) -> Void, onSuccess: @escaping () -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            guard let strongSelf = self else { return }
            // ...
            if error != nil {
                onFailure(error)
//                print(error?.localizedDescription ?? "")
            } else {
                DispatchQueue.main.async {
                    strongSelf.authState = .loggedIn
                    strongSelf.authMethod = .email
                }
                onSuccess()
            }
        }
    }

    func facebookLogIn(onFailure: @escaping (Error) -> Void) {
        // 1
        authMethod = .facebook

        let loginManager = LoginManager()

        if AccessToken.current != nil {
            // Access token available -- user already logged in
            // Perform log out

            // 2
            loginManager.logOut()

        } else {
            // Access token not available -- user already logged out
            // Perform log in

            // 3
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            guard let rootViewController = windowScene.windows.first?.rootViewController else { return }

            loginManager.logIn(permissions: ["email"], from: rootViewController) { result, error in
                // 4
                // Check for error
                guard error == nil else {
                    // Error occurred
                    self.authMethod = nil
                    print(error?.localizedDescription ?? "Unknown error")
                    return
                }

                // 5
                // Check for cancel
                guard let result, !result.isCancelled else {
                    self.authMethod = nil
                    print("User cancelled login")
                    return
                }

                // Successfully logged in
                // 6
//                self?.updateButton(isLoggedIn: true)
//                let credential = FacebookAuthProvider.credential(withAccessToken: AccessToken.current!.tokenString)

                // 7
//                Profile.loadCurrentProfile { (profile, error) in
//                    self?.updateMessage(with: Profile.current?.name)
//                }

                var user: Profile?
                var error: Error?

                Profile.loadCurrentProfile { profile, fbError in
                    user = profile
                    error = fbError
                }

                self.authenticateUser(for: user, with: error) { error in
                    onFailure(error)
                }
            }
        }
    }

    func googleLogIn(onFailure: @escaping (Error) -> Void) {
        // 1
        authMethod = .google

        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            GIDSignIn.sharedInstance.restorePreviousSignIn { [unowned self] user, error in
                // If restore fails, fall back to fresh sign-in
                if error != nil {
                    print("⚠️ Failed to restore previous sign-in, attempting fresh sign-in...")
                    GIDSignIn.sharedInstance.signOut()
                    performFreshGoogleSignIn(onFailure: onFailure)
                } else {
                    authenticateUser(for: user, with: error) { error in
                        onFailure(error)
                    }
                }
            }
        } else {
            performFreshGoogleSignIn(onFailure: onFailure)
        }
    }

    private func performFreshGoogleSignIn(onFailure: @escaping (Error) -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        guard let rootViewController = windowScene.windows.first?.rootViewController else { return }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            guard let result = signInResult else {
                // Inspect error with detailed logging
                self.authMethod = nil
                if let error {
                    print("❌ Google Sign In Error:")
                    print("Description: \(error.localizedDescription)")
                    let nsError = error as NSError
                    print("Domain: \(nsError.domain)")
                    print("Code: \(nsError.code)")
                    print("UserInfo: \(nsError.userInfo)")
                    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                        print("Underlying Error: \(underlyingError)")
                    }
                }
                return
            }
            self.authenticateUser(for: result.user, with: error) { error in
                onFailure(error)
            }
        }
    }

    /// Authenticate Google user with Firebase
    private func authenticateUser(for user: GIDGoogleUser?, with error: Error?, onFailure: @escaping (Error) -> Void) {
        // 1
        if let error {
            authMethod = nil

            // Detailed error logging
            print("❌ Google Auth Error (before Firebase):")
            print("Description: \(error.localizedDescription)")
            let nsError = error as NSError
            print("Domain: \(nsError.domain)")
            print("Code: \(nsError.code)")
            print("UserInfo: \(nsError.userInfo)")

            return
        }

        // 2
        guard
            let accessToken = user?.accessToken.tokenString,
            let idToken = user?.idToken?.tokenString
        else { return }

        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        // 3
        Auth.auth().signIn(with: credential) { _, error in
            if let error {
                GIDSignIn.sharedInstance.signOut()

                self.authMethod = nil

                // Detailed error logging
                print("❌ Firebase Auth Error:")
                print("Description: \(error.localizedDescription)")
                let nsError = error as NSError
                print("Domain: \(nsError.domain)")
                print("Code: \(nsError.code)")
                print("UserInfo: \(nsError.userInfo)")

                // Log token info for debugging (be careful with sensitive data in production)
                print("Access Token exists: \(user?.accessToken.tokenString != nil)")
                print("ID Token exists: \(user?.idToken?.tokenString != nil)")

                onFailure(error)
            } else {
                DispatchQueue.main.async {
                    self.authMethod = .google
                    self.authState = .loggedIn
                }
            }
        }
    }

    /// Authenticate Facebook user with Firebase
    private func authenticateUser(for user: Profile?, with error: Error?, onFailure: @escaping (Error) -> Void) {
        // 1
        if let error {
            authMethod = nil
            print(error.localizedDescription)
            return
        }

        guard let tokenString = AccessToken.current?.tokenString else { return }
        let credential = FacebookAuthProvider.credential(withAccessToken: tokenString)

        // 3
        Auth.auth().signIn(with: credential) { _, error in
            if let error {
                let loginManager = LoginManager()

                loginManager.logOut()

                self.authMethod = nil
                print(error.localizedDescription)
                onFailure(error)
            } else {
                DispatchQueue.main.async {
                    self.authMethod = .facebook
                    self.authState = .loggedIn
                }
            }
        }
    }

    func logOut() {
        guard let providerId = Auth.auth().currentUser?.providerData.first?.providerID as String? else {
            print("No user is logged in")
            return
        }

        switch providerId {
        case AuthMethod.apple.rawValue:
            print("Logging out apple user")
        case AuthMethod.facebook.rawValue:
            print("Logging out facebook user")
            do {
                try Auth.auth().signOut()
                LoginManager().logOut()
                DispatchQueue.main.async {
                    self.authState = .loggedOut
                    self.authMethod = nil
                }
            } catch let signOutError as NSError {
                print("Error signing out: %@", signOutError)
            }
        case AuthMethod.google.rawValue:
            print("Logging out google user")
            do {
                try Auth.auth().signOut()
                GIDSignIn.sharedInstance.signOut()
                DispatchQueue.main.async {
                    self.authState = .loggedOut
                    self.authMethod = nil
                }
            } catch let signOutError as NSError {
                print("Error signing out: %@", signOutError)
            }
        case AuthMethod.email.rawValue:
            print("Logging out email user")
            do {
                try Auth.auth().signOut()
                DispatchQueue.main.async {
                    self.authState = .loggedOut
                    self.authMethod = nil
                }
            } catch let signOutError as NSError {
                print("Error signing out: %@", signOutError)
            }
        default:
            print("No authMethod was set, this might be a bug.")
        }
    }
}
