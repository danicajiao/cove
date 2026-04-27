//
//  ProductCardView.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/6/22.
//

import FirebaseFirestore
import FirebaseStorage
import SwiftUI

private struct RGBAComponents {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
}

struct ProductCardView: View {
    var product: any Product
    var titleStr: String = "Title"
    var subtitleStr: String = "Subtitle"
    var price: Float = 9

    @State private var uiImage: UIImage?
    @State private var averageColor: Color = .white // Default background color

    init(product: any Product) {
        self.product = product

        if let coffeeProduct = product as? CoffeeProduct {
            // product is a CoffeeProduct
            titleStr = coffeeProduct.info.name
            subtitleStr = coffeeProduct.info.roastery
            price = coffeeProduct.defaultPrice
        } else if let musicProduct = product as? MusicProduct {
            // product is a MusicProduct
            titleStr = musicProduct.info.album
            subtitleStr = musicProduct.info.artist
            price = musicProduct.defaultPrice
        } else if let apparelProduct = product as? ApparelProduct {
            // product is a ApparelProduct
            titleStr = apparelProduct.info.name
            subtitleStr = apparelProduct.info.brand
            price = apparelProduct.defaultPrice
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let productId = product.id {
                NavigationLink(value: Path.product(id: productId)) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())

                LikeButton(productId: productId, categoryId: product.categoryId)
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
                    .onAppear {
                        fetchImage()
                    }
            }

            VStack(spacing: Spacing.sm) {
                VStack(spacing: 0) {
                    Text(titleStr)
                        .font(Font.custom("Gazpacho-Black", size: 12))
                        .foregroundStyle(Color.Colors.Fills.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(subtitleStr)
                        .font(Font.custom("Lato-Regular", size: 12))
                        .foregroundStyle(Color.Colors.Fills.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("$\(Int(price))")
                    .font(Font.custom("Lato-SemiBold", size: 14))
                    .foregroundStyle(Color.Colors.Fills.primary)
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

    private func fetchImage() {
        guard let imageURL = URL(string: product.defaultImageURL) else { return }
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
                        print("✅ Got average color: \(uiColor)")
                        averageColor = Color(uiColor) // Convert UIColor to SwiftUI Color
                    } else {
                        print("❌ averageColor returned nil")
                    }
                }
            }
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

struct ProductCardView_Previews: PreviewProvider {
    static let product = ApparelProduct(
        id: "12345aaa",
        createdAt: Timestamp(),
        categoryId: "apparel category id",
        defaultPrice: 23,
        defaultImageURL: "some url",
        info: ApparelProduct.ApparelInfo(brand: "Some brand", name: "Some name"),
        isFavorite: true,
        productDetailsId: "12345"
    )

    static var previews: some View {
        ProductCardView(product: product)
    }
}
