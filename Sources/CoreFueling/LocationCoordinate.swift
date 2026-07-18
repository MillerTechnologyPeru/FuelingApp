//
//  LocationCoordinate.swift
//  CoreFueling
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// Geographic coordinate (latitude / longitude in degrees).
public struct LocationCoordinate: Equatable, Hashable, Codable, Sendable {

    /// Latitude in degrees.
    public var latitude: Double

    /// Longitude in degrees.
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public extension LocationCoordinate {

    /// Great-circle distance to the specified coordinate in meters,
    /// computed with the haversine formula.
    func distance(to other: LocationCoordinate) -> Double {
        haversineDistance(latitude, longitude, other.latitude, other.longitude)
    }
}

/// Earth's mean radius, in meters.
internal let earthRadius = 6_371_000.0

/// Great-circle distance between two coordinates in meters, via the haversine formula.
internal func haversineDistance(
    _ latitude1: Double,
    _ longitude1: Double,
    _ latitude2: Double,
    _ longitude2: Double
) -> Double {
    let phi1 = latitude1 * .pi / 180
    let phi2 = latitude2 * .pi / 180
    let deltaPhi = (latitude2 - latitude1) * .pi / 180
    let deltaLambda = (longitude2 - longitude1) * .pi / 180
    let a =
        sin(deltaPhi / 2) * sin(deltaPhi / 2)
        + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
    let c = 2 * atan2(a.squareRoot(), (1 - a).squareRoot())
    return earthRadius * c
}
