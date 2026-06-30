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
                "GrokBar.xcodeproj",
                "Assets.xcassets",
                "Info.plist",
                "README.md",
                "Tests",
                "GrokBar.app",
                "build_app.sh",
                "GrokBar.entitlements",
                "BundleResources.json",
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
