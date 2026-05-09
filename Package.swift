// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipFlow",
    defaultLocalization: "en",
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
            path: "Sources",
            exclude: [
                "Resources/Info.plist"
            ],
            resources: [
                .process("Resources/Assets.xcassets"),
                .process("Resources/Localizations"),
                .process("Core/Storage/ClipFlow.xcdatamodeld")
            ]
        ),
        .testTarget(
            name: "ClipFlowTests",
            dependencies: ["ClipFlow"],
            path: "Tests"
        )
    ]
)
