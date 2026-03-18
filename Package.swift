// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DENNetworking",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "DENNetworking",
            targets: ["DENNetworking"]
        ),
    ],
    targets: [
        .target(
            name: "DENNetworking",
            path: "Sources"
        ),
        .testTarget(
            name: "DENNetworkingTests",
            dependencies: ["DENNetworking"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
