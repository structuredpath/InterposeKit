// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "InterposeKit",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_13),
        .tvOS(.v12),
        .watchOS(.v5)
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
