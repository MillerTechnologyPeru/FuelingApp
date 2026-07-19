//
//  FuelingApp.swift
//  Fueling
//

import SwiftUI
import FuelingModel
import FuelingAPI
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
    /// Fetches from a real server, its base URL injected via the
    /// `FUELING_SERVER_URL` environment variable (set it in the Xcode
    /// scheme's Arguments tab, or `export` it before `swift run`) — defaults
    /// to `http://localhost:8080` when unset. Swap in the bundled sample data
    /// instead for an offline demo:
    ///
    ///     let store = try Store(locationService: .mock, isStoredInMemoryOnly: true)
    ///
    @MainActor
    private func loadStore() throws -> Store {
        let service = APILocationService(server: .fromEnvironment())
        let store = try Store(
            locationService: service,
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
