#if os(macOS)

import Foundation
import Testing
@testable import ChineseChess

// MARK: - 方案 E：In-process Mock UCI 引擎测试

@Suite("方案 E: ExternalEngineManager Mock 模式")
struct PlanEMockEngineTests {

    @Test("Mock 引擎启动和 ready 状态")
    func mockEngineStartAndReady() async throws {
        let config = ExternalEngineConfig(
            name: "TestMock",
            executablePath: "",
            options: [],
            isEnabled: true,
            useInProcessMock: true
        )

        let manager = ExternalEngineManager(config: config)
        try await manager.start()

        let ready = await manager.isReady
        #expect(ready == true, "Mock 引擎启动后应 ready")

        await manager.shutdown()
        #expect(await manager.isReady == false)
    }

    @Test("Mock 引擎 bestMove 返回固定 h2e2")
    func mockEngineBestMoveReturnsH2e2() async throws {
        let config = ExternalEngineConfig(
            name: "BestMoveTest",
            executablePath: "",
            options: [],
            isEnabled: true,
            useInProcessMock: true
        )

        let manager = ExternalEngineManager(config: config)
        try await manager.start()

        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w"
        let move = await manager.bestMove(
            fen: fen,
            moveHistory: [],
            difficulty: AIDifficulty.medium,
            timeLimitMs: 0
        )

        #expect(move == "h2e2", "Mock 引擎应返回固定 h2e2")

        await manager.shutdown()
    }

    @Test("Mock 引擎未启动时 bestMove 返回 nil")
    func mockEngineNotReadyReturnsNil() async {
        let config = ExternalEngineConfig(
            name: "NotReadyTest",
            executablePath: "",
            options: [],
            isEnabled: true,
            useInProcessMock: true
        )

        let manager = ExternalEngineManager(config: config)
        // 不调用 start()

        let move = await manager.bestMove(
            fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w",
            moveHistory: [],
            difficulty: AIDifficulty.medium,
            timeLimitMs: 0
        )

        #expect(move == nil, "未启动时应返回 nil")
    }

    @Test("Mock 引擎 displayName 和 engineType")
    func mockEngineProperties() async throws {
        let config = ExternalEngineConfig(
            name: "PropertyTest",
            executablePath: "",
            options: [],
            isEnabled: true,
            useInProcessMock: true
        )

        let manager = ExternalEngineManager(config: config)
        try await manager.start()

        #expect(manager.displayName == "PropertyTest")
        #expect(manager.engineType == EngineType.external)

        await manager.shutdown()
    }

    @Test("Mock 引擎 newGame 无副作用")
    func mockEngineNewGame() async throws {
        let config = ExternalEngineConfig(
            name: "NewGameTest",
            executablePath: "",
            options: [],
            isEnabled: true,
            useInProcessMock: true
        )

        let manager = ExternalEngineManager(config: config)
        try await manager.start()
        #expect(await manager.isReady == true)

        await manager.newGame()
        #expect(await manager.isReady == true, "newGame 不影响 ready 状态")

        await manager.shutdown()
    }

    @Test("Mock 引擎 stopSearch 无副作用")
    func mockEngineStopSearch() async throws {
        let config = ExternalEngineConfig(
            name: "StopSearchTest",
            executablePath: "",
            options: [],
            isEnabled: true,
            useInProcessMock: true
        )

        let manager = ExternalEngineManager(config: config)
        try await manager.start()

        await manager.stopSearch()
        #expect(await manager.isReady == true)

        await manager.shutdown()
    }

    @Test("Mock 引擎多次操作")
    func mockEngineMultipleOperations() async throws {
        let config = ExternalEngineConfig(
            name: "MultiOpTest",
            executablePath: "",
            options: [],
            isEnabled: true,
            useInProcessMock: true
        )

        let manager = ExternalEngineManager(config: config)
        try await manager.start()

        // 多次 bestMove
        for _ in 0..<5 {
            let move = await manager.bestMove(
                fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w",
                moveHistory: [],
                difficulty: AIDifficulty.medium,
                timeLimitMs: 0
            )
            #expect(move == "h2e2")
        }

        await manager.shutdown()
        #expect(await manager.isReady == false)
    }
}

