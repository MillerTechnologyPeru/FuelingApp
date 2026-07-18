//
//  SitesViewModel.swift
//  FuelingModel
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Observation
import CoreModel
import CoreFueling

/// View model backing the site list and map.
@MainActor
@Observable
public final class SitesViewModel {

    // MARK: - Initialization

    public init(store: Store) {
        self.store = store
        self.reload()
    }

    deinit {
        task?.cancel()
    }

    // MARK: - Properties

    internal let store: Store

    public private(set) var state: State = .loading

    /// Sites matching the current search, sorted by distance when a user
    /// location is available.
    public private(set) var sites: [Site] = []

    /// Text filter applied to name, city, address, zip code and state.
    public var searchText = "" {
        didSet {
            guard oldValue != searchText else { return }
            filterDidChange()
        }
    }

    public var usesMetric = Locale.current.measurementSystem == .metric

    @ObservationIgnored
    private var task: Task<Void, Never>?

    public var userLocation: LocationCoordinate? {
        store.userLocation
    }

    public var error: String? {
        if case let .error(error) = state {
            return error.message
        }
        return nil
    }

    public var isLoading: Bool {
        state == .loading
    }

    // MARK: - Methods

    public func onAppear() {
        reload()
    }

    public func onDisappear() {
        task?.cancel()
        task = nil
    }

    /// Refresh sites from the network (when stale) and re-apply the filter.
    public func reload() {
        guard task == nil else {
            return
        }
        state = .loading
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.task = nil
            }
            do {
                try await self.downloadSites()
                try await self.fetchSites()
            } catch is CancellationError {
                return
            } catch {
                self.setError(error)
            }
        }
    }

    private func filterDidChange() {
        task?.cancel()
        state = .loading
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.task = nil
            }
            do {
                // debounce while typing
                try await Task.sleep(nanoseconds: 250_000_000)
                try await self.fetchSites()
            } catch is CancellationError {
                return
            } catch {
                self.setError(error)
            }
        }
    }

    /// Fetch sites from storage with the current filter.
    private func fetchSites() async throws {
        var sites = try await store.storage.fetch(Site.self, search: searchText)
        if let userLocation = store.userLocation {
            sites.sort {
                $0.coordinates.distance(to: userLocation) < $1.coordinates.distance(to: userLocation)
            }
        } else {
            sites.sort { $0.name < $1.name }
        }
        self.sites = sites
        self.state = .loaded
    }

    private func downloadSites() async throws {
        guard store.shouldDownloadSites else { return }
        try await store.locations()
    }

    private func setError(_ error: any Swift.Error) {
        sites = []
        state = .error(.init(error))
    }

    /// Formatted distance from the user location to the site.
    public func distance(to site: Site) -> String? {
        guard let userLocation else {
            return nil
        }
        let meters = userLocation.distance(to: site.coordinates)
        return Self.distance(for: meters, usesMetric: usesMetric)
    }

    internal nonisolated static func distance(
        for meters: Double,
        usesMetric: Bool = false
    ) -> String {
        let number: Int
        let unit: String
        if usesMetric {
            number = Int(meters / 1000)
            unit = "km"
        } else {
            number = Int(meters / 1609.344)
            unit = "mi"
        }
        guard number > 0 else {
            return "Here"
        }
        return number.description + " " + unit
    }
}

// MARK: - Supporting Types

public extension SitesViewModel {

    enum State: Equatable, Hashable, Sendable {

        case loading
        case loaded
        case error(FuelingError)
    }
}
