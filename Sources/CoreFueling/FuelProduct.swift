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

// MARK: - Supporting Types

public extension FuelProduct {

    struct ID: Codable, Equatable, Hashable, Sendable {

        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

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
