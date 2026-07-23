//
//  InMemoryStoreTests.swift
//  FuelingTests
//

import Foundation
import Testing
import CoreModel
import CoreFueling
@testable import FuelingModel

@MainActor
@Suite
struct InMemoryStoreTests {

    @Test
    func fetchLocations() async throws {
        let store = Store(inMemory: .fueling, locationService: .mock)
        // download and persist all locations
        let ids = try await store.locations()
        #expect(ids.count == MockHTTPClient.locations.count)
        // fetch back through storage — the location DTO mapping omits the
        // `fuelProducts` relationship and the optional `lastViewed` attribute,
        // so this exercises the store's default-fill on read (without it,
        // `Location.init(from:)` throws `keyNotFound`).
        let locations = try await store.storage.fetch(Location.self, search: nil)
        #expect(locations.count == ids.count)
        // filtered fetch
        let filtered = try await store.storage.fetch(Location.self, search: "Seville")
        #expect(filtered.count == 1)
        #expect(filtered.first?.id == 15)
        // read through the synchronous view context too
        let viewed = try store.viewContext.fetch(Location.self, for: 15)
        #expect(viewed?.name == "Seville Travel Center")
    }

    @Test
    func fetchFuelPrices() async throws {
        let store = Store(inMemory: .fueling, locationService: .mock)
        let location: Location.ID = 15
        try await store.locations(ids: [location])
        let products = try await store.fuelPrices(for: [location])
        #expect(products.isEmpty == false)
        // The in-memory store doesn't maintain inverse relationships, so the
        // parent location's `fuelProducts` isn't back-populated; query the
        // `FuelProduct` entities by their own `location` field instead.
        let fetched = try await store.storage
            .fetch(FuelProduct.self)
            .filter { $0.location == location }
        #expect(Set(fetched.map(\.id)) == Set(products))
    }

    @Test
    func partialUpdatePreservesRelationships() async throws {
        let store = Store(inMemory: .fueling)
        let id: Location.ID = 42
        // Seed a location that already references a fuel product.
        try await store.storage.insert(
            ModelData(
                entity: Location.entityName,
                id: ObjectID(id),
                attributes: [PropertyKey(Location.CodingKeys.name): .string("Original")],
                relationships: [PropertyKey(Location.CodingKeys.fuelProducts): .toMany([ObjectID("1")])]
            )
        )
        // A refresh that only updates the name (and omits `fuelProducts`, as the
        // location DTO mapping does) must not sever the existing link.
        try await store.storage.insert(
            ModelData(
                entity: Location.entityName,
                id: ObjectID(id),
                attributes: [PropertyKey(Location.CodingKeys.name): .string("Renamed")]
            )
        )
        // Inspect the raw `ModelData` (decoding would require all of the
        // location's non-optional attributes, which this minimal seed omits).
        let raw = try #require(try store.viewContext.fetch(Location.entityName, for: ObjectID(id)))
        #expect(raw.attributes[PropertyKey(Location.CodingKeys.name)] == .string("Renamed"))
        #expect(raw.relationships[PropertyKey(Location.CodingKeys.fuelProducts)] == .toMany([ObjectID("1")]))
    }
}
