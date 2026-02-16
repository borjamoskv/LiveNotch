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
            resources: [
                .process("Resources")
            ],
            // Swift 6.2 has strict concurrency built-in; removed legacy -enable-actor-data-race-checks
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("IOKit"),
                .linkedFramework("EventKit"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("GameplayKit"),   // For procedural noise
                .linkedFramework("Vision"),         // For face/eye gesture detection
                .linkedFramework("IOBluetooth"),    // AirPods detection & battery
                .linkedFramework("CoreBluetooth")   // BLE accessory scanning
            ]
        )
    ]
)
