//
//  TabNavigationStack.swift
//  Cove
//
//  Created by Copilot on 2/11/26.
//

import SwiftUI

struct TabNavigationStack<Content: View>: View {
    @EnvironmentObject var bag: Bag
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(for: Path.self) { path in
                    switch path {
                    case let .product(id):
                        ProductDetailView(productId: id)
                            .environmentObject(bag)
                    default:
                        #if DEBUG
                            let _ = print("⚠️ Unhandled navigation path in TabNavigationStack: \(path)")
                        #endif
                        EmptyView()
                    }
                }
        }
    }
}
