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
        .executable(
            name: "KeyTailorCoreCheck",
            targets: ["KeyTailorCoreCheck"]
        ),
    ],
    targets: [
        .target(
            name: "KeyTailorCore",
            path: "Sources/KeyTailorCore"
        ),
        .executableTarget(
            name: "KeyTailorCoreCheck",
            dependencies: ["KeyTailorCore"],
            path: "Sources/KeyTailorCoreCheck"
        ),
    ]
)
