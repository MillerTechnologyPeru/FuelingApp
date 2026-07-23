//
//  FuelingStore.swift
//  FuelingWeb
//

import Reactivity
import FuelingModel
import CoreFueling

/// Bridges the `@Observable` ``Store`` (stdlib Observation) into ElementaryUI's
/// own reactivity system.
///
/// ElementaryUI tracks changes to `@Reactive` properties, not stdlib
/// `@Observable` objects, so this coordinator owns the plain snapshots the
/// views render (`locations`, `detailPrices`, `isLoading`, …) and re-populates
/// them from the `Store` after each operation. Mutating a `@Reactive` property
/// schedules a re-render.
///
/// The type is deliberately **not** `@MainActor` — ElementaryUI renders view
/// bodies and dispatches DOM events from a `nonisolated` context, so the
/// snapshot properties must be reachable there. The `@MainActor` `Store` is
/// only ever touched inside `MainActor.assumeIsolated` (synchronous cache
/// reads) or `Task { @MainActor in … }` (async network), both valid on wasm's
/// single thread.
@Reactive
final class FuelingStore {

    let store: Store

    // MARK: List state

    var locations: [Location] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = ""

    // MARK: Detail state

    var detailID: Location.ID?
    var detailLocation: Location?
    var detailPrices: [FuelProduct] = []
    var detailLoading = false

    init(store: Store) {
        self.store = store
    }

    // MARK: List

    func onAppear() {
        guard locations.isEmpty else { return }
        refresh()
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task { @MainActor in
            do {
                _ = try await store.locations()
            } catch {
                errorMessage = String(describing: error)
            }
            reloadFromCache()
            isLoading = false
        }
    }

    func setSearch(_ text: String) {
        guard text != searchText else { return }
        searchText = text
        // Synchronous, cache-only — no network round trip while typing.
        MainActor.assumeIsolated {
            reloadFromCache()
        }
    }

    @MainActor
    private func reloadFromCache() {
        let results = (try? store.viewContext.fetch(Location.self, search: searchText)) ?? []
        locations = results.sorted { $0.name < $1.name }
    }

    // MARK: Detail

    func open(_ id: Location.ID) {
        detailID = id
        detailLoading = true
        MainActor.assumeIsolated {
            detailLocation = try? store.viewContext.fetch(Location.self, for: id)
            detailPrices = prices(for: id)
        }
        Task { @MainActor in
            // Refresh the location and its fuel prices from the network.
            _ = try? await store.location(for: id)
            _ = try? await store.fuelPrices(for: [id])
            detailLocation = try? store.viewContext.fetch(Location.self, for: id)
            detailPrices = prices(for: id)
            detailLoading = false
        }
    }

    func closeDetail() {
        detailID = nil
        detailLocation = nil
        detailPrices = []
        detailLoading = false
    }

    /// Fuel products for a location, queried by each product's `location` field.
    ///
    /// The DB-backed stores populate `Location.fuelProducts` via inverse-
    /// relationship maintenance, which the in-memory store doesn't do — so this
    /// filters `FuelProduct` by its own to-one `location` instead, which works
    /// on any backend.
    @MainActor
    private func prices(for id: Location.ID) -> [FuelProduct] {
        let all = (try? store.viewContext.fetch(FuelProduct.self)) ?? []
        return all
            .filter { $0.location == id }
            .sorted { $0.descriptionText < $1.descriptionText }
    }

    /// Format a fuel price as US dollars without relying on Foundation's
    /// `NumberFormatter`/`String(format:)` (unreliable on wasm/FoundationEssentials).
    func formattedPrice(_ product: FuelProduct) -> String {
        let cents = Int((product.price * 100).rounded())
        let dollars = cents / 100
        let remainder = abs(cents % 100)
        let padded = remainder < 10 ? "0\(remainder)" : "\(remainder)"
        return "$\(dollars).\(padded)"
    }
}
