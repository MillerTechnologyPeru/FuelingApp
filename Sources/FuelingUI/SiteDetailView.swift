//
//  SiteDetailView.swift
//  FuelingUI
//

#if canImport(SwiftUI)
import Foundation
import SwiftUI
import CoreFueling
import FuelingModel

/// Detail screen for a single site, including current fuel prices.
public struct SiteDetailView: View {

    @Environment(Store.self)
    private var store: Store

    internal let site: Site.ID

    public init(site: Site.ID) {
        self.site = site
    }

    public var body: some View {
        LazyViewModel(viewModel: SiteDetailViewModel(id: site, store: store)) {
            ViewModelView(viewModel: $0)
        }
    }
}

internal extension SiteDetailView {

    struct ViewModelView: View {

        var viewModel: SiteDetailViewModel

        var body: some View {
            StateView(
                state: viewModel.state,
                distance: viewModel.distance,
                reload: viewModel.reload
            )
            .onAppear(perform: viewModel.onAppear)
            .onDisappear(perform: viewModel.onDisappear)
        }
    }
}

internal extension SiteDetailView {

    struct StateView: View {

        let state: SiteDetailViewModel.State

        let distance: String?

        let reload: () -> ()

        var body: some View {
            switch state {
            case .loading(nil):
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(nil, let error):
                VStack(spacing: 16) {
                    Text("Error: \(error.message)")
                    Button("Retry", action: reload)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loading(.some(let site)),
                .loaded(let site),
                .error(.some(let site), _):
                ContentView(
                    site: site,
                    distance: distance,
                    isLoading: state.isLoading,
                    reload: reload
                )
            }
        }
    }
}

internal extension SiteDetailViewModel.State {

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

internal extension SiteDetailView {

    struct ContentView: View {

        let site: SiteDetailViewModel.SiteData

        let distance: String?

        let isLoading: Bool

        let reload: () -> ()

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(verbatim: site.name)
                                .font(.title2.weight(.semibold))
                            Spacer()
                            if let distance {
                                Text(verbatim: distance)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(verbatim: site.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            ForEach(site.directions) { directions in
                                Link(directions.title, destination: directions.url)
                                    .font(.subheadline)
                            }
                        }
                    }

                    // Current fuel prices
                    if site.fuelProducts.isEmpty == false {
                        FuelPricesView(
                            fuelProducts: site.fuelProducts,
                            fuelLanes: site.fuelLanes
                        )
                    } else if isLoading {
                        ProgressView("Loading fuel prices…")
                            .frame(maxWidth: .infinity)
                    }

                    // Fuel options
                    if site.fuelOptions.isEmpty == false {
                        SectionView(title: "Fueling Options") {
                            ForEach(site.fuelOptions, id: \.self) { option in
                                Label(option, systemImage: "fuelpump")
                                    .font(.subheadline)
                            }
                        }
                    }

                    // Amenity counts
                    SectionView(title: "Amenities") {
                        DetailRow(title: "Fuel Lanes", value: site.fuelLanes.description)
                        DetailRow(title: "Truck Parking Spaces", value: site.truckParkingSpaces.description)
                        DetailRow(title: "Showers", value: site.showers.description)
                    }

                    // Additional details
                    SectionView(title: "Site Details") {
                        ForEach(site.details) { detail in
                            DetailRow(title: detail.title, value: detail.value)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(Text(verbatim: site.name))
            .refreshable { reload() }
        }
    }
}

internal extension SiteDetailView {

    struct SectionView<Content: View>: View {

        let title: String

        @ViewBuilder
        let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: title)
                    .font(.headline)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            )
        }
    }

    struct DetailRow: View {

        let title: String

        let value: String

        var body: some View {
            HStack {
                Text(verbatim: title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(verbatim: value)
                    .font(.subheadline)
            }
        }
    }

    struct FuelPricesView: View {

        let fuelProducts: [SiteDetailViewModel.FuelProduct]

        let fuelLanes: Int

        var body: some View {
            SectionView(title: "Current Fuel Prices") {
                ForEach(fuelProducts) { product in
                    HStack {
                        Text(verbatim: product.name)
                            .font(.subheadline)
                        Spacer()
                        Text(verbatim: product.price)
                            .font(.subheadline.weight(.semibold))
                    }
                    if product.id != fuelProducts.last?.id {
                        Divider()
                    }
                }
                HStack {
                    Label("Fuel Lanes", systemImage: "fuelpump")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(verbatim: fuelLanes.description)
                        .font(.subheadline)
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let store = try! Store(
        siteService: .mock,
        isStoredInMemoryOnly: true
    )
    return NavigationStack {
        SiteDetailView(site: 15)
    }
    .environment(store)
}
#endif

#endif
