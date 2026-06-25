// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KarabinerPlus",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "KarabinerPlusCore",
            targets: ["KarabinerPlusCore"]
        ),
        .executable(
            name: "KarabinerPlusApp",
            targets: ["KarabinerPlusApp"]
        ),
        .executable(
            name: "KarabinerPlusCoreCheck",
            targets: ["KarabinerPlusCoreCheck"]
        ),
    ],
    targets: [
        .target(
            name: "KarabinerPlusCore",
            path: "Sources/KarabinerPlusCore"
        ),
        .executableTarget(
            name: "KarabinerPlusApp",
            dependencies: ["KarabinerPlusCore"],
            path: "Sources/KarabinerPlusApp",
            exclude: ["Info.plist"]
        ),
        .executableTarget(
            name: "KarabinerPlusCoreCheck",
            dependencies: ["KarabinerPlusCore"],
            path: "Sources/KarabinerPlusCoreCheck"
        ),
    ]
)
