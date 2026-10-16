// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Focus",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Focus",
            path: "Sources/Focus",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
