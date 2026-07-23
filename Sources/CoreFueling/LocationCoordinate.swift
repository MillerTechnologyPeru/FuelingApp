//
//  LocationCoordinate.swift
//  CoreFueling
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
// `sin`/`cos`/`atan2` come from Foundation on Darwin, but `FoundationEssentials`
// — preferred above whenever it's importable, which includes Android, and
// always true under Embedded Swift (no Foundation there at all) — doesn't
// transitively expose libm on those platforms. Pull it from the platform's
// own libc module directly; verified empirically (Android's `FoundationEssentials`
// alone fails to resolve `sin`/`cos`/`atan2` when actually cross-compiled).
#if canImport(Bionic)
import Bionic
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#elseif canImport(ucrt)
import ucrt
#elseif hasFeature(Embedded)
// Bare-metal Embedded targets (e.g. the Nintendo DS port) have no importable
// libc module at all; bind the libm symbols directly — the platform C library
// (newlib on devkitARM, linked via `-lm`) provides them at link time.
@_silgen_name("sin") private func sin(_ x: Double) -> Double
@_silgen_name("cos") private func cos(_ x: Double) -> Double
@_silgen_name("atan2") private func atan2(_ y: Double, _ x: Double) -> Double
#endif

/// Geographic coordinate (latitude / longitude in degrees).
public struct LocationCoordinate: Equatable, Hashable, Sendable {

    /// Latitude in degrees.
    public var latitude: Double

    /// Longitude in degrees.
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// Codable relies on stdlib synthesis, which is unavailable under Embedded Swift.
#if !hasFeature(Embedded)
extension LocationCoordinate: Codable {}
#endif

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
