//
//  SiteTests.swift
//  FuelingTests
//

import Foundation
import Testing
import CoreModel
@testable import CoreFueling

@Suite
struct SiteTests {

    @Test
    func schema() {
        let model = Model.fueling
        #expect(model.entities.count == 3)
        let entityNames = Set(model.entities.map { $0.id.rawValue })
        #expect(entityNames == ["Site", "FuelProduct", "FuelOption"])
    }

    @Test
    func identifier() {
        let id: Site.ID = 15
        #expect(id.description == "15")
        let prefixed = Site.ID.Prefixed(id: id)
        #expect(prefixed.rawValue == "0015")
        #expect(Site.ID.Prefixed(rawValue: "0015") == prefixed)
        #expect(Site.ID(prefixed) == id)
        #expect(Site.ID.Prefixed(rawValue: "abc") == nil)
    }

    @Test
    func encode() throws {
        let site = Site(
            id: 15,
            fuelOptions: [.diesel, .defIslandFueling],
            name: "Seville Travel Center",
            address: "8834 Lake Road",
            city: "Seville",
            state: "Ohio",
            zipCode: "44273",
            phone: "330-555-2053",
            directions: "I-71 & I-76 at Rt. 224, Exit 209",
            latitude: 41.0322,
            longitude: -81.9078,
            fuelLanes: 9,
            truckParkingSpaces: 237,
            showers: 10
        )
        let data = try site.encode()
        #expect(data.entity == Site.entityName)
        #expect(data.id == ObjectID(site.id))
        let decoded = try Site(from: data)
        #expect(decoded == site)
    }

    @Test
    func coordinates() {
        let seville = LocationCoordinate(latitude: 41.0322, longitude: -81.9078)
        let columbus = LocationCoordinate(latitude: 39.8781, longitude: -82.8121)
        let distance = seville.distance(to: columbus)
        // ~150 km apart
        #expect(distance > 100_000)
        #expect(distance < 200_000)
        #expect(seville.distance(to: seville) == 0)
    }

    @Test
    func fuelOptionIdentifier() {
        #expect(FuelOption.ID(name: "DEF Island Fueling") == .defIslandFueling)
        #expect(FuelOption.ID(name: "Auto Diesel") == .autoDiesel)
        #expect(FuelOption.ID(name: "") == nil)
    }

    @Test
    func query() {
        let query = Site.Query.search("Seville")
        #expect(query != nil)
        #expect(Site.Query.search("") == nil)
        #expect(Site.Query.search(nil) == nil)
        // predicate should compile to a compound OR
        if case .compound = query!.predicate {
        } else {
            Issue.record("Expected compound predicate")
        }
    }
}
