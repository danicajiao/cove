//
//  APIEnvironment.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/17/26.
//

import Foundation

/// The backend environment the app points at.
///
/// ## Environment selection
///
/// `APIEnvironment.current` is resolved at runtime using a compile-time flag:
/// - **Debug** builds default to `.staging`
/// - **Release** builds default to `.production`
///
/// This was chosen over an Info.plist key because we don't yet have CI lanes that
/// produce per-environment builds, so a simple `#if DEBUG` check covers all current
/// cases without additional tooling. If QA ever needs to switch environments without
/// a recompile, replace `current` with an Info.plist lookup and add a
/// `API_BASE_URL` key to each scheme's Run configuration.
///
/// ## Staging URL
///
/// The staging URL below is a placeholder — confirm the actual hostname when the
/// staging Cloudflare Tunnel is provisioned in Phase 1.
enum APIEnvironment {
    case staging
    case production

    // MARK: - Base URL

    var baseURL: URL {
        switch self {
        case .staging:
            // Placeholder — confirm hostname when Phase 1 staging Cloudflare Tunnel is provisioned.
            // Candidate: https://staging.api.coveapp.dev
            // swiftlint:disable:next force_unwrapping
            URL(string: "https://staging.api.coveapp.dev")!
        case .production:
            // swiftlint:disable:next force_unwrapping
            URL(string: "https://api.coveapp.dev")!
        }
    }

    // MARK: - Current environment

    /// The environment used by `APIClient` when no explicit `baseURL` is injected.
    ///
    /// - Debug builds → `.staging`
    /// - Release builds → `.production`
    static var current: APIEnvironment {
        #if DEBUG
            return .staging
        #else
            return .production
        #endif
    }
}
