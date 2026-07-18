//
//  LocationDetailView.swift
//  FuelingUI
//

#if canImport(SwiftUI)
import Foundation
import SwiftUI
import CoreFueling
import FuelingModel

/// Detail screen for a single location, including current fuel prices.
public struct LocationDetailView: View {

    @Environment(Store.self)
    private var store: Store

    internal let location: Location.ID

    public init(location: Location.ID) {
        self.location = location
    }

    public var body: some View {
        LazyViewModel(viewModel: LocationDetailViewModel(id: location, store: store)) {
            ViewModelView(viewModel: $0)
        }
    }
}

internal extension LocationDetailView {

    struct ViewModelView: View {

        var viewModel: LocationDetailViewModel

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

internal extension LocationDetailView {

    struct StateView: View {

        let state: LocationDetailViewModel.State

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
            case .loading(.some(let location)),
                .loaded(let location),
                .error(.some(let location), _):
                ContentView(
                    location: location,
                    distance: distance,
                    isLoading: state.isLoading,
                    reload: reload
                )
            }
        }
    }
}

internal extension LocationDetailViewModel.State {

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

internal extension LocationDetailView {

    struct ContentView: View {

        let location: LocationDetailViewModel.LocationData

        let distance: String?

        let isLoading: Bool

        let reload: () -> ()

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(verbatim: location.name)
                                .font(.title2.weight(.semibold))
                            Spacer()
                            if let distance {
                                Text(verbatim: distance)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(verbatim: location.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            ForEach(location.directions) { directions in
                                Link(directions.title, destination: directions.url)
                                    .font(.subheadline)
                            }
                        }
                    }

                    // Current fuel prices
                    if location.fuelProducts.isEmpty == false {
                        FuelPricesView(
                            fuelProducts: location.fuelProducts,
                            fuelLanes: location.fuelLanes
                        )
                    } else if isLoading {
                        ProgressView("Loading fuel prices…")
                            .frame(maxWidth: .infinity)
                    }

                    // Fuel options
                    if location.fuelOptions.isEmpty == false {
                        SectionView(title: "Fueling Options") {
                            ForEach(location.fuelOptions, id: \.self) { option in
                                Label(option, systemImage: "fuelpump")
                                    .font(.subheadline)
                            }
                        }
                    }

                    // Amenity counts
                    SectionView(title: "Amenities") {
                        DetailRow(title: "Fuel Lanes", value: location.fuelLanes.description)
                        DetailRow(title: "Truck Parking Spaces", value: location.truckParkingSpaces.description)
                        DetailRow(title: "Showers", value: location.showers.description)
                    }

                    // Additional details
                    SectionView(title: "Location Details") {
                        ForEach(location.details) { detail in
                            DetailRow(title: detail.title, value: detail.value)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(Text(verbatim: location.name))
            .refreshable { reload() }
        }
    }
}

internal extension LocationDetailView {

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

        let fuelProducts: [LocationDetailViewModel.FuelProduct]

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
        locationService: .mock,
        isStoredInMemoryOnly: true
    )
    return NavigationStack {
        LocationDetailView(location: 15)
    }
    .environment(store)
}
#endif

#endif
