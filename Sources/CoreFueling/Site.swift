//
//  Site.swift
//  CoreFueling
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreModel

/// A fueling site (location).
@Entity
public struct Site: Equatable, Hashable, Codable, Identifiable, Sendable, CachedEntity {

    public let id: ID

    @Relationship(destination: FuelProduct.self, inverse: .site)
    public var fuelProducts: [FuelProduct.ID]

    @Relationship(destination: FuelOption.self, inverse: .sites)
    public var fuelOptions: [FuelOption.ID]

    @Attribute
    public var name: String

    @Attribute
    public var brand: String?

    @Attribute
    public var address: String

    @Attribute
    public var city: String

    @Attribute
    public var state: String

    @Attribute
    public var zipCode: String

    @Attribute
    public var phone: String

    @Attribute
    public var directions: String?

    @Attribute
    public var latitude: Double

    @Attribute
    public var longitude: Double

    @Attribute(.int16)
    public var fuelLanes: Int

    @Attribute(.int16)
    public var truckParkingSpaces: Int

    @Attribute(.int16)
    public var showers: Int

    @Attribute
    public var lastCached: Date

    @Attribute
    public var lastViewed: Date?

    public init(
        id: ID,
        fuelProducts: [FuelProduct.ID] = [],
        fuelOptions: [FuelOption.ID] = [],
        name: String,
        brand: String? = nil,
        address: String,
        city: String,
        state: String,
        zipCode: String,
        phone: String,
        directions: String? = nil,
        latitude: Double,
        longitude: Double,
        fuelLanes: Int = 0,
        truckParkingSpaces: Int = 0,
        showers: Int = 0,
        lastCached: Date = Date(),
        lastViewed: Date? = nil
    ) {
        self.id = id
        self.fuelProducts = fuelProducts
        self.fuelOptions = fuelOptions
        self.name = name
        self.brand = brand
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.phone = phone
        self.directions = directions
        self.latitude = latitude
        self.longitude = longitude
        self.fuelLanes = fuelLanes
        self.truckParkingSpaces = truckParkingSpaces
        self.showers = showers
        self.lastCached = lastCached
        self.lastViewed = lastViewed
    }

    public enum CodingKeys: String, CaseIterable, CodingKey {
        case id
        case fuelProducts
        case fuelOptions
        case name
        case brand
        case address
        case city
        case state
        case zipCode
        case phone
        case directions
        case latitude
        case longitude
        case fuelLanes
        case truckParkingSpaces
        case showers
        case lastCached
        case lastViewed
    }
}

public extension Site {

    /// Geographic coordinates of the site.
    var coordinates: LocationCoordinate {
        LocationCoordinate(latitude: latitude, longitude: longitude)
    }

    /// Full postal address, one component per line.
    var postalAddress: String {
        address + "\n" + city + ", " + state + " " + zipCode
    }
}

// MARK: - CoreModel

extension Site.ID: ObjectIDConvertible {

    public init?(objectID: CoreModel.ObjectID) {
        guard let rawValue = UInt(objectID.rawValue) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }
}
