//
//  RootView.swift
//  FuelingWeb
//

import ElementaryUI

/// Owns the reactive coordinator for the app's lifetime (via `@State`) and
/// publishes it into the environment so every child view observes its changes.
@View
struct RootView {

    @State var model: FuelingStore

    var body: some View {
        ContentView()
            .environment(model)
    }
}

/// Switches between the locations list and a location's detail screen.
@View
struct ContentView {

    @Environment(FuelingStore.self) var model

    var body: some View {
        div {
            h1 { "Fueling" }
                .attributes(.style(["margin": "8px 0 16px", "font-size": "1.6rem"]))

            if model.detailID != nil {
                LocationDetailView()
            } else {
                LocationsListView()
            }
        }
    }
}
