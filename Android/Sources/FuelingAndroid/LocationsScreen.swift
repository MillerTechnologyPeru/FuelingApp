//
//  LocationsScreen.swift
//  FuelingAndroid
//
//  JNI adapter over `LocationsViewModel`, exported to Java/Kotlin via swift-java.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreFueling
import FuelingModel

/// Exposes a `LocationsViewModel` to Java/Kotlin as flat, index-based
/// primitive getters. The view model's array of location entities is
/// flattened into `locationX(_:)` accessors so no domain types cross the JNI
/// boundary.
///
/// See ``FuelingSession`` for the main-thread threading contract; every
/// method hops onto the main actor with `MainActor.assumeIsolated`.
public final class LocationsScreen {

    let viewModel: LocationsViewModel

    /// Internal so swift-java does not try to export a `Store`-typed initializer;
    /// instances are created via ``FuelingSession/makeLocationsScreen()``.
    init(store: Store) {
        self.viewModel = MainActor.assumeIsolated { LocationsViewModel(store: store) }
    }

    // MARK: - Lifecycle

    /// Reload the location list (fetches from the local cache; networking is
    /// not yet wired up on Android).
    public func reload() {
        MainActor.assumeIsolated { viewModel.reload() }
    }

    public func onAppear() {
        MainActor.assumeIsolated { viewModel.onAppear() }
    }

    public func onDisappear() {
        MainActor.assumeIsolated { viewModel.onDisappear() }
    }

    // MARK: - Search

    /// Update the search text filter (name, city, address, zip code or state).
    public func setSearchText(_ text: String) {
        MainActor.assumeIsolated { viewModel.searchText = text }
    }

    public func searchText() -> String {
        MainActor.assumeIsolated { viewModel.searchText }
    }

    // MARK: - State

    public func isLoading() -> Bool {
        MainActor.assumeIsolated { viewModel.isLoading }
    }

    /// The current error message, or an empty string when there is none.
    public func errorMessage() -> String {
        MainActor.assumeIsolated { viewModel.error ?? "" }
    }

    // MARK: - Locations

    public func locationCount() -> Int {
        MainActor.assumeIsolated { viewModel.locations.count }
    }

    public func locationId(_ index: Int) -> Int64 {
        MainActor.assumeIsolated {
            guard let location = location(at: index) else { return -1 }
            return Int64(location.id.rawValue)
        }
    }

    public func locationName(_ index: Int) -> String {
        MainActor.assumeIsolated { location(at: index)?.name ?? "" }
    }

    public func locationAddress(_ index: Int) -> String {
        MainActor.assumeIsolated { location(at: index)?.postalAddress ?? "" }
    }

    /// Formatted distance to the location (e.g. "12 mi"), or empty when unavailable.
    public func locationDistance(_ index: Int) -> String {
        MainActor.assumeIsolated {
            guard let location = location(at: index) else { return "" }
            return viewModel.distance(to: location) ?? ""
        }
    }

    // MARK: - Helpers

    @MainActor
    private func location(at index: Int) -> CoreFueling.Location? {
        let locations = viewModel.locations
        guard locations.indices.contains(index) else { return nil }
        return locations[index]
    }
}
