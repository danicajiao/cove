//
//  PrimaryButton.swift
//  Cove
//
//  Created by Daniel Cajiao on 12/14/22.
//

import SwiftUI

struct PrimaryButton: PrimitiveButtonStyle {
    @State private var isPressed = false
    let width: CGFloat?
    let height: CGFloat?

    init(width: CGFloat? = .infinity, height: CGFloat? = 50) {
        self.width = width
        self.height = height
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Lato-Bold", size: 14))
            .padding()
            .frame(maxWidth: width)
            .frame(height: height)
            .foregroundStyle(Color.Colors.Fills.secondary)
            .background {
                Capsule()
                    .fill(Color.Colors.Fills.primary)
            }
            // animation defaults
            .opacity(isPressed ? 0.2 : 1)
            .animation(.default, value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            isPressed = true
                        }
                    }.onEnded { _ in
                        isPressed = false
                        configuration.trigger()
                    }
            )
    }
}

#Preview {
    Button("Press Me") {
        print("Button pressed!")
    }
    .buttonStyle(PrimaryButton())
    .padding()
}
