//
//  ItemDetailView.swift
//
//  Created by Daniel Cajiao on 5/8/22.
//

import SwiftUI

/// A preference key to store a view's rect
struct ViewSizeKey: PreferenceKey {
    typealias Value = CGSize
    static var defaultValue = CGSize.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {}
}

struct ItemDetailView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject var viewModel: ItemDetailViewModel

    let itemId: String

    @State private var uiImage: UIImage?
    @State private var averageColor: Color = .Colors.Backgrounds.primary

    init(itemId: String) {
        self.itemId = itemId
        _viewModel = StateObject(wrappedValue: ItemDetailViewModel(itemId: itemId))
    }

    var body: some View {
        Group {
            if let item = viewModel.item {
                // Item loaded, display the details
                ItemDetailContent(
                    item: item,
                    viewModel: viewModel,
                    uiImage: $uiImage,
                    averageColor: $averageColor
                )
            } else {
                // Loading state
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Loading item...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, Spacing.sm)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
    }
}

/// Extracted content view to handle the item display
private struct ItemDetailContent: View {
    let item: any Item
    @ObservedObject var viewModel: ItemDetailViewModel
    @Binding var uiImage: UIImage?
    @Binding var averageColor: Color

    @Environment(\.imageRepository) private var imageRepository
    @EnvironmentObject private var appState: AppState

    // MARK: - Image fetch

    private func fetchImage() async {
        // Fast path: use the pre-signed URL from the API when available.
        if let discoveryItem = item as? DiscoveryItem,
           let variants = discoveryItem.primaryImage,
           let url = variants.url(forTargetPointSize: 300)
        {
            await loadImage(from: url)
            return
        }

        // Fallback: fetch a signed URL via the image repository (legacy items).
        guard !item.defaultImageURL.isEmpty else { return }
        do {
            let url = try await imageRepository.imageURL(for: item.defaultImageURL)
            await loadImage(from: url)
        } catch {
            print("Error fetching image: \(error.localizedDescription)")
        }
    }

    private func loadImage(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                uiImage = image
                if let uiColor = image.averageColor {
                    averageColor = Color(uiColor)
                }
            }
        } catch {
            print("Error loading image: \(error.localizedDescription)")
        }
    }

    // MARK: - Computed properties

    var titleStr: String {
        (item as? DiscoveryItem)?.name ?? "Title"
    }

    /// The producer when there is one, otherwise the brand.
    var subtitleStr: String {
        (item as? DiscoveryItem)?.madeBy ?? ""
    }

    /// Places that sell the item, for the "Where to find it" section.
    var places: [DiscoveryItem.Place] {
        (item as? DiscoveryItem)?.places ?? []
    }

    var price: Float {
        item.defaultPrice
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
                            Color.Colors.Brand.blue
                                .padding(.top, -1000)
                        )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .task {
                            await fetchImage()
                        }
                        .background(
                            Color.Colors.Brand.blue
                                .padding(.top, -1000)
                        )
                }

                VStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.lg) {
                        VStack(spacing: 0) {
                            Text(titleStr)
                                .font(Font.custom("Gazpacho-Black", size: 20))
                                .foregroundStyle(Color.Colors.Text.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(subtitleStr)
                                .font(Font.custom("Lato-Regular", size: 20))
                                .foregroundStyle(Color.Colors.Text.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        NavigationLink(destination: Text("Item Reviews!")) {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    HStack(spacing: Spacing.md) {
                                        Rating(rating: 4)
                                        Text("4.3")
                                            .font(Font.custom("Lato-Regular", size: 14))
                                    }
                                    Text("22 Reviews \(Image(systemName: "chevron.right"))")
                                        .font(Font.custom("Lato-Regular", size: 14))
                                        .foregroundStyle(Color.Colors.Text.tertiary)
                                }

                                Spacer()

                                Circle()
                                    .frame(width: 35, height: 35)
                                    .foregroundStyle(Color.Colors.Fills.inverse)
                                    .overlay {
                                        Circle()
                                            .frame(width: 30, height: 30)
                                    }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.lg)
                            .background(Color.Colors.Fills.inverse)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(Color.Colors.Strokes.primary, lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())

                        ItemDetailTabs(viewModel: viewModel)
                    }
                    .padding(.horizontal, Spacing.xl)

                    if !places.isEmpty {
                        Rectangle()
                            .frame(height: 3)
                            .foregroundStyle(Color.Colors.Fills.quinary)

                        VStack(spacing: Spacing.lg) {
                            SectionHeader(title: "Where to find it")

                            VStack(spacing: Spacing.md) {
                                ForEach(places) { place in
                                    PlaceRow(place: place)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.xl)
                    }

                    Rectangle()
                        .frame(height: 3)
                        .foregroundStyle(Color.Colors.Fills.quinary)

                    VStack(spacing: Spacing.lg) {
                        SectionHeader(title: "Similar to this")

                        ScrollView(.horizontal) {
                            HStack(spacing: Spacing.md) {
                                ForEach(viewModel.similarItems, id: \.id) { item in
                                    ItemCard(item: item)
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
                    Color.Colors.Fills.inverse
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
    }
}

/// One place in the "Where to find it" list: name and place type.
private struct PlaceRow: View {
    let place: DiscoveryItem.Place

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(place.name)
                .font(Font.custom("Lato-Bold", size: 16))
                .foregroundStyle(Color.Colors.Text.primary)
            Text(place.typeLabel)
                .font(Font.custom("Lato-Regular", size: 14))
                .foregroundStyle(Color.Colors.Text.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.Colors.Fills.inverse)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(Color.Colors.Strokes.primary, lineWidth: 1))
    }
}
