//
//  FuelingAPITests.swift
//  FuelingTests
//

import Foundation
import Testing
import CoreModel
import CoreFueling
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
        let client = URLSessionFuelingAPIClient(
            server: ServerURL(rawValue: "https://example.com")!
        )
        let url = client.url(path: "v1/fuelprice", sites: [15, 23])
        #expect(url.absoluteString == "https://example.com/v1/fuelprice?siteIds=0015&siteIds=0023")
        let allURL = client.url(path: "v1/locations", sites: [])
        #expect(allURL.absoluteString == "https://example.com/v1/locations")
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
        let site = try Site(from: graph[0])
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
