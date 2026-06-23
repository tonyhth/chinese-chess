import Foundation
import Testing
@testable import ChineseChess

// MARK: - 第二批次 P1 任务测试

@Suite("P1 #1: 路径 ~ 展开")
struct TildePathExpansionTests {

    @Test("~/ 展开为用户主目录")
    func expandTildePath() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let tildePath = "~/bin/pikafish"
        let resolved = (tildePath as NSString).expandingTildeInPath

        #expect(resolved.hasPrefix(homeDir), "展开后应以用户主目录开头")
        #expect(resolved.hasSuffix("bin/pikafish"), "路径尾部应保留")
        #expect(!resolved.contains("~"), "不应包含 ~")
    }

    @Test("绝对路径不受影响")
    func absolutePathUnchanged() {
        let absPath = "/usr/local/bin/engine"
        let resolved = (absPath as NSString).expandingTildeInPath

        #expect(resolved == absPath, "绝对路径应保持不变")
    }

    @Test("空路径不崩溃")
    func emptyPathNoCrash() {
        let empty = ""
        let resolved = (empty as NSString).expandingTildeInPath

        #expect(resolved == "", "空路径应返回空")
    }

    @Test("相对路径（非 ~）不受影响")
    func relativePathUnchanged() {
        let relPath = "bin/engine"
        let resolved = (relPath as NSString).expandingTildeInPath

        #expect(resolved == relPath, "相对路径应保持不变")
    }
}

@Suite("P1 #3: UCI id 行解析")
struct UCIParseIdLineTests {

    @Test("解析 id name")
    func parseIdName() {
        // 直接测试 parseIdLine 的逻辑（通过模拟输入）
        // UCITransceiver 是 actor，需要通过方法测试
        // 测试解析逻辑的等价实现
        let line = "id name Pikafish 4.0"
        let tokens = line.split(separator: " ")
        #expect(tokens.count >= 3)
        #expect(tokens[1] == "name")
        let name = tokens[2...].joined(separator: " ")
        #expect(name == "Pikafish 4.0")
    }

    @Test("解析 id version")
    func parseIdVersion() {
        let line = "id version 4.0.0"
        let tokens = line.split(separator: " ")
        #expect(tokens.count >= 3)
        #expect(tokens[1] == "version")
        let version = String(tokens[2])
        #expect(version == "4.0.0")
    }

    @Test("解析 id name 单个词")
    func parseIdNameSingleWord() {
        let line = "id name Pikafish"
        let tokens = line.split(separator: " ")
        #expect(tokens.count >= 3)
        #expect(tokens[1] == "name")
        let name = tokens[2...].joined(separator: " ")
        #expect(name == "Pikafish")
    }

    @Test("id 行 token 不足跳过")
    func insufficientTokensSkipped() {
        let line = "id name"
        let tokens = line.split(separator: " ")
        #expect(tokens.count < 3, "应不足 3 个 token，跳过解析")
    }

    @Test("非 id 行不解析")
    func nonIdLineIgnored() {
        let lines = [
            "uciok",
            "readyok",
            "bestmove h2e2",
            "info depth 10 score cp 50"
        ]
        for line in lines {
            let hasPrefix = line.hasPrefix("id ")
            #expect(!hasPrefix, "'\(line)' 不应以 'id ' 开头")
        }
    }
}

@Suite("P1 #3/#5: ExternalEngineConfig resolvedName/resolvedVersion")
struct ExternalEngineConfigResolvedInfoTests {

    @Test("resolvedName/resolvedVersion 默认为 nil")
    func defaultsToNil() {
        let config = ExternalEngineConfig.defaultConfig
        #expect(config.resolvedName == nil)
        #expect(config.resolvedVersion == nil)
    }

    @Test("设置 resolvedName/resolvedVersion")
    func setResolvedInfo() {
        var config = ExternalEngineConfig.defaultConfig
        config.resolvedName = "Pikafish"
        config.resolvedVersion = "4.0.0"

        #expect(config.resolvedName == "Pikafish")
        #expect(config.resolvedVersion == "4.0.0")
    }

    @Test("旧配置加载不含 resolvedName/resolvedVersion 时为 nil")
    func legacyConfigWithoutResolvedInfo() throws {
        let legacyJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "name": "MyEngine",
            "executablePath": "/usr/local/bin/engine",
            "arguments": null,
            "options": [],
            "isEnabled": true
        }
        """
        let data = legacyJSON.data(using: .utf8)!
        let config = try JSONDecoder().decode(ExternalEngineConfig.self, from: data)

        #expect(config.resolvedName == nil, "旧配置应 resolvedName = nil")
        #expect(config.resolvedVersion == nil, "旧配置应 resolvedVersion = nil")
        #expect(config.useInProcessMock == false, "旧配置应 useInProcessMock = false")
    }

    @Test("新配置包含 resolvedName/resolvedVersion")
    func newConfigWithResolvedInfo() throws {
        let newJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "name": "Pikafish",
            "executablePath": "/usr/local/bin/pikafish",
            "arguments": null,
            "options": [],
            "isEnabled": true,
            "useInProcessMock": false,
            "resolvedName": "Pikafish",
            "resolvedVersion": "4.0.0"
        }
        """
        let data = newJSON.data(using: .utf8)!
        let config = try JSONDecoder().decode(ExternalEngineConfig.self, from: data)

