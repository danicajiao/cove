//
//  Spacing.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/24/25.
//

import CoreFoundation

/// Named spacing constants matching the Figma `Spacing` variable collection.
///
/// Based on a 4pt grid. Use these instead of raw `CGFloat` values so that
/// spacing stays in sync with the design system.
///
/// Reference: `docs/DESIGN_SYSTEM.md` — Spacing section
///
/// Usage:
/// ```swift
/// .padding(.horizontal, Spacing.lg)
/// .padding(.bottom, Spacing.xxl)
/// VStack(spacing: Spacing.md) { ... }
/// ```
enum Spacing {
    /// 4pt — icon/label gap, tight component internals
    static let xs: CGFloat = 4
    /// 8pt — label → input gap, icon margins, badge padding
    static let sm: CGFloat = 8
    /// 12pt — between components in a group, cell padding
    static let md: CGFloat = 12
    /// 16pt — screen edge inset, row vertical padding, card internals
    static let lg: CGFloat = 16
    /// 20pt — between form fields, button vertical padding
    static let xl: CGFloat = 20
    /// 24pt — card-to-card gap, section breathing room
    static let xxl: CGFloat = 24
    /// 32pt — major section separators, modal padding
    static let xxxl: CGFloat = 32
    /// 48pt — hero spacing, top-of-screen clearance
    static let xxxxl: CGFloat = 48
}
