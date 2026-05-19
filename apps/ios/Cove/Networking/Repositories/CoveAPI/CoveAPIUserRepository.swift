//
//  CoveAPIUserRepository.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import Foundation

/// Stub implementation of `UserRepository` backed by `cove-api`.
///
/// Throws `APIError.server(statusCode: 501)` until Phase 3 fleshes it
/// out with real `CoveUserClient` calls.
final class CoveAPIUserRepository: UserRepository {
    func fetchProfile(uid: String) async throws -> UserProfile {
        throw APIError.server(statusCode: 501, message: "fetchProfile not implemented in Phase 0")
    }

    func updateProfile(_ profile: UserProfile) async throws {
        throw APIError.server(statusCode: 501, message: "updateProfile not implemented in Phase 0")
    }
}
