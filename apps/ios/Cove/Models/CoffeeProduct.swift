//
//  CoffeeProduct.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/6/23.
//

import FirebaseFirestore

struct CoffeeProduct: Product {
    @DocumentID var id: String?
    @ServerTimestamp var createdAt: Timestamp?
    var categoryId: String
    var defaultPrice: Float
    var defaultImageURL: String
    var info: CoffeeInfo
    var isFavorite: Bool?
    var productDetailsId: String

//    internal enum CodingKeys : String, CodingKey {
//        case id
//        case createdAt
//        case categoryId
//        case defaultPrice
//        case defaultImageURL
//        case info
//        case sku
//    }

    struct CoffeeInfo: Codable {
        var name: String
        var roastery: String

//        enum InfoCodingKeys : String, CodingKey {
//            case name
//            case roastery
//        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CoffeeProduct, rhs: CoffeeProduct) -> Bool {
        lhs.id == rhs.id
    }

//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//
//        id = try container.decode(DocumentID<DocumentReference>.self, forKey: .id).wrappedValue?.documentID
//        createdAt = try container.decode(Timestamp.self, forKey: .createdAt).dateValue()
//        categoryId = try container.decode(DocumentReference.self, forKey: .categoryId)
//        defaultPrice = try container.decode(Float.self, forKey: .defaultPrice)
//        defaultImageURL = try container.decode(String.self, forKey: .defaultImageURL)
//
//        let infoContainer = try container.nestedContainer(keyedBy: Info.InfoCodingKeys.self, forKey: .info)
//
//        let name = try infoContainer.decode(String.self, forKey: Info.InfoCodingKeys.name)
//        let roastery = try infoContainer.decode(String.self, forKey: Info.InfoCodingKeys.roastery)
//        info = Info(name: name, roastery: roastery)
//
//        sku = try container.decode(String.self, forKey: .sku)
//    }

//    init(defaultPrice: Float, defaultImgPath: String, createdAt: Timestamp, sku: String, categoryId: DocumentReference, info: Info) {
//        self.sku = sku
//        self.categoryId = categoryId
//        self.info = info
//        super.init(defaultPrice: defaultPrice, defaultImgPath: defaultImgPath, createdAt: createdAt)
//    }
//
//    // This initializer is used for previews
//    init(defaultPrice: Float, defaultImgPath: String, imgData: Data, createdAt: Timestamp, sku: String, categoryId: DocumentReference, info: Info) {
//        self.sku = sku
//        self.categoryId = categoryId
//        self.info = info
//        super.init(defaultPrice: defaultPrice, defaultImgPath: defaultImgPath, imgData: imgData, createdAt: createdAt)
//    }

//    override func encode(to encoder: Encoder) throws {
//        try super.encode(to: encoder)
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(brand, forKey: .brand)
//        try container.encode(name, forKey: .name)
//    }
}
