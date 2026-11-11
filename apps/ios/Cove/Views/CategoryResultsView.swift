//
//  CategoryResultsView.swift
//  Cove
//
//  Created by Daniel Cajiao on 6/12/26.
//

import SwiftUI

/// Discovery results scoped to a single category, pushed from a homepage
/// `CategoryCard`. Fetches `GET /discovery?category=<path>` and renders the
/// items in the same two-column grid as the home feed.
struct CategoryResultsView: View {
    let categoryPath: String
    let title: String

    @StateObject private var viewModel: CategoryResultsViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xl), count: 2)

    init(categoryPath: String, title: String) {
        self.categoryPath = categoryPath
        self.title = title
        _viewModel = StateObject(wrappedValue: CategoryResultsViewModel(categoryPath: categoryPath))
    }

    var body: some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.Colors.Backgrounds.primary.ignoresSafeArea(.all))
            .task { await viewModel.fetch() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            errorState(errorMessage)
        } else if viewModel.isEmpty {
            emptyState
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, alignment: .center, spacing: Spacing.xl) {
                    ForEach(viewModel.items, id: \.id) { item in
                        ItemCard(item: item)
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.xl)
            }
            .refreshable { await viewModel.fetch(forceRefresh: true) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(Color.Colors.Text.tertiary)
            Text("Nothing here yet")
                .textStyle(.bodyLG)
                .foregroundStyle(Color.Colors.Text.primary)
            Text("No items found in \(title).")
                .textStyle(.bodySM)
                .foregroundStyle(Color.Colors.Text.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Text(message)
                .textStyle(.bodySM)
                .foregroundStyle(Color.Colors.Text.tertiary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await viewModel.fetch(forceRefresh: true) }
            }
            .textStyle(.bodySMBold)
            .foregroundStyle(Color.Colors.Brand.accent)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        CategoryResultsView(categoryPath: "food.coffee", title: "Coffee")
            .environmentObject(FavoritesStore())
    }
}
