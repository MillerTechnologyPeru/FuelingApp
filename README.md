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

Open `Fueling.swiftpm` in Xcode or Swift Playgrounds and run. It fetches from
a real server whose base URL is injected via the `FUELING_SERVER_URL`
environment variable (set it in the Xcode scheme's Arguments tab, or `export`
it before `swift run`) — nothing is hardcoded, and it defaults to
`http://localhost:8080` when unset:

```swift
let service = APILocationService(server: .fromEnvironment())
let store = try Store(locationService: service)
```

For an offline demo instead, use the bundled sample data with an in-memory
store:

```swift
let store = try Store(locationService: .mock, isStoredInMemoryOnly: true)
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

Like the playground app, it fetches from a real server via `URLSession`
(`FoundationNetworking`), with the base URL injected from the
`FUELING_SERVER_URL` environment variable at Gradle build time (baked into
`BuildConfig`, since an installed app has no shell environment of its own to
read at runtime) — defaulting to `http://localhost:8080`. Persistence is a
local SQLite cache, same as the rest of the package.

## Tests

```sh
swift test
```
