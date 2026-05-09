// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClipFlow", targets: ["ClipFlow"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0")
    ],
    targets: [
        .executableTarget(
            name: "ClipFlow",
            dependencies: [
                "KeyboardShortcuts",
                "Sparkle"
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "ClipFlowTests",
            dependencies: ["ClipFlow"],
            path: "Tests"
        )
    ]
)
