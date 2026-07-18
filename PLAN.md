# Fueling — Implementation Plan

A modular Swift package for browsing fueling sites (list and map) and viewing
site details with current fuel prices. Persistence and querying are built on
[CoreModel](https://github.com/PureSwift/CoreModel). The app is delivered as a
Swift Playground (`Fueling.swiftpm`) — no Xcode project is generated.

## Goals

- **List / Map of sites** — searchable list and an interactive map of fueling
  locations, sorted by distance when a user location is available.
- **Site detail with fuel prices** — address, directions links, lane counts,
  and current fuel prices per product.
- **Injectable server URL** — no hardcoded production hostnames. The REST
  client accepts any base URL; a mock service allows running fully offline.
- **CoreModel persistence** — domain entities are declared with the `@Entity`
  macro and persisted via `ModelStorage` (CoreData-backed on Apple platforms),
  so the UI works from the local cache and refreshes from the network.

## Architecture

Four library targets, layered bottom-up:

```
CoreFueling  →  FuelingAPI  →  FuelingModel  →  FuelingUI
(entities)      (REST DTOs      (Store +          (SwiftUI
 CoreModel       + client)       ViewModels)       views)
```

### CoreFueling — domain model

CoreModel `@Entity` value types and shared primitives:

- `Site` — a fueling location (name, address, coordinates, lane counts,
  relationships to fuel products/options) plus `Site.Query` predicates for
  text search.
- `Site.ID` / `Site.ID.Prefixed` — numeric identifier and its zero-padded
  4-digit wire format.
- `FuelProduct` — a priced fuel product at a site (price, description,
  updated date).
- `FuelOption` — a fueling option offered by sites (diesel, DEF, etc.).
- `LocationCoordinate` — latitude/longitude with haversine distance.
- `CachedEntity` — protocol for entities that track `lastCached`.
- `FuelingError` — app-level error type shared by services and view models.
- `Model.fueling` — the CoreModel schema built from the entities.

### FuelingAPI — REST client

Hand-written `URLSession` client. **The base URL is injected** via
`ServerURL`; nothing is hardcoded.

- `ServerURL` — validated wrapper around the injectable base URL.
- `APIResponse<T>` — generic `{status, message, data}` envelope.
- `Location` DTO — snake_case wire representation of a site.
- `FuelPrice` DTO — price, product description, fuel code, load date.
- `FuelingAPIClient` protocol + `URLSessionFuelingAPIClient` —
  `locations(sites:)` and `fuelPrices(for:)` (GET `/v1/locations`,
  GET `/v1/fuelprice`, `Device-ID` header, repeated `siteIds` query items).
- `ModelData` mapping — converts DTOs into the CoreModel entity graph
  (site + fuel options + fuel products).

### FuelingModel — store and view models

- `SiteService` — transport protocol returning entity IDs plus the
  `ModelData` graph to persist (keeps the store transport-agnostic).
- `APISiteService` — adapts any `FuelingAPIClient` to `SiteService`.
- `MockSiteService` — in-process sample data for previews/playgrounds.
- `Store` — `@MainActor @Observable` composition root: owns `ModelStorage`,
  a synchronous `ViewContext` for the UI, the `SiteService`, an optional
  user location, and a `changeCount` revision for fetch invalidation.
- `Store+SiteService` — fetch-and-persist operations (`locations()`,
  `site(for:)`, `fuelPrices(for:)`, stale-site cleanup, `didView`).
- `Store+CoreData` — convenience initializer using CoreModel's
  `PersistentContainerStorage` (on-disk or in-memory).
- `SitesViewModel` — loading/loaded/error state, debounced text search,
  distance sorting; backs both the list and the map.
- `SiteDetailViewModel` — loads one site plus its fuel prices, formats
  currency and directions links.

### FuelingUI — SwiftUI views

- `SitesView` — segmented List/Map container with search field.
- `SiteListView` + `SiteCardView` — scrolling cards (name, distance,
  address), pull to refresh.
- `SiteMapView` — `Map` with site annotations and camera that follows the
  user location.
- `SiteDetailView` — header, address, directions links, fuel lanes, and the
  current fuel prices table.
- `LazyViewModel` — creates a view model once per view identity.

### Fueling.swiftpm — app playground

Swift Playground app (`iOSApplication` product) depending on the package via
a relative path. Uses the in-memory store with `MockSiteService` so it runs
without network access; a real deployment injects `ServerURL` +
`URLSessionFuelingAPIClient` instead.

### Tests

`FuelingTests` — entity round-trip through `ModelData`, DTO decoding from
sample JSON, query predicate construction, and mock-service store flows.

## Conventions

- One commit per file.
- Platforms: iOS 17+, macOS 14+ (SwiftUI MapKit APIs).
- Dependency: `CoreModel` ≥ 2.8.0 (`CoreModel` + `CoreDataModel` products).
- No generated Xcode project; build with SwiftPM / Swift Playgrounds.