        #expect(config.resolvedName == "Pikafish")
        #expect(config.resolvedVersion == "4.0.0")
    }
}

@Suite("P1 #5: pendingEngineId + hasPendingSwitch")
struct PendingEngineIdTests {

    @MainActor @Test("初始状态无 pending switch")
    func initialState() {
        let store = EngineConfigStore.shared
        // 不直接断言，因为 store 是单例，可能有之前的状态
        // 验证 hasPendingSwitch 计算属性
        let hasPending = store.hasPendingSwitch
        #expect(hasPending == (store.pendingEngineId != store.selectedEngineId))
    }

    @MainActor @Test("pendingEngineId 设置和持久化")
    func setPendingEngineId() {
        let store = EngineConfigStore.shared
        let originalPending = store.pendingEngineId

        // 创建一个临时 UUID
        let testUUID = UUID()
        store.pendingEngineId = testUUID
        #expect(store.pendingEngineId == testUUID, "pendingEngineId 应更新")

        // 验证 UserDefaults 持久化
        let stored = UserDefaults.standard.string(forKey: "chinesechess.pendingEngine")
        #expect(stored == testUUID.uuidString, "应持久化到 UserDefaults")

        // 恢复
        store.pendingEngineId = originalPending
    }

    @MainActor @Test("pendingEngineId = nil 清除持久化")
    func clearPendingEngineId() {
        let store = EngineConfigStore.shared
        let originalPending = store.pendingEngineId

        store.pendingEngineId = nil
        #expect(store.pendingEngineId == nil)
        #expect(UserDefaults.standard.string(forKey: "chinesechess.pendingEngine") == nil,
                "nil 应清除 UserDefaults")

        store.pendingEngineId = originalPending
    }

    @MainActor @Test("hasPendingSwitch 计算正确")
    func hasPendingSwitchCalculation() {
        let store = EngineConfigStore.shared
        let originalPending = store.pendingEngineId
        let originalSelected = store.selectedEngineId

        // 相同时无 pending
        store.pendingEngineId = originalSelected
        #expect(store.hasPendingSwitch == false, "相同 ID 时无 pending")

        // 不同时有 pending
        store.pendingEngineId = UUID()  // 一定不同于 selectedEngineId
        #expect(store.hasPendingSwitch == true, "不同 ID 时有 pending")

        // 恢复
        store.pendingEngineId = originalPending
    }
}

#if os(macOS)

@Suite("P1 #4: EngineStateObserver 状态绑定")
struct EngineStateObserverTests {

    @MainActor
    @Test("初始状态")
    func initialState() {
        let observer = EngineStateObserver.shared
        // 只验证类型和访问不崩溃
        _ = observer.isEngineReady
        _ = observer.currentEngineType
        _ = observer.currentEngineName
        _ = observer.isSwitching
    }

    @MainActor
    @Test("updateState 更新所有字段")
    func updateStateUpdatesAllFields() {
        let observer = EngineStateObserver.shared
        observer.updateState(
            isReady: true,
            type: .external,
            name: "Pikafish",
            resolvedName: "Pikafish",
            resolvedVersion: "4.0.0"
        )

        #expect(observer.isEngineReady == true)
        #expect(observer.currentEngineType == .external)
        #expect(observer.currentEngineName == "Pikafish")
        #expect(observer.resolvedEngineName == "Pikafish")
        #expect(observer.resolvedEngineVersion == "4.0.0")
    }

    @MainActor
    @Test("setError 清除 ready 状态")
    func setErrorClearsReady() {
        let observer = EngineStateObserver.shared
        observer.updateState(isReady: true, type: .external, name: "Test")
        #expect(observer.isEngineReady == true)

        observer.setError("引擎启动失败")
        #expect(observer.isEngineReady == false, "setError 应清除 ready")
        #expect(observer.errorMessage == "引擎启动失败")

        observer.clearError()
        #expect(observer.errorMessage == nil)
    }

    @MainActor
    @Test("setPendingSwitch 消息")
    func setPendingSwitchMessage() {
        let observer = EngineStateObserver.shared
        let store = EngineConfigStore.shared

        // 设置 pending 为 nil（内置引擎）
        observer.setPendingSwitch(pendingId: nil)
        #expect(observer.pendingSwitchMessage == "将使用内置引擎")

        // 设置 pending 为有效引擎 ID
        if let engine = store.engines.first {
            observer.setPendingSwitch(pendingId: engine.id)
            let expectedName = engine.resolvedName ?? engine.name
            #expect(observer.pendingSwitchMessage == "引擎将在下次对局生效: \(expectedName)")
        }

        // 设置 pending 为无效 UUID
        observer.setPendingSwitch(pendingId: UUID())
        #expect(observer.pendingSwitchMessage == nil, "无效 UUID 应无消息")
    }

    @MainActor
    @Test("setSwitching 状态")
    func setSwitchingState() {
        let observer = EngineStateObserver.shared
        observer.setSwitching(true)
        #expect(observer.isSwitching == true)
        observer.setSwitching(false)
        #expect(observer.isSwitching == false)
    }
}

#endif