//
//  LocationDetailScreen.swift
//  FuelingAndroid
//
//  JNI adapter over `LocationDetailViewModel`, exported to Java/Kotlin via swift-java.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreFueling
import FuelingModel

/// Exposes a `LocationDetailViewModel` to Java/Kotlin as flat primitive
/// getters. Nested value types (fuel products, fuel options) are flattened
/// into index-based accessors so no domain types cross the JNI boundary.
///
/// See ``FuelingSession`` for the main-thread threading contract; every
/// method hops onto the main actor with `MainActor.assumeIsolated`.
public final class LocationDetailScreen {

    let viewModel: LocationDetailViewModel

    /// Internal so swift-java does not try to export a `Store`-typed initializer;
    /// instances are created via ``FuelingSession/makeLocationDetailScreen(locationId:)``.
    init(store: Store, locationId: Int64) {
        self.viewModel = MainActor.assumeIsolated {
            LocationDetailViewModel(id: .init(rawValue: UInt(locationId)), store: store)
        }
    }

    // MARK: - Lifecycle

    public func onAppear() {
        MainActor.assumeIsolated { viewModel.onAppear() }
    }

    public func onDisappear() {
        MainActor.assumeIsolated { viewModel.onDisappear() }
    }

    public func reload() {
        MainActor.assumeIsolated { viewModel.reload() }
    }

    // MARK: - State

    public func isLoading() -> Bool {
        MainActor.assumeIsolated { viewModel.isLoading }
    }

    /// The current error message, or an empty string when there is none.
    public func errorMessage() -> String {
        MainActor.assumeIsolated { viewModel.error ?? "" }
    }

    // MARK: - Location

    public func locationName() -> String {
        MainActor.assumeIsolated { viewModel.location?.name ?? "" }
    }

    public func locationAddress() -> String {
        MainActor.assumeIsolated { viewModel.location?.address ?? "" }
    }

    /// Formatted distance to the location (e.g. "12 mi"), or empty when unavailable.
    public func distance() -> String {
        MainActor.assumeIsolated { viewModel.distance ?? "" }
    }

    public func fuelLanes() -> Int64 {
        MainActor.assumeIsolated { Int64(viewModel.location?.fuelLanes ?? 0) }
    }

    public func showerCount() -> Int64 {
        MainActor.assumeIsolated { Int64(viewModel.location?.showers ?? 0) }
    }

    public func truckParkingSpaces() -> Int64 {
        MainActor.assumeIsolated { Int64(viewModel.location?.truckParkingSpaces ?? 0) }
    }

    // MARK: - Fuel Options

    public func fuelOptionCount() -> Int {
        MainActor.assumeIsolated { viewModel.location?.fuelOptions.count ?? 0 }
    }

    public func fuelOption(_ index: Int) -> String {
        MainActor.assumeIsolated {
            guard let fuelOptions = viewModel.location?.fuelOptions, fuelOptions.indices.contains(index) else {
                return ""
            }
            return fuelOptions[index]
        }
    }

    // MARK: - Fuel Products

    public func fuelProductCount() -> Int {
        MainActor.assumeIsolated { viewModel.location?.fuelProducts.count ?? 0 }
    }

    public func fuelProductName(_ index: Int) -> String {
        MainActor.assumeIsolated { fuelProduct(at: index)?.name ?? "" }
    }

    public func fuelProductPrice(_ index: Int) -> String {
        MainActor.assumeIsolated { fuelProduct(at: index)?.price ?? "" }
    }

    // MARK: - Helpers

    @MainActor
    private func fuelProduct(at index: Int) -> LocationDetailViewModel.FuelProduct? {
        guard let fuelProducts = viewModel.location?.fuelProducts, fuelProducts.indices.contains(index) else {
            return nil
        }
        return fuelProducts[index]
    }
}
