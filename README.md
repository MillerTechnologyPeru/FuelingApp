# FuelingApp

Modular Swift package for browsing fueling sites — a searchable list and map
of locations, and a site detail screen with current fuel prices.

Built on [CoreModel](https://github.com/PureSwift/CoreModel) for persistence
and delivered as a Swift Playground app (no Xcode project).

## Modules

| Module | Description |
|---|---|
| `CoreFueling` | Domain entities (`Site`, `FuelProduct`, `FuelOption`) declared with the CoreModel `@Entity` macro, plus search queries and geo primitives. |
| `FuelingAPI` | REST API implemented as extensions of an `HTTPClient` protocol ([swift-http-types](https://github.com/apple/swift-http-types)) with an **injectable base URL** (`ServerURL`) — no hardcoded hostnames, `URLSession` is just one conformer. |
| `FuelingModel` | `Store` (persistence + network composition root) and `@Observable` view models for the site list and site detail. |
| `FuelingUI` | SwiftUI views: `SitesView` (list/map toggle), `SiteListView`, `SiteMapView`, `SiteDetailView`. |

See [PLAN.md](PLAN.md) for the architecture.

## Running the app

Open `Fueling.swiftpm` in Xcode or Swift Playgrounds and run. The demo uses
bundled sample data (`MockHTTPClient`) with an in-memory store, so it
works offline.

To run against a real server, inject the base URL:

```swift
let service = APISiteService(server: ServerURL(rawValue: "https://api.example.com")!)
let store = try Store(siteService: service)
```

## Usage

```swift
import SwiftUI
import FuelingModel
import FuelingUI

// list / map of sites
SitesView { siteID in
    // handle selection
}
.environment(store)

// site detail with fuel prices
SiteDetailView(site: siteID)
    .environment(store)
```

## Tests

```sh
swift test
```
