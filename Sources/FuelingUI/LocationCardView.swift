//
//  LocationCardView.swift
//  FuelingUI
//

#if canImport(SwiftUI)
import Foundation
import SwiftUI

/// Card view for a location row in the list.
public struct LocationCardView: View {

    let name: String

    let distance: String?

    let address: String

    public init(
        name: String,
        distance: String? = nil,
        address: String
    ) {
        self.name = name
        self.distance = distance
        self.address = address
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: name)
                    .font(.headline)
                    .foregroundStyle(.tint)
                Spacer()
                if let distance {
                    Text(verbatim: distance)
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
            }
            Divider()
            Text(verbatim: address)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ScrollView {
        VStack {
            LocationCardView(
                name: "Seville Travel Center",
                distance: "Here",
                address: "8834 Lake Road\nSeville, Ohio 44273"
            )
            LocationCardView(
                name: "Columbus East Fuel Stop",
                distance: "94 mi",
                address: "6161 Interstate Parkway\nColumbus, Ohio 43217"
            )
            LocationCardView(
                name: "Steel City Truck Plaza",
                address: "1150 Smithfield Street\nPittsburgh, Pennsylvania 15222"
            )
        }
        .padding()
    }
}
#endif

#endif
