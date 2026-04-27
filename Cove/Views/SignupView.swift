//
//  SignupView.swift
//  Cove
//
//  Created by Daniel Cajiao on 1/1/23.
//

import FirebaseAuth
import SwiftUI

struct SignupView: View {
    @EnvironmentObject private var appState: AppState

    @State private var presentAlert = false
    @State private var errorMessage: String?

    @State var email: String = ""
    @State var password: String = ""
    @State var loading: Bool = false

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: Spacing.xl) {
                Text("Cove.")
                    .font(.custom("Gazpacho-Heavy", size: 40))
                    .foregroundStyle(Color.Colors.Fills.primary)

                SpectrumDivider()

                Group {
                    Text("Create your account")
                        .font(.custom("Lato-Bold", size: 28))
                        .foregroundStyle(Color.Colors.Fills.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: Spacing.xs) {
                        CustomTextField(
                            placeholder: "email@provider.com",
                            text: $email,
                            returnKeyType: .next,
                            autocapitalizationType: UITextAutocapitalizationType.none,
                            keyboardType: .emailAddress,
                            textContentType: .username,
                            label: "Email",
                            tag: 0
                        )
                        CustomTextField(
                            placeholder: "Password",
                            text: $password,
                            isSecureTextEntry: true,
                            returnKeyType: .done,
                            keyboardType: .default,
                            textContentType: .password, // update to .newPassword once enrolled in ADP
                            label: "Password",
                            tag: 1
                        )
                        HStack {
                            Text("Passwords must contain at least 8 characters.")
                                .font(.custom("Lato-Regular", size: 12))
                                .foregroundStyle(Color.Colors.Fills.tertiary)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.md)
                    }
                }

                VStack(spacing: Spacing.md) {
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
                            Text("Sign Up")
                        } else {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .buttonStyle(PrimaryButton())
                    .alert(isPresented: $presentAlert) {
                        Alert(
                            title: Text("Login Failed"),
                            message: Text(errorMessage ?? "Missing error message"),
                            dismissButton: .default(Text("OK"))
                        )
                    }

                    HStack {
                        Text("By signing up, you are agreeing to our Terms of Service. View our Privacy Policy.")
                            .font(.custom("Lato-Regular", size: 12))
                            .foregroundStyle(Color.Colors.Fills.tertiary)
                    }
                    .padding(.horizontal, Spacing.md)
                }

                HStack(spacing: Spacing.md) {
                    Capsule()
                        .fill(Color.Colors.Fills.quaternary)
                        .frame(width: 100, height: 2)
                        .padding(.horizontal, Spacing.md)
                    Text("OR")
                        .font(.custom("Lato-Regular", size: 12))
                        .foregroundStyle(Color.Colors.Fills.quaternary)
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
                    Text("Already have an email account? ")
                        .font(.custom("Lato-Regular", size: 14))
                        .foregroundStyle(Color.Colors.Fills.tertiary)
                    Button {
                        appState.path.append(.login)
                    } label: {
                        Text("Log in")
                            .font(.custom("Lato-Regular", size: 14))
                            .underline()
                            .foregroundStyle(Color.Colors.Fills.primary)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Spacing.xl)
            .background(Color.Colors.Backgrounds.primary)
            .overlay(alignment: .topLeading) {
                BackButton()
                    .padding(Spacing.xl)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                print(appState.path)
            }
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
        .ignoresSafeArea(.keyboard, edges: .all)
    }
}

struct SignupView_Previews: PreviewProvider {
    static let appState = AppState()
    static var previews: some View {
        SignupView()
            .environmentObject(appState)
    }
}
