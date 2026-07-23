//
//  LocationDetailView.swift
//  FuelingWeb
//

import ElementaryUI
import CoreFueling

/// A location's detail screen: address plus the current fuel prices table.
/// Mirrors `FuelingUI.LocationDetailView`.
@View
struct LocationDetailView {

    @Environment(FuelingStore.self) var model

    var body: some View {
        div {
            button { "← Back" }
                .attributes(
                    .style([
                        "background": "none",
                        "border": "none",
                        "color": "var(--accent)",
                        "font-size": "1rem",
                        "cursor": "pointer",
                        "padding": "4px 0",
                        "margin-bottom": "8px",
                    ])
                )
                .onClick {
                    model.closeDetail()
                }

            if let location = model.detailLocation {
                h2 { location.name }
                    .attributes(.style(["margin": "4px 0"]))
                p { location.postalAddress }
                    .attributes(.style(["color": "var(--muted)", "white-space": "pre-line"]))

                h3 { "Fuel Prices" }
                    .attributes(.style(["margin": "20px 0 8px"]))

                if model.detailPrices.isEmpty {
                    p {
                        model.detailLoading ? "Loading prices…" : "No prices available."
                    }
                    .attributes(.style(["color": "var(--muted)"]))
                }

                ForEach(model.detailPrices, key: { $0.id.description }) { product in
                    div {
                        span { product.descriptionText }
                        span { model.formattedPrice(product) }
                            .attributes(.style(["font-weight": "600"]))
                    }
                    .attributes(
                        .style([
                            "display": "flex",
                            "justify-content": "space-between",
                            "padding": "10px 0",
                            "border-bottom": "1px solid var(--border)",
                        ])
                    )
                }
            } else {
                p { "Loading…" }.attributes(.style(["color": "var(--muted)"]))
            }
        }
    }
}
