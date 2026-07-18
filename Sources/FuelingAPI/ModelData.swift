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

// MARK: - Location

public extension Location {

    /// Parsed site identifier.
    var id: Site.ID? {
        Site.ID.Prefixed(rawValue: siteID).map { Site.ID($0) }
    }
}

public extension ModelData {

    /// Convert a location response into the entity graph to persist
    /// (site + fuel options).
    static func location(
        _ location: Location,
        lastCached: Date = Date()
    ) -> [ModelData] {
        guard let siteData = ModelData(location: location, lastCached: lastCached) else {
            return []
        }
        var modelData = [siteData]
        modelData += (location.fuelingOptions ?? [])
            .compactMap { ModelData(fuelOption: $0) }
        return modelData
    }

    /// Site entity data for a location response.
    init?(
        location: Location,
        lastCached: Date = Date()
    ) {
        guard let id = location.id else {
            return nil
        }
        self.init(entity: Site.entityName, id: ObjectID(id))

        // set attributes
        attributes[.init(Site.CodingKeys.name)] = .string(location.name)
        attributes[.init(Site.CodingKeys.brand)] = location.storeBrand.map { .string($0) } ?? .null
        attributes[.init(Site.CodingKeys.address)] = .string(location.address)
        attributes[.init(Site.CodingKeys.city)] = .string(location.city)
        attributes[.init(Site.CodingKeys.state)] = .string(location.state)
        attributes[.init(Site.CodingKeys.zipCode)] = .string(location.zipCode)
        attributes[.init(Site.CodingKeys.phone)] = .string(location.phoneNumbers.primaryPhoneNumber ?? "")
        attributes[.init(Site.CodingKeys.directions)] = location.directions.map { .string($0) } ?? .null
        attributes[.init(Site.CodingKeys.latitude)] = .double(location.latitude)
        attributes[.init(Site.CodingKeys.longitude)] = .double(location.longitude)
        attributes[.init(Site.CodingKeys.fuelLanes)] = .int16(location.dieselDispenserLanes.map { numericCast($0) } ?? 0)
        attributes[.init(Site.CodingKeys.truckParkingSpaces)] = .int16(location.truckParkingSpaces.map { numericCast($0) } ?? 0)
        attributes[.init(Site.CodingKeys.showers)] = .int16(location.privateShowers.map { numericCast($0) } ?? 0)
        attributes[.init(Site.CodingKeys.lastCached)] = .date(lastCached)

        // set relationships
        let fuelOptions = (location.fuelingOptions ?? [])
            .compactMap { FuelOption.ID(name: $0) }
            .map { ObjectID($0) }
        relationships[.init(Site.CodingKeys.fuelOptions)] = .toMany(fuelOptions)
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

    /// Parsed site identifier.
    var site: Site.ID? {
        Site.ID.Prefixed(rawValue: siteID).map { Site.ID($0) }
    }

    /// Fuel product identifier for this price entry.
    var product: FuelProduct.ID? {
        site.map { .fuelPrice(fuelCode, site: $0) }
    }
}

public extension ModelData {

    /// Fuel product entity data for a fuel price response.
    init?(
        fuelPrice: FuelPrice,
        lastCached: Date = Date()
    ) {
        guard let site = fuelPrice.site,
            let product = fuelPrice.product
        else {
            return nil
        }
        self.init(entity: FuelProduct.entityName, id: ObjectID(product))
        attributes[.init(FuelProduct.CodingKeys.updated)] = .date(fuelPrice.updated() ?? lastCached)
        attributes[.init(FuelProduct.CodingKeys.price)] = .double(fuelPrice.price)
        attributes[.init(FuelProduct.CodingKeys.descriptionText)] = .string(fuelPrice.productDescription)
        attributes[.init(FuelProduct.CodingKeys.lastCached)] = .date(lastCached)
        relationships[.init(FuelProduct.CodingKeys.site)] = .toOne(ObjectID(site))
    }
}
