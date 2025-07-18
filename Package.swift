// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Harbinger",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Harbinger",
            targets: ["Harbinger"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Harbinger",
            dependencies: [],
            path: "Sources"
        )
    ]
)
