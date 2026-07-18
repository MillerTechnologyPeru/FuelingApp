// swift-tools-version: 6.0
import PackageDescription
import class Foundation.ProcessInfo

let darwin: [Platform] = [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .macCatalyst]
let otherPlatforms: [Platform] = [.linux, .windows, .openbsd, .wasi]
let nonAndroidPlatforms: [Platform] = darwin + otherPlatforms

// The Android jextract/JNI build (see Android/fueling-jni/build.gradle.kts) cross-compiles
// this package with this flag set, so every library in the graph — including this package's
// own products — builds as its own `.so`, staged into the app's `jniLibs` alongside
// CoreModel/CoreModel-SQLite/SQLite's. Unset (the default), library products keep SwiftPM's
// automatic linkage, which is static for every consumer in this repo.
let dynamicLibrary = ProcessInfo.processInfo.environment["SWIFT_BUILD_DYNAMIC_LIBRARY"] == "1"
let libraryType: PackageDescription.Product.Library.LibraryType? = dynamicLibrary ? .dynamic : nil

let package = Package(
    name: "FuelingApp",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "CoreFueling",
            type: libraryType,
            targets: ["CoreFueling"]
        ),
        .library(
            name: "FuelingAPI",
            type: libraryType,
            targets: ["FuelingAPI"]
        ),
        .library(
            name: "FuelingModel",
            type: libraryType,
            targets: ["FuelingModel"]
        ),
        .library(
            name: "FuelingUI",
            type: libraryType,
            targets: ["FuelingUI"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/CoreModel.git",
            from: "2.8.0"
        ),
        .package(
            url: "https://github.com/apple/swift-http-types",
            from: "1.4.0"
        ),
        .package(
            url: "https://github.com/PureSwift/CoreModel-SQLite",
            branch: "master"
        ),
        .package(
            url: "https://github.com/PureSwift/SQLite",
            branch: "master"
        )
    ],
    targets: [
        .target(
            name: "CoreFueling",
            dependencies: [
                .product(
                    name: "CoreModel",
                    package: "CoreModel"
                )
            ]
        ),
        .target(
            name: "FuelingAPI",
            dependencies: [
                "CoreFueling",
                .product(
                    name: "CoreModel",
                    package: "CoreModel"
                ),
                .product(
                    name: "HTTPTypes",
                    package: "swift-http-types"
                ),
                .product(
                    name: "HTTPTypesFoundation",
                    package: "swift-http-types"
                )
            ]
        ),
        .target(
            name: "FuelingModel",
            dependencies: [
                "CoreFueling",
                .target(
                    name: "FuelingAPI",
                    condition: .when(platforms: nonAndroidPlatforms)
                ),
                .product(
                    name: "CoreModel",
                    package: "CoreModel"
                ),
                .product(
                    name: "HTTPTypes",
                    package: "swift-http-types",
                    condition: .when(platforms: nonAndroidPlatforms)
                ),
                .product(
                    name: "CoreDataModel",
                    package: "CoreModel",
                    condition: .when(platforms: darwin)
                ),
                .product(
                    name: "CoreModelSQLite",
                    package: "CoreModel-SQLite"
                ),
                .product(
                    name: "SQLite",
                    package: "SQLite"
                )
            ]
        ),
        .target(
            name: "FuelingUI",
            dependencies: [
                "FuelingModel"
            ]
        ),
        .testTarget(
            name: "FuelingTests",
            dependencies: [
                "CoreFueling",
                "FuelingAPI",
                "FuelingModel",
                .product(
                    name: "CoreModel",
                    package: "CoreModel"
                )
            ],
            resources: [
                .copy("TestFiles")
            ]
        )
    ]
)
