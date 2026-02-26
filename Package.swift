// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VoiceOverlay",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "VoiceOverlay",
            path: "Sources"
        ),
        .testTarget(
            name: "VoiceOverlayTests",
            dependencies: ["VoiceOverlay"],
            path: "Tests/VoiceOverlayTests"
        )
    ]
)
