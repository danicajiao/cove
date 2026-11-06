//
//  PrimaryButton.swift
//  Cove
//
//  Created by Daniel Cajiao on 12/14/22.
//

import SwiftUI

struct PrimaryButton: PrimitiveButtonStyle {
    @State private var isPressed = false
    /// `.disabled(true)` blocks taps but doesn't change a custom style's look,
    /// so dim it to match the Large Button's Disabled state in Figma.
    @Environment(\.isEnabled) private var isEnabled
    let width: CGFloat?
    let height: CGFloat?

    init(width: CGFloat? = .infinity, height: CGFloat? = 50) {
        self.width = width
        self.height = height
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.bodySMBold)
            .padding()
            .frame(maxWidth: width)
            .frame(height: height)
            .foregroundStyle(Color.Colors.Fills.inverse)
            .background {
                Capsule()
                    .fill(Color.Colors.Fills.primary)
            }
            // animation defaults
            .opacity(isPressed ? 0.2 : isEnabled ? 1 : 0.4)
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
    VStack {
        Button("Press Me") {
            print("Button pressed!")
        }
        .buttonStyle(PrimaryButton())

        Button("Disabled") {}
            .buttonStyle(PrimaryButton())
            .disabled(true)
    }
    .padding()
}
