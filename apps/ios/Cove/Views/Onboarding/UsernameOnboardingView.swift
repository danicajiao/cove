//
//  UsernameOnboardingView.swift
//  Cove
//

import SwiftUI

struct UsernameOnboardingView: View {
    @StateObject private var viewModel: UsernameOnboardingViewModel

    init(appState: AppState) {
        _viewModel = StateObject(wrappedValue: UsernameOnboardingViewModel(appState: appState))
    }

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: Spacing.xl) {
                Text("Cove.")
                    .font(.custom("Gazpacho-Heavy", size: 40))
                    .foregroundStyle(Color.Colors.Text.primary)

                SpectrumDivider()

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Choose a username")
                        .font(.custom("Gazpacho-Black", size: 28))
                        .tracking(-1.4) // Figma letter spacing -5% × 28pt
                        .foregroundStyle(Color.Colors.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("This is how others will find you on Cove.")
                        .font(.custom("Lato-Regular", size: 14))
                        .foregroundStyle(Color.Colors.Text.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    CustomTextField(
                        placeholder: "yourname",
                        text: $viewModel.username,
                        returnKeyType: .done,
                        autocapitalizationType: .none,
                        keyboardType: .asciiCapable,
                        textContentType: .username,
                        label: "Username",
                        tag: 0,
                        onCommit: {
                            Task { await viewModel.submit() }
                        }
                    )

                    if let error = viewModel.validationError ?? viewModel.serverError {
                        Text(error)
                            .font(.custom("Lato-Regular", size: 12))
                            .foregroundStyle(Color.Colors.Support.Error.fg)
                            .padding(.horizontal, Spacing.md)
                    } else {
                        Text("3–30 characters. Letters, numbers, and underscores.")
                            .font(.custom("Lato-Regular", size: 12))
                            .foregroundStyle(Color.Colors.Text.tertiary)
                            .padding(.horizontal, Spacing.md)
                    }
                }

                Button {
                    Task { await viewModel.submit() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Continue")
                    }
                }
                .buttonStyle(PrimaryButton())
                .disabled(!viewModel.canSubmit)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Spacing.xl)
            .background(Color.Colors.Backgrounds.primary)
            .toolbar(.hidden, for: .navigationBar)
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .all)
    }
}

#Preview {
    UsernameOnboardingView(appState: AppState())
}
