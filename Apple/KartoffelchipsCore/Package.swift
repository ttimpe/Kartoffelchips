// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KartoffelchipsCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "KartoffelchipsCore", targets: ["KartoffelchipsCore"]),
    ],
    targets: [
        .target(
            name: "KartoffelchipsCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "KartoffelchipsCoreTests",
            dependencies: ["KartoffelchipsCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
