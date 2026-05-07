//
//  Radius.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/24/25.
//

import CoreFoundation

/// Named corner radius constants matching the Figma `Radius` variable collection.
///
/// Use these instead of raw `CGFloat` values so that corner radii stay in
/// sync with the design system.
///
/// Reference: `docs/DESIGN_SYSTEM.md` — Corner Radius section
///
/// Usage:
/// ```swift
/// .cornerRadius(Radius.md)   // buttons, list rows
/// .cornerRadius(Radius.lg)   // cards, sheets
/// ```
enum Radius {
    /// 0pt — dividers, full-width elements, ruled lines
    static let none: CGFloat = 0
    /// 2pt — tags, badges, small chips
    static let xs: CGFloat = 2
    /// 4pt — input fields, tooltips, small overlays
    static let sm: CGFloat = 4
    /// 8pt — buttons, list rows, image thumbnails
    static let md: CGFloat = 8
    /// 10pt — cards, sheets, action menus
    static let lg: CGFloat = 10
    /// 16pt — large cards, modals, featured banners
    static let xl: CGFloat = 16
    /// 9999pt — pills, avatar chips, toggle tracks
    static let full: CGFloat = 9999
}
