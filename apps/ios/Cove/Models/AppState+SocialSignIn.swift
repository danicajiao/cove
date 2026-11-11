//
//  AppState+SocialSignIn.swift
//  Cove
//

import FBSDKLoginKit
import FirebaseAuth
import GoogleSignIn
import SwiftUI

/// Google and Facebook sign-in. Both hand their Firebase credential to
/// `signInOrLink(with:method:onFailure:)`, which links it to a guest's account
/// instead of signing in when the current user is a guest.
extension AppState {
    // MARK: - Facebook

    func facebookLogIn(onFailure: @escaping (Error) -> Void) {
        authMethod = .facebook

        let loginManager = LoginManager()

        if AccessToken.current != nil {
            // Access token available -- user already logged in. Perform log out.
            loginManager.logOut()
        } else {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            guard let rootViewController = windowScene.windows.first?.rootViewController else { return }

            loginManager.logIn(permissions: ["email"], from: rootViewController) { result, error in
                guard error == nil else {
                    self.authMethod = nil
                    print(error?.localizedDescription ?? "Unknown error")
                    return
                }

                guard let result, !result.isCancelled else {
                    self.authMethod = nil
                    print("User cancelled login")
                    return
                }

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

    // MARK: - Google

    func googleLogIn(onFailure: @escaping (Error) -> Void) {
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
        if let error {
            authMethod = nil
            print("❌ Google Auth Error (before Firebase):")
            print("Description: \(error.localizedDescription)")
            let nsError = error as NSError
            print("Domain: \(nsError.domain)")
            print("Code: \(nsError.code)")
            print("UserInfo: \(nsError.userInfo)")
            return
        }

        guard
            let accessToken = user?.accessToken.tokenString,
            let idToken = user?.idToken?.tokenString
        else { return }

        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        signInOrLink(with: credential, method: .google) { error in
            GIDSignIn.sharedInstance.signOut()
            self.authMethod = nil
            print("❌ Firebase Auth Error: \(error.localizedDescription)")
            onFailure(error)
        }
    }

    /// Authenticate Facebook user with Firebase
    private func authenticateUser(for user: Profile?, with error: Error?, onFailure: @escaping (Error) -> Void) {
        if let error {
            authMethod = nil
            print(error.localizedDescription)
            return
        }

        guard let tokenString = AccessToken.current?.tokenString else { return }
        let credential = FacebookAuthProvider.credential(withAccessToken: tokenString)

        signInOrLink(with: credential, method: .facebook) { error in
            LoginManager().logOut()
            self.authMethod = nil
            print(error.localizedDescription)
            onFailure(error)
        }
    }
}
