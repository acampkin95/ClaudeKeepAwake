// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeKeepAwake",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeKeepAwake",
            path: "Sources/ClaudeKeepAwake",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("IOKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
