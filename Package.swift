// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Hello",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Hello", path: "Sources/Hello"),
        .testTarget(name: "HelloTests", dependencies: ["Hello"])
    ]
)
