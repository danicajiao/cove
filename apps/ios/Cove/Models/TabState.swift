//
//  TabState.swift
//  Cove
//
//  Created by Daniel Cajiao on 5/8/22.
//

import Foundation

class TabState: Identifiable, ObservableObject {
    @Published var currentTab = "home"
    @Published var previousTab = "home"
}
