//
//  SiteService.swift
//  FuelingModel
//

import CoreModel
import CoreFueling

/// Transport for site and fuel price data.
///
/// Implementations convert their wire representation into the `ModelData`
/// entity graph, but do not persist it; ``Store`` performs the actual
/// `insert`/`fetch` against its storage.
public protocol SiteService: Sendable {

    /// Fetch the given sites, or all sites if empty. Returns both the resulting
    /// IDs and the entity graph (site + fuel options) for the caller to persist.
    func locations(sites: [Site.ID]) async throws(FuelingError) -> (ids: [Site.ID], data: [ModelData])

    /// Fetch fuel prices for the given sites. Returns both the resulting
    /// product IDs and the `ModelData` to persist.
    func fuelPrices(for sites: [Site.ID]) async throws(FuelingError) -> (ids: [FuelProduct.ID], data: [ModelData])
}

public extension SiteService {

    /// Fetch all sites.
    func locations() async throws(FuelingError) -> (ids: [Site.ID], data: [ModelData]) {
        try await locations(sites: [])
    }
}
