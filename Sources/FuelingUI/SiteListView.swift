//
//  SiteListView.swift
//  FuelingUI
//

#if canImport(SwiftUI)
import Foundation
import SwiftUI
import CoreFueling
import FuelingModel

/// Scrolling list of fueling sites.
public struct SiteListView: View {

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

internal extension SiteListView {

    struct ViewModelView: View {

        @Bindable
        var viewModel: SitesViewModel

        let selection: (Site.ID) -> ()

        var body: some View {
            StateView(
                state: viewModel.state,
                sites: viewModel.sites,
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

internal extension SiteListView {

    struct StateView: View {

        let state: SitesViewModel.State

        let sites: [Site]

        let distance: (Site) -> String?

        let selection: (Site.ID) -> ()

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
                    sites: sites,
                    distance: distance,
                    selection: selection,
                    reload: reload
                )
            }
        }
    }
}

internal extension SiteListView {

    struct ContentView: View {

        let sites: [Site]

        let distance: (Site) -> String?

        let selection: (Site.ID) -> ()

        let reload: () -> ()

        var body: some View {
            if sites.isEmpty {
                Text("No sites found")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack {
                        ForEach(sites) { site in
                            Button(
                                action: { selection(site.id) },
                                label: {
                                    SiteCardView(
                                        name: site.name,
                                        distance: distance(site),
                                        address: site.postalAddress
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
        siteService: .mock,
        isStoredInMemoryOnly: true
    )
    return NavigationStack {
        SiteListView(selection: { _ in })
            .navigationTitle(Text("Sites"))
    }
    .environment(store)
}
#endif

#endif
