// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FuelingAndroid",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "FuelingAndroid",
            type: .dynamic,
            targets: ["FuelingAndroid"]
        )
    ],
    dependencies: [
        .package(path: ".."),
        .package(
            url: "https://github.com/PureSwift/CoreModel",
            from: "2.8.0"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-java",
            from: "0.4.2"
        ),
        .package(
            url: "https://github.com/swift-android-sdk/swift-android-native",
            from: "2.1.0"
        )
    ],
    targets: [
        .target(
            name: "FuelingAndroid",
            dependencies: [
                // NOTE: no explicit FuelingAPI/HTTPTypes product dependencies —
                // both are statically embedded in the dynamic FuelingModel
                // product, and adding them as products creates a SECOND copy of
                // the `HTTPClient` protocol descriptor (`libFuelingAPI.so` +
                // the copy inside `libFuelingModel.so`), which breaks runtime
                // conformance lookup for `AndroidHTTPClient: HTTPClient`
                // (null witness table → SIGSEGV when copying the
                // `any LocationService` existential). Their modules remain
                // importable transitively through the build graph.
                .product(name: "FuelingModel", package: "FuelingApp"),
                .product(name: "CoreFueling", package: "FuelingApp"),
                .product(
                    name: "CoreModel",
                    package: "CoreModel"
                ),
                .product(
                    name: "SwiftJava",
                    package: "swift-java"
                ),
                .product(
                    name: "AndroidLooper",
                    package: "swift-android-native",
                    condition: .when(platforms: [.android])
                )
            ],
            exclude: [
                "swift-java.config"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(
                    ["-Osize", "-Xfrontend", "-internalize-at-link"],
                    .when(platforms: [.android], configuration: .release)
                )
            ],
            plugins: [
                .plugin(
                    name: "JExtractSwiftPlugin",
                    package: "swift-java"
                )
            ]
        )
    ]
)
