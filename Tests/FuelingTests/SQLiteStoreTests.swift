//
//  SQLiteStoreTests.swift
//  FuelingTests
//

import Foundation
import Testing
import CoreModel
import CoreFueling
@testable import FuelingModel

@MainActor
@Suite
struct SQLiteStoreTests {

    @Test
    func fetchLocations() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("FuelingTests-\(UUID()).sqlite")
            .path
        let store = try Store(
            sqliteDatabase: path,
            locationService: .mock
        )
        // download and persist all locations
        let ids = try await store.locations()
        #expect(ids.count == MockHTTPClient.locations.count)
        // fetch from storage
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
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("FuelingTests-\(UUID()).sqlite")
            .path
        let store = try Store(
            sqliteDatabase: path,
            locationService: .mock
        )
        let location: Location.ID = 15
        try await store.locations(ids: [location])
        let products = try await store.fuelPrices(for: [location])
        #expect(products.isEmpty == false)
        let cached = try #require(try await store.storage.fetch(Location.self, for: location))
        #expect(Set(cached.fuelProducts) == Set(products))
    }
}
