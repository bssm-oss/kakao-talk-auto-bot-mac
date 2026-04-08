// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "katalk-ax",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "KTalkAXCore", targets: ["KTalkAXCore"]),
        .executable(name: "katalk-ax", targets: ["KTalkAXCLI"]),
        .executable(name: "kabot", targets: ["KabotCLI"]),
        .executable(name: "katalk-ax-menu-bar", targets: ["KTalkAXMenuBar"]),
        .executable(name: "katalk-ax-mcp", targets: ["KTalkAXMCP"])
    ],
    targets: [
        .target(
            name: "KTalkAXCore",
            path: "Sources/KTalkAX"
        ),
        .executableTarget(
            name: "KTalkAXCLI",
            dependencies: ["KTalkAXCore"],
            path: "Sources/KTalkAXCLI"
        ),
        .executableTarget(
            name: "KabotCLI",
            dependencies: ["KTalkAXCore"],
            path: "Sources/KabotCLI"
        ),
        .target(
            name: "KTalkAXMenuBarApp",
            dependencies: ["KTalkAXCore"],
            path: "Sources/KTalkAXMenuBarApp"
        ),
        .executableTarget(
            name: "KTalkAXMenuBar",
            dependencies: ["KTalkAXMenuBarApp"],
            path: "Sources/KTalkAXMenuBar"
        ),
        .executableTarget(
            name: "KTalkAXMCP",
            dependencies: ["KTalkAXCore"],
            path: "Sources/KTalkAXMCP"
        ),
        .testTarget(
            name: "KTalkAXTests",
            dependencies: ["KTalkAXCore"],
            path: "Tests/KTalkAXTests",
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xfrontend", "-disable-cross-import-overlays"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-framework", "Testing",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ]
        ),
        .testTarget(
            name: "KTalkAXMenuBarTests",
            dependencies: ["KTalkAXMenuBarApp"],
            path: "Tests/KTalkAXMenuBarTests",
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xfrontend", "-disable-cross-import-overlays"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-framework", "Testing",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ]
        )
    ]
)
