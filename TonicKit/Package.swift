// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TonicKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "TonicKit", targets: ["TonicKit"]),
    ],
    targets: [
        .target(name: "TonicKit"),
        .testTarget(name: "TonicKitTests", dependencies: ["TonicKit"]),
    ]
)
