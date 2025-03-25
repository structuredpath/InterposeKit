// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "InterposeKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "InterposeKit",
            targets: ["InterposeKit"]
        ),
    ],
    targets: [
        .target(name: "ITKSuperBuilder"),
        .target(
            name: "InterposeKit",
            dependencies: ["ITKSuperBuilder"]
        ),
        .testTarget(
            name: "InterposeKitTests",
            dependencies: ["InterposeKit"]
        ),
    ]
)
