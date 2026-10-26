//
//  LevelOneCategories.swift
//  Cove
//

import SwiftUI

/// Display order and pill color for the level 1 categories in interest onboarding.
///
/// Presentation only: the server doesn't know this order. Level 1 categories not
/// listed here are shown after these, by name, with `fallbackColor`.
enum LevelOneCategories {
    static let styles: [(path: String, color: Color)] = [
        ("eat_drink", Color.Colors.Brand.sage),
        ("food", Color.Colors.Brand.amber),
        ("apparel", Color.Colors.Brand.blue),
        ("beauty", Color.Colors.Brand.coral),
        ("plants", Color.Colors.Brand.sage),
        ("alcohol", Color.Colors.Brand.yellow),
        ("home", Color.Colors.Brand.violet),
        ("art", Color.Colors.Brand.amber),
        ("pets", Color.Colors.Brand.coral),
        ("music", Color.Colors.Brand.blue)
    ]

    static let fallbackColor = Color.Colors.Fills.tertiary

    /// Position in the fixed order, or `nil` for an unlisted category.
    static func rank(of path: String) -> Int? {
        styles.firstIndex { $0.path == path }
    }

    static func color(for path: String) -> Color {
        styles.first { $0.path == path }?.color ?? fallbackColor
    }
}
