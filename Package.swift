// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Sylt",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MediaRemoteAdapter", type: .dynamic, targets: ["MediaRemoteAdapter"]),
    ],
    targets: [
        .target(
            name: "MediaRemoteAdapter",
            path: "Sources/MediaRemoteAdapter",
            linkerSettings: [.linkedFramework("Foundation"), .linkedFramework("QuartzCore")]
        ),
        .executableTarget(
            name: "Sylt",
            path: "Sources/Sylt",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("IOBluetooth"),
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                              "-Xlinker", "Resources/Info.plist"]),
            ]
        ),
        .testTarget(
            name: "SyltTests",
            dependencies: ["Sylt"],
            path: "Tests/SyltTests"
        ),
    ]
)
