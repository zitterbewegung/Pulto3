// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CarnetsCoreKit",
    platforms: [
        .iOS(.v16), .macOS(.v13), .visionOS(.v1)
    ],
    products: [
        .library(name: "CarnetsCoreKit", targets: ["CarnetsCoreKit"])
    ],
    targets: [
        // Point these paths to YOUR local built frameworks:
        .binaryTarget(name: "pythonA",     path: "../Carnets/cpython/build/pythonA.xcframework"),
        .binaryTarget(name: "pythonB",     path: "../Carnets/cpython/build/pythonB.xcframework"),
        .binaryTarget(name: "pythonC",     path: "../Carnets/cpython/build/pythonC.xcframework"),
        .binaryTarget(name: "pythonD",     path: "../Carnets/cpython/build/pythonD.xcframework"),
        .binaryTarget(name: "pythonE",     path: "../Carnets/cpython/build/pythonE.xcframework"),
        .binaryTarget(name: "python3_ios", path: "../Carnets/cpython/build/python3_ios.xcframework"),

        .target(
            name: "CarnetsCoreKit",
            dependencies: ["pythonA", "pythonB", "pythonC", "pythonD", "pythonE", "python3_ios"],
            path: "Sources"
        )
    ]
)

