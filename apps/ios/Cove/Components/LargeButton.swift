//
//  LargeButton.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/5/23.
//

import SwiftUI

struct LargeButton: View {
    let category: String

    var body: some View {
        switch category {
        case "Music":
            Rectangle()
                .foregroundStyle(.clear)
                .overlay {
                    Image("727a7238365525.576d3001c7656 2")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .overlay(alignment: .topLeading) {
                    Text(category)
                        .font(Font.custom("Lato-Regular", size: 14))
                        .padding(Spacing.sm)
                }
                .frame(width: 140, height: 200)
                .cornerRadius(Radius.md)
        case "Coffee":
            Rectangle()
                .foregroundStyle(.clear)
                .overlay {
                    Image("coffee-subscription-2048px-3198-3x2-1")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .offset(x: 120, y: 0)
                }
                .overlay(alignment: .topLeading) {
                    Text(category)
                        .font(Font.custom("Lato-Regular", size: 14))
                        .padding(Spacing.sm)
                }
                .frame(width: 140, height: 200)
                .cornerRadius(Radius.md)
        case "Home":
            Rectangle()
                .foregroundStyle(.clear)
                .overlay {
                    Image("6a24c9162480919.63d6b3eceb963")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(2.0)
                        .offset(x: 25, y: 30)
                }
                .overlay(alignment: .topLeading) {
                    Text(category)
                        .font(Font.custom("Lato-Regular", size: 14))
                        .padding(Spacing.sm)
                }
                .frame(width: 140, height: 200)
                .cornerRadius(Radius.md)
        case "Bevs":
            Rectangle()
                .foregroundStyle(.clear)
                .overlay {
                    Image("58533a99308279.5ef03e3c0da5a")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .rotationEffect(.degrees(90))
                        .scaleEffect(0.65)
                        .offset(x: 10, y: 25)
                }
                .overlay(alignment: .topLeading) {
                    Text(category)
                        .font(Font.custom("Lato-Regular", size: 14))
                        .padding(Spacing.sm)
                }
                .background(Color(red: 255 / 255, green: 252 / 255, blue: 246 / 255))
                .frame(width: 140, height: 200)
                .cornerRadius(Radius.md)
        default:
            Rectangle()
                .foregroundStyle(.clear)
                .overlay {
                    Image("817b69111912037.600a933bbd858")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(2.5)
                        .offset(x: 30, y: 50)
                }
                .overlay(alignment: .topLeading) {
                    Text(category)
                        .font(Font.custom("Lato-Regular", size: 14))
                        .padding(Spacing.sm)
                }
                .background(Color(red: 255 / 255, green: 252 / 255, blue: 246 / 255))
                .frame(width: 140, height: 200)
                .cornerRadius(Radius.md)
        }
    }
}

struct LargeButton_Previews: PreviewProvider {
    static var previews: some View {
        LargeButton(category: "Preview")
            .previewLayout(.sizeThatFits)
    }
}
