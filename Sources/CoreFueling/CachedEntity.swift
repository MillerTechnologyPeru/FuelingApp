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
