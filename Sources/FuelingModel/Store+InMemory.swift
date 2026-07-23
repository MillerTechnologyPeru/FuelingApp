//
//  Store+InMemory.swift
//  FuelingModel
//

import CoreModel
import CoreFueling

public extension Store {

    /// Build a store backed entirely by an in-memory dictionary.
    ///
    /// No filesystem, no C dependencies — the storage backend for platforms
    /// without CoreData or SQLite (notably the browser/wasm target), and a
    /// convenient one for previews and tests everywhere.
    ///
    /// The same ``InMemoryStore`` instance serves as both the store's
    /// asynchronous `storage` and its synchronous `viewContext`, so UI reads
    /// see prior writes immediately.
    ///
    /// - Parameters:
    ///   - model: The schema to validate entities against. Defaults to `.fueling`.
    ///   - locationService: Network transport, or `nil` for offline use.
    ///   - userLocation: Current user location, if known.
    convenience init(
        inMemory model: Model = .fueling,
        locationService: (any LocationService)? = nil,
        userLocation: LocationCoordinate? = nil
    ) {
        let store = InMemoryStore(model: model)
        self.init(
            storage: store,
            viewContext: store,
            locationService: locationService,
            userLocation: userLocation
        )
    }
}
