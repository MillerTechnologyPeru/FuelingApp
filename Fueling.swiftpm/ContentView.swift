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
    private var navigationPath = [Location.ID]()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            LocationsView(
                selection: { location in
                    navigationPath.append(location)
                }
            )
            .navigationTitle(Text("Locations"))
            .navigationDestination(for: Location.ID.self) {
                LocationDetailView(location: $0)
            }
        }
    }
}
