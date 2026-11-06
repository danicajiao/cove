//
//  GazpachoHeading.swift
//  Cove
//

import SwiftUI

extension Text {
    /// Gazpacho Black heading text, matching the Figma `Gazpacho/*` text styles:
    /// Display 40, Heading XL 32, LG 28, MD 24 and SM 20, all with -5% letter spacing.
    ///
    /// Figma's percentage letter spacing is relative to the font size, so the
    /// SwiftUI tracking in points is `size × -0.05`.
    func gazpachoHeading(size: CGFloat) -> Text {
        font(.custom("Gazpacho-Black", size: size))
            .tracking(size * -0.05)
    }
}
