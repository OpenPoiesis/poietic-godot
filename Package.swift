// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "poietic-godot",
    platforms: [ .macOS(.v15), ],
    products: [
        .library(
            name: "PoieticGodot",
            type: .dynamic,
            targets: ["PoieticGodot"]),
    ],
    dependencies: [
                .package(url: "https://github.com/migueldeicaza/SwiftGodot", branch: "main"),
                .package(url: "https://github.com/openpoiesis/poietic-core", branch: "main"),
                .package(url: "https://github.com/openpoiesis/poietic-flows", branch: "main"),
    ],
    targets: [
        .target(
            name: "PoieticGodot",
            dependencies: [
                .product(name: "SwiftGodot", package: "SwiftGodot"),
                .product(name: "PoieticCore", package: "poietic-core"),
                .product(name: "PoieticFlows", package: "poietic-flows"),
            ],
            swiftSettings: [.unsafeFlags(["-suppress-warnings"])]
        ),
        .testTarget(
            name: "PoieticGodotTests",
            dependencies: ["PoieticGodot"]),
    ]
)
