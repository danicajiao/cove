//
//  MusicProductDetails.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/9/23.
//

import FirebaseFirestore

struct MusicProductDetails: ProductDetails {
    @DocumentID var id: String?
    var about: String
    var categoryId: String
    @ServerTimestamp var createdAt: Timestamp?
    var productId: String
    var description: String
    var tracklist: [Track]

    struct Track: Codable, Hashable {
        var durationSec: Int
        var title: String
    }
}
