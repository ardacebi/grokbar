// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GrokBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "GrokBar", targets: ["GrokBar"])
    ],
    targets: [
        .executableTarget(
            name: "GrokBar",
            path: ".",
            exclude: [
                "Info.plist",
                "README.md",
                "Tests",
                "GrokBar.app",
                "build_app.sh",
                "build_dmg.sh",
                "generate_icon.sh",
                "Icon_GrokBar.icns",
                "dist",
                "GrokBar.entitlements",
                "grok-small.png",
                "Icon_GrokBar.icon"
            ]
        ),
        .testTarget(
            name: "GrokBarTests",
            dependencies: ["GrokBar"],
            path: "Tests/GrokBarTests"
        )
    ]
)
