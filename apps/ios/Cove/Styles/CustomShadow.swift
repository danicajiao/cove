//
//  CustomShadow.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/21/25.
//

import SwiftUI

struct CustomShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0), radius: 5, x: 0, y: 16)
            .shadow(color: .black.opacity(0.01), radius: 4, x: 0, y: 10)
            .shadow(color: .black.opacity(0.02), radius: 3, x: 0, y: 6)
            .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 3)
            .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

extension View {
    func customShadow() -> some View {
        modifier(CustomShadowModifier())
    }
}

#Preview {
    Text("Hello, World!")
        .customShadow()
}
