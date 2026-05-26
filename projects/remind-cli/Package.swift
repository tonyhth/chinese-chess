// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "remind-cli",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "rem", targets: ["RemCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "RemCLI",
            dependencies: ["RemCore", .product(name: "ArgumentParser", package: "swift-argument-parser")],
            path: "Sources/RemCLI"
        ),
        .target(
            name: "RemCore",
            path: "Sources/RemCore"
        ),
        .testTarget(
            name: "RemCoreTests",
            dependencies: ["RemCore"],
            path: "Tests/RemCoreTests"
        )
    ]
)
