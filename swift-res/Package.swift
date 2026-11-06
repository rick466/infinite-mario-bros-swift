// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-res",
    platforms: [.iOS(.v17)],
    products: [
        .iOSApplication(
            name: "SwiftRes",
            targets: ["SwiftRes"],
            bundleIdentifier: "com.rick466.infinitemariobrosswift",
            teamIdentifier: "",
            displayVersion: "2.5",
            bundleVersion: "40",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor("AccentColor"),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [.landscapeLeft, .landscapeRight]
        )
    ],
    targets: [
        .executableTarget(
            name: "SwiftRes",
            path: "src",
            resources: [.process("Resources")]
        )
    ]
)
