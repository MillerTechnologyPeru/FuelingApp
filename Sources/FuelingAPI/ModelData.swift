//
//  ModelData.swift
//  FuelingAPI
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreModel
import CoreFueling

// MARK: - GetLocation

public extension GetLocation {

    /// Parsed location identifier.
    var id: Location.ID? {
        Location.ID.Prefixed(rawValue: siteID).map { Location.ID($0) }
    }
}

public extension ModelData {

    /// Convert a location response into the entity graph to persist
    /// (location + fuel options).
    static func location(
        _ location: GetLocation,
        lastCached: Date = Date()
    ) -> [ModelData] {
        guard let locationData = ModelData(location: location, lastCached: lastCached) else {
            return []
        }
        var modelData = [locationData]
        modelData += (location.fuelingOptions ?? [])
            .compactMap { ModelData(fuelOption: $0) }
        return modelData
    }

    /// Location entity data for a location response.
    init?(
        location: GetLocation,
        lastCached: Date = Date()
    ) {
        guard let id = location.id else {
            return nil
        }
        self.init(entity: Location.entityName, id: ObjectID(id))

        // set attributes
        attributes[.init(Location.CodingKeys.name)] = .string(location.name)
        attributes[.init(Location.CodingKeys.brand)] = location.storeBrand.map { .string($0) } ?? .null
        attributes[.init(Location.CodingKeys.address)] = .string(location.address)
        attributes[.init(Location.CodingKeys.city)] = .string(location.city)
        attributes[.init(Location.CodingKeys.state)] = .string(location.state)
        attributes[.init(Location.CodingKeys.zipCode)] = .string(location.zipCode)
        attributes[.init(Location.CodingKeys.phone)] = .string(location.phoneNumbers.primaryPhoneNumber ?? "")
        attributes[.init(Location.CodingKeys.directions)] = location.directions.map { .string($0) } ?? .null
        attributes[.init(Location.CodingKeys.latitude)] = .double(location.latitude)
        attributes[.init(Location.CodingKeys.longitude)] = .double(location.longitude)
        attributes[.init(Location.CodingKeys.fuelLanes)] = .int16(location.dieselDispenserLanes.map { numericCast($0) } ?? 0)
        attributes[.init(Location.CodingKeys.truckParkingSpaces)] = .int16(location.truckParkingSpaces.map { numericCast($0) } ?? 0)
        attributes[.init(Location.CodingKeys.showers)] = .int16(location.privateShowers.map { numericCast($0) } ?? 0)
        attributes[.init(Location.CodingKeys.lastCached)] = .date(lastCached)

        // set relationships
        let fuelOptions = (location.fuelingOptions ?? [])
            .compactMap { FuelOption.ID(name: $0) }
            .map { ObjectID($0) }
        relationships[.init(Location.CodingKeys.fuelOptions)] = .toMany(fuelOptions)
    }

    /// Fuel option entity data for a fueling option name.
    init?(fuelOption name: String) {
        guard let id = FuelOption.ID(name: name) else {
            return nil
        }
        self.init(entity: FuelOption.entityName, id: ObjectID(id))
        attributes[.init(FuelOption.CodingKeys.name)] = .string(name)
    }
}

// MARK: - FuelPrice

public extension FuelPrice {

    /// Parsed location identifier.
    var location: Location.ID? {
        Location.ID.Prefixed(rawValue: siteID).map { Location.ID($0) }
    }

    /// Fuel product identifier for this price entry.
    var product: FuelProduct.ID? {
        location.map { .fuelPrice(fuelCode, location: $0) }
    }
}

public extension ModelData {

    /// Fuel product entity data for a fuel price response.
    init?(
        fuelPrice: FuelPrice,
        lastCached: Date = Date()
    ) {
        guard let location = fuelPrice.location,
            let product = fuelPrice.product
        else {
            return nil
        }
        self.init(entity: FuelProduct.entityName, id: ObjectID(product))
        attributes[.init(FuelProduct.CodingKeys.updated)] = .date(fuelPrice.updated() ?? lastCached)
        attributes[.init(FuelProduct.CodingKeys.price)] = .double(fuelPrice.price)
        attributes[.init(FuelProduct.CodingKeys.descriptionText)] = .string(fuelPrice.productDescription)
        attributes[.init(FuelProduct.CodingKeys.lastCached)] = .date(lastCached)
        relationships[.init(FuelProduct.CodingKeys.location)] = .toOne(ObjectID(location))
    }
}
