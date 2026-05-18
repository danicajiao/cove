//
//  FirebaseUserRepository.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/18/26.
//

import FirebaseAuth
import FirebaseFirestore

/// Firestore-backed implementation of `UserRepository`.
///
/// Stores user profile data in `users/{uid}` in Firestore.
/// On first access, lazily creates a default profile record seeded from
/// the Firebase Auth user object so callers never receive a missing-profile error.
///
/// `ProfileViewModel` currently reads profile data entirely from Firebase Auth.
/// After the DI refactor in #226, it will depend on this repository instead,
/// enabling the migration to `cove-user` in Phase 3 with no ViewModel changes.
final class FirebaseUserRepository: UserRepository {
    // MARK: - Properties

    private let firestore = Firestore.firestore()

    // MARK: - UserRepository

    func fetchProfile(uid: String) async throws -> UserProfile {
        let ref = firestore.collection("users").document(uid)
        let snapshot = try await ref.getDocument()

        if snapshot.exists, let data = snapshot.data() {
            return UserProfile(
                id: uid,
                displayName: data["displayName"] as? String,
                email: data["email"] as? String,
                photoURL: (data["photoURL"] as? String).flatMap(URL.init(string:)),
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
            )
        }

        // Lazy-create: seed a default profile from Firebase Auth and persist it.
        let authUser = Auth.auth().currentUser
        let profile = UserProfile(
            id: uid,
            displayName: authUser?.displayName,
            email: authUser?.email,
            photoURL: authUser?.photoURL,
            createdAt: authUser?.metadata.creationDate
        )

        var fields: [String: Any] = [:]
        if let displayName = profile.displayName { fields["displayName"] = displayName }
        if let email = profile.email { fields["email"] = email }
        if let photoURL = profile.photoURL { fields["photoURL"] = photoURL.absoluteString }
        fields["createdAt"] = Timestamp(date: profile.createdAt ?? Date())

        try await ref.setData(fields, merge: true)
        return profile
    }

    func updateProfile(_ profile: UserProfile) async throws {
        var fields: [String: Any] = [:]
        if let displayName = profile.displayName { fields["displayName"] = displayName }
        if let email = profile.email { fields["email"] = email }
        if let photoURL = profile.photoURL { fields["photoURL"] = photoURL.absoluteString }
        if let createdAt = profile.createdAt { fields["createdAt"] = Timestamp(date: createdAt) }

        try await firestore.collection("users").document(profile.id).setData(fields, merge: true)
    }
}
