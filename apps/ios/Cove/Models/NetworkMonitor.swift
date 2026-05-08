//
//  NetworkMonitor.swift
//  Cove
//
//  Created by Daniel Cajiao on 2/24/25.
//

import Network
import SwiftUI

class NetworkMonitor: ObservableObject {
    private var monitor: NWPathMonitor
    private var queue: DispatchQueue

    @Published var isConnected: Bool = false

    init() {
        monitor = NWPathMonitor()
        queue = DispatchQueue(label: "NetworkMonitor")

        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                print("Network status: \(path.status)")
                self.isConnected = path.status == .satisfied
            }
        }

        monitor.start(queue: queue)
    }

    deinit {
        print("Cancelling network monitor")
        self.monitor.cancel()
    }
}
