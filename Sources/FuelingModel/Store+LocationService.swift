//
//  Store+LocationService.swift
//  FuelingModel
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreModel
import CoreFueling

public extension Store {

    /// Fetch a single location from the network, persist it, and return the domain entity.
    @discardableResult
    func location(for id: Location.ID) async throws(FuelingError) -> Location {
        let ids = try await locations(ids: [id])
        guard ids.contains(id) else {
            throw FuelingError.invalidResponse
        }
        do {
            guard let location = try await storage.fetch(Location.self, for: id) else {
                throw FuelingError.invalidResponse
            }
            return location
        } catch let error as FuelingError {
            throw error
        } catch {
            throw FuelingError(error)
        }
    }

    /// Fetch (and persist) the given locations, or all locations if empty, returning their IDs.
    @discardableResult
    func locations(ids: [Location.ID] = []) async throws(FuelingError) -> [Location.ID] {
        guard let service = locationService else {
            throw FuelingError.serviceUnavailable
        }
        let fetchAll = ids.isEmpty
        let (locationIDs, data) = try await service.locations(ids: ids)
        do {
            try await insert(data)
        } catch {
            throw FuelingError(error)
        }
        if fetchAll {
            lastLocationsRefresh = Date()
            // delete stale locations when refreshing the full location set
            do {
                let fetchRequest = FetchRequest(entity: Location.entityName)
                let cachedLocations = try await storage.fetchID(fetchRequest)
                let responseLocations = Set(locationIDs.map { ObjectID($0) })
                let staleLocations = cachedLocations.filter { responseLocations.contains($0) == false }
                if staleLocations.isEmpty == false {
                    try await delete(Location.entityName, for: staleLocations)
                }
            } catch {
                throw FuelingError(error)
            }
        }
        return locationIDs
    }

    /// Fetch (and persist) fuel prices for the given locations, returning the product IDs.
    @discardableResult
    func fuelPrices(for locations: [Location.ID]) async throws(FuelingError) -> [FuelProduct.ID] {
        guard let service = locationService else {
            throw FuelingError.serviceUnavailable
        }
        let (ids, data) = try await service.fuelPrices(for: locations)
        do {
            try await insert(data)
        } catch {
            throw FuelingError(error)
        }
        return ids
    }

    /// Load a location from the cache, fetching it from the network if not already cached.
    func cached(_ id: Location.ID) async throws(FuelingError) -> Location {
        if let cached = try? await storage.fetch(Location.self, for: id) {
            return cached
        }
        return try await self.location(for: id)
    }
}
