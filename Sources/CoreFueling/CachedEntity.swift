//
//  CachedEntity.swift
//  CoreFueling
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreModel

/// An entity cached from a remote source, tracking when it was last fetched.
public protocol CachedEntity: Entity {

    var lastCached: Date { get }
}

#if hasFeature(Embedded)
public extension Date {

    /// Stand-in for `Foundation.Date.now` under Embedded Swift, whose
    /// `CoreModel`-provided `Date` has no wall clock. Returns the reference date;
    /// real callers pass an explicit timestamp.
    static var now: Date {
        Date(timeIntervalSinceReferenceDate: 0)
    }
}
#endif
