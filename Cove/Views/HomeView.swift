//
//  HomeView.swift
//  Cove
//
//  Created by Daniel Cajiao on 2/16/22.
//

import FirebaseFirestore
import FirebaseStorage
import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

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
                        .foregroundStyle(Color.Colors.Fills.primary)
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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.md) {
                            ForEach(viewModel.categories, id: \.self) { category in
                                SmallCategoryButton(category: category)
                            }
                        }
                    }
                    .scrollClipDisabled()
                }
                .padding(.horizontal, Spacing.xl)

                VStack(spacing: Spacing.lg) {
                    SectionHeader(title: "Featured")
                    BannerButton(bannerType: 1)
                }
                .padding(.horizontal, Spacing.xl)

                VStack(spacing: Spacing.lg) {
                    SectionHeader(title: "Popular")

                    if !viewModel.products.isEmpty {
                        LazyVGrid(
                            columns: columns,
                            alignment: .center,
                            spacing: Spacing.xl
                        ) {
                            ForEach(viewModel.products, id: \.id) { product in
                                ProductCardView(product: product)
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
                                        .fill(Color.Colors.Fills.secondary)
                                        .stroke(Color.Colors.Strokes.primary, lineWidth: 1)
                                        .frame(width: 131, height: 131)
                                        .overlay {
                                            AsyncImage(url: URL(string: brand.imageURL)) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 91, height: 91)
                                            } placeholder: {
                                                ProgressView()
                                            }
                                            .padding(Spacing.xl)
                                        }

                                    Text(brand.name)
                                        .font(Font.custom("Lato-Regular", size: 12))
                                        .foregroundStyle(Color.Colors.Fills.primary)
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
            try? await viewModel.fetchProducts(forceRefresh: true)
            try? await viewModel.fetchBrands()
        }
        .onAppear {
            print("homeView appeared")
            Task {
                try await viewModel.fetchProducts()
                try await viewModel.fetchBrands()
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
