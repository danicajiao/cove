//
//  UserProfile.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import Foundation

/// A user's persisted profile record.
///
/// Distinct from Firebase Auth's `User` object, which is the authentication identity.
/// `UserProfile` is the app-layer record stored in the backend (Firestore in Phase 0,
/// `cove-user` in Phase 3) and may carry additional fields that Firebase Auth does not own.
///
/// The `id` field is the Firebase Auth UID and serves as the primary key in the backend.
struct UserProfile: Codable, Identifiable {
    /// The Firebase Auth UID. Primary key in the backend.
    var id: String

    /// The user's display name, if set.
    var displayName: String?

    /// The user's email address.
    var email: String?

    /// URL of the user's profile photo, if set.
    var photoURL: URL?

    /// When the profile record was first created.
    var createdAt: Date?
}
