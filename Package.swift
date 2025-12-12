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
            exclude: ["GrokBar.xcodeproj", "Assets.xcassets", "Info.plist", "README.md"]
        )
    ]
)
