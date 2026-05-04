//
//  FavoritesView.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/18/26.
//

import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()

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
                            Text("Products you save will appear here")
                                .multilineTextAlignment(.center)
                                .font(Font.custom("Lato-Regular", size: 16))
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
                        ForEach(viewModel.favorites, id: \.id) { product in
                            ProductCardView(product: product)
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                }
            }
            .padding(.top, Spacing.xxxl)
        }
        .background(Color.Colors.Backgrounds.primary.ignoresSafeArea(.all))
        .onAppear {
            Task {
                try await viewModel.fetchFavorites()
            }
        }
    }
}

#Preview {
    FavoritesView()
}
