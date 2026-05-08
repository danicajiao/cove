//
//  SmallSocialButton.swift
//  Cove
//
//  Created by Daniel Cajiao on 12/20/22.
//

import SwiftUI

enum SocialType {
    case apple
    case facebook
    case google
}

struct SmallSocialButton: View {
    @EnvironmentObject var appState: AppState

    @State private var presentAlert = false
    @State private var errorMessage: String?

    let socialType: SocialType
    let color: Color
    let imgName: String

    init(socialType: SocialType) {
        self.socialType = socialType

        switch self.socialType {
        case .apple:
            color = .black
            imgName = "apple"
        case .facebook:
            color = Color(red: 0.376, green: 0.537, blue: 0.839)
            imgName = "facebook"
        case .google:
            color = .white
            imgName = "google"
        }
    }

    var body: some View {
        Button {
            // TODO: Add Links to Social Provider Views // swiftlint:disable:this todo
            switch socialType {
            case .apple:
                print("Apple sign in pressed")
            case .facebook:
                print("Facebook sign in pressed")
                appState.facebookLogIn { error in
                    errorMessage = error.localizedDescription
                    presentAlert = true
                }
            case .google:
                print("Google sign in pressed")
                appState.googleLogIn { error in
                    errorMessage = error.localizedDescription
                    presentAlert = true
                }
            }
        } label: {
            Circle()
                .fill(color)
                .strokeBorder(Color.Colors.Strokes.primary, lineWidth: 1)
                .frame(width: 55, height: 55)
                .overlay {
                    Image(imgName)
                }
        }
        .alert(isPresented: $presentAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "")
            )
        }
    }
}

struct SmallSocialButton_Previews: PreviewProvider {
    static var previews: some View {
        SmallSocialButton(socialType: .google)
    }
}
