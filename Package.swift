// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LiveNotch",
    platforms: [
        .macOS(.v14)  // Sonoma+ for latest APIs
    ],
    targets: [
        .executableTarget(
            name: "LiveNotch",
            dependencies: [],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-actor-data-race-checks"])
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("IOKit"),
                .linkedFramework("EventKit"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("GameplayKit"),   // For procedural noise
                .linkedFramework("Vision")          // For face/eye gesture detection
            ]
        )
    ]
)
