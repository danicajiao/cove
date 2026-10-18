//
//  HomeView.swift
//  Cove
//
//  Created by Daniel Cajiao on 2/16/22.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var favoritesStore: FavoritesStore

    @State var search: String = ""

//    private var columns: [GridItem] = [
//        GridItem(.adaptive(minimum: 100, maximum: .infinity), spacing: 20),
//        GridItem(.adaptive(minimum: 100, maximum: .infinity), spacing: 20)
//    ]

    private var columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 2)

    var body: some View {
        let _ = Self._printChanges()
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                HStack(spacing: Spacing.md) {
                    // TODO: Implement time-based greeting message // swiftlint:disable:this todo
                    Text("Good morning, Daniel")
                        .frame(width: 300, alignment: .leading)
                        .font(Font.custom("Gazpacho-Black", size: 28))
                        .lineSpacing(6) // SwiftUI lineSpacing = Figma line height - Font size
                        .foregroundStyle(Color.Colors.Text.primary)
                    Spacer()
                    // TODO: Add notifications button to the right of greeting Text // swiftlint:disable:this todo
                    Image(systemName: "bell.fill")
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundStyle(Color.Colors.Brand.accent)
                }
                .padding(.horizontal, Spacing.xl)

                CustomTextField(
                    placeholder: "Find records, coffee, home, and more",
                    text: $search,
                    returnKeyType: .next,
                    autocapitalizationType: UITextAutocapitalizationType.none,
                    keyboardType: .default,
                    leftIcon: "magnifyingglass",
                    tag: 0
                )
                .padding(.horizontal, Spacing.xl)

                VStack {
                    SectionHeader(title: "Categories")

                    if viewModel.isLoadingCategories {
                        ProgressView()
                            .frame(height: 80)
                            .frame(maxWidth: .infinity)
                    } else if viewModel.categories.isEmpty {
                        Text("No categories yet")
                            .font(Font.custom("Lato-Regular", size: 14))
                            .foregroundStyle(Color.Colors.Text.tertiary)
                            .frame(height: 80)
                            .frame(maxWidth: .infinity)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: Spacing.md) {
                                ForEach(viewModel.categories, id: \.id) { category in
                                    CategoryCard(
                                        category: category,
                                        imageURL: viewModel.categoryImageURLs[category.path]
                                    ) {
                                        viewModel.recordCategoryTap(category)
                                    }
                                }
                            }
                        }
                        .scrollClipDisabled()
                    }
                }
                .padding(.horizontal, Spacing.xl)

                VStack(spacing: Spacing.lg) {
                    SectionHeader(title: "Featured")
                    BannerButton(bannerType: 1)
                }
                .padding(.horizontal, Spacing.xl)

                VStack(spacing: Spacing.lg) {
                    SectionHeader(title: "Popular")

                    if !viewModel.items.isEmpty {
                        LazyVGrid(
                            columns: columns,
                            alignment: .center,
                            spacing: Spacing.xl
                        ) {
                            ForEach(viewModel.items, id: \.id) { item in
                                ItemCard(item: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)

                BannerButton(bannerType: 2)
                    .padding(.horizontal, Spacing.xl)

                VStack(spacing: Spacing.lg) {
                    SectionHeader(title: "Stores")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Spacing.md) {
                            ForEach(viewModel.brands, id: \.id) { brand in
                                VStack(spacing: Spacing.xs) {
                                    Circle()
                                        .fill(Color.Colors.Fills.inverse)
                                        .stroke(Color.Colors.Strokes.primary, lineWidth: 1)
                                        .frame(width: 131, height: 131)
                                        .overlay {
                                            BrandLogo(imageKey: brand.imageURL)
                                        }

                                    Text(brand.name)
                                        .font(Font.custom("Lato-Regular", size: 12))
                                        .foregroundStyle(Color.Colors.Text.primary)
                                        .frame(width: 100)
                                        .multilineTextAlignment(.center)
                                        .truncationMode(.tail)
                                }
                            }
                        }
                    }
                    .scrollClipDisabled()
                }
                .padding(.horizontal, Spacing.xl)
            }
            .padding(.top, Spacing.xxxl)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.Colors.Backgrounds.primary.ignoresSafeArea(.all))
        .refreshable {
            try? await viewModel.fetchItems(forceRefresh: true)
            try? await viewModel.fetchBrands()
        }
        .onAppear {
            print("homeView appeared")
            Task {
                await viewModel.fetchCategories()
                try await viewModel.fetchItems()
                try await viewModel.fetchBrands()
                await favoritesStore.loadFavorites()
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
