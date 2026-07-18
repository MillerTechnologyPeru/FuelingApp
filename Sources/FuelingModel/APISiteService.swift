//
//  APISiteService.swift
//  FuelingModel
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreModel
import CoreFueling
import FuelingAPI

/// Adapts a ``FuelingAPI/FuelingAPIClient`` to ``SiteService``.
public struct APISiteService: SiteService {

    public let client: any FuelingAPIClient

    public init(client: any FuelingAPIClient) {
        self.client = client
    }

    public func locations(sites: [Site.ID]) async throws(FuelingError) -> (ids: [Site.ID], data: [ModelData]) {
        let locations = try await client.locations(sites: sites)
        let lastCached = Date()
        var ids = [Site.ID]()
        var data = [ModelData]()
        ids.reserveCapacity(locations.count)
        for location in locations {
            guard let id = location.id else {
                continue
            }
            ids.append(id)
            data += ModelData.location(location, lastCached: lastCached)
        }
        return (ids, data)
    }

    public func fuelPrices(for sites: [Site.ID]) async throws(FuelingError) -> (ids: [FuelProduct.ID], data: [ModelData]) {
        let prices = try await client.fuelPrices(for: sites)
        let lastCached = Date()
        var ids = [FuelProduct.ID]()
        var data = [ModelData]()
        ids.reserveCapacity(prices.count)
        for price in prices {
            guard let id = price.product,
                let modelData = ModelData(fuelPrice: price, lastCached: lastCached)
            else {
                continue
            }
            ids.append(id)
            data.append(modelData)
        }
        return (ids, data)
    }
}

public extension APISiteService {

    /// Build a service for the injected server base URL.
    init(
        server: ServerURL,
        deviceID: String = "0",
        session: URLSession = .shared
    ) {
        self.init(
            client: URLSessionFuelingAPIClient(
                server: server,
                deviceID: deviceID,
                session: session
            )
        )
    }
}
