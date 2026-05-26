// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChineseChess",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ChineseChess",
            path: "ChineseChess",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ChineseChessTests",
            dependencies: ["ChineseChess"],
            path: "ChineseChessTests"
        )
    ]
)
