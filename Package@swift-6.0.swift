// swift-tools-version: 6.0

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
        .target(
            name: "InterposeKit",
            dependencies: ["InterposeKitObjC"]
        ),
        .target(
            name: "InterposeKitObjC"
        ),
        .testTarget(
            name: "InterposeKitTests",
            dependencies: ["InterposeKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
