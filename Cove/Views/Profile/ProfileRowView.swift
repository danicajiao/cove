//
//  ProfileRowView.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/15/26.
//

import SwiftUI

struct ProfileRowView: View {
    let systemImage: String
    let label: String
    var isDestructive: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.lg) {
                Image(systemName: systemImage)
                    .frame(width: 20)
                    .foregroundStyle(foregroundColor)

                Text(label)
                    .font(Font.custom("Lato-Bold", size: 16))
                    .foregroundStyle(foregroundColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.Colors.Fills.tertiary)
            }
            .padding(.vertical, Spacing.lg)

            Divider()
        }
    }

    private var foregroundColor: Color {
        isDestructive ? Color.red : Color.Colors.Fills.primary
    }
}

struct ProfileRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            ProfileRowView(systemImage: "person", label: "Profile")
            ProfileRowView(systemImage: "doc.text", label: "Privacy Policy")
            ProfileRowView(systemImage: "lock", label: "Security and Logins")
            ProfileRowView(systemImage: "rectangle.portrait.and.arrow.right", label: "Log Out", isDestructive: true)
        }
        .padding(.horizontal, Spacing.xl)
        .background(Color.Colors.Backgrounds.primary)
    }
}
