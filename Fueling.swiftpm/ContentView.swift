//
//  ContentView.swift
//  Fueling
//

import SwiftUI
import CoreFueling
import FuelingModel
import FuelingUI

struct ContentView: View {

    @State
    private var navigationPath = [Site.ID]()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            SitesView(
                selection: { site in
                    navigationPath.append(site)
                }
            )
            .navigationTitle(Text("Sites"))
            .navigationDestination(for: Site.ID.self) {
                SiteDetailView(site: $0)
            }
        }
    }
}
