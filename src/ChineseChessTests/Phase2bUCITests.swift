#if os(macOS)

import Foundation
import Testing
@testable import ChineseChess

// MARK: - Phase 2b: UCI 外部引擎通信测试

@Suite("Phase 2b: UCIInfo 解析")
struct UCIInfoParseTests {

    @Test("解析 depth + score cp")
    func parseDepthAndScore() {
        let info = UCIInfo.parse(line: "info depth 15 nodes 12345 score cp 250 time 1000 nps 12345 pv h2e2")
        #expect(info.depth == 15)
        #expect(info.nodes == 12345)
        #expect(info.score == 250)
        #expect(info.timeMs == 1000)
        #expect(info.nps == 12345)
        #expect(info.pv == "h2e2")
    }

    @Test("解析 mate score")
    func parseMateScore() {
        let info = UCIInfo.parse(line: "info depth 10 score mate 5")
        #expect(info.score == 100005)  // 100000 + 5
    }

    @Test("解析负 mate score")
    func parseNegativeMate() {
        let info = UCIInfo.parse(line: "info depth 8 score mate -3")
        // value=-3, 公式: -100000 - (-3) = -99997
        // 越近的 mate 越严重（-99997 < -99995），排序正确
        #expect(info.score == -99997)
    }

    @Test("最简 info 行")
    func parseMinimalInfo() {
        let info = UCIInfo.parse(line: "info string hello")
        #expect(info.depth == nil)
        #expect(info.nodes == nil)
        #expect(info.score == nil)
    }
}

@Suite("Phase 2b: ExternalEngineConfig 持久化")
struct ExternalEngineConfigTests {

    @Test("Codable 往返编解码")
    func codableRoundTrip() throws {
        let config = ExternalEngineConfig(
            name: "Pikafish",
            executablePath: "/usr/local/bin/pikafish",
            arguments: ["--threads=2"],
            options: [UCIOption(name: "Hash", value: "256")],
            isEnabled: true
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ExternalEngineConfig.self, from: data)

        #expect(decoded.name == "Pikafish")
        #expect(decoded.executablePath == "/usr/local/bin/pikafish")
        #expect(decoded.arguments == ["--threads=2"])
        #expect(decoded.options.count == 1)
        #expect(decoded.options[0].name == "Hash")
        #expect(decoded.options[0].value == "256")
        #expect(decoded.isEnabled == true)
        // P2 #7: 验证 id 往返一致性
        #expect(decoded.id == config.id)
        #expect(decoded.options[0].id == config.options[0].id)
    }

    @Test("默认配置")
    func defaultConfig() {
        let config = ExternalEngineConfig.defaultConfig
        #expect(config.name == "")
        #expect(config.executablePath == "")
        #expect(config.options.isEmpty)
        #expect(config.isEnabled == false)
    }

    @Test("UCIOption Identifiable")
    func ucioptionIdentifiable() {
        let opt = UCIOption(name: "Threads", value: "4")
        #expect(opt.id != UCIOption(name: "Threads", value: "4").id)  // 每次 UUID 不同
    }
}

@Suite("Phase 2b: Mock UCI 引擎集成")
struct ExternalEngineIntegrationTests {

    @Test("方案 E：In-process Mock 引擎握手 + bestmove")
    func inProcessMockEngineTest() async throws {
        // 使用 useInProcessMock: true，无需外部进程，根治残留问题
        let config = ExternalEngineConfig(
            name: "MockEngine",
            executablePath: "",  // mock 模式无需路径
            options: [],
            isEnabled: true,
            useInProcessMock: true
        )

        let manager = ExternalEngineManager(config: config)
        try await manager.start()

        #expect(await manager.isReady)
        #expect(await manager.engineType == EngineType.external)
        #expect(await manager.displayName == "MockEngine")

        // 初始局面求走法
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w"
        let bestMove = await manager.bestMove(
            fen: fen,
            moveHistory: [],
            difficulty: AIDifficulty.medium,
            timeLimitMs: 0
        )

        #expect(bestMove != nil)
        #expect(bestMove == "h2e2")  // mock 引擎固定返回

        await manager.shutdown()
        #expect(await manager.isReady == false)
    }

    @Test("Pikafish 真实引擎握手（如可用）", .enabled(if: FileManager.default.isExecutableFile(atPath: "/Users/hth/DevTeam/tools/pikafish/pikafish-bmi2")))
    func pikafishIntegration() async throws {
        let pikafishPath = "/Users/hth/DevTeam/tools/pikafish/pikafish-bmi2"

        let config = ExternalEngineConfig(
            name: "Pikafish",
            executablePath: pikafishPath,
            arguments: nil,
            options: [],
            isEnabled: true
        )

        let manager = ExternalEngineManager(config: config)
        try await manager.start()

        #expect(await manager.isReady)

        // 初始局面求走法
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w"
        let bestMove = await manager.bestMove(
            fen: fen,
            moveHistory: [],
            difficulty: .medium,
            timeLimitMs: 3000
        )

        #expect(bestMove != nil, "Pikafish should return a move")
        if let move = bestMove {
            #expect(move.count == 4, "UCI move should be 4 chars, got: \(move)")
        }

        await manager.shutdown()
    }
}

#endif
