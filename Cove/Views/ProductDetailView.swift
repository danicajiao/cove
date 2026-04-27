//
//  ProductDetailView.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/8/22.
//

import FirebaseFirestore
import FirebaseStorage
import SwiftUI

/// A preference key to store a view's rect
struct ViewSizeKey: PreferenceKey {
    typealias Value = CGSize
    static var defaultValue = CGSize.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {}
}

struct ProductDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject var bag: Bag
    @StateObject var viewModel: ProductDetailViewModel

    let productId: String

    @State private var uiImage: UIImage?
    @State private var averageColor: Color = .Colors.Backgrounds.primary

    @State var count: Int = 1

    init(productId: String) {
        self.productId = productId
        _viewModel = StateObject(wrappedValue: ProductDetailViewModel(productId: productId))
    }

//    var rows: [GridItem] = [
//        GridItem(.adaptive(minimum: .infinity, maximum: .infinity), spacing: 20)
//    ]

    private func fetchImage() {
        guard let product = viewModel.product,
              let imageURL = URL(string: product.defaultImageURL) else { return }
        let storageRef = Storage.storage().reference(forURL: imageURL.absoluteString)

        storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
            if let error {
                print("Error fetching image: \(error.localizedDescription)")
                return
            }

            if let data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    uiImage = image
                    if let uiColor = image.averageColor {
                        averageColor = Color(uiColor) // Convert UIColor to SwiftUI Color
                    }
                }
            }
        }
    }

    var body: some View {
        Group {
            if let product = viewModel.product {
                // Product loaded, display the details
                ProductDetailContent(
                    product: product,
                    viewModel: viewModel,
                    uiImage: $uiImage,
                    averageColor: $averageColor,
                    count: $count,
                    fetchImage: fetchImage
                )
            } else {
                // Loading state
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Loading product...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, Spacing.sm)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            #if DEBUG
                print(appState.path)
            #endif
        }
    }
}

/// Extracted content view to handle the product display
private struct ProductDetailContent: View {
    let product: any Product
    @ObservedObject var viewModel: ProductDetailViewModel
    @Binding var uiImage: UIImage?
    @Binding var averageColor: Color
    @Binding var count: Int
    let fetchImage: () -> Void

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject var bag: Bag

    /// Computed properties for product-specific info
    var titleStr: String {
        if let coffeeProduct = product as? CoffeeProduct {
            return coffeeProduct.info.name
        } else if let musicProduct = product as? MusicProduct {
            return musicProduct.info.album
        } else if let apparelProduct = product as? ApparelProduct {
            return apparelProduct.info.name
        }
        return "Title"
    }

    var subtitleStr: String {
        if let coffeeProduct = product as? CoffeeProduct {
            return coffeeProduct.info.roastery
        } else if let musicProduct = product as? MusicProduct {
            return musicProduct.info.artist
        } else if let apparelProduct = product as? ApparelProduct {
            return apparelProduct.info.brand
        }
        return "Subtitle"
    }

    var price: Float {
        product.defaultPrice
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .background(
                            Color.Colors.Brand.Palette.blue
                                .padding(.top, -1000)
                        )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .onAppear {
                            fetchImage()
                        }
                        .background(
                            Color.Colors.Brand.Palette.blue
                                .padding(.top, -1000)
                        )
                }

                VStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.lg) {
                        VStack(spacing: 0) {
                            Text(titleStr)
                                .font(Font.custom("Gazpacho-Black", size: 20))
                                .foregroundStyle(Color.Colors.Fills.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(subtitleStr)
                                .font(Font.custom("Lato-Regular", size: 20))
                                .foregroundStyle(Color.Colors.Fills.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        NavigationLink(destination: Text("Item Reviews!")) {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    HStack(spacing: Spacing.md) {
                                        RatingView(rating: 4)
                                        Text("4.3")
                                            .font(Font.custom("Lato-Regular", size: 14))
                                    }
                                    Text("22 Reviews \(Image(systemName: "chevron.right"))")
                                        .font(Font.custom("Lato-Regular", size: 14))
                                        .foregroundStyle(Color.Colors.Fills.tertiary)
                                }

                                Spacer()

                                Circle()
                                    .frame(width: 35, height: 35)
                                    .foregroundStyle(Color.Colors.Fills.secondary)
                                    .overlay {
                                        Circle()
                                            .frame(width: 30, height: 30)
                                    }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.lg)
                            .background(Color.Colors.Fills.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(Color.Colors.Strokes.primary, lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())

                        ProductDetailTabs(viewModel: viewModel)
                    }
                    .padding(.horizontal, Spacing.xl)

                    Rectangle()
                        .frame(height: 3)
                        .foregroundStyle(Color.Colors.Fills.quinary)

                    VStack(spacing: Spacing.lg) {
                        SectionHeader(title: "Similar to this")

                        ScrollView(.horizontal) {
                            HStack(spacing: Spacing.md) {
                                ForEach(viewModel.similarProducts, id: \.id) { product in
                                    ProductCardView(product: product)
                                }
                            }
                        }
                        .scrollClipDisabled()
                    }
                    .padding(.horizontal, Spacing.xl)
                }
                .padding(.top, Spacing.xxxl)
                .padding(.bottom, Spacing.xl)
                .background(
                    Color.Colors.Fills.secondary
                        .padding(.bottom, -1000)
                )
            }
        }
        .overlay(alignment: .top) {
            HStack {
                BackButton()
                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color.Colors.Fills.quinary)
                HStack(spacing: Spacing.lg) {
//                    if let productId = product.id {
//                        LikeButton(productId: productId, categoryId: product.categoryId, size: 40, outlined: true)
//                    }

                    Button {
                        if !bag.bagProducts.contains(where: { bagProduct in
                            bagProduct.product.id == product.id
                        }) {
                            bag.bagProducts.append(BagProduct(product: product, quantity: count))
                            bag.totalItems += count
                        } else {
                            let indexOfExisting = bag.bagProducts.firstIndex { bagProduct in
                                bagProduct.product.id == product.id
                            }
                            guard let index = indexOfExisting else {
                                print("Failed to get local index of existing product")
                                return
                            }
                            bag.bagProducts[index].quantity += count
                            bag.totalItems += count
                        }

                        if !bag.categories.contains(where: { category in
                            category == product.categoryId
                        }) {
                            bag.categories.append(product.categoryId)
                        }

                        print(bag.bagProducts)
                    } label: {
                        Text("Add to visit list")
                    }
                    .buttonStyle(PrimaryButton())
                }
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.xl)
                .background {
                    Color.Colors.Fills.secondary.ignoresSafeArea()
                }
            }
        }
    }
}
