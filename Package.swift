// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AsyncToSyncBridge",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
        .macCatalyst(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "AsyncToSyncBridge",
            targets: ["AsyncToSyncBridge"]
        ),
    ],
    targets: [
        .target(
            name: "AsyncToSyncBridge"
        ),
        .testTarget(
            name: "AsyncToSyncBridgeTests",
            dependencies: ["AsyncToSyncBridge"]
        ),
    ]
)

