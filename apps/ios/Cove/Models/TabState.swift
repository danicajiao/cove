//
//  TabState.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/8/22.
//

import Foundation

enum AppTab {
    case home
    case browse
    case favorites
    case profile
}

class TabState: Identifiable, ObservableObject {
    @Published var currentTab: AppTab = .home
    @Published var previousTab: AppTab = .home
}
