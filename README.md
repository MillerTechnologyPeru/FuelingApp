# FuelingApp

Modular Swift package for browsing fueling locations — a searchable list and
map of locations, and a location detail screen with current fuel prices.

Built on [CoreModel](https://github.com/PureSwift/CoreModel) for persistence
and delivered as a Swift Playground app (no Xcode project).

## Modules

| Module | Description |
|---|---|
| `CoreFueling` | Domain entities (`Location`, `FuelProduct`, `FuelOption`) declared with the CoreModel `@Entity` macro, plus search queries and geo primitives. |
| `FuelingAPI` | REST API implemented as extensions of an `HTTPClient` protocol ([swift-http-types](https://github.com/apple/swift-http-types)) with an **injectable base URL** (`ServerURL`) — no hardcoded hostnames, `URLSession` is just one conformer. |
| `FuelingModel` | `Store` (persistence + network composition root) and `@Observable` view models for the location list and location detail. |
| `FuelingUI` | SwiftUI views: `LocationsView` (list/map toggle), `LocationListView`, `LocationMapView`, `LocationDetailView`. |

`Store` supports two storage backends: CoreData (`Store(named:)`, Darwin only)
and SQLite (`Store(sqliteDatabase:)`, cross-platform — used on Android/Linux).

## Running the app

Open `Fueling.swiftpm` in Xcode or Swift Playgrounds and run. The demo uses
bundled sample data (`MockHTTPClient`) with an in-memory store, so it
works offline.

To run against a real server, inject the base URL:

```swift
let service = APILocationService(server: ServerURL(rawValue: "https://api.example.com")!)
let store = try Store(locationService: service)
```

## Usage

```swift
import SwiftUI
import FuelingModel
import FuelingUI

// list / map of locations
LocationsView { locationID in
    // handle selection
}
.environment(store)

// location detail with fuel prices
LocationDetailView(location: locationID)
    .environment(store)
```

## Android

`Android/` is a separate Swift package (`FuelingAndroid`) and Gradle project
that exports `FuelingModel`/`CoreFueling` to Kotlin over JNI using
[swift-java](https://github.com/swiftlang/swift-java) (jextract). See
`Android/README.md` for the build/toolchain requirements.

The Android build excludes `FuelingAPI` (and its `HTTPTypesFoundation`/
`FoundationNetworking` dependency) from the dependency graph entirely — no
network transport is wired up there yet, so the app persists to a local
SQLite cache seeded with sample data and works fully offline.

## Tests

```sh
swift test
```
