//
//  Location.swift
//  CoreFueling
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreModel

// Under Embedded Swift the `@Entity`/`@Attribute`/`@Relationship` macros are
// unavailable (swift-syntax can't run there), so this type is declared twice:
// the macro-driven version below for normal builds, and a hand-written
// equivalent — conforming to `Entity` directly and implementing what the
// macro would otherwise synthesize — under `#if hasFeature(Embedded)`. Each
// branch must be a complete, independently-balanced declaration; Swift does
// not allow splitting a single declaration's braces across `#if`/`#else`.
//
// The Embedded branch does NOT declare `Entity`/`CachedEntity` conformance:
// `Entity.init(from:)` is an untyped `throws` requirement, and satisfying it
// with a witness that actually throws a concrete error forces the compiler to
// synthesize a boxing thunk (`any Error`) for the protocol witness table,
// which Embedded Swift disallows outright. Nothing under Embedded needs the
// conformance anyway — CoreModel's generic `Entity`-based `ModelStorage`
// helpers are themselves unavailable there (see CoreModel's README) — so this
// type just exposes the same members concretely, with typed throws.
#if hasFeature(Embedded)

/// A fueling location.
public struct Location: Equatable, Hashable, Identifiable, Sendable {

    public let id: ID

    public var fuelProducts: [FuelProduct.ID]

    public var fuelOptions: [FuelOption.ID]

    public var name: String

    public var brand: String?

    public var address: String

    public var city: String

    public var state: String

    public var zipCode: String

    public var phone: String

    public var directions: String?

    public var latitude: Double

    public var longitude: Double

    public var fuelLanes: Int

    public var truckParkingSpaces: Int

    public var showers: Int

    public var lastCached: Date

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
        lastCached: Date = .now,
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

    public static var entityName: EntityName { "Location" }

    public static var attributes: [CodingKeys: AttributeType] {
        [
            .name: .string,
            .brand: .string,
            .address: .string,
            .city: .string,
            .state: .string,
            .zipCode: .string,
            .phone: .string,
            .directions: .string,
            .latitude: .double,
            .longitude: .double,
            .fuelLanes: .int16,
            .truckParkingSpaces: .int16,
            .showers: .int16,
            .lastCached: .date,
            .lastViewed: .date
        ]
    }

    // Built from the base `Relationship(id:type:destinationEntity:inverseRelationship:)`
    // initializer rather than the `Entity`-constrained convenience one — see the
    // note atop this file on why these types don't conform to `Entity`.
    public static var relationships: [CodingKeys: Relationship] {
        [
            .fuelProducts: Relationship(
                id: PropertyKey(CodingKeys.fuelProducts),
                type: .toMany,
                destinationEntity: FuelProduct.entityName,
                inverseRelationship: PropertyKey(FuelProduct.CodingKeys.location)
            ),
            .fuelOptions: Relationship(
                id: PropertyKey(CodingKeys.fuelOptions),
                type: .toMany,
                destinationEntity: FuelOption.entityName,
                inverseRelationship: PropertyKey(FuelOption.CodingKeys.locations)
            )
        ]
    }

    public init(from container: ModelData) throws(CoreModelError) {
        guard container.entity.rawValue == Self.entityName.rawValue else {
            throw CoreModelError.invalidEntity(container.entity)
        }
        guard let id = Self.ID(objectID: container.id) else {
            throw CoreModelError.invalidIdentifier(container.id)
        }
        self.id = id
        self.fuelProducts = try container.toMany(FuelProduct.ID.self, forKey: CodingKeys.fuelProducts)
        self.fuelOptions = try container.toMany(FuelOption.ID.self, forKey: CodingKeys.fuelOptions)
        self.name = try container.string(forKey: CodingKeys.name)
        self.brand = try container.optionalString(forKey: CodingKeys.brand)
        self.address = try container.string(forKey: CodingKeys.address)
        self.city = try container.string(forKey: CodingKeys.city)
        self.state = try container.string(forKey: CodingKeys.state)
        self.zipCode = try container.string(forKey: CodingKeys.zipCode)
        self.phone = try container.string(forKey: CodingKeys.phone)
        self.directions = try container.optionalString(forKey: CodingKeys.directions)
        self.latitude = try container.double(forKey: CodingKeys.latitude)
        self.longitude = try container.double(forKey: CodingKeys.longitude)
        self.fuelLanes = try container.int16(forKey: CodingKeys.fuelLanes)
        self.truckParkingSpaces = try container.int16(forKey: CodingKeys.truckParkingSpaces)
        self.showers = try container.int16(forKey: CodingKeys.showers)
        self.lastCached = try container.date(forKey: CodingKeys.lastCached)
        self.lastViewed = try container.optionalDate(forKey: CodingKeys.lastViewed)
    }

    public func encode() -> ModelData {
        var container = ModelData(
            entity: Self.entityName,
            id: ObjectID(self.id)
        )
        container.encodeToMany(self.fuelProducts, forKey: CodingKeys.fuelProducts)
        container.encodeToMany(self.fuelOptions, forKey: CodingKeys.fuelOptions)
        container.encode(self.name, forKey: CodingKeys.name)
        container.encode(self.brand, forKey: CodingKeys.brand)
        container.encode(self.address, forKey: CodingKeys.address)
        container.encode(self.city, forKey: CodingKeys.city)
        container.encode(self.state, forKey: CodingKeys.state)
        container.encode(self.zipCode, forKey: CodingKeys.zipCode)
        container.encode(self.phone, forKey: CodingKeys.phone)
        container.encode(self.directions, forKey: CodingKeys.directions)
        container.encode(self.latitude, forKey: CodingKeys.latitude)
        container.encode(self.longitude, forKey: CodingKeys.longitude)
        container.encodeInt16(self.fuelLanes, forKey: CodingKeys.fuelLanes)
        container.encodeInt16(self.truckParkingSpaces, forKey: CodingKeys.truckParkingSpaces)
        container.encodeInt16(self.showers, forKey: CodingKeys.showers)
        container.encode(self.lastCached, forKey: CodingKeys.lastCached)
        container.encode(self.lastViewed, forKey: CodingKeys.lastViewed)
        return container
    }
}

#else

/// A fueling location.
@Entity
public struct Location: Equatable, Hashable, Codable, Identifiable, Sendable, CachedEntity {

    public let id: ID

    @Relationship(destination: FuelProduct.self, inverse: .location)
    public var fuelProducts: [FuelProduct.ID]

    @Relationship(destination: FuelOption.self, inverse: .locations)
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

#endif

public extension Location {

    /// Geographic coordinates of the location.
    var coordinates: LocationCoordinate {
        LocationCoordinate(latitude: latitude, longitude: longitude)
    }

    /// Full postal address, one component per line.
    var postalAddress: String {
        address + "\n" + city + ", " + state + " " + zipCode
    }
}

// MARK: - CoreModel

extension Location.ID: ObjectIDConvertible {

    public init?(objectID: CoreModel.ObjectID) {
        guard let rawValue = UInt(objectID.rawValue) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }
}
