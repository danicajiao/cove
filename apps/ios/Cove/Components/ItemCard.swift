//
//  ItemCard.swift
//
//  Created by Daniel Cajiao on 3/6/22.
//

import SwiftUI

private struct RGBAComponents {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
}

struct ItemCard: View {
    var item: any Item
    var titleStr: String = "Title"
    var subtitleStr: String = "Subtitle"
    var price: Float = 9

    @Environment(\.imageRepository) private var imageRepository

    @State private var uiImage: UIImage?
    @State private var averageColor: Color = .white // Default background color

    init(item: any Item) {
        self.item = item

        if let discoveryItem = item as? DiscoveryItem {
            titleStr = discoveryItem.name
            subtitleStr = discoveryItem.madeBy
            price = discoveryItem.defaultPrice
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let itemId = item.id {
                NavigationLink(value: Path.item(id: itemId)) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())

                LikeButton(itemId: itemId, categoryId: item.categoryId)
                    .padding(Spacing.sm)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit) // Maintain aspect ratio
                    .frame(maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxHeight: .infinity)
                    .task {
                        await fetchImage()
                    }
            }

            VStack(spacing: Spacing.sm) {
                VStack(spacing: 0) {
                    Text(titleStr)
                        .font(Font.custom("Gazpacho-Black", size: 12))
                        .foregroundStyle(Color.Colors.Text.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(subtitleStr)
                        .font(Font.custom("Lato-Regular", size: 12))
                        .foregroundStyle(Color.Colors.Text.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("$\(Int(price))")
                    .font(Font.custom("Lato-SemiBold", size: 14))
                    .foregroundStyle(Color.Colors.Text.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.sm)
            .background(.white)
        }
        .frame(maxWidth: .infinity) // Take up the full width of the column
        .frame(minWidth: 171)
        .frame(height: 239)
        .background(averageColor)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .customShadow()
    }

    private func fetchImage() async {
        // Fast path: use the pre-signed URL from the API when available.
        if let discoveryItem = item as? DiscoveryItem,
           let variants = discoveryItem.primaryImage,
           let url = variants.url(forTargetPointSize: 171)
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
                    print("✅ Got average color: \(uiColor)")
                    averageColor = Color(uiColor)
                } else {
                    print("❌ averageColor returned nil")
                }
            }
        } catch {
            print("Error loading image: \(error.localizedDescription)")
        }
    }
}

extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else {
            print("❌ Failed to create CIImage")
            return nil
        }

        // Calculate average color for the entire image
        guard let color = averageColor(for: inputImage, in: inputImage.extent) else {
            return nil
        }

        // Convert RGB to HSB to boost vibrancy
        let averageUIColor = UIColor(red: color.red, green: color.green, blue: color.blue, alpha: 1.0)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        averageUIColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Boost saturation and brightness for vibrant pastels
        let boostedSaturation: CGFloat = 0.1 // Fixed moderate saturation for vibrancy
        let boostedBrightness: CGFloat = 0.98 // Very light brightness for pastel look

        return UIColor(hue: hue, saturation: boostedSaturation, brightness: boostedBrightness, alpha: 1.0)
    }

    private func averageColor(for inputImage: CIImage, in rect: CGRect) -> RGBAComponents? {
        let extentVector = CIVector(x: rect.origin.x, y: rect.origin.y, z: rect.size.width, w: rect.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]),
              let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let red = CGFloat(bitmap[0]) / 255
        let green = CGFloat(bitmap[1]) / 255
        let blue = CGFloat(bitmap[2]) / 255
        let alpha = CGFloat(bitmap[3]) / 255

        return RGBAComponents(red: red, green: green, blue: blue, alpha: alpha)
    }
}

#Preview {
    ItemCard(
        item: DiscoveryItem(
            id: "12345aaa",
            createdAt: nil,
            categoryId: "",
            defaultPrice: 23,
            defaultImageURL: "",
            isFavorite: true,
            itemDetailsId: "12345aaa",
            name: "Southern Weather Blend",
            producerName: "Onyx Coffee Lab",
            producerID: nil,
            brand: nil,
            itemDescription: nil,
            places: [],
            primaryImage: nil,
            media: []
        )
    )
}
