//
//  UserRepository.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import Foundation

/// Abstraction over user profile reads and writes.
///
/// **Lazy-create semantics:** `fetchProfile(uid:)` implementations are expected to
/// create a default profile record on first access if one does not yet exist.
/// Callers may always `await fetchProfile` and treat the result as non-nil.
protocol UserRepository {
    /// Fetches the profile for the given Firebase UID.
    ///
    /// If no profile record exists yet (e.g. first sign-in), implementations
    /// should create and return a default profile rather than throwing.
    ///
    /// - Parameter uid: The Firebase Auth UID of the user whose profile to fetch.
    func fetchProfile(uid: String) async throws -> UserProfile

    /// Persists changes to an existing user profile.
    ///
    /// The `profile.id` field must match an existing record. Implementations
    /// should perform a partial update (merge) rather than a full overwrite so
    /// that concurrent writes to different fields do not conflict.
    ///
    /// - Parameter profile: The updated profile to persist.
    func updateProfile(_ profile: UserProfile) async throws
}
