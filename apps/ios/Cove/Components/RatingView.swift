//
//  RatingView.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/9/22.
//

import SwiftUI

struct RatingView: View {
    @State var rating: Int

    var label = ""

    var maximumRating = 5

    var offImage: Image?
    var onImage = Image(systemName: "star.fill")

    var offColor = Color.gray
    var onColor = Color.Colors.Feedback.star

    var body: some View {
        HStack(spacing: 0) {
            if label.isEmpty == false {
                Text(label)
            }

            ForEach(1 ... maximumRating, id: \.self) { number in
                image(for: number)
                    .foregroundStyle(number > rating ? offColor : onColor)
//                    .onTapGesture {
//                        rating = number
//                    }
            }
        }
    }

    func image(for number: Int) -> Image {
        if number > rating {
            offImage ?? onImage
        } else {
            onImage
        }
    }
}

struct RatingView_Previews: PreviewProvider {
    static var previews: some View {
        RatingView(rating: 4)
    }
}
