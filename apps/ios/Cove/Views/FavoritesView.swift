//
//  FavoritesView.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/18/26.
//

import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    @EnvironmentObject private var favoritesStore: FavoritesStore

    private var columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xl), count: 2)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                HStack {
                    Text("My Favorites")
                        .font(Font.custom("Lato-Bold", size: 26))
                    Spacer()
                }
                .padding([.leading, .trailing], Spacing.xl)

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Spacing.xxxxl)
                } else if viewModel.favorites.isEmpty {
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(Color.Colors.Fills.inverse)
                        .overlay {
                            Text("Items you save will appear here")
                                .multilineTextAlignment(.center)
                                .textStyle(.bodyMD)
                                .foregroundStyle(Color.Colors.Text.primary)
                                .padding(Spacing.xxxxl)
                        }
                        .border(Color.Colors.Strokes.primary, width: 1)
                        .frame(height: 300)
                        .padding([.leading, .trailing], Spacing.xl)
                } else {
                    LazyVGrid(
                        columns: columns,
                        alignment: .center,
                        spacing: Spacing.xl
                    ) {
                        ForEach(viewModel.favorites, id: \.id) { item in
                            ItemCard(item: item)
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                }
            }
            .padding(.top, Spacing.xxxl)
        }
        .background(Color.Colors.Backgrounds.primary.ignoresSafeArea(.all))
        .task(id: favoritesStore.favoriteIds) {
            try? await viewModel.fetchFavorites()
        }
    }
}

#Preview {
    FavoritesView()
}
