// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ControlIsland",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MediaRemoteAdapter", type: .dynamic, targets: ["MediaRemoteAdapter"]),
    ],
    targets: [
        .target(
            name: "MediaRemoteAdapter",
            path: "Sources/MediaRemoteAdapter",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        .executableTarget(
            name: "ControlIsland",
            path: "Sources/ControlIsland",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                              "-Xlinker", "Resources/Info.plist"]),
            ]
        )
    ]
)
