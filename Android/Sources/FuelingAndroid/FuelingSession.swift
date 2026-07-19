//
//  FuelingSession.swift
//  FuelingAndroid
//
//  JNI entry point exported to Java/Kotlin via swift-java (jextract, JNI mode).
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreModel
import CoreFueling
import FuelingAPI
import FuelingModel
#if os(Android)
import AndroidLooper
#endif

/// The Android entry point into the shared Fueling model layer.
///
/// A `FuelingSession` owns a `Store` backed by a local SQLite database and
/// exposes primitive accessors plus screen-adapter factories to Java/Kotlin.
/// Only primitives and `String`s cross the JNI boundary — no CoreModel or
/// domain types are exported.
///
/// ## Threading
/// The public API is deliberately `nonisolated`: swift-java's JNI thunks invoke
/// these methods synchronously from the calling Java thread, so each method hops
/// onto the main actor with `MainActor.assumeIsolated`. Callers **must** invoke
/// this API from the app's main thread (the Android UI thread).
///
/// Swift's `MainActor` is backed by the libdispatch main queue on Android, which
/// nothing pumps by default — `Task { @MainActor in ... }` work (used throughout
/// `Store` and the view models for reload/search) would never run.
/// `AndroidMainActor.setupMainLooper()` bridges the dispatch main queue into the
/// Android `Looper` on the calling thread, so it must run once, on the main
/// thread, before any `Store`/view-model work is scheduled.
///
/// ## Networking
/// The `Store` is built with a real `APILocationService<URLSession>` pointed
/// at the injected `serverURL` (see ``init(documentsPath:serverURL:)``), so
/// persistence, search and view models fetch from that server the same way
/// they do on Darwin. Pass an empty or invalid URL to run fully offline
/// instead — seed a starting point with ``seedSampleLocations()`` in that
/// case, since no network call will ever populate the cache.
public final class FuelingSession {

    let store: Store

    #if os(Android)
    /// Bridges the libdispatch main queue into the Android `Looper` on the
    /// calling thread so `@MainActor` work actually executes. Must run once,
    /// on the main thread, before any Task work is scheduled.
    private static let setUpMainLooper: Bool = AndroidMainActor.setupMainLooper()
    #endif

    /// Create a session whose SQLite database lives under `documentsPath`
    /// (pass the Android `Context.getFilesDir()` path).
    ///
    /// - Parameter serverURL: Base URL of the fueling API (e.g.
    ///   `BuildConfig.FUELING_SERVER_URL`, itself injected from the
    ///   `FUELING_SERVER_URL` environment variable at Gradle build time,
    ///   defaulting to `http://localhost:8080`). Empty or unparsable strings
    ///   fall back to running fully offline rather than throwing.
    public init(documentsPath: String, serverURL: String) throws {
        #if os(Android)
        _ = Self.setUpMainLooper
        #endif
        let directory = URL(fileURLWithPath: documentsPath, isDirectory: true)
        let databasePath = directory.appendingPathComponent("Fueling.sqlite").path
        let locationService = ServerURL(rawValue: serverURL).map { APILocationService(server: $0) }
        self.store = try MainActor.assumeIsolated {
            try Store(sqliteDatabase: databasePath, locationService: locationService)
        }
    }

    // MARK: - Store primitives

    /// A monotonically increasing counter bumped on every persistence change.
    public func changeCount() -> Int {
        MainActor.assumeIsolated { store.changeCount }
    }

    // MARK: - Seeding

    /// Insert a few sample locations into the local SQLite database so the
    /// Locations screen has data without the (not yet wired up) networking layer.
    ///
    /// Best-effort and asynchronous — the insert runs on the main actor.
    public func seedSampleLocations() {
        let store = self.store
        let data = Self.sampleLocationData()
        Task { @MainActor in
            do {
                try await store.insert(data)
            } catch {
                // Best-effort seeding for the demo; ignore failures.
            }
        }
    }

    // MARK: - Screens

    /// Create a Locations screen adapter backed by this session's store.
    public func makeLocationsScreen() -> LocationsScreen {
        MainActor.assumeIsolated { LocationsScreen(store: store) }
    }

    /// Create a Location Detail screen adapter for the location with the given ID.
    public func makeLocationDetailScreen(locationId: Int64) -> LocationDetailScreen {
        MainActor.assumeIsolated { LocationDetailScreen(store: store, locationId: locationId) }
    }
}

// MARK: - Sample data

extension FuelingSession {

    /// A few sample locations, built directly from the `CoreFueling` domain
    /// types (not the network DTOs — `FuelingAPI`/`HTTPTypesFoundation`'s
    /// `FoundationNetworking` dependency is excluded from the Android build
    /// entirely, see the package manifest), so the Locations screen has data
    /// without a real network transport.
    static func sampleLocationData() -> [ModelData] {
        let fuelOptions: [FuelOption] = [
            FuelOption(id: .diesel, name: "Diesel"),
            FuelOption(id: .autoDiesel, name: "Auto Diesel"),
            FuelOption(id: .defIslandFueling, name: "DEF Island Fueling"),
            FuelOption(id: .unleadedGasoline, name: "Unleaded Gasoline"),
            FuelOption(id: .electricChargingStations, name: "Electric Charging Stations")
        ]
        let locations: [CoreFueling.Location] = [
            CoreFueling.Location(
                id: 15,
                fuelOptions: [.diesel, .autoDiesel, .defIslandFueling, .unleadedGasoline],
                name: "Seville Travel Center",
                address: "8834 Lake Road",
                city: "Seville",
                state: "Ohio",
                zipCode: "44273",
                phone: "330-555-2053",
                directions: "I-71 & I-76 at Rt. 224, Exit 209",
                latitude: 41.0322,
                longitude: -81.9078,
                fuelLanes: 9,
                truckParkingSpaces: 237,
                showers: 10
            ),
            CoreFueling.Location(
                id: 23,
                fuelOptions: [.diesel, .defIslandFueling, .unleadedGasoline],
                name: "Columbus East Fuel Stop",
                address: "6161 Interstate Parkway",
                city: "Columbus",
                state: "Ohio",
                zipCode: "43217",
                phone: "614-555-0148",
                directions: "I-270 at US-33, Exit 46",
                latitude: 39.8781,
                longitude: -82.8121,
                fuelLanes: 7,
                truckParkingSpaces: 150,
                showers: 8
            ),
            CoreFueling.Location(
                id: 42,
                fuelOptions: [.diesel, .autoDiesel, .electricChargingStations],
                name: "Toledo Junction Travel Plaza",
                address: "3483 Libbey Road",
                city: "Perrysburg",
                state: "Ohio",
                zipCode: "43551",
                phone: "419-555-0837",
                directions: "I-75 & I-80/90, Exit 71",
                latitude: 41.5164,
                longitude: -83.5992,
                fuelLanes: 6,
                truckParkingSpaces: 122,
                showers: 6
            )
        ]
        return locations.map { $0.encode() } + fuelOptions.map { $0.encode() }
    }
}
