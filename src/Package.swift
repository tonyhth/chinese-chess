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
                // Pikafish 构建脚本和版本文件（非源码）
                "Pikafish/build.sh",
                "Pikafish/VERSION",
                // Pikafish 预编译静态库（由 build.sh 生成，不入 Git）
                "Pikafish/lib"
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