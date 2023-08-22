// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftNavigation",
    platforms: [
        .visionOS(.v1),
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftRecast",
            targets: ["SwiftRecast"]),
        .library(
            name: "SwiftDetour",
            targets: ["SwiftDetour"]),

    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftRecast",
            dependencies: ["CRecast"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .target(
            name: "SwiftDetour",
            dependencies: ["CDetour"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .target(
            name: "CRecast"),
        .target(
            name: "CDetour"),
        .testTarget(
            name: "DetourTests",
            dependencies: ["SwiftDetour"],
            swiftSettings: [.interoperabilityMode(.Cxx)]),
    ]
)
