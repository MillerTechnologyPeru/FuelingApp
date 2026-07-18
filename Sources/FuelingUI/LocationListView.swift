//
//  LocationListView.swift
//  FuelingUI
//

#if canImport(SwiftUI)
import Foundation
import SwiftUI
import CoreFueling
import FuelingModel

/// Scrolling list of fueling locations.
public struct LocationListView: View {

    @Environment(Store.self)
    private var store: Store

    internal var selection: (Location.ID) -> ()

    public init(
        selection: @escaping (Location.ID) -> ()
    ) {
        self.selection = selection
    }

    public var body: some View {
        LazyViewModel(viewModel: LocationsViewModel(store: store)) {
            ViewModelView(viewModel: $0, selection: selection)
        }
    }
}

internal extension LocationListView {

    struct ViewModelView: View {

        @Bindable
        var viewModel: LocationsViewModel

        let selection: (Location.ID) -> ()

        var body: some View {
            StateView(
                state: viewModel.state,
                locations: viewModel.locations,
                distance: viewModel.distance(to:),
                selection: selection,
                reload: viewModel.reload
            )
            .searchable(text: $viewModel.searchText)
            .onAppear(perform: viewModel.onAppear)
            .onDisappear(perform: viewModel.onDisappear)
        }
    }
}

internal extension LocationListView {

    struct StateView: View {

        let state: LocationsViewModel.State

        let locations: [Location]

        let distance: (Location) -> String?

        let selection: (Location.ID) -> ()

        let reload: () -> ()

        var body: some View {
            switch state {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(let error):
                VStack(spacing: 16) {
                    Text("Error: \(error.message)")
                    Button("Retry", action: reload)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                ContentView(
                    locations: locations,
                    distance: distance,
                    selection: selection,
                    reload: reload
                )
            }
        }
    }
}

internal extension LocationListView {

    struct ContentView: View {

        let locations: [Location]

        let distance: (Location) -> String?

        let selection: (Location.ID) -> ()

        let reload: () -> ()

        var body: some View {
            if locations.isEmpty {
                Text("No locations found")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack {
                        ForEach(locations) { location in
                            Button(
                                action: { selection(location.id) },
                                label: {
                                    LocationCardView(
                                        name: location.name,
                                        distance: distance(location),
                                        address: location.postalAddress
                                    )
                                }
                            )
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .refreshable { reload() }
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
        LocationListView(selection: { _ in })
            .navigationTitle(Text("Locations"))
    }
    .environment(store)
}
#endif

#endif
