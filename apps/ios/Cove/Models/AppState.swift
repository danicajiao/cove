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
    case login
    case signup
    case item(id: String)
    /// Discovery results scoped to a category subtree. `path` is the ltree path
    /// passed to `GET /discovery?category=`; `name` is the display title.
    case categoryResults(path: String, name: String)
}

enum AuthState {
    case loggedIn
    case loggedOut
    /// Signed in anonymously, with a guest profile and interests picked.
    /// Shows the main app; account-only actions return `CoveAPIError.accountRequired`.
    case guest
    case needsUsernameOnboarding
    case needsInterestOnboarding
    /// Signed in, but the profile couldn't be loaded. Shows a retry screen
    /// instead of guessing where the user belongs.
    case profileLoadFailed
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

    /// Whether the signed-in user already has a cove-user profile. Username
    /// onboarding uses it to choose between creating a profile (`POST /users/me`)
    /// and naming a linked guest's existing one (`PATCH /users/me`).
    private(set) var hasProfile = false

    private var authListener: AuthStateDidChangeListenerHandle?

    /// True while the signed-in Firebase user is anonymous (a guest).
    var isGuest: Bool {
        Auth.auth().currentUser?.isAnonymous ?? false
    }

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            guard let user else {
                setAuthState(.loggedOut)
                return
            }
            Task {
                await self.handlePostSignIn(method: Self.method(for: user))
            }
        }
    }

    deinit {
        if let authListener { Auth.auth().removeStateDidChangeListener(authListener) }
    }

    func setAuthState(_ state: AuthState) {
        withAnimation {
            authState = state
        }
    }

    private static func method(for user: User) -> AuthMethod? {
        user.providerData.lazy.compactMap { AuthMethod(rawValue: $0.providerID) }.first
    }

    // MARK: - Guest

    /// Starts a guest session: signs in anonymously. The auth listener then
    /// creates the guest profile and routes to interest onboarding.
    func startGuestSession(onFailure: @escaping (Error) -> Void) {
        Auth.auth().signInAnonymously { _, error in
            if let error {
                print("❌ Anonymous sign-in failed: \(error.localizedDescription)")
                onFailure(error)
            }
        }
    }

    /// Called when interest onboarding finishes or is skipped.
    func finishInterestOnboarding() {
        setAuthState(isGuest ? .guest : .loggedIn)
    }

    /// Called when username onboarding saves a username. Re-reads the profile so
    /// a new user goes on to interests and a linked guest, whose interests are
    /// kept, goes straight in.
    func finishUsernameOnboarding() async {
        await handlePostSignIn(method: authMethod)
    }

    /// Retries loading the profile after `.profileLoadFailed`.
    func retryProfileLoad() async {
        guard let user = Auth.auth().currentUser else {
            setAuthState(.loggedOut)
            return
        }
        await handlePostSignIn(method: Self.method(for: user))
    }

    // MARK: - Email

    /// Creates an email account. As a guest, the email login is linked to the
    /// guest account so the UID and the guest's data are kept.
    func emailSignUp(email: String, password: String, onFailure: @escaping (Error?) -> Void, onSuccess: @escaping () -> Void) {
        if let guest = Auth.auth().currentUser, guest.isAnonymous {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            guest.link(with: credential) { _, error in
                if let error {
                    guard Self.isAlreadyInUse(error) else {
                        onFailure(error)
                        return
                    }
                    // The email belongs to another account: sign in to it instead.
                    // The guest's data is dropped.
                    self.emailLogIn(email: email, password: password, onFailure: onFailure, onSuccess: onSuccess)
                    return
                }
                self.authMethod = .email
                Task { await self.handleLinked(method: .email) }
                onSuccess()
            }
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { _, error in
            if error != nil {
                onFailure(error)
            } else {
                DispatchQueue.main.async {
                    self.authMethod = .email
                    self.setAuthState(.needsUsernameOnboarding)
                }
                onSuccess()
            }
        }
    }

    func emailLogIn(email: String, password: String, onFailure: @escaping (Error?) -> Void, onSuccess: @escaping () -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            guard let strongSelf = self else { return }
            if error != nil {
                onFailure(error)
            } else {
                Task {
                    await strongSelf.handlePostSignIn(method: .email)
                }
                onSuccess()
            }
        }
    }

    // MARK: - Sign-in and linking

    /// Signs in with a provider credential. As a guest, links the credential to
    /// the guest account instead, so the UID and the guest's data are kept. If
    /// the login already belongs to another account, signs in to that account
    /// and the guest's data is dropped.
    func signInOrLink(with credential: AuthCredential, method: AuthMethod, onFailure: @escaping (Error) -> Void) {
        guard let guest = Auth.auth().currentUser, guest.isAnonymous else {
            signIn(with: credential, method: method, onFailure: onFailure)
            return
        }

        guest.link(with: credential) { _, error in
            guard let error else {
                Task { await self.handleLinked(method: method) }
                return
            }
            guard Self.isAlreadyInUse(error) else {
                onFailure(error)
                return
            }
            // Firebase hands back a fresh credential for the existing account;
            // the original one may already be spent.
            let existing = (error as NSError).userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
            self.signIn(with: existing ?? credential, method: method, onFailure: onFailure)
        }
    }

    private func signIn(with credential: AuthCredential, method: AuthMethod, onFailure: @escaping (Error) -> Void) {
        Auth.auth().signIn(with: credential) { _, error in
            if let error {
                onFailure(error)
            } else {
                Task { await self.handlePostSignIn(method: method) }
            }
        }
    }

    private static func isAlreadyInUse(_ error: Error) -> Bool {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        return code == .credentialAlreadyInUse || code == .emailAlreadyInUse
    }

    /// Routes a guest who just linked a real login. Linking doesn't fire the
    /// auth state listener, and the cached ID token still says "anonymous", so
    /// refresh it first: the gateway then sends `X-Cove-Guest: false` and
    /// cove-user clears `is_guest`.
    private func handleLinked(method: AuthMethod) async {
        do {
            _ = try await Auth.auth().currentUser?.getIDTokenResult(forcingRefresh: true)
        } catch {
            print("⚠️ Token refresh after linking failed: \(error)")
        }
        await handlePostSignIn(method: method)
    }

    // MARK: - Routing

    /// Decides where a signed-in user belongs from their Firebase user and
    /// cove-user profile:
    /// - guest: no profile → create one; then interests, then `.guest`
    /// - signed up: no profile or no username → username onboarding; then
    ///   interests if not done, then `.loggedIn`
    /// - profile load failed for any other reason → `.profileLoadFailed`
    private func handlePostSignIn(method: AuthMethod?) async {
        let guest = isGuest
        let next: AuthState
        var profileExists = true

        do {
            let profile = try await CoveAPIClient.shared.me()
            next = route(guest: guest, hasUsername: profile.username != nil, interestsOnboarded: profile.interests_onboarded)
        } catch CoveAPIError.unexpectedStatus(404) {
            if guest {
                next = await createGuestProfile()
            } else {
                profileExists = false
                next = .needsUsernameOnboarding
            }
        } catch {
            print("❌ Loading profile failed: \(error)")
            next = .profileLoadFailed
        }

        await MainActor.run {
            self.authMethod = method
            self.hasProfile = profileExists
            self.setAuthState(next)
        }
    }

    private func route(guest: Bool, hasUsername: Bool, interestsOnboarded: Bool) -> AuthState {
        if guest {
            return interestsOnboarded ? .guest : .needsInterestOnboarding
        }
        if !hasUsername {
            return .needsUsernameOnboarding
        }
        return interestsOnboarded ? .loggedIn : .needsInterestOnboarding
    }

    private func createGuestProfile() async -> AuthState {
        do {
            _ = try await CoveAPIClient.shared.createGuestProfile()
            return .needsInterestOnboarding
        } catch CoveAPIError.unexpectedStatus(409) {
            // Created by a concurrent call (the listener and a sign-in callback
            // can both get here); re-read it to route.
            do {
                let profile = try await CoveAPIClient.shared.me()
                return route(guest: true, hasUsername: false, interestsOnboarded: profile.interests_onboarded)
            } catch {
                print("❌ Loading guest profile failed: \(error)")
                return .profileLoadFailed
            }
        } catch {
            print("❌ Creating guest profile failed: \(error)")
            return .profileLoadFailed
        }
    }

    // MARK: - Sign out

    /// Signs out any user, including guests (who have no provider data), and
    /// clears the Google and Facebook SDK sessions when those were used.
    func logOut() {
        let providers = Set(Auth.auth().currentUser?.providerData.map(\.providerID) ?? [])
        do {
            try Auth.auth().signOut()
        } catch {
            print("❌ Error signing out: \(error)")
            return
        }
        if providers.contains(AuthMethod.google.rawValue) {
            GIDSignIn.sharedInstance.signOut()
        }
        if providers.contains(AuthMethod.facebook.rawValue) {
            LoginManager().logOut()
        }
        DispatchQueue.main.async {
            self.authMethod = nil
            self.hasProfile = false
            self.setAuthState(.loggedOut)
        }
    }
}
