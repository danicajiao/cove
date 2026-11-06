//
//  LoginView.swift
//  Cove
//
//  Created by Daniel Cajiao on 12/16/22.
//

import FirebaseAuth
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState

    var onBack: () -> Void
    var onNavigateToSignup: () -> Void

    @State private var presentAlert = false
    @State private var errorMessage: String?

    @State var email: String = ""
    @State var password: String = ""
    @State var loading: Bool = false

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: Spacing.xl) {
                Wordmark()

                SpectrumDivider()

                Group {
                    Text("Log in to your account")
                        .textStyle(.headingLG)
                        .foregroundStyle(Color.Colors.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: Spacing.xs) {
                        CustomTextField(
                            placeholder: "name@example.com",
                            text: $email,
                            returnKeyType: .next,
                            autocapitalizationType: UITextAutocapitalizationType.none,
                            keyboardType: .emailAddress,
                            textContentType: .username,
                            label: "Email",
                            tag: 0
                        )
                        CustomTextField(
                            placeholder: "",
                            text: $password,
                            isSecureTextEntry: true,
                            returnKeyType: .done,
                            keyboardType: .default,
                            textContentType: .password,
                            label: "Password",
                            tag: 1
                        )
                        HStack {
                            Button {
                                print("TODO: nav to forgot password view")
                            } label: {
                                Text("Forgot password?")
                                    .textStyle(.caption)
                                    .underline()
                                    .foregroundStyle(Color.Colors.Text.tertiary)
                            }
                            Spacer()
                            Button {
                                print("TODO: auth with Face ID")
                            } label: {
                                Text("Face ID \(Image(systemName: "faceid"))")
                                    .textStyle(.bodySM)
                                    .foregroundStyle(Color.Colors.Text.tertiary)
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                    }
                }

                Button {
                    loading = true
                    appState.emailLogIn(
                        email: email,
                        password: password,
                        onFailure: { error in
                            presentAlert = true
                            errorMessage = error?.localizedDescription
                            loading = false
                        },
                        onSuccess: {
                            // onSuccess work here
                            loading = false
                        }
                    )
                } label: {
                    if !loading {
                        Text("Log in")
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .buttonStyle(PrimaryButton())
                .alert(isPresented: $presentAlert) {
                    Alert(title: Text("Login Failed"), message: Text(errorMessage ?? "Missing error message"), dismissButton: .default(Text("OK")))
                }

                HStack(spacing: Spacing.md) {
                    Capsule()
                        .fill(Color.Colors.Fills.quaternary)
                        .frame(width: 100, height: 2)
                        .padding(.horizontal, Spacing.md)
                    Text("OR")
                        .textStyle(.caption)
                        .foregroundStyle(Color.Colors.Text.quaternary)
                    Capsule()
                        .fill(Color.Colors.Fills.quaternary)
                        .frame(width: 100, height: 2)
                        .padding(.horizontal, Spacing.md)
                }

                // TODO: Add Links to Social Provider Views // swiftlint:disable:this todo
                HStack(spacing: Spacing.xxl) {
                    SmallSocialButton(socialType: .apple)
                    SmallSocialButton(socialType: .facebook)
                    SmallSocialButton(socialType: .google)
                }

                HStack(spacing: Spacing.xs) {
                    Text("Don't have an account? ")
                        .textStyle(.bodySM)
                        .foregroundStyle(Color.Colors.Text.tertiary)
                    Button {
                        onNavigateToSignup()
                    } label: {
                        Text("Sign up")
                            .textStyle(.bodySM)
                            .underline()
                            .foregroundStyle(Color.Colors.Text.primary)
                    }
                }

                Spacer()
            }
            .padding(Spacing.xl)
            .background(Color.Colors.Backgrounds.primary)
            .overlay(alignment: .topLeading) {
                BackButton(action: onBack)
                    .padding(Spacing.xl)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onDisappear {
                email = ""
                password = ""
            }
            .contentShape(Rectangle()) // Makes the entire view tappable
            .onTapGesture {
                // Dismiss the keyboard
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct LoginView_Previews: PreviewProvider {
    static let appState = AppState()
    static var previews: some View {
        LoginView(onBack: {}, onNavigateToSignup: {})
            .environmentObject(appState)
    }
}
