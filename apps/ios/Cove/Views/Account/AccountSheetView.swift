//
//  AccountSheetView.swift
//  Cove
//

import SwiftUI

/// The sign-up sheet a guest sees when an action needs an account.
///
/// Starts on a short prompt (or straight on sign-up / log in from the guest
/// Profile tab), then follows the person through email sign-up or log in and
/// any onboarding the new account needs. When `AppState` reaches `.loggedIn`
/// it closes the sheet and retries the action that opened it.
struct AccountSheetView: View {
    @EnvironmentObject private var appState: AppState

    let prompt: AccountPrompt

    @State private var step: Step
    @State private var promptHeight: CGFloat = 460
    @State private var detent: PresentationDetent = .large

    private enum Step {
        case prompt
        case signup
        case login
    }

    init(prompt: AccountPrompt) {
        self.prompt = prompt
        switch prompt {
        case .createAccount: _step = State(initialValue: .signup)
        case .logIn: _step = State(initialValue: .login)
        case .favorite, .follow: _step = State(initialValue: .prompt)
        }
    }

    /// True once a login is linked or signed in and the account still needs a
    /// username or interests. The sheet can't be swiped away then.
    private var isOnboarding: Bool {
        appState.authState == .needsUsernameOnboarding || appState.authState == .needsInterestOnboarding
    }

    private var showsPrompt: Bool {
        step == .prompt && !isOnboarding
    }

    var body: some View {
        content
            .animation(.default, value: step)
            .animation(.default, value: appState.authState)
            .presentationDetents(showsPrompt ? [.height(promptHeight)] : [.large], selection: $detent)
            .presentationDragIndicator(showsPrompt ? .visible : .hidden)
            .presentationBackground(Color.Colors.Backgrounds.primary)
            .interactiveDismissDisabled(isOnboarding)
            .onAppear { detent = showsPrompt ? .height(promptHeight) : .large }
            .onChange(of: showsPrompt) { _, showsPrompt in
                detent = showsPrompt ? .height(promptHeight) : .large
            }
            .onChange(of: promptHeight) { _, height in
                if showsPrompt { detent = .height(height) }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.authState {
        case .needsUsernameOnboarding:
            UsernameOnboardingView(appState: appState)
                .transition(.opacity)
        case .needsInterestOnboarding:
            InterestOnboardingView(appState: appState)
                .transition(.opacity)
        default:
            switch step {
            case .prompt:
                AccountPromptContent(
                    prompt: prompt,
                    onSignUpWithEmail: { step = .signup },
                    onLogIn: { step = .login },
                    onNotNow: { appState.cancelAccountPrompt() }
                )
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { promptHeight = $0 }
                .transition(.opacity)
            case .signup:
                SignupView(onBack: back, onNavigateToLogin: { step = .login })
                    .transition(.opacity)
            case .login:
                LoginView(onBack: back, onNavigateToSignup: { step = .signup })
                    .transition(.opacity)
            }
        }
    }

    /// Back from sign-up or log in: to the prompt, or closes the sheet when it
    /// was opened straight on that step from the Profile tab.
    private func back() {
        switch prompt {
        case .favorite, .follow: step = .prompt
        case .createAccount, .logIn: appState.cancelAccountPrompt()
        }
    }
}

/// The short first step: why an account is needed, and the ways to get one.
private struct AccountPromptContent: View {
    let prompt: AccountPrompt
    let onSignUpWithEmail: () -> Void
    let onLogIn: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: prompt.systemImage)
                .font(.system(size: 24))
                .foregroundStyle(Color.Colors.Fills.primary)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color.Colors.Fills.quinary))

            VStack(spacing: Spacing.sm) {
                Text(prompt.title)
                    .font(.custom("Gazpacho-Black", size: 28))
                    .tracking(-1.4) // Figma letter spacing -5% × 28pt
                    .foregroundStyle(Color.Colors.Text.primary)
                Text(prompt.message)
                    .font(.custom("Lato-Regular", size: 14))
                    .foregroundStyle(Color.Colors.Text.tertiary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Button("Sign up with email", action: onSignUpWithEmail)
                .buttonStyle(PrimaryButton())

            OrDivider()

            HStack(spacing: Spacing.xxl) {
                SmallSocialButton(socialType: .apple)
                SmallSocialButton(socialType: .facebook)
                SmallSocialButton(socialType: .google)
            }

            HStack(spacing: Spacing.xs) {
                Text("Already have an account?")
                    .foregroundStyle(Color.Colors.Text.tertiary)
                Button(action: onLogIn) {
                    Text("Log in")
                        .underline()
                        .foregroundStyle(Color.Colors.Text.primary)
                }
            }
            .font(.custom("Lato-Regular", size: 14))

            Button(action: onNotNow) {
                Text("Not now")
                    .font(.custom("Lato-Bold", size: 14))
                    .foregroundStyle(Color.Colors.Text.tertiary)
            }
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.xxl)
        .padding(.bottom, Spacing.sm)
    }
}

#Preview {
    Color.Colors.Backgrounds.primary
        .sheet(isPresented: .constant(true)) {
            AccountSheetView(prompt: .favorite)
                .environmentObject(AppState())
        }
}
