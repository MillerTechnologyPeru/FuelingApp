//
//  main.swift
//  FuelingWeb
//

import ElementaryUI
import JavaScriptKit
import JavaScriptEventLoop
import FuelingAPI
import FuelingModel

// Install the JS-promise-aware global executor so `await`s (network fetches,
// Store tasks) resume on the browser's single thread.
JavaScriptEventLoop.installGlobalExecutor()

// `main`'s top-level code is nonisolated, but on wasm it runs on the single
// browser thread — so it is safe to assume the main actor to build the
// `@MainActor` store and mount the app.
MainActor.assumeIsolated {
    // Talk to the page's own origin so requests stay same-origin (the Vite dev
    // server proxies `/v1` to the local test server); fall back to localhost.
    let origin = JSObject.global.location.object?.origin.string
    let server = origin.flatMap { ServerURL(rawValue: $0) } ?? .localhost(port: 8080)

    // Composition root: an in-memory store (no SQLite/CoreData on wasm) fed by
    // the browser `fetch` transport. Same `Store` the Apple and Android apps use.
    let store = Store(
        inMemory: .fueling,
        locationService: APILocationService(
            client: FetchHTTPClient(),
            server: server
        )
    )

    Application(RootView(model: FuelingStore(store: store))).mount(in: "#app")
}
