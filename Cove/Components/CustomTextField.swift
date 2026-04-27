//
//  CustomTextField.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/7/25.
//

import SwiftUI
import UIKit

enum Field: Hashable {
    case email
    case password
}

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    @State var isSecureTextEntry: Bool
    @State var isHidden: Bool?

    var returnKeyType: UIReturnKeyType
    var autocapitalizationType: UITextAutocapitalizationType
    var keyboardType: UIKeyboardType
    var textContentType: UITextContentType?
    var uiFont: UIFont?
    var label: String?
    var leftIcon: String?

    var tag: Int?
    var inputAccessoryView: UIToolbar?

    var onCommit: (() -> Void)?

    init(
        placeholder: String,
        text: Binding<String>,
        isSecureTextEntry: Bool = false,
        returnKeyType: UIReturnKeyType,
        autocapitalizationType: UITextAutocapitalizationType = .none,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        uiFont: UIFont? = UIFont(name: "Lato-Regular", size: 14),
        label: String? = nil,
        leftIcon: String? = nil,
        tag: Int? = nil,
        inputAccessoryView: UIToolbar? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        _text = text
        self.isSecureTextEntry = isSecureTextEntry
        isHidden = isSecureTextEntry
        self.returnKeyType = returnKeyType
        self.autocapitalizationType = autocapitalizationType
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.uiFont = uiFont
        self.label = label
        self.leftIcon = leftIcon
        self.tag = tag
        self.inputAccessoryView = inputAccessoryView
        self.onCommit = onCommit
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            if label != nil {
                Text(label ?? "")
                    .font(.custom("Lato-Bold", size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .foregroundStyle(Color.Colors.Fills.tertiary)
            }
            HStack(spacing: Spacing.md) {
                if let leftIcon {
                    Image(systemName: leftIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.Colors.Fills.quaternary)
                }
                UITextFieldRepresentable(
                    placeholder: placeholder,
                    text: $text,
                    isHidden: $isHidden,
                    returnKeyType: returnKeyType,
                    autocapitalizationType: autocapitalizationType,
                    keyboardType: keyboardType,
                    textContentType: textContentType,
                    uiFont: uiFont,
                    tag: tag
                )
                if isSecureTextEntry {
                    Button {
                        isHidden?.toggle()
                    } label: {
                        Image(systemName: (isHidden ?? true) ? "eye.slash" : "eye")
                            .foregroundStyle(Color.Colors.Fills.quaternary)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: 50)
            .background(.white)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(Color.Colors.Strokes.primary, lineWidth: 1)
            }
        }
    }
}

private struct UITextFieldRepresentable: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var isHidden: Bool?

    var returnKeyType: UIReturnKeyType = .default
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var uiFont: UIFont?

    var tag: Int?
    var inputAccessoryView: UIToolbar?

    var onCommit: (() -> Void)?

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.placeholder = placeholder

        textField.returnKeyType = returnKeyType
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = .no
        textField.keyboardType = keyboardType
        textField.isSecureTextEntry = isHidden ?? false
        textField.textContentType = textContentType
        textField.textAlignment = .left
        textField.font = uiFont

        if let tag {
            textField.tag = tag
        }

        textField.inputAccessoryView = inputAccessoryView
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)

        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        print("updateUI HIT: \(placeholder)")
        uiView.text = text
        uiView.isSecureTextEntry = isHidden ?? false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let parent: UITextFieldRepresentable

        init(_ parent: UITextFieldRepresentable) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            print("textFieldDidBeginEditing HIT")
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            print("textFieldShouldReturn HIT")
            if let nextField = textField.superview?.superview?.viewWithTag(textField.tag + 1) as? UITextField {
                nextField.becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
            return false
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onCommit?()
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}

#Preview {
    @Previewable @State var email = ""
    @Previewable @State var password = ""

    VStack {
        Text("email: \(email)")
        Text("password: \(password)")
        CustomTextField(
            placeholder: "email@provider.com",
            text: $email,
            returnKeyType: .next,
            label: "Email",
            leftIcon: "envelope",
            tag: 0
        )
        CustomTextField(
            placeholder: "Password",
            text: $password,
            isSecureTextEntry: true,
            returnKeyType: .done,
            label: "Password",
            tag: 1
        )
    }
    .padding()
}