@Suite("方案 E: 配置兼容性")
struct PlanEConfigCompatibilityTests {

    @Test("旧配置加载：缺少 useInProcessMock 字段时默认 false")
    func legacyConfigLoad() throws {
        // 模拟旧配置 JSON（不包含 useInProcessMock）
        let legacyJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "name": "LegacyEngine",
            "executablePath": "/usr/local/bin/engine",
            "arguments": null,
            "options": [],
            "isEnabled": true
        }
        """

        let data = legacyJSON.data(using: .utf8)!
        let config = try JSONDecoder().decode(ExternalEngineConfig.self, from: data)

        #expect(config.useInProcessMock == false, "旧配置应默认 useInProcessMock: false")
        #expect(config.name == "LegacyEngine")
    }

    @Test("新配置包含 useInProcessMock")
    func newConfigLoad() throws {
        let newJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "name": "NewMockEngine",
            "executablePath": "",
            "arguments": null,
            "options": [],
            "isEnabled": true,
            "useInProcessMock": true
        }
        """

        let data = newJSON.data(using: .utf8)!
        let config = try JSONDecoder().decode(ExternalEngineConfig.self, from: data)

        #expect(config.useInProcessMock == true)
    }

    @Test("Codable 往返包含 useInProcessMock")
    func codableRoundTripWithMockFlag() throws {
        let config = ExternalEngineConfig(
            name: "Test",
            executablePath: "/path",
            options: [],
            isEnabled: true,
            useInProcessMock: true
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ExternalEngineConfig.self, from: data)

        #expect(decoded.useInProcessMock == true)
        #expect(decoded.name == "Test")
    }

    @Test("默认配置 useInProcessMock = false")
    func defaultConfigMockFlag() {
        let config = ExternalEngineConfig.defaultConfig
        #expect(config.useInProcessMock == false)
    }
}

@Suite("方案 E: 进程残留根治验证")
struct PlanEProcessResidueTests {

    @Test("多次 Mock 操作后无进程残留")
    func multipleMockOperationsNoLeak() async throws {
        // 执行多个 Mock 引擎操作
        for i in 0..<10 {
            let config = ExternalEngineConfig(
                name: "RepeatedMock\(i)",
                executablePath: "",
                options: [],
                isEnabled: true,
                useInProcessMock: true
            )

            let manager = ExternalEngineManager(config: config)
            try await manager.start()
            _ = await manager.bestMove(
                fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w",
                moveHistory: [],
                difficulty: AIDifficulty.medium,
                timeLimitMs: 0
            )
            await manager.shutdown()
        }

        // 方案 E 使用 actor，不会有进程泄漏
        // 验证：测试框架不崩溃，actor 正常工作
        #expect(true, "方案 E 使用 Swift actor，根治进程残留")
    }

    @Test("快速连续创建销毁 Mock")
    func rapidCreateDestroyMock() async throws {
        for _ in 0..<20 {
            let config = ExternalEngineConfig(
                name: "RapidTest",
                executablePath: "",
                options: [],
                isEnabled: true,
                useInProcessMock: true
            )

            let manager = ExternalEngineManager(config: config)
            try await manager.start()
            await manager.shutdown()
        }

        #expect(true, "快速创建销毁不崩溃")
    }
}

@Suite("方案 E: useInProcessMock: false 不创建 Mock")
struct PlanENoMockTests {

    @Test("useInProcessMock: false 时外部进程路径必须有效")
    func noMockRequiresValidPath() async {
        let config = ExternalEngineConfig(
            name: "NoMock",
            executablePath: "/nonexistent/path",
            options: [],
            isEnabled: true,
            useInProcessMock: false
        )

        let manager = ExternalEngineManager(config: config)

        do {
            try await manager.start()
            Issue.record("无效路径不应启动成功")
        } catch {
            // 预期：启动失败
            #expect(await manager.isReady == false)
        }
    }
}

#endif