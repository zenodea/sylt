// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ControlIsland",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ControlIsland",
            path: "Sources/ControlIsland",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
            ]
        )
    ]
)
