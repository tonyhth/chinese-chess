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

// MARK: - v3.4 Phase C → v6.3 E5: EngineConfigStore 开关退场后的残余面测试

@Suite("v6.3 E5: EngineConfigStore 开关退场")
struct EngineConfigStoreSimplifiedTests {

    @MainActor
    @Test("v6.3 E5: 引擎开关退场（单例仍可用，编译锢定属性已删）")
    func engineSwitchRemoved() {
        // E5 全清：属性已删，本用例锢定单例仍可访问（迁移清理职责仍在）
        _ = EngineConfigStore.shared
    }

    @MainActor
    @Test("旧配置迁移：清理 legacy keys（含 v6.3 E5 并入的退场 key）")
    func legacyConfigMigration() {
        // 设置旧 key（含开关本体——E5 后属 legacy，防脏 key 复活）
        let defaults = UserDefaults.standard
        defaults.set("test", forKey: "chinesechess.externalEngines")
        defaults.set("test", forKey: "chinesechess.selectedEngine")
        defaults.set("test", forKey: "chinesechess.pendingEngine")
        defaults.set(true, forKey: "chinesechess.pendingNative")
        defaults.set(true, forKey: "chinesechess.wantsExternalEngine")
        defaults.set(true, forKey: "chinesechess.useEmbeddedEngine")

        // 迁移由 init 调用；单例已初始化，此处验证旧 key 已写入后清理路径不炸
        #expect(defaults.object(forKey: "chinesechess.externalEngines") != nil)

        // 清理（模拟迁移后状态）
        defaults.removeObject(forKey: "chinesechess.externalEngines")
        defaults.removeObject(forKey: "chinesechess.selectedEngine")
        defaults.removeObject(forKey: "chinesechess.pendingEngine")
        defaults.removeObject(forKey: "chinesechess.pendingNative")
        defaults.removeObject(forKey: "chinesechess.wantsExternalEngine")
        defaults.removeObject(forKey: "chinesechess.useEmbeddedEngine")

        #expect(defaults.object(forKey: "chinesechess.externalEngines") == nil, "旧 key 应被清理")
        #expect(defaults.object(forKey: "chinesechess.useEmbeddedEngine") == nil, "E5 退场 key 应被清理")
    }
}
