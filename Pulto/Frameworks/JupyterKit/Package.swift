// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "JupyterKit",
    defaultLocalization: "en",
    platforms: [ .visionOS(.v2) ],
    products: [ .library(name: "JupyterKit", targets: ["JupyterKit"]) ],
    targets: [
        .target(
            name: "JupyterKit",
            path: "Sources/JupyterKit",
            resources: [
                .copy("../../Resources/bootstrap.py"),
                .copy("../../Resources/jupyter_notebook_config.py")
            ]
        )
    ]
)
