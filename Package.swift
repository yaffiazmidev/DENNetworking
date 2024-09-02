// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DENNetworking",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "DENNetworking",
            targets: ["DENNetworking"]),
    ],
    targets: [
        .target(
            name: "DENNetworking"),
        .testTarget(
            name: "DENNetworkingTests",
            dependencies: ["DENNetworking"]),
    ]
)
