//
//  Store+SiteService.swift
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

    /// Fetch a single site from the network, persist it, and return the domain entity.
    @discardableResult
    func site(for id: Site.ID) async throws(FuelingError) -> Site {
        let ids = try await locations(sites: [id])
        guard ids.contains(id) else {
            throw FuelingError.invalidResponse
        }
        do {
            guard let site = try await storage.fetch(Site.self, for: id) else {
                throw FuelingError.invalidResponse
            }
            return site
        } catch let error as FuelingError {
            throw error
        } catch {
            throw FuelingError(error)
        }
    }

    /// Fetch (and persist) the given sites, or all sites if empty, returning their IDs.
    @discardableResult
    func locations(sites: [Site.ID] = []) async throws(FuelingError) -> [Site.ID] {
        guard let service = siteService else {
            throw FuelingError.serviceUnavailable
        }
        let fetchAll = sites.isEmpty
        let (ids, data) = try await service.locations(sites: sites)
        do {
            try await insert(data)
        } catch {
            throw FuelingError(error)
        }
        if fetchAll {
            lastSitesRefresh = Date()
            // delete stale sites when refreshing the full location set
            do {
                let fetchRequest = FetchRequest(entity: Site.entityName)
                let cachedSites = try await storage.fetchID(fetchRequest)
                let responseSites = Set(ids.map { ObjectID($0) })
                let staleSites = cachedSites.filter { responseSites.contains($0) == false }
                if staleSites.isEmpty == false {
                    try await delete(Site.entityName, for: staleSites)
                }
            } catch {
                throw FuelingError(error)
            }
        }
        return ids
    }

    /// Fetch (and persist) fuel prices for the given sites, returning the product IDs.
    @discardableResult
    func fuelPrices(for sites: [Site.ID]) async throws(FuelingError) -> [FuelProduct.ID] {
        guard let service = siteService else {
            throw FuelingError.serviceUnavailable
        }
        let (ids, data) = try await service.fuelPrices(for: sites)
        do {
            try await insert(data)
        } catch {
            throw FuelingError(error)
        }
        return ids
    }

    /// Load a site from the cache, fetching it from the network if not already cached.
    func cached(_ site: Site.ID) async throws(FuelingError) -> Site {
        if let cached = try? await storage.fetch(Site.self, for: site) {
            return cached
        }
        return try await self.site(for: site)
    }
}
