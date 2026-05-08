//
//  Bag.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/18/23.
//

import Foundation

class Bag: ObservableObject {
    @Published var bagProducts = [BagProduct]()
    @Published var total: Int = 0
    var categories = [String]()
    var totalItems: Int = 0
}

struct BagProduct: Equatable {
    static func == (lhs: BagProduct, rhs: BagProduct) -> Bool {
        lhs.product.id == rhs.product.id && lhs.quantity == rhs.quantity
    }

    var product: any Product
    var quantity: Int = 0
}
