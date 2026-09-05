// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MsCleaner",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MsCleaner",
            path: "Sources/MsCleaner",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
