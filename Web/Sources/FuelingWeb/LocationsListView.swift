//
//  LocationsListView.swift
//  FuelingWeb
//

import ElementaryUI
import CoreFueling

/// Searchable list of fueling locations. Mirrors `FuelingUI.LocationListView`.
@View
struct LocationsListView {

    @Environment(FuelingStore.self) var model

    var body: some View {
        div {
            input(.type(.text), .placeholder("Search locations"))
                .attributes(
                    .style([
                        "width": "100%",
                        "padding": "10px 12px",
                        "margin-bottom": "12px",
                        "border": "1px solid var(--border)",
                        "border-radius": "10px",
                        "background": "var(--card)",
                        "color": "var(--text)",
                        "font-size": "1rem",
                    ])
                )
                .onInput { event in
                    model.setSearch(event.targetValue ?? "")
                }

            if let error = model.errorMessage {
                p { "Couldn't load locations: \(error)" }
                    .attributes(.style(["color": "#ff6b6b"]))
            }

            if model.isLoading && model.locations.isEmpty {
                p { "Loading…" }.attributes(.style(["color": "var(--muted)"]))
            } else if model.locations.isEmpty {
                p { "No locations found." }.attributes(.style(["color": "var(--muted)"]))
            }

            ForEach(model.locations, key: { $0.id.description }) { location in
                LocationCardView(location: location)
            }
        }
        .onAppear {
            model.onAppear()
        }
    }
}

/// A single tappable location row. Mirrors `FuelingUI.LocationCardView`.
@View
struct LocationCardView {

    @Environment(FuelingStore.self) var model
    let location: Location

    var body: some View {
        div {
            div { location.name }
                .attributes(.style(["font-weight": "600", "font-size": "1.05rem"]))
            div { "\(location.city), \(location.state)" }
                .attributes(.style(["color": "var(--muted)", "font-size": "0.9rem", "margin-top": "2px"]))
        }
        .attributes(
            .style([
                "background": "var(--card)",
                "border": "1px solid var(--border)",
                "border-radius": "12px",
                "padding": "12px 14px",
                "margin-bottom": "8px",
                "cursor": "pointer",
            ])
        )
        .onClick {
            model.open(location.id)
        }
    }
}
