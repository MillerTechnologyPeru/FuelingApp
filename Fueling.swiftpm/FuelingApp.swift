//
//  FuelingApp.swift
//  Fueling
//

import SwiftUI
import FuelingModel
import FuelingUI

@main
struct FuelingApp: App {

    @State
    private var store: Store?

    var body: some Scene {
        WindowGroup {
            if let store {
                ContentView()
                    .environment(store)
            } else {
                ProgressView()
                    .task {
                        store = try? loadStore()
                    }
            }
        }
    }

    /// Build the store for the demo.
    ///
    /// Uses the bundled sample data. To run against a real deployment,
    /// inject the server base URL instead:
    ///
    ///     let service = APILocationService(server: ServerURL(rawValue: "https://example.com")!)
    ///     let store = try Store(locationService: service)
    ///
    @MainActor
    private func loadStore() throws -> Store {
        let store = try Store(
            locationService: .mock,
            isStoredInMemoryOnly: true
        )
        // simulated user position near the first sample site
        store.userLocation = LocationCoordinate(
            latitude: 41.0322,
            longitude: -81.9078
        )
        return store
    }
}
