# FuelingWeb

The browser / WebAssembly front end for FuelingApp, built with
[ElementaryUI](https://github.com/elementary-swift/elementary-ui) and
[JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit).

This is a **standalone Swift package** (like `../Android/`) that depends on the
root package via a path dependency for the reusable model layer — the same
`FuelingModel` `Store`, view-model logic, and `CoreFueling` entities the Apple
and Android apps use. On top of that it adds:

- **`FetchHTTPClient`** — an `HTTPClient` transport backed by the browser
  `fetch` API (the wasm counterpart to `URLSession` / the Android JNI client).
- **`Store(inMemory:)`** — an in-memory persistence backend (the SQLite backend
  can't compile for wasm), defined in `FuelingModel`.
- **ElementaryUI views** — a searchable locations list and a location detail
  screen with live fuel prices.

## Prerequisites

- Swift 6.3+ with the WebAssembly SDK from swift.org:
  `swift sdk install <swift-6.3.3 wasm SDK URL>` (installs
  `swift-6.3.3-RELEASE_wasm`).
- Node.js 20+ and npm.

## Run

```sh
# 1. Start the local test server (from the repo root)
python3 ../Scripts/test-server.py --port 8080

# 2. Install JS deps and start the dev server (from this directory)
npm install
npm run dev
```

Open http://localhost:5173. The Vite plugin
(`@elementary-swift/vite-plugin-swift-wasm`) cross-compiles `FuelingWeb` to wasm
on demand and hot-reloads on source changes. `/v1/*` requests are proxied to the
test server on port 8080, so the app talks to its own origin (no CORS).

`npm run build` produces a static production bundle in `dist/` (release wasm,
optionally `wasm-opt`-minified).

## Notes

- The build uses the **non-embedded** WASI SDK (`useEmbeddedSDK: false` in
  `vite.config.ts`) because the reused model layer needs full Foundation.
- `BrowserRuntime/` vendors ElementaryUI's browser runtime (it isn't published
  to npm); it's referenced as a `file:` dependency.
- Don't run a CLI `swift build` here while `npm run dev` is running — they race
  on `.build`; let the Vite watcher own the rebuilds.
