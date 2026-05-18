// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AudioPin",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AudioPin",
            path: "Sources/AudioPin",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AudioPinTests",
            dependencies: ["AudioPin"],
            path: "Tests/AudioPinTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
