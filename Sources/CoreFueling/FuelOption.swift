//
//  FuelOption.swift
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
// declaration. The Embedded branch skips `Entity` conformance for the same
// reason as `Location` — see that file's note.

#if hasFeature(Embedded)

/// A fueling option offered by locations (diesel, DEF, etc).
public struct FuelOption: Equatable, Hashable, Identifiable, Sendable {

    public let id: ID

    public var name: String

    public var locations: [Location.ID]

    public init(id: ID, name: String, locations: [Location.ID] = []) {
        self.id = id
        self.name = name
        self.locations = locations
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case locations
    }

    public static var entityName: EntityName { "FuelOption" }

    public static var attributes: [CodingKeys: AttributeType] {
        [
            .name: .string
        ]
    }

    public static var relationships: [CodingKeys: Relationship] {
        [
            .locations: Relationship(
                id: PropertyKey(CodingKeys.locations),
                type: .toMany,
                destinationEntity: Location.entityName,
                inverseRelationship: PropertyKey(Location.CodingKeys.fuelOptions)
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
        self.name = try container.string(forKey: CodingKeys.name)
        self.locations = try container.toMany(Location.ID.self, forKey: CodingKeys.locations)
    }

    public func encode() -> ModelData {
        var container = ModelData(
            entity: Self.entityName,
            id: ObjectID(self.id)
        )
        container.encode(self.name, forKey: CodingKeys.name)
        container.encodeToMany(self.locations, forKey: CodingKeys.locations)
        return container
    }
}

#else

/// A fueling option offered by locations (diesel, DEF, etc).
@Entity
public struct FuelOption: Equatable, Hashable, Codable, Identifiable, Sendable {

    public let id: ID

    @Attribute
    public var name: String

    @Relationship(destination: Location.self, inverse: .fuelOptions)
    public var locations: [Location.ID]

    public init(id: ID, name: String, locations: [Location.ID] = []) {
        self.id = id
        self.name = name
        self.locations = locations
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case locations
    }
}

#endif

// MARK: - Supporting Types

public extension FuelOption {

    struct ID: RawRepresentable, Equatable, Hashable, Sendable {

        public let rawValue: String

        public init?(rawValue: String) {
            guard rawValue.isEmpty == false else {
                return nil
            }
            self.init(rawValue)
        }

        private init(_ raw: String) {
            assert(raw.isEmpty == false)
            self.rawValue = raw
        }
    }
}

#if !hasFeature(Embedded)
extension FuelOption.ID: Codable {}
#endif

public extension FuelOption.ID {

    /// Derive a stable identifier slug from a display name.
    init?(name: String) {
        let id =
            name
            .lowercased()
            .replacingAllOccurrences(of: "-", with: "")
            .replacingAllOccurrences(of: " ", with: "-")
        self.init(rawValue: id)
    }
}

internal extension String {

    /// Foundation-free character replacement — `String.replacing(_:with:)`
    /// needs Foundation, which is unavailable under Embedded Swift.
    func replacingAllOccurrences(of target: Character, with replacement: String) -> String {
        var result = ""
        result.reserveCapacity(count)
        for character in self {
            if character == target {
                result += replacement
            } else {
                result.append(character)
            }
        }
        return result
    }
}

// MARK: - CoreModel

extension FuelOption.ID: ObjectIDConvertible {}

// MARK: - ExpressibleByStringLiteral

extension FuelOption.ID: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        guard let value = FuelOption.ID(rawValue: value) else {
            fatalError("Invalid raw value for \(FuelOption.ID.self): \(value)")
        }
        self = value
    }
}

// MARK: - CustomStringConvertible

extension FuelOption.ID: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        rawValue
    }

    public var debugDescription: String {
        rawValue
    }
}

// MARK: - Constants

public extension FuelOption.ID {

    /// Diesel
    static var diesel: FuelOption.ID { "diesel" }
    /// Auto Diesel
    static var autoDiesel: FuelOption.ID { "auto-diesel" }
    /// Biodiesel Blend
    static var biodieselBlend: FuelOption.ID { "biodiesel-blend" }
    /// DEF Island Fueling
    static var defIslandFueling: FuelOption.ID { "def-island-fueling" }
    /// Unleaded Gasoline
    static var unleadedGasoline: FuelOption.ID { "unleaded-gasoline" }
    /// Electric Charging Stations
    static var electricChargingStations: FuelOption.ID { "electric-charging-stations" }
    /// Hydrogen
    static var hydrogen: FuelOption.ID { "hydrogen" }
}
