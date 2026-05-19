//
//  CoveAPIImageRepository.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import Foundation

/// Stub implementation of `ImageRepository` backed by `cove-api`.
///
/// Throws `APIError.server(statusCode: 501)` until Phase 2 fleshes it
/// out with real `CoveImageClient` calls.
final class CoveAPIImageRepository: ImageRepository {
    func imageURL(for productId: String) async throws -> URL {
        throw APIError.server(statusCode: 501, message: "imageURL not implemented in Phase 0")
    }
}
