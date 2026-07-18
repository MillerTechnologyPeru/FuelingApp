//
//  GetLocation.swift
//  FuelingAPI
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// Wire representation of a fueling location returned by `GET /v1/locations`.
public struct GetLocation: Codable, Equatable, Hashable, Sendable {

    public let siteID: String

    public let name: String

    public let address: String

    public let city: String

    public let state: String

    public let zipCode: String

    public let latitude: Double

    public let longitude: Double

    public let directions: String?

    public let phoneNumbers: PhoneNumbers

    public let fuelingOptions: [String]?

    public let dieselDispenserLanes: Int?

    public let truckParkingSpaces: Int?

    public let privateShowers: Int?

    public let storeBrand: String?

    public enum CodingKeys: String, CodingKey {
        case siteID = "site_id"
        case name = "location_name"
        case address = "address_line_1"
        case city
        case state
        case zipCode = "zip_code"
        case latitude
        case longitude
        case directions
        case phoneNumbers = "phone_numbers"
        case fuelingOptions = "fueling_options"
        case dieselDispenserLanes = "diesel_dispenser_lanes"
        case truckParkingSpaces = "truck_parking_spaces"
        case privateShowers = "private_showers"
        case storeBrand = "store_brand"
    }

    public init(
        siteID: String,
        name: String,
        address: String,
        city: String,
        state: String,
        zipCode: String,
        latitude: Double,
        longitude: Double,
        directions: String? = nil,
        phoneNumbers: PhoneNumbers = .init(),
        fuelingOptions: [String]? = nil,
        dieselDispenserLanes: Int? = nil,
        truckParkingSpaces: Int? = nil,
        privateShowers: Int? = nil,
        storeBrand: String? = nil
    ) {
        self.siteID = siteID
        self.name = name
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.latitude = latitude
        self.longitude = longitude
        self.directions = directions
        self.phoneNumbers = phoneNumbers
        self.fuelingOptions = fuelingOptions
        self.dieselDispenserLanes = dieselDispenserLanes
        self.truckParkingSpaces = truckParkingSpaces
        self.privateShowers = privateShowers
        self.storeBrand = storeBrand
    }
}

// MARK: - Supporting Types

public extension GetLocation {

    struct PhoneNumbers: Codable, Equatable, Hashable, Sendable {

        public let primaryPhoneNumber: String?

        public enum CodingKeys: String, CodingKey {
            case primaryPhoneNumber = "primary_phone_number"
        }

        public init(primaryPhoneNumber: String? = nil) {
            self.primaryPhoneNumber = primaryPhoneNumber
        }
    }
}
