//
//  CoffeeProductDetails.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/11/23.
//

import FirebaseFirestore

struct CoffeeProductDetails: ProductDetails {
    @DocumentID var id: String?
    var about: String
    var categoryId: String
    @ServerTimestamp var createdAt: Timestamp?
    var productId: String
    var description: String
    var origin: [OriginInfo]

    struct OriginInfo: Codable, Hashable {
        var content: String
        var title: String
    }
}
