//
//  FirebaseImageRepository.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import FirebaseFirestore
import FirebaseStorage

/// Firebase Storage-backed implementation of `ImageRepository`.
///
/// Fetches the product's `defaultImageURL` from Firestore, then resolves
/// it to a fresh HTTPS download URL via Firebase Storage. In Phase 2 this
/// implementation is replaced by `CoveAPIImageRepository`, which calls
/// `cove-image` directly and avoids the double round-trip.
final class FirebaseImageRepository: ImageRepository {
    // MARK: - Properties

    private let firestore = Firestore.firestore()
    private let storage = Storage.storage()

    // MARK: - ImageRepository

    func imageURL(for productId: String) async throws -> URL {
        let snapshot = try await firestore
            .collection("products")
            .document(productId)
            .getDocument()

        guard snapshot.exists,
              let urlString = snapshot["defaultImageURL"] as? String
        else {
            throw APIError.notFound
        }

        let ref = storage.reference(forURL: urlString)
        return try await ref.downloadURL()
    }
}
