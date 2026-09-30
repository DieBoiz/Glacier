// swift-tools-version:6.0
import PackageDescription

// Test-only package. It compiles Ice's pure macOS 27 logic so that logic can be
// unit tested with `swift test`. The same files are compiled into the Ice app
// through the synchronized `Ice` folder group.
let package = Package(
    name: "GlacierMacOS27Core",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "GlacierMacOS27Core",
            path: "Glacier/MenuBar/MacOS27/Core",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "GlacierMacOS27CoreTests",
            dependencies: ["GlacierMacOS27Core"],
            path: "Tests/GlacierMacOS27CoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
