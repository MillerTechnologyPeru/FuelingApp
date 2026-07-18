//
//  SiteDetailViewModel.swift
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

/// View model for a single site's detail screen, including fuel prices.
@MainActor
@Observable
public final class SiteDetailViewModel: Identifiable {

    // MARK: - Initialization

    public init(
        id: Site.ID,
        store: Store
    ) {
        self.id = id
        self.store = store
        self.reload()
    }

    deinit {
        task?.cancel()
    }

    // MARK: - Properties

    public let id: Site.ID

    internal let store: Store

    @ObservationIgnored
    private var task: Task<Void, Never>?

    public private(set) var state: State = .loading(nil)

    public var error: String? {
        if case .error(_, let error) = state {
            return error.message
        }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    public var site: SiteData? {
        switch state {
        case .loading(let site): return site
        case .loaded(let site): return site
        case .error(let site, _): return site
        }
    }

    public var usesMetric = Locale.current.measurementSystem == .metric

    /// Formatted distance from the user location.
    public var distance: String? {
        guard let userLocation = store.userLocation,
            let coordinates = site?.coordinates
        else {
            return nil
        }
        let meters = userLocation.distance(to: coordinates)
        return SitesViewModel.distance(for: meters, usesMetric: usesMetric)
    }

    // MARK: - Methods

    public func onAppear() {
        let store = self.store
        let id = self.id
        Task {
            try? await store.didView(id)
        }
        reload()
    }

    public func onDisappear() {
        task?.cancel()
        task = nil
    }

    /// Reload the site from cache and refresh it (with fuel prices) from the network.
    public func reload() {
        guard task == nil else {
            return
        }
        loadData(isLoading: true)
        let store = self.store
        let id = self.id
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.task = nil
            }
            guard store.siteService != nil else {
                // offline: present cached data only
                self.loadData()
                return
            }
            // fetch site
            do {
                _ = try await store.site(for: id)
                self.loadData(isLoading: true)
            } catch is CancellationError {
                return
            } catch {
                self.setError(error)
                return
            }
            // fetch fuel prices optionally
            do {
                _ = try await store.fuelPrices(for: [id])
            } catch is CancellationError {
                return
            } catch {
                // keep showing the site without prices
            }
            self.loadData()
        }
    }

    private func setError(_ error: any Swift.Error) {
        state = .error(site, .init(error))
    }

    private func loadData(isLoading: Bool = false) {
        do {
            guard let site = try store.viewContext.fetch(Site.self, for: id) else {
                // not cached yet
                state = isLoading ? .loading(nil) : .error(nil, .invalidResponse)
                return
            }
            // load fuel products
            let fuelProducts = try site.fuelProducts
                .compactMap { id in
                    try store.viewContext.fetch(CoreFueling.FuelProduct.self, for: id)
                }
                .sorted { $0.descriptionText < $1.descriptionText }
                .map { FuelProduct($0) }
            // load fuel options
            let fuelOptions = try site.fuelOptions
                .compactMap { id in
                    try store.viewContext.fetch(FuelOption.self, for: id)
                }
                .map { $0.name }
                .sorted()
            // build address and directions
            var address = site.postalAddress
            if let directions = site.directions, directions.isEmpty == false {
                address += "\n" + directions
            }
            let directions = [
                ("Apple Maps", "http://maps.apple.com/?ll=\(site.latitude),\(site.longitude)"),
                ("Google Maps", "https://www.google.com/maps/place/\(site.latitude),\(site.longitude)")
            ].compactMap { (title, string) in
                URL(string: string).flatMap { Directions(title: title, url: $0) }
            }
            // additional details
            var details = [Detail]()
            if site.phone.isEmpty == false {
                details.append(Detail(title: "Phone", value: site.phone))
            }
            details += [
                Detail(title: "Latitude", value: site.latitude.description),
                Detail(title: "Longitude", value: site.longitude.description),
                Detail(title: "Site ID", value: Site.ID.Prefixed(id: site.id).rawValue)
            ]
            let data = SiteData(
                entity: site,
                address: address,
                directions: directions,
                details: details,
                fuelProducts: fuelProducts,
                fuelOptions: fuelOptions
            )
            state = isLoading ? .loading(data) : .loaded(data)
        } catch {
            setError(error)
        }
    }
}

// MARK: - Supporting Types

public extension SiteDetailViewModel {

    enum State: Equatable, Hashable, Sendable {

        case loading(SiteData?)
        case loaded(SiteData)
        case error(SiteData?, FuelingError)
    }

    struct SiteData: Equatable, Hashable, Sendable, Identifiable {

        public let entity: Site

        public let address: String

        public let directions: [Directions]

        public let details: [Detail]

        public let fuelProducts: [FuelProduct]

        public let fuelOptions: [String]

        public var id: Site.ID {
            entity.id
        }

        public var name: String {
            entity.name
        }

        public var coordinates: LocationCoordinate {
            entity.coordinates
        }

        public var fuelLanes: Int {
            entity.fuelLanes
        }

        public var truckParkingSpaces: Int {
            entity.truckParkingSpaces
        }

        public var showers: Int {
            entity.showers
        }
    }

    struct Directions: Equatable, Hashable, Sendable, Identifiable {

        public let title: String

        public let url: URL

        public var id: String {
            title
        }

        public init(title: String, url: URL) {
            self.title = title
            self.url = url
        }
    }

    struct Detail: Equatable, Hashable, Sendable, Identifiable {

        public let title: String

        public let value: String

        public var id: String {
            title
        }

        public init(title: String, value: String) {
            self.title = title
            self.value = value
        }
    }

    struct FuelProduct: Equatable, Hashable, Sendable, Identifiable {

        public let id: CoreFueling.FuelProduct.ID

        public let name: String

        public let price: String

        public let updated: Date

        internal init(_ entity: CoreFueling.FuelProduct) {
            self.id = entity.id
            self.name = entity.descriptionText
            self.price = Self.priceFormatter.string(from: entity.price as NSNumber)
                ?? "$" + entity.price.description
            self.updated = entity.updated
        }

        internal static let priceFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.minimumFractionDigits = 3
            formatter.maximumFractionDigits = 3
            return formatter
        }()
    }
}
