//
//  TabNavigationStack.swift
//  Cove
//
//  Created by Copilot on 2/11/26.
//

import SwiftUI

struct TabNavigationStack<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(for: Path.self) { path in
                    switch path {
                    case let .item(id):
                        ItemDetailView(itemId: id)
                    case let .categoryResults(categoryPath, name):
                        CategoryResultsView(categoryPath: categoryPath, title: name)
                    default:
                        let _ = assertionFailure("Unhandled navigation path: \(path)")
                        EmptyView()
                    }
                }
        }
    }
}
