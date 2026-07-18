//
//  StoreTests.swift
//  FuelingTests
//

import Foundation
import Testing
import CoreModel
import CoreFueling
@testable import FuelingModel

@MainActor
@Suite
struct StoreTests {

    @Test
    func fetchLocations() async throws {
        let store = try Store(
            named: "FuelingTests-\(UUID())",
            locationService: .mock,
            isStoredInMemoryOnly: true
        )
        // download and persist all locations
        let ids = try await store.locations()
        #expect(ids.count == MockHTTPClient.locations.count)
        #expect(store.lastLocationsRefresh != nil)
        // fetch from storage
        let locations = try await store.storage.fetch(Location.self, search: nil)
        #expect(locations.count == ids.count)
        // filtered fetch
        let filtered = try await store.storage.fetch(Location.self, search: "Seville")
        #expect(filtered.count == 1)
        #expect(filtered.first?.id == 15)
        // search by state
        let ohio = try await store.storage.fetch(Location.self, search: "Ohio")
        #expect(ohio.count == 3)
    }

    @Test
    func fetchFuelPrices() async throws {
        let store = try Store(
            named: "FuelingTests-\(UUID())",
            locationService: .mock,
            isStoredInMemoryOnly: true
        )
        // fetch location with fuel prices
        let location: Location.ID = 15
        try await store.locations(ids: [location])
        let products = try await store.fuelPrices(for: [location])
        #expect(products.isEmpty == false)
        // fuel products should be linked to the location
        let cached = try #require(try await store.storage.fetch(Location.self, for: location))
        #expect(Set(cached.fuelProducts) == Set(products))
        // load a product
        let product = try #require(try await store.storage.fetch(FuelProduct.self, for: products[0]))
        #expect(product.location == location)
        #expect(product.price > 0)
    }

    @Test
    func locationDetailViewModel() async throws {
        let store = try Store(
            named: "FuelingTests-\(UUID())",
            locationService: .mock,
            isStoredInMemoryOnly: true
        )
        let viewModel = LocationDetailViewModel(id: 15, store: store)
        // wait for the load task to finish
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let location = try #require(viewModel.location)
        #expect(location.name == "Seville Travel Center")
        #expect(location.fuelProducts.isEmpty == false)
        #expect(location.fuelProducts.allSatisfy { $0.price.hasPrefix("$") })
        #expect(location.fuelLanes == 9)
        #expect(viewModel.error == nil)
    }

    @Test
    func locationsViewModel() async throws {
        let store = try Store(
            named: "FuelingTests-\(UUID())",
            locationService: .mock,
            isStoredInMemoryOnly: true
        )
        store.userLocation = LocationCoordinate(latitude: 41.0322, longitude: -81.9078)
        let viewModel = LocationsViewModel(store: store)
        // wait for the load task to finish
        try await Task.sleep(nanoseconds: 2_000_000_000)
        #expect(viewModel.state == .loaded)
        #expect(viewModel.locations.count == MockHTTPClient.locations.count)
        // nearest location first
        #expect(viewModel.locations.first?.id == 15)
        #expect(viewModel.distance(to: viewModel.locations.first!) == "Here")
        // search
        viewModel.searchText = "Pittsburgh"
        try await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(viewModel.locations.count == 1)
        #expect(viewModel.locations.first?.id == 57)
    }

    @Test
    func offlineStore() async throws {
        let store = try Store(
            named: "FuelingTests-\(UUID())",
            isStoredInMemoryOnly: true
        )
        #expect(store.shouldDownloadLocations == false)
        await #expect(throws: FuelingError.serviceUnavailable) {
            try await store.locations()
        }
        // insert directly and read back
        let location = Location(
            id: 1,
            name: "Test Location",
            address: "1 Main Street",
            city: "Springfield",
            state: "Ohio",
            zipCode: "45501",
            phone: "555-555-5555",
            latitude: 39.9,
            longitude: -83.8
        )
        try await store.insert(location)
        #expect(store.changeCount == 1)
        let cached = try await store.cached(1)
        #expect(cached.name == "Test Location")
    }
}
