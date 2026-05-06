// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudioPin",
    // TODO: update to .v16 when targeting macOS Tahoe
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "AudioPin",
            path: "Sources/AudioPin",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
