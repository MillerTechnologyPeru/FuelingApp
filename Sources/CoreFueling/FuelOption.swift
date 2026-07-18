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

// MARK: - Supporting Types

public extension FuelOption {

    struct ID: RawRepresentable, Codable, Equatable, Hashable, Sendable {

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

public extension FuelOption.ID {

    /// Derive a stable identifier slug from a display name.
    init?(name: String) {
        let id =
            name
            .lowercased()
            .replacing("-", with: "")
            .replacing(" ", with: "-")
        self.init(rawValue: id)
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
