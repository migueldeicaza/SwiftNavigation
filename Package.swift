// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftNavigation",
    platforms: [
        .visionOS(.v1),
        .iOS(.v13),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftNavigation",
            targets: ["SwiftNavigation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftNavigation",
            dependencies: ["CRecast"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .target(
            name: "CRecast"),
        .testTarget(
            name: "RecastTests",
            dependencies: ["SwiftNavigation"],
            swiftSettings: [.interoperabilityMode(.Cxx)]),
    ]
)
