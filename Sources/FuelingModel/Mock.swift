//
//  Mock.swift
//  FuelingModel
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreFueling
import FuelingAPI

/// In-process ``FuelingAPI/FuelingAPIClient`` serving sample data,
/// for previews, playgrounds and tests.
public struct MockFuelingAPIClient: FuelingAPIClient {

    /// Simulated network delay.
    public var delay: TimeInterval

    public init(delay: TimeInterval = 0.3) {
        self.delay = delay
    }

    public func locations(sites: [Site.ID]) async throws(FuelingError) -> [Location] {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        let locations = Self.locations
        guard sites.isEmpty == false else {
            return locations
        }
        let requested = Set(sites.map { Site.ID.Prefixed(id: $0).rawValue })
        return locations.filter { requested.contains($0.siteID) }
    }

    public func fuelPrices(for sites: [Site.ID]) async throws(FuelingError) -> [FuelPrice] {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        let prices = Self.fuelPrices
        guard sites.isEmpty == false else {
            return prices
        }
        let requested = Set(sites.map { Site.ID.Prefixed(id: $0).rawValue })
        return prices.filter { requested.contains($0.siteID) }
    }
}

public extension SiteService where Self == APISiteService {

    /// Sample-data service for previews and playgrounds.
    static var mock: APISiteService {
        APISiteService(client: MockFuelingAPIClient())
    }
}

public extension MockFuelingAPIClient {

    static let locations: [Location] = [
        Location(
            siteID: "0015",
            name: "Seville Travel Center",
            address: "8834 Lake Road",
            city: "Seville",
            state: "Ohio",
            zipCode: "44273",
            latitude: 41.0322,
            longitude: -81.9078,
            directions: "I-71 & I-76 at Rt. 224, Exit 209",
            phoneNumbers: .init(primaryPhoneNumber: "330-555-2053"),
            fuelingOptions: ["Diesel", "Auto Diesel", "DEF Island Fueling", "Unleaded Gasoline"],
            dieselDispenserLanes: 9,
            truckParkingSpaces: 237,
            privateShowers: 10,
            storeBrand: "Roadstar"
        ),
        Location(
            siteID: "0023",
            name: "Columbus East Fuel Stop",
            address: "6161 Interstate Parkway",
            city: "Columbus",
            state: "Ohio",
            zipCode: "43217",
            latitude: 39.8781,
            longitude: -82.8121,
            directions: "I-270 at US-33, Exit 46",
            phoneNumbers: .init(primaryPhoneNumber: "614-555-0148"),
            fuelingOptions: ["Diesel", "DEF Island Fueling", "Unleaded Gasoline"],
            dieselDispenserLanes: 7,
            truckParkingSpaces: 150,
            privateShowers: 8,
            storeBrand: "Roadstar"
        ),
        Location(
            siteID: "0042",
            name: "Toledo Junction Travel Plaza",
            address: "3483 Libbey Road",
            city: "Perrysburg",
            state: "Ohio",
            zipCode: "43551",
            latitude: 41.5164,
            longitude: -83.5992,
            directions: "I-75 & I-80/90, Exit 71",
            phoneNumbers: .init(primaryPhoneNumber: "419-555-0837"),
            fuelingOptions: ["Diesel", "Auto Diesel", "Electric Charging Stations"],
            dieselDispenserLanes: 6,
            truckParkingSpaces: 122,
            privateShowers: 6,
            storeBrand: "Summit"
        ),
        Location(
            siteID: "0057",
            name: "Steel City Truck Plaza",
            address: "1150 Smithfield Street",
            city: "Pittsburgh",
            state: "Pennsylvania",
            zipCode: "15222",
            latitude: 40.4306,
            longitude: -80.0034,
            directions: "I-76 at Exit 57",
            phoneNumbers: .init(primaryPhoneNumber: "412-555-0921"),
            fuelingOptions: ["Diesel", "Unleaded Gasoline"],
            dieselDispenserLanes: 5,
            truckParkingSpaces: 96,
            privateShowers: 4,
            storeBrand: "Summit"
        ),
        Location(
            siteID: "0068",
            name: "Crossroads Travel Center",
            address: "5720 West Morris Street",
            city: "Indianapolis",
            state: "Indiana",
            zipCode: "46241",
            latitude: 39.7381,
            longitude: -86.2645,
            directions: "I-465 at Exit 12A",
            phoneNumbers: .init(primaryPhoneNumber: "317-555-0264"),
            fuelingOptions: ["Diesel", "Auto Diesel", "DEF Island Fueling", "Hydrogen"],
            dieselDispenserLanes: 8,
            truckParkingSpaces: 180,
            privateShowers: 9,
            storeBrand: "Roadstar"
        )
    ]

    static let fuelPrices: [FuelPrice] = locations.flatMap { location in
        var prices = [
            FuelPrice(
                siteID: location.siteID,
                price: 3.899,
                productDescription: "Diesel",
                loadDate: "2026-07-17T06:00:00",
                fuelCode: "DSL"
            ),
            FuelPrice(
                siteID: location.siteID,
                price: 4.249,
                productDescription: "DEF",
                loadDate: "2026-07-17T06:00:00",
                fuelCode: "DEF"
            )
        ]
        if location.fuelingOptions?.contains("Unleaded Gasoline") == true {
            prices.append(
                FuelPrice(
                    siteID: location.siteID,
                    price: 3.199,
                    productDescription: "Unleaded Gasoline",
                    loadDate: "2026-07-17T06:00:00",
                    fuelCode: "UNL"
                )
            )
        }
        return prices
    }
}
