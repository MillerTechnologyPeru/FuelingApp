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

    /// Zero-padded location identifier.
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

    /// Parsed `loadDate` (fixed `yyyy-MM-dd'T'HH:mm:ss` format), interpreted
    /// in the given time zone.
    ///
    /// Hand-parses the string with `Calendar`/`DateComponents` instead of
    /// `DateFormatter`, which — like `NumberFormatter` — lives in full
    /// `Foundation` (not `FoundationEssentials`). This keeps `FuelingAPI`
    /// buildable wherever only the lean subset is linked, e.g. Android, which
    /// this project's `#if canImport(FoundationEssentials)` /
    /// `#elseif canImport(Foundation)` import guards prefer whenever it's
    /// available rather than always falling back to full `Foundation`.
    func updated(in timeZone: TimeZone = .current) -> Date? {
        let fields = loadDate.split(whereSeparator: { $0 == "-" || $0 == "T" || $0 == ":" })
        guard fields.count == 6,
            let year = Int(fields[0]),
            let month = Int(fields[1]),
            let day = Int(fields[2]),
            let hour = Int(fields[3]),
            let minute = Int(fields[4]),
            let second = Int(fields[5])
        else {
            return nil
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: components)
    }
}
