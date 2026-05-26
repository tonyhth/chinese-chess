// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "calendar-cli",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "calcli", targets: ["EvtCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "EvtCLI",
            dependencies: ["EvtCore", .product(name: "ArgumentParser", package: "swift-argument-parser")],
            path: "Sources/EvtCLI"
        ),
        .target(
            name: "EvtCore",
            path: "Sources/EvtCore"
        ),
        .testTarget(
            name: "EvtCoreTests",
            dependencies: ["EvtCore"],
            path: "Tests/EvtCoreTests"
        )
    ]
)
