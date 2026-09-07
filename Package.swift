// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Stayup",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Stayup",
            path: "Sources/Stayup",
            linkerSettings: [.linkedFramework("IOKit")]
        )
    ]
)
