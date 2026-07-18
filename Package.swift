// swift-tools-version: 6.0
import PackageDescription

let darwin: [Platform] = [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .macCatalyst]

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
            targets: ["CoreFueling"]
        ),
        .library(
            name: "FuelingAPI",
            targets: ["FuelingAPI"]
        ),
        .library(
            name: "FuelingModel",
            targets: ["FuelingModel"]
        ),
        .library(
            name: "FuelingUI",
            targets: ["FuelingUI"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/CoreModel.git",
            from: "2.8.0"
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
                )
            ]
        ),
        .target(
            name: "FuelingModel",
            dependencies: [
                "CoreFueling",
                "FuelingAPI",
                .product(
                    name: "CoreModel",
                    package: "CoreModel"
                ),
                .product(
                    name: "CoreDataModel",
                    package: "CoreModel",
                    condition: .when(platforms: darwin)
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
            ]
        )
    ]
)
