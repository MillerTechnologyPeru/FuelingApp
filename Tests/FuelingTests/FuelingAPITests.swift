//
//  FuelingAPITests.swift
//  FuelingTests
//

import Foundation
import Testing
import HTTPTypes
import CoreModel
import CoreFueling
import FuelingModel
@testable import FuelingAPI

@Suite
struct FuelingAPITests {

    @Test
    func serverURL() {
        let server = ServerURL(rawValue: "https://example.com")!
        #expect(server.rawValue == "https://example.com")
        #expect(server.host == "example.com")
        #expect(server.appending("v1").rawValue == "https://example.com/v1")
        #expect(ServerURL.localhost().rawValue == "http://localhost:8080")
    }

    @Test
    func requestURL() {
        let server = ServerURL(rawValue: "https://example.com")!
        let url = FuelingAPI.url(for: "v1/fuelprice", sites: [15, 23], server: server)
        #expect(url.absoluteString == "https://example.com/v1/fuelprice?siteIds=0015&siteIds=0023")
        let allURL = FuelingAPI.url(for: "v1/locations", sites: [], server: server)
        #expect(allURL.absoluteString == "https://example.com/v1/locations")
    }

    @Test
    func httpClient() async throws {
        // exercise the protocol-extension API end to end over a mock transport
        let client = MockHTTPClient(delay: 0)
        let server = ServerURL.localhost()
        let locations = try await client.locations(server: server)
        #expect(locations.count == MockHTTPClient.locations.count)
        let filtered = try await client.locations(sites: [15], server: server)
        #expect(filtered.map { $0.id } == [15])
        let prices = try await client.fuelPrices(for: [15], server: server)
        #expect(prices.isEmpty == false)
        #expect(prices.allSatisfy { $0.site == 15 })
    }

    @Test
    func httpClientNotFound() async throws {
        let client = MockHTTPClient(delay: 0)
        let request = HTTPRequest(
            method: .get,
            scheme: "http",
            authority: "localhost:8080",
            path: "/v1/unknown"
        )
        let (_, response) = try await client.data(for: request)
        #expect(response.status == .notFound)
    }

    @Test
    func decodeFuelPrices() throws {
        let json = Data(
            #"""
            {
                "status": "Success",
                "message": null,
                "data": [
                    {
                        "siteID": "0015",
                        "price": 3.899,
                        "productDescription": "Diesel",
                        "loadDate": "2026-07-17T06:00:00",
                        "fuelCode": "DSL"
                    }
                ]
            }
            """#.utf8)
        let response = try JSONDecoder().decode(APIResponse<[FuelPrice]>.self, from: json)
        let prices = try response.get()
        #expect(prices.count == 1)
        let price = prices[0]
        #expect(price.site == 15)
        #expect(price.product == .fuelPrice("DSL", site: 15))
        #expect(price.price == 3.899)
        #expect(price.updated() != nil)
    }

    @Test
    func decodeErrorResponse() throws {
        let json = Data(
            #"{ "status": "Error", "message": "Something failed", "data": null }"#.utf8)
        let response = try JSONDecoder().decode(APIResponse<[FuelPrice]>.self, from: json)
        #expect(throws: FuelingError.errorResponse("Something failed")) {
            try response.get()
        }
    }

    @Test
    func decodeLocations() throws {
        let json = Data(
            #"""
            {
                "status": "Success",
                "message": null,
                "data": [
                    {
                        "site_id": "0015",
                        "location_name": "Seville Travel Center",
                        "address_line_1": "8834 Lake Road",
                        "city": "Seville",
                        "state": "Ohio",
                        "zip_code": "44273",
                        "latitude": 41.0322,
                        "longitude": -81.9078,
                        "directions": "I-71 & I-76 at Rt. 224, Exit 209",
                        "phone_numbers": { "primary_phone_number": "330-555-2053" },
                        "fueling_options": ["Diesel", "DEF Island Fueling"],
                        "diesel_dispenser_lanes": 9,
                        "truck_parking_spaces": 237,
                        "private_showers": 10,
                        "store_brand": "Roadstar"
                    }
                ]
            }
            """#.utf8)
        let response = try JSONDecoder().decode(APIResponse<[Location]>.self, from: json)
        let locations = try response.get()
        #expect(locations.count == 1)
        let location = locations[0]
        #expect(location.id == 15)
        #expect(location.name == "Seville Travel Center")
        #expect(location.dieselDispenserLanes == 9)
    }

    @Test
    func locationModelData() throws {
        let location = Location(
            siteID: "0015",
            name: "Seville Travel Center",
            address: "8834 Lake Road",
            city: "Seville",
            state: "Ohio",
            zipCode: "44273",
            latitude: 41.0322,
            longitude: -81.9078,
            phoneNumbers: .init(primaryPhoneNumber: "330-555-2053"),
            fuelingOptions: ["Diesel", "DEF Island Fueling"],
            dieselDispenserLanes: 9
        )
        let graph = ModelData.location(location)
        // 1 site + 2 fuel options
        #expect(graph.count == 3)
        // the mapping is a partial update: `fuelProducts` is deliberately left
        // untouched so refreshing a location never severs cached price links
        var siteData = graph[0]
        #expect(siteData.relationships[PropertyKey(Site.CodingKeys.fuelProducts)] == nil)
        siteData.relationships[PropertyKey(Site.CodingKeys.fuelProducts)] = .toMany([])
        siteData.attributes[PropertyKey(Site.CodingKeys.lastViewed)] = .null
        let site = try Site(from: siteData)
        #expect(site.id == 15)
        #expect(site.name == "Seville Travel Center")
        #expect(site.fuelLanes == 9)
        #expect(Set(site.fuelOptions) == [.diesel, .defIslandFueling])
    }

    @Test
    func fuelPriceModelData() throws {
        let price = FuelPrice(
            siteID: "0015",
            price: 3.899,
            productDescription: "Diesel",
            loadDate: "2026-07-17T06:00:00",
            fuelCode: "DSL"
        )
        let modelData = try #require(ModelData(fuelPrice: price))
        let product = try FuelProduct(from: modelData)
        #expect(product.id == .fuelPrice("DSL", site: 15))
        #expect(product.site == 15)
        #expect(product.price == 3.899)
        #expect(product.descriptionText == "Diesel")
    }
}
