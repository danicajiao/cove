//
//  BackButton.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/7/25.
//

import SwiftUI

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Circle()
                .fill(Color.Colors.Fills.secondary)
                .strokeBorder(Color.Colors.Strokes.primary, lineWidth: 1)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "arrow.left")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.Colors.Fills.primary)
                }
        }
    }
}

#Preview {
    BackButton()
}
