//
//  MusicProduct.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/6/23.
//

import FirebaseFirestore

struct MusicProduct: Product {
    @DocumentID var id: String?
    @ServerTimestamp var createdAt: Timestamp?
    var categoryId: String
    var defaultPrice: Float
    var defaultImageURL: String
    var info: MusicInfo
    var isFavorite: Bool?
    var productDetailsId: String

    struct MusicInfo: Codable {
        var artist: String
        var album: String
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MusicProduct, rhs: MusicProduct) -> Bool {
        lhs.id == rhs.id
    }
}
