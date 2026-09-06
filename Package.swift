// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Reclaim",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Reclaim",
            path: "Sources/Reclaim",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
