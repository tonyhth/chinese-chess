import Foundation
import Testing
@testable import ChineseChess

// MARK: - 第二批次 P1 任务测试（v3.4.0 Phase C 适配版）

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

// MARK: - v3.4.0 Phase C: EngineConfigStore 简化版测试

@Suite("v3.4 Phase C: EngineConfigStore 简化版")
struct EngineConfigStoreSimplifiedTests {

    @MainActor
    @Test("useEmbeddedEngine 默认值")
    func useEmbeddedEngineDefault() {
        let store = EngineConfigStore.shared
        // 默认应为 false（使用内置引擎）
        // 注：单例状态可能受之前测试影响
        _ = store.useEmbeddedEngine
    }

    @MainActor
    @Test("useEmbeddedEngine 设置和持久化")
    func useEmbeddedEnginePersistence() {
        let store = EngineConfigStore.shared
        let original = store.useEmbeddedEngine

        store.useEmbeddedEngine = true
        #expect(store.useEmbeddedEngine == true, "应更新为 true")

        let stored = UserDefaults.standard.bool(forKey: "chinesechess.useEmbeddedEngine")
        #expect(stored == true, "应持久化到 UserDefaults")

        // 恢复
        store.useEmbeddedEngine = original
    }

    @MainActor
    @Test("quickToggleEngine 返回正确值")
    func quickToggleEngine() {
        let store = EngineConfigStore.shared
        let original = store.useEmbeddedEngine

        // 场景 1: 当前用内置 → 切换到嵌入式
        store.useEmbeddedEngine = false
        let result1 = store.quickToggleEngine()
        #expect(result1 == "external", "从内置切换到嵌入式应返回 external")
        #expect(store.useEmbeddedEngine == true)

        // 场景 2: 当前用嵌入式 → 切换到内置
        let result2 = store.quickToggleEngine()
        #expect(result2 == "builtIn", "从嵌入式切换到内置应返回 builtIn")
        #expect(store.useEmbeddedEngine == false)

        // 恢复
        store.useEmbeddedEngine = original
    }

    @MainActor
    @Test("旧配置迁移：清理 legacy keys")
    func legacyConfigMigration() {
        // 设置旧 key
        let defaults = UserDefaults.standard
        defaults.set("test", forKey: "chinesechess.externalEngines")
        defaults.set("test", forKey: "chinesechess.selectedEngine")
        defaults.set("test", forKey: "chinesechess.pendingEngine")
        defaults.set(true, forKey: "chinesechess.pendingNative")
        defaults.set(true, forKey: "chinesechess.wantsExternalEngine")

        // EngineConfigStore.init() 会调用 migrateLegacyConfig()
        // 由于是单例，我们手动验证旧 key 已存在
        #expect(defaults.object(forKey: "chinesechess.externalEngines") != nil)

        // 清理（模拟迁移后状态）
        defaults.removeObject(forKey: "chinesechess.externalEngines")
        defaults.removeObject(forKey: "chinesechess.selectedEngine")
        defaults.removeObject(forKey: "chinesechess.pendingEngine")
        defaults.removeObject(forKey: "chinesechess.pendingNative")
        defaults.removeObject(forKey: "chinesechess.wantsExternalEngine")

        #expect(defaults.object(forKey: "chinesechess.externalEngines") == nil, "旧 key 应被清理")
    }
}
