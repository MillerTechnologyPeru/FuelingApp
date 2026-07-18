//
//  LocationService.swift
//  FuelingModel
//

import CoreModel
import CoreFueling

/// Transport for location and fuel price data.
///
/// Implementations convert their wire representation into the `ModelData`
/// entity graph, but do not persist it; ``Store`` performs the actual
/// `insert`/`fetch` against its storage.
public protocol LocationService: Sendable {

    /// Fetch the given locations, or all locations if empty. Returns both the
    /// resulting IDs and the entity graph (location + fuel options) for the
    /// caller to persist.
    func locations(ids: [Location.ID]) async throws(FuelingError) -> (ids: [Location.ID], data: [ModelData])

    /// Fetch fuel prices for the given locations. Returns both the resulting
    /// product IDs and the `ModelData` to persist.
    func fuelPrices(for locations: [Location.ID]) async throws(FuelingError) -> (ids: [FuelProduct.ID], data: [ModelData])
}

public extension LocationService {

    /// Fetch all locations.
    func locations() async throws(FuelingError) -> (ids: [Location.ID], data: [ModelData]) {
        try await locations(ids: [])
    }
}
