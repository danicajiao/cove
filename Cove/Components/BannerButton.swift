//
//  BannerButton.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/9/22.
//

import SwiftUI

struct BannerButton: View {
    let bannerType: Int

    var body: some View {
        switch bannerType {
        case 1:
            Image("coffee-subscription-2048px-3198-3x2-1")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 148)
                .overlay {
                    GeometryReader { geometry in
                        VStack {
                            VStack(alignment: .leading) {
                                Text("Select craft roasters")
                                    .font(Font.custom("Gazpacho-Bold", size: 12))
                                    .frame(width: 70, alignment: .leading)

                                Spacer()

                                HStack(alignment: .center) {
                                    Text("40%")
                                        .font(Font.custom("Gazpacho-Black", size: 34))
                                    Text("off")
                                        .font(Font.custom("Gazpacho-Bold", size: 14))
                                }

                                Spacer()

                                Text("See all items \(Image(systemName: "arrow.right"))")
                                    .font(Font.custom("Lato-Regular", size: 10))
                            }
                            .padding(Spacing.lg)
                            .frame(width: geometry.size.height - (11 * 2), height: geometry.size.height - (11 * 2))
                            .background(Color.Colors.Fills.secondary)
                            .foregroundStyle(Color.Colors.Fills.primary)
                            .cornerRadius(Radius.lg)
                        }
                        .frame(width: geometry.size.height, height: geometry.size.height)
                    }
                }
                .cornerRadius(Radius.xl)
                .customShadow()
        default:
            HStack(spacing: 0) {
                VStack(alignment: .leading) {
                    Text("New")
                        .font(Font.custom("Gazpacho-Black", size: 36))
                    Text("Stumpton Huye Mountain")
                        .font(Font.custom("Lato-Regular", size: 14))
                }
                .foregroundStyle(Color.Colors.Fills.primary)
                .frame(maxWidth: .infinity)
                .padding(Spacing.xl)

                Image("How-To-Store-Coffee-Beans-Gear-Patrol-Lead-Full")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 150)
                    .clipped()
            }
            .frame(height: 120)
            .background(Color.Colors.Fills.secondary)
            .cornerRadius(Radius.xl)
            .customShadow()
        }
    }
}

struct BannerButton_Previews: PreviewProvider {
    static var previews: some View {
        BannerButton(bannerType: 1)
            .padding(.horizontal, Spacing.xl)
            .previewLayout(.sizeThatFits)

        BannerButton(bannerType: 2)
            .padding(.horizontal, Spacing.xl)
            .previewLayout(.sizeThatFits)
    }
}
