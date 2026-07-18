//
//  FuelProduct.swift
//  CoreFueling
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreModel

// See the note atop Location.swift: Embedded Swift can't run the `@Entity`
// macro, so this type is declared twice — hand-written under Embedded,
// macro-driven otherwise. Each branch is an independent, fully-balanced
// declaration. The Embedded branch skips `Entity`/`CachedEntity` conformance
// for the same reason as `Location` — see that file's note.

#if hasFeature(Embedded)

/// A priced fuel product sold at a location.
public struct FuelProduct: Equatable, Hashable, Identifiable, Sendable {

    public let id: ID

    public let location: Location.ID

    public let updated: Date

    public var price: Double

    public var descriptionText: String

    public var lastCached: Date

    public init(
        id: FuelProduct.ID,
        location: Location.ID,
        updated: Date,
        price: Double,
        descriptionText: String,
        lastCached: Date = .now
    ) {
        self.id = id
        self.location = location
        self.updated = updated
        self.price = price
        self.descriptionText = descriptionText
        self.lastCached = lastCached
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case location
        case updated
        case price
        case descriptionText
        case lastCached
    }

    public static var entityName: EntityName { "FuelProduct" }

    public static var attributes: [CodingKeys: AttributeType] {
        [
            .updated: .date,
            .price: .double,
            .descriptionText: .string,
            .lastCached: .date
        ]
    }

    public static var relationships: [CodingKeys: Relationship] {
        [
            .location: Relationship(
                id: PropertyKey(CodingKeys.location),
                type: .toOne,
                destinationEntity: Location.entityName,
                inverseRelationship: PropertyKey(Location.CodingKeys.fuelProducts)
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
        self.location = try container.toOne(Location.ID.self, forKey: CodingKeys.location)
        self.updated = try container.date(forKey: CodingKeys.updated)
        self.price = try container.double(forKey: CodingKeys.price)
        self.descriptionText = try container.string(forKey: CodingKeys.descriptionText)
        self.lastCached = try container.date(forKey: CodingKeys.lastCached)
    }

    public func encode() -> ModelData {
        var container = ModelData(
            entity: Self.entityName,
            id: ObjectID(self.id)
        )
        container.encodeToOne(self.location, forKey: CodingKeys.location)
        container.encode(self.updated, forKey: CodingKeys.updated)
        container.encode(self.price, forKey: CodingKeys.price)
        container.encode(self.descriptionText, forKey: CodingKeys.descriptionText)
        container.encode(self.lastCached, forKey: CodingKeys.lastCached)
        return container
    }
}

#else

/// A priced fuel product sold at a location.
@Entity
public struct FuelProduct: Codable, Equatable, Hashable, Identifiable, Sendable, CachedEntity {

    public let id: ID

    @Relationship(destination: Location.self, inverse: .fuelProducts)
    public let location: Location.ID

    @Attribute
    public let updated: Date

    @Attribute
    public var price: Double

    @Attribute
    public var descriptionText: String

    @Attribute
    public var lastCached: Date

    public init(
        id: FuelProduct.ID,
        location: Location.ID,
        updated: Date,
        price: Double,
        descriptionText: String,
        lastCached: Date = Date()
    ) {
        self.id = id
        self.location = location
        self.updated = updated
        self.price = price
        self.descriptionText = descriptionText
        self.lastCached = lastCached
    }

    public enum CodingKeys: CodingKey {
        case id
        case location
        case updated
        case price
        case descriptionText
        case lastCached
    }
}

#endif

// MARK: - Supporting Types

public extension FuelProduct {

    struct ID: Equatable, Hashable, Sendable {

        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

#if !hasFeature(Embedded)
extension FuelProduct.ID: Codable {}
#endif

extension FuelProduct.ID: CustomStringConvertible {

    public var description: String {
        rawValue
    }
}

extension FuelProduct.ID: ObjectIDConvertible {

    public init?(objectID: ObjectID) {
        self.init(rawValue: objectID.rawValue)
    }
}

public extension FuelProduct.ID {

    /// Identifier for a fuel price entry, namespaced by location.
    static func fuelPrice(
        _ code: String,
        location: Location.ID
    ) -> Self {
        .init(rawValue: location.description + "/fuelprice/" + code)
    }
}
