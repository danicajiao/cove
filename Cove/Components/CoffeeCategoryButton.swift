//
//  CoffeeCategoryButton.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/9/22.
//

import SwiftUI

struct CoffeeCategoryButton: View {
    let category: String
    let cornerRadius = Radius.md

    var body: some View {
        // TODO: Refactor category buttons to have less reused code // swiftlint:disable:this todo
        // TODO: Correct text alignment // swiftlint:disable:this todo
        switch category {
        case "Fruity":
            ZStack {
                Image("jocelyn-morales-YpvaFwddSoI-unsplash")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(1.2)
                    .offset(x: 30, y: 2)
                Rectangle()
                    .foregroundStyle(Color.Colors.Category.fruity)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.black, .clear]),
                            startPoint: UnitPoint(x: 0.4, y: 0),
                            endPoint: UnitPoint(x: 0.5, y: 0)
                        )
                    )
                Text(category)
                    .font(Font.custom("Lato-Regular", size: 16))
                    .offset(x: -32, y: 0)
            }
            .frame(width: 140, height: 65)
            .mask {
                Rectangle()
            }
            .cornerRadius(cornerRadius)
        case "Choco":
            ZStack {
                Image("no-revisions-pLmTMF2Se7M-unsplash")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(2.5)
                    .offset(x: 30, y: 0)
                Rectangle()
                    .foregroundStyle(Color.Colors.Category.choco)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.black, .clear]),
                            startPoint: UnitPoint(x: 0.4, y: 0),
                            endPoint: UnitPoint(x: 0.5, y: 0)
                        )
                    )
                Text(category)
                    .font(Font.custom("Lato-Regular", size: 14))
                    .offset(x: -32, y: 0)
            }
            .frame(width: 140, height: 65)
            .mask {
                Rectangle()
            }
            .cornerRadius(cornerRadius)
        case "Citrus":
            ZStack {
                Image("am-jd-8du-1nR9OkM-unsplash")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(1.4)
                    .offset(x: 30, y: -4)
                Rectangle()
                    .foregroundStyle(Color.Colors.Category.citrus)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.black, .clear]),
                            startPoint: UnitPoint(x: 0.4, y: 0),
                            endPoint: UnitPoint(x: 0.5, y: 0)
                        )
                    )
                Text(category)
                    .font(Font.custom("Lato-Regular", size: 14))
                    .offset(x: -32, y: 0)
            }
            .frame(width: 140, height: 65)
            .mask {
                Rectangle()
            }
            .cornerRadius(cornerRadius)
        case "Earthy":
            ZStack {
                Image("jocelyn-morales-uReASzIJDBs-unsplash")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(1.0)
                    .offset(x: 30, y: 0)
                Rectangle()
                    .foregroundStyle(Color.Colors.Category.earthy)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.black, .clear]),
                            startPoint: UnitPoint(x: 0.4, y: 0),
                            endPoint: UnitPoint(x: 0.5, y: 0)
                        )
                    )
                Text(category)
                    .font(Font.custom("Lato-Regular", size: 14))
                    .offset(x: -32, y: 0)
            }
            .frame(width: 140, height: 65)
            .mask {
                Rectangle()
            }
            .cornerRadius(cornerRadius)
        default:
            ZStack {
                Image("michael-c-9qxNIXCg1Yw-unsplash")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(1.7)
                    .offset(x: 35, y: -6)
                Rectangle()
                    .foregroundStyle(Color.Colors.Category.floral)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.black, .clear]),
                            startPoint: UnitPoint(x: 0.5, y: 0),
                            endPoint: UnitPoint(x: 0.55, y: 0)
                        )
                    )
                Text(category)
                    .font(Font.custom("Lato-Regular", size: 14))
                    .offset(x: -32, y: 0)
            }
            .frame(width: 140, height: 65)
            .mask {
                Rectangle()
            }
            .cornerRadius(cornerRadius)
        }
    }
}

struct CoffeeCategoryButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            CoffeeCategoryButton(category: "Fruity")
                .previewLayout(.sizeThatFits)
            CoffeeCategoryButton(category: "Choco")
                .previewLayout(.sizeThatFits)
            CoffeeCategoryButton(category: "Citrus")
                .previewLayout(.sizeThatFits)
            CoffeeCategoryButton(category: "Earthy")
                .previewLayout(.sizeThatFits)
            CoffeeCategoryButton(category: "Preview")
                .previewLayout(.sizeThatFits)
        }
    }
}
