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

    /// The step the sheet is sized for. Changes before `visibleStep` when the
    /// sheet resizes.
    @State private var step: Step
    /// The step on screen. `nil` while the sheet resizes between steps.
    @State private var visibleStep: Step?
    @State private var isTransitioning = false
    @State private var promptHeight: CGFloat = 460
    /// The sheet's allowed sizes and the current one. Normally a single size;
    /// both sizes are allowed only while animating from one to the other.
    @State private var detents: Set<PresentationDetent>
    @State private var selectedDetent: PresentationDetent

    private enum Step: Equatable {
        case prompt
        case signup
        case login
    }

    init(prompt: AccountPrompt) {
        self.prompt = prompt
        let initial: Step = switch prompt {
        case .createAccount: .signup
        case .logIn: .login
        case .favorite, .follow: .prompt
        }
        let detent: PresentationDetent = initial == .prompt ? .height(460) : .large
        _step = State(initialValue: initial)
        _visibleStep = State(initialValue: initial)
        _detents = State(initialValue: [detent])
        _selectedDetent = State(initialValue: detent)
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
        ZStack(alignment: .top) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(Self.fade, value: appState.authState)
        .presentationDetents(detents, selection: $selectedDetent)
        .presentationDragIndicator(showsPrompt ? .visible : .hidden)
        .presentationBackground(Color.Colors.Backgrounds.primary)
        .interactiveDismissDisabled(isOnboarding)
        .onChange(of: promptHeight) { _, height in
            // Fit the prompt to its measured height. Not animated: it only
            // changes as the sheet first appears.
            guard step == .prompt, !isTransitioning else { return }
            setDetent(.height(height))
        }
        .onChange(of: isOnboarding) { _, onboarding in
            guard onboarding, selectedDetent != .large else { return }
            Task { await resize(to: .large) }
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
            switch visibleStep {
            case nil:
                EmptyView()
            case .prompt:
                AccountPromptContent(
                    prompt: prompt,
                    onSignUpWithEmail: { go(to: .signup) },
                    onLogIn: { go(to: .login) },
                    onNotNow: { appState.cancelAccountPrompt() }
                )
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { promptHeight = $0 }
                .transition(.opacity)
            case .signup:
                SignupView(onBack: back, onNavigateToLogin: { go(to: .login) })
                    .transition(.opacity)
            case .login:
                LoginView(onBack: back, onNavigateToSignup: { go(to: .signup) })
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Transitions

    private static let fade = Animation.easeInOut(duration: 0.2)
    private static let resizeAnimation = Animation.smooth(duration: 0.35)

    private func detent(for step: Step) -> PresentationDetent {
        step == .prompt ? .height(promptHeight) : .large
    }

    /// Moves to another step. When the sheet changes size (the prompt to a
    /// form or back), it runs in three parts so nothing moves while visible:
    /// fade the current step out, animate the empty sheet to its new size,
    /// fade the next step in. Between sign-up and log in, both full height,
    /// it's a plain crossfade.
    private func go(to newStep: Step) {
        guard !isTransitioning, newStep != step else { return }

        guard detent(for: newStep) != detent(for: step) else {
            withAnimation(Self.fade) {
                step = newStep
                visibleStep = newStep
            }
            return
        }

        isTransitioning = true
        withAnimation(Self.fade) {
            visibleStep = nil
        } completion: {
            Task { @MainActor in
                step = newStep
                await resize(to: detent(for: newStep))
                withAnimation(Self.fade) { visibleStep = newStep }
                isTransitioning = false
            }
        }
    }

    /// Animates the sheet to `target`. iOS only animates a change of the
    /// selected detent, and only to one that's already allowed: replacing the
    /// allowed set makes the sheet jump. So allow both sizes, let that apply,
    /// animate the selection, then allow only the new size once it's there.
    private func resize(to target: PresentationDetent) async {
        detents = [selectedDetent, target]
        try? await Task.sleep(for: .milliseconds(20))
        withAnimation(Self.resizeAnimation) { selectedDetent = target }
        try? await Task.sleep(for: .milliseconds(350))
        detents = [target]
    }

    /// Changes the size without animating. The set and the selection change
    /// together so the selection is always an allowed detent.
    private func setDetent(_ detent: PresentationDetent) {
        detents = [detent]
        selectedDetent = detent
    }

    /// Back from sign-up or log in: to the prompt, or closes the sheet when it
    /// was opened straight on that step from the Profile tab.
    private func back() {
        switch prompt {
        case .favorite, .follow: go(to: .prompt)
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
                    .textStyle(.headingLG)
                    .foregroundStyle(Color.Colors.Text.primary)
                Text(prompt.message)
                    .textStyle(.bodySM)
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
            .textStyle(.bodySM)

            Button(action: onNotNow) {
                Text("Not now")
                    .textStyle(.bodySMBold)
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
