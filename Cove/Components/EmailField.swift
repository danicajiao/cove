//
//  EmailField.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/7/25.
//

import SwiftUI

struct EmailField: View {
    @Binding var text: String
    @FocusState.Binding var focus: Field?

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text("Email")
                .font(.custom("Lato-Bold", size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Color.Colors.Text.tertiary)
            TextField(String("email@example.com"), text: $text)
                .font(.custom("Lato-Regular", size: 14))
                .padding()
                .frame(maxWidth: .infinity, maxHeight: 50)
                .background(Color.Colors.Fills.inverse)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.Colors.Strokes.primary, lineWidth: 1)
                )
                .focused($focus, equals: Field.email)
                .onTapGesture {
                    focus = Field.email
                }
        }
    }
}

#Preview {
    @Previewable @State var email = ""
    @Previewable @FocusState var focusedField: Field?

    EmailField(text: $email, focus: $focusedField)
        .padding()
        .background(Color.Colors.Backgrounds.secondary)
        .onAppear {
            focusedField = Field.email
        }
}
