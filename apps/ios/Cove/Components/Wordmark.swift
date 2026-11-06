//
//  Wordmark.swift
//  Cove
//

import SwiftUI

/// The "Cove." wordmark. It's the logo set in Gazpacho Heavy, so it lives
/// here instead of in `TextStyle`.
struct Wordmark: View {
    enum Size {
        /// 40pt, above the Login, Signup and onboarding forms.
        case regular
        /// 60pt, on the Welcome screen.
        case large

        var points: CGFloat {
            switch self {
            case .regular: 40
            case .large: 60
            }
        }

        /// Figma line height in points. Recorded but not applied, like `TextStyle`.
        var lineHeight: CGFloat {
            switch self {
            case .regular: 44
            case .large: 66
            }
        }

        /// Matches Figma: only the Welcome wordmark is tightened, by -5%.
        var tracking: CGFloat {
            switch self {
            case .regular: 0
            case .large: points * -0.05
            }
        }
    }

    var size: Size = .regular

    var body: some View {
        Text("Cove.")
            .font(.custom("Gazpacho-Heavy", size: size.points))
            .tracking(size.tracking)
            .foregroundStyle(Color.Colors.Text.primary)
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        Wordmark(size: .large)
        Wordmark()
    }
}
