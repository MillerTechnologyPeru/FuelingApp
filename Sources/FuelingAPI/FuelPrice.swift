//
//  FuelPrice.swift
//  FuelingAPI
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// Wire representation of a fuel price returned by `GET /v1/fuelprice`.
public struct FuelPrice: Codable, Equatable, Hashable, Sendable {

    /// Zero-padded site identifier.
    public let siteID: String

    /// Fuel price at the specified site.
    public let price: Double

    /// Description of the fuel product.
    public let productDescription: String

    /// Date the price was loaded, e.g. `2024-01-30T13:26:15`.
    public let loadDate: String

    /// Unique code for each fuel type.
    public let fuelCode: String

    public enum CodingKeys: String, CodingKey {
        case siteID
        case price
        case productDescription
        case loadDate
        case fuelCode
    }

    public init(
        siteID: String,
        price: Double,
        productDescription: String,
        loadDate: String,
        fuelCode: String
    ) {
        self.siteID = siteID
        self.price = price
        self.productDescription = productDescription
        self.loadDate = loadDate
        self.fuelCode = fuelCode
    }
}

public extension FuelPrice {

    /// Parsed `loadDate`, interpreted in the given time zone.
    func updated(in timeZone: TimeZone = .current) -> Date? {
        FuelPrice.dateFormatter(timeZone).date(from: loadDate)
    }

    internal static func dateFormatter(_ timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = timeZone
        return formatter
    }
}
