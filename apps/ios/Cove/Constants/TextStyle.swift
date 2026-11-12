//
//  TextStyle.swift
//  Cove
//

import SwiftUI

/// The text styles from the Figma Typography page. Keep each case in sync with
/// its Figma style.
///
/// Apply one with `.textStyle(_:)`, which sets the font and letter spacing.
/// Line heights are recorded here but not applied yet: text still uses each
/// font's built-in line height.
enum TextStyle: CaseIterable {
    /// Gazpacho/Display
    case display
    /// Gazpacho/Heading XL
    case headingXL
    /// Gazpacho/Heading LG
    case headingLG
    /// Gazpacho/Heading MD
    case headingMD
    /// Gazpacho/Heading SM
    case headingSM
    /// Gazpacho/Heading XS
    case headingXS
    /// Lato/Body LG
    case bodyLG
    /// Lato/Body MD
    case bodyMD
    /// Lato/Body SM
    case bodySM
    /// Lato/Body SM Bold
    case bodySMBold
    /// Lato/Caption
    case caption
    /// Lato/Caption Bold
    case captionBold
    /// Lato/Caption SM
    case captionSM

    /// PostScript name of the font file.
    var fontName: String {
        switch self {
        case .display, .headingXL, .headingLG, .headingMD, .headingSM, .headingXS: "Gazpacho-Black"
        case .bodyLG, .bodySMBold, .captionBold: "Lato-Bold"
        case .bodyMD, .bodySM, .caption, .captionSM: "Lato-Regular"
        }
    }

    var size: CGFloat {
        switch self {
        case .display: 40
        case .headingXL: 32
        case .headingLG: 28
        case .headingMD: 24
        case .headingSM: 20
        case .headingXS: 12
        case .bodyLG: 18
        case .bodyMD: 16
        case .bodySM, .bodySMBold: 14
        case .caption, .captionBold: 12
        case .captionSM: 10
        }
    }

    /// Figma line height in points.
    var lineHeight: CGFloat {
        switch self {
        case .display: 44
        case .headingXL: 38
        case .headingLG: 34
        case .headingMD: 30
        case .headingSM: 26
        case .headingXS: 16
        case .bodyLG: 28
        case .bodyMD: 24
        case .bodySM, .bodySMBold: 20
        case .caption, .captionBold: 16
        case .captionSM: 12
        }
    }

    /// Figma letter spacing as a fraction of the font size (-4.2% is -0.042).
    var letterSpacing: CGFloat {
        switch self {
        case .display, .headingXL, .headingLG, .headingMD, .headingSM, .headingXS: -0.042
        case .bodyLG, .bodyMD, .bodySM, .bodySMBold, .caption, .captionBold, .captionSM: 0
        }
    }

    /// Letter spacing in points, for SwiftUI's `tracking`.
    var tracking: CGFloat {
        size * letterSpacing
    }

    var font: Font {
        .custom(fontName, size: size)
    }
}

extension Text {
    /// Applies a Figma text style's font and letter spacing. Returns `Text`,
    /// so styled text can still be concatenated with `+`.
    func textStyle(_ style: TextStyle) -> Text {
        font(style.font).tracking(style.tracking)
    }
}

extension View {
    /// Applies a Figma text style's font and letter spacing to all text in
    /// this view, such as a button label or text field.
    func textStyle(_ style: TextStyle) -> some View {
        font(style.font).tracking(style.tracking)
    }
}
