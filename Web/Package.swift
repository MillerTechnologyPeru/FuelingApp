// swift-tools-version: 6.3
import PackageDescription

// FuelingWeb — the browser/WebAssembly front end.
//
// A standalone package (like `Android/`) so the heavy, wasm-only ElementaryUI /
// JavaScriptKit / swift-syntax graph never touches the root package's Darwin,
// Android, or test builds. It depends on the root package via path for the
// reusable model layer (`FuelingModel` + `CoreFueling`) — the same `Store`,
// view models, and domain entities the Apple and Android apps use — and adds a
// JavaScriptKit `fetch` transport plus ElementaryUI views on top.
//
// Build & run through the Vite toolchain (`npm run dev` / `npm run build`),
// which drives `swift build --swift-sdk swift-6.3.3-RELEASE_wasm` under the hood
// via `@elementary-swift/vite-plugin-swift-wasm` (`useEmbeddedSDK: false`, since
// the model layer needs full Foundation).
let package = Package(
    name: "FuelingWeb",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(path: ".."),
        .package(
            url: "https://github.com/elementary-swift/elementary-ui",
            from: "0.5.0"
        ),
        .package(
            url: "https://github.com/swiftwasm/JavaScriptKit",
            .upToNextMinor(from: "0.56.1")
        )
    ],
    targets: [
        .executableTarget(
            name: "FuelingWeb",
            dependencies: [
                .product(name: "FuelingModel", package: "FuelingApp"),
                .product(name: "CoreFueling", package: "FuelingApp"),
                .product(name: "ElementaryUI", package: "elementary-ui"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
