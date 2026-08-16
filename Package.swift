// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Drawstate",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DrawstateCore", targets: ["DrawstateCore"]),
        .executable(name: "Drawstate", targets: ["Drawstate"])
    ],
    targets: [
        .target(
            name: "DrawstateCore",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "Drawstate",
            dependencies: ["DrawstateCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(name: "DrawstateCoreTests", dependencies: ["DrawstateCore"])
    ],
    swiftLanguageModes: [.v5]
)
