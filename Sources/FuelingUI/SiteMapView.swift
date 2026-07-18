//
//  SiteMapView.swift
//  FuelingUI
//

#if canImport(SwiftUI) && canImport(MapKit)
import Foundation
import SwiftUI
import CoreLocation
import MapKit
#if canImport(_MapKit_SwiftUI)
import _MapKit_SwiftUI
#endif
import CoreFueling
import FuelingModel

/// Map of fueling sites.
public struct SiteMapView: View {

    @Environment(Store.self)
    private var store: Store

    internal var selection: (Site.ID) -> ()

    public init(
        selection: @escaping (Site.ID) -> ()
    ) {
        self.selection = selection
    }

    public var body: some View {
        LazyViewModel(viewModel: SitesViewModel(store: store)) {
            ViewModelView(viewModel: $0, selection: selection)
        }
    }
}

internal extension SiteMapView {

    struct ViewModelView: View {

        var viewModel: SitesViewModel

        let selection: (Site.ID) -> ()

        var body: some View {
            MapView(
                sites: viewModel.sites,
                userLocation: viewModel.userLocation,
                distance: viewModel.distance(to:),
                selection: selection
            )
            .onAppear(perform: viewModel.onAppear)
            .onDisappear(perform: viewModel.onDisappear)
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
        }
    }
}

internal extension SiteMapView {

    struct MapView: View {

        let sites: [Site]

        let userLocation: LocationCoordinate?

        let distance: (Site) -> String?

        let selection: (Site.ID) -> ()

        @State
        private var position: MapCameraPosition = .automatic

        @State
        private var lastLocation: LocationCoordinate?

        var body: some View {
            Map(position: $position) {
                ForEach(sites) { site in
                    Annotation(
                        site.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: site.latitude,
                            longitude: site.longitude
                        )
                    ) {
                        AnnotationView(
                            distance: distance(site),
                            action: { selection(site.id) }
                        )
                    }
                }
            }
            .mapStyle(.standard)
            #if os(iOS) || os(macOS)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            #endif
            .onChange(of: userLocation) {
                userLocationChanged(userLocation)
            }
            .onAppear {
                userLocationChanged(userLocation)
            }
        }

        private func userLocationChanged(_ newValue: LocationCoordinate?) {
            let oldValue = lastLocation
            lastLocation = newValue
            guard let location = newValue, oldValue != newValue else {
                return
            }
            position = .camera(
                MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    ),
                    distance: 250 * 1609.344  // 250 miles in meters
                )
            )
        }
    }
}

internal extension SiteMapView {

    struct AnnotationView: View {

        let distance: String?

        let action: () -> ()

        var body: some View {
            Button(action: action) {
                VStack(spacing: 2) {
                    Image(systemName: "fuelpump.circle.fill")
                        .font(.title)
                        .symbolRenderingMode(.multicolor)
                    if let distance {
                        Text(verbatim: distance)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.background.opacity(0.8), in: Capsule())
                    }
                }
            }
            .buttonStyle(.plain)
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
    store.userLocation = LocationCoordinate(latitude: 41.0322, longitude: -81.9078)
    return NavigationStack {
        SiteMapView(selection: { _ in })
            .navigationTitle(Text("Sites"))
    }
    .environment(store)
}
#endif

#endif
