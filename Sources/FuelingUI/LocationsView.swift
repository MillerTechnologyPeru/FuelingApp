//
//  LocationsView.swift
//  FuelingUI
//

#if canImport(SwiftUI) && canImport(MapKit)
import Foundation
import SwiftUI
import CoreFueling
import FuelingModel

/// Container switching between the location list and map.
public struct LocationsView: View {

    internal var selection: (Location.ID) -> ()

    @State
    private var display: Display = .list

    public init(
        selection: @escaping (Location.ID) -> ()
    ) {
        self.selection = selection
    }

    public var body: some View {
        Group {
            switch display {
            case .list:
                LocationListView(selection: selection)
            case .map:
                LocationMapView(selection: selection)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Display", selection: $display) {
                    ForEach(Display.allCases) { display in
                        Label(display.title, systemImage: display.systemImage)
                            .tag(display)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

// MARK: - Supporting Types

internal extension LocationsView {

    enum Display: String, CaseIterable, Identifiable {

        case list
        case map

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .list:
                return "List"
            case .map:
                return "Map"
            }
        }

        var systemImage: String {
            switch self {
            case .list:
                return "list.bullet"
            case .map:
                return "map"
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
    store.userLocation = LocationCoordinate(latitude: 41.0322, longitude: -81.9078)
    return NavigationStack {
        LocationsView(selection: { _ in })
            .navigationTitle(Text("Locations"))
            .navigationDestination(for: Location.ID.self) {
                LocationDetailView(location: $0)
            }
    }
    .environment(store)
}
#endif

#endif
