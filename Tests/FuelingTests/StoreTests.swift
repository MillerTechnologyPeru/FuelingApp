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
            siteService: .mock,
            isStoredInMemoryOnly: true
        )
        // download and persist all sites
        let ids = try await store.locations()
        #expect(ids.count == MockHTTPClient.locations.count)
        #expect(store.lastSitesRefresh != nil)
        // fetch from storage
        let sites = try await store.storage.fetch(Site.self, search: nil)
        #expect(sites.count == ids.count)
        // filtered fetch
        let filtered = try await store.storage.fetch(Site.self, search: "Seville")
        #expect(filtered.count == 1)
        #expect(filtered.first?.id == 15)
        // search by state
        let ohio = try await store.storage.fetch(Site.self, search: "Ohio")
        #expect(ohio.count == 3)
    }

    @Test
    func fetchFuelPrices() async throws {
        let store = try Store(
            named: "FuelingTests-\(UUID())",
            siteService: .mock,
            isStoredInMemoryOnly: true
        )
        // fetch site with fuel prices
        let site: Site.ID = 15
        try await store.locations(sites: [site])
        let products = try await store.fuelPrices(for: [site])
        #expect(products.isEmpty == false)
        // fuel products should be linked to the site
        let cached = try #require(try await store.storage.fetch(Site.self, for: site))
        #expect(Set(cached.fuelProducts) == Set(products))
        // load a product
        let product = try #require(try await store.storage.fetch(FuelProduct.self, for: products[0]))
        #expect(product.site == site)
        #expect(product.price > 0)
    }

    @Test
    func siteDetailViewModel() async throws {
        let store = try Store(
            named: "FuelingTests-\(UUID())",
            siteService: .mock,
            isStoredInMemoryOnly: true
        )
        let viewModel = SiteDetailViewModel(id: 15, store: store)
        // wait for the load task to finish
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let site = try #require(viewModel.site)
        #expect(site.name == "Seville Travel Center")
        #expect(site.fuelProducts.isEmpty == false)
        #expect(site.fuelProducts.allSatisfy { $0.price.hasPrefix("$") })
        #expect(site.fuelLanes == 9)
        #expect(viewModel.error == nil)
    }

    @Test
    func sitesViewModel() async throws {
        let store = try Store(
            named: "FuelingTests-\(UUID())",
            siteService: .mock,
            isStoredInMemoryOnly: true
        )
        store.userLocation = LocationCoordinate(latitude: 41.0322, longitude: -81.9078)
        let viewModel = SitesViewModel(store: store)
        // wait for the load task to finish
        try await Task.sleep(nanoseconds: 2_000_000_000)
        #expect(viewModel.state == .loaded)
        #expect(viewModel.sites.count == MockHTTPClient.locations.count)
        // nearest site first
        #expect(viewModel.sites.first?.id == 15)
        #expect(viewModel.distance(to: viewModel.sites.first!) == "Here")
        // search
        viewModel.searchText = "Pittsburgh"
        try await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(viewModel.sites.count == 1)
        #expect(viewModel.sites.first?.id == 57)
    }

    @Test
    func offlineStore() async throws {
        let store = try Store(
            named: "FuelingTests-\(UUID())",
            isStoredInMemoryOnly: true
        )
        #expect(store.shouldDownloadSites == false)
        await #expect(throws: FuelingError.serviceUnavailable) {
            try await store.locations()
        }
        // insert directly and read back
        let site = Site(
            id: 1,
            name: "Test Site",
            address: "1 Main Street",
            city: "Springfield",
            state: "Ohio",
            zipCode: "45501",
            phone: "555-555-5555",
            latitude: 39.9,
            longitude: -83.8
        )
        try await store.insert(site)
        #expect(store.changeCount == 1)
        let cached = try await store.cached(1)
        #expect(cached.name == "Test Site")
    }
}
