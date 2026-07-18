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
/// There is no network transport wired up on Android yet — the `Store` is built
/// with `locationService: nil`, so persistence, search and view models work
/// against the local SQLite cache, seeded with sample data via
/// ``seedSampleLocations()``, while any call that would reach the network
/// throws `FuelingError.serviceUnavailable`.
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
    public init(documentsPath: String) throws {
        #if os(Android)
        _ = Self.setUpMainLooper
        #endif
        let directory = URL(fileURLWithPath: documentsPath, isDirectory: true)
        let databasePath = directory.appendingPathComponent("Fueling.sqlite").path
        self.store = try MainActor.assumeIsolated {
            try Store(sqliteDatabase: databasePath)
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

    /// The same bundled sample locations used by previews and tests
    /// (``FuelingModel/MockHTTPClient``), converted to the entity graph so the
    /// Locations screen has data without a real network transport.
    static func sampleLocationData() -> [ModelData] {
        MockHTTPClient.locations.flatMap { ModelData.location($0) }
    }
}
