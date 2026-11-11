//
//  AccountPrompt.swift
//  Cove
//

import Foundation

/// Why the sign-up sheet is shown. Sets the sheet's icon, title and first step.
///
/// Presented with `AppState.requireAccount(_:then:)`.
enum AccountPrompt: String, Identifiable {
    /// A guest tried to favorite an item.
    case favorite
    /// A guest tried to follow a place.
    case follow
    /// "Create account" on the guest Profile tab: opens straight to email sign-up.
    case createAccount
    /// "Log in" on the guest Profile tab: opens straight to log in.
    case logIn

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .favorite: "heart"
        case .follow: "person.badge.plus"
        case .createAccount, .logIn: "person"
        }
    }

    var title: String {
        switch self {
        case .favorite: "Save it to your favorites"
        case .follow: "Follow places you love"
        case .createAccount, .logIn: "Create your free account"
        }
    }

    var message: String {
        "Create a free account to save favorites and follow places. Your interest picks come with you."
    }
}
