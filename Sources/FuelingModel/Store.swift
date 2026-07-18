//
//  Store.swift
//  FuelingModel
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Observation
@_exported import CoreModel
@_exported import CoreFueling

/// Fueling `Store`
///
/// Composition root owning the persistent storage, a synchronous view
/// context for the UI, and the (optional) network transport.
@MainActor
@Observable
public final class Store {

    // MARK: - Properties

    /// Bumped on every persistence mutation so views and view models can
    /// observe it and know when to re-fetch.
    public private(set) var changeCount = 0

    /// Persistent storage.
    public let storage: any ModelStorage

    /// Synchronous main-actor context for UI reads.
    public let viewContext: any ViewContext

    /// Network transport for sites and fuel prices, or `nil` for offline use.
    internal let siteService: (any SiteService)?

    /// Current user location, injected by the app.
    public var userLocation: LocationCoordinate?

    /// Last time the full site list was refreshed from the network.
    public internal(set) var lastSitesRefresh: Date?

    /// Interval after which cached data is considered stale.
    public var staleInterval: TimeInterval = 60 * 60

    // MARK: - Initialization

    public init(
        storage: some ModelStorage,
        viewContext: some ViewContext,
        siteService: (any SiteService)? = nil,
        userLocation: LocationCoordinate? = nil
    ) {
        self.storage = storage
        self.viewContext = viewContext
        self.siteService = siteService
        self.userLocation = userLocation
    }

    // MARK: - Methods

    /// Signals that a mutation occurred, for observers watching `changeCount`.
    internal func objectDidChange() {
        if changeCount == .max {
            changeCount = 0
        } else {
            changeCount += 1
        }
    }
}

public extension Store {

    /// Insert entity data and signal the change.
    func insert(_ data: [ModelData]) async throws {
        try await storage.insert(data)
        objectDidChange()
    }

    /// Insert a single entity and signal the change.
    func insert(_ value: some Entity) async throws {
        try await storage.insert(value)
        objectDidChange()
    }

    /// Delete entities and signal the change.
    func delete(_ entity: EntityName, for ids: [ObjectID]) async throws {
        try await storage.delete(entity, for: ids)
        objectDidChange()
    }

    /// Mark a site as viewed.
    func didView(_ id: Site.ID) async throws {
        try await storage.didView(id)
        objectDidChange()
    }

    /// Whether the cached site list should be refreshed from the network.
    var shouldDownloadSites: Bool {
        guard siteService != nil else {
            return false
        }
        if let lastDate = lastSitesRefresh,
            Date().timeIntervalSince(lastDate) < staleInterval
        {
            return false
        }
        return true
    }
}
