// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RealityKitContent",
    platforms: [
        .visionOS(.v26),
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26)
    ],
    products: [
        .library(
            name: "RealityKitContent",
            targets: ["RealityKitContent"]),
    ],
    dependencies: [
        .package(path: "../../../External/Carnets/cpython"),
        .package(path: "../../../Carnets/xcfs"),
    ],
    targets: [
        .target(
            name: "RealityKitContent",
            dependencies: [
                .product(name: "ios_system", package: "xcfs"),
                .product(name: "shell", package: "xcfs"),
                .product(name: "files", package: "xcfs"),
                .product(name: "text", package: "xcfs"),
                .product(name: "curl_ios", package: "xcfs"),
                .product(name: "tar", package: "xcfs"),
                .product(name: "ssh_cmd", package: "xcfs"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility")
            ]),
    ]
)
