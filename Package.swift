// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyTailor",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "KeyTailorCore",
            targets: ["KeyTailorCore"]
        ),
    ],
    targets: [
        .target(
            name: "KeyTailorCore",
            path: "Sources/KeyTailorCore"
        ),
        .testTarget(
            name: "KeyTailorCoreTests",
            dependencies: ["KeyTailorCore"],
            path: "Tests/KeyTailorCoreTests"
        ),
    ]
)
