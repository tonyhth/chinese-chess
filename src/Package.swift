// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChineseChess",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        // Pikafish C library (systemLibrary with modulemap)
        .systemLibrary(
            name: "CPikafish",
            path: "ChineseChess/Pikafish/include"
        ),
        
        // Main target
        .executableTarget(
            name: "ChineseChess",
            dependencies: ["CPikafish"],
            path: "ChineseChess",
            exclude: [
                // Pikafish 构建产物目录（静态库在 lib/macos/）
                "Pikafish/build.sh",
                "Pikafish/build_test.sh",
                "Pikafish/VERSION",
                "Pikafish/benchmark_stub.cpp"
            ],
            resources: [.process("Resources")],
            linkerSettings: [
                .unsafeFlags(["-LChineseChess/Pikafish/lib/macos"], .when(platforms: [.macOS])),
                .linkedLibrary("pikafish", .when(platforms: [.macOS])),
                .linkedLibrary("c++", .when(platforms: [.macOS]))
            ]
        ),
        
        // Test target
        .testTarget(
            name: "ChineseChessTests",
            dependencies: ["ChineseChess"],
            path: "ChineseChessTests"
        )
    ]
)