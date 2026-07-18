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

/// Adapts any ``FuelingAPI/HTTPClient`` transport to ``SiteService``.
public struct APISiteService<Client: HTTPClient>: SiteService {

    /// HTTP transport executing the requests.
    public let client: Client

    /// Injected server base URL.
    public let server: ServerURL

    /// Unique device identifier sent with each request.
    public let deviceID: String

    public init(
        client: Client,
        server: ServerURL,
        deviceID: String = "0"
    ) {
        self.client = client
        self.server = server
        self.deviceID = deviceID
    }

    public func locations(sites: [Site.ID]) async throws(FuelingError) -> (ids: [Site.ID], data: [ModelData]) {
        let locations = try await client.locations(sites: sites, server: server, device: deviceID)
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
        let prices = try await client.fuelPrices(for: sites, server: server, device: deviceID)
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

#if canImport(FoundationNetworking) || canImport(Darwin)
public extension APISiteService where Client == URLSession {

    /// Build a `URLSession`-backed service for the injected server base URL.
    init(
        server: ServerURL,
        deviceID: String = "0",
        session: URLSession = .shared
    ) {
        self.init(
            client: session,
            server: server,
            deviceID: deviceID
        )
    }
}
#endif
