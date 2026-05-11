// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TokenIsland",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TokenIsland", targets: ["TokenIsland"]),
        .executable(name: "tokenisland-bridge", targets: ["TokenIslandBridge"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
    ],
    targets: [
        .target(
            name: "TokenIslandCore",
            path: "Sources/TokenIslandCore"
        ),
        .executableTarget(
            name: "TokenIsland",
            dependencies: [
                "TokenIslandCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/TokenIsland",
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "TokenIslandBridge",
            dependencies: ["TokenIslandCore"],
            path: "Sources/TokenIslandBridge"
        ),
        .executableTarget(
            name: "TokenIslandVerify",
            dependencies: ["TokenIslandCore"],
            path: "Sources/TokenIslandVerify"
        ),
        .testTarget(
            name: "TokenIslandCoreTests",
            dependencies: ["TokenIslandCore"],
            path: "Tests/TokenIslandCoreTests"
        ),
    ]
)
