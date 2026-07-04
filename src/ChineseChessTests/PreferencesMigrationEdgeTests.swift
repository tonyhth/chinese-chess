//
//  PreferencesMigrationEdgeTests.swift
//  ChineseChessTests
//
//  Bundle ID 迁移边界测试（补充 Cody 的 T1-T9）
//

import Testing
import Foundation
@testable import ChineseChess

@Suite("PreferencesMigration 边界测试")
struct PreferencesMigrationEdgeTests {

    // MARK: - 辅助方法（复用 Cody 的模式）

    private func makeTempHome() -> String {
        let tempDir = NSTemporaryDirectory() + "PrefMigEdge-\(UUID().uuidString)/"
        let prefsDir = tempDir + "Library/Preferences/"
        try? FileManager.default.createDirectory(
            atPath: prefsDir, withIntermediateDirectories: true
        )
        return tempDir
    }

    private func writePlist(_ dict: [String: Any], to path: String) {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )
        (dict as NSDictionary).write(toFile: path, atomically: true)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "PrefMigEdge-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func cleanup(_ homeDir: String) {
        try? FileManager.default.removeItem(atPath: homeDir)
    }

    // MARK: - E1: 损坏的 plist 文件（非合法 plist）

    @Test("E1: 损坏的 plist 文件安全跳过，不崩溃")
    func testCorruptPlist() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        let plistPath = homeDir + "Library/Preferences/com.hth.ChineseChess.plist"
        let corruptData = "this is not a valid plist".data(using: .utf8)!
        try? corruptData.write(to: URL(fileURLWithPath: plistPath))

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        #expect(count == 0, "损坏 plist 不应迁移任何 key")
        #expect(defaults.bool(forKey: PreferencesMigration.migrationFlagKey), "标记仍应设置")
    }

    // MARK: - E2: Preferences 目录不存在

    @Test("E2: Library/Preferences 目录不存在时安全处理")
    func testNoPreferencesDir() {
        let tempDir = NSTemporaryDirectory() + "PrefMigEdge-\(UUID().uuidString)/"
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        // 不创建 Library/Preferences 目录
        let defaults = makeDefaults()

        let count = PreferencesMigration.migrate(homeDir: tempDir, defaults: defaults)

        #expect(count == 0)
        #expect(defaults.bool(forKey: PreferencesMigration.migrationFlagKey))
    }

    // MARK: - E3: 只存在 com.hongtao.ChineseChess（第二个旧 ID）

    @Test("E3: 只存在 com.hongtao.ChineseChess 时正常迁移")
    func testOnlySecondLegacyId() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        let plistPath = homeDir + "Library/Preferences/com.hongtao.ChineseChess.plist"
        writePlist([
            "chinesechess.language": "en",
            "chinesechess.difficulty": "hard",
        ], to: plistPath)

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        #expect(count == 2)
        #expect(defaults.string(forKey: "chinesechess.language") == "en")
        #expect(defaults.string(forKey: "chinesechess.difficulty") == "hard")
    }

    // MARK: - E4: key 前缀边界 — "chinesechess" 不带点

    @Test("E4: key 恰好为 'chinesechess' 不带点时不迁移")
    func testExactPrefixWithoutDot() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        let plistPath = homeDir + "Library/Preferences/com.hth.ChineseChess.plist"
        writePlist([
            "chinesechess": "should-not-migrate",   // 不带点
            "chineseschess": "typo-should-not-migrate",  // 拼错
            "chinesechess.": "edge-empty-suffix",    // 只有点
            "chinesechess.x": "valid",
        ], to: plistPath)

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        // "chinesechess." 和 "chinesechess.x" 都 hasPrefix("chinesechess.") → 迁移
        // "chinesechess" 和 "chineseschess" 不 hasPrefix("chinesechess.") → 不迁移
        #expect(count == 2, "chinesechess. 和 chinesechess.x 匹配前缀，其余不匹配")
        #expect(defaults.object(forKey: "chinesechess") == nil)
        #expect(defaults.object(forKey: "chineseschess") == nil)
        #expect(defaults.string(forKey: "chinesechess.") == "edge-empty-suffix")
        #expect(defaults.string(forKey: "chinesechess.x") == "valid")
    }

    // MARK: - E5: 大量 key 迁移（性能/正确性）

    @Test("E5: 大量 key 迁移正确")
    func testBulkMigration() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        var plistData: [String: Any] = [:]
        for i in 0..<100 {
            plistData["chinesechess.key\(i)"] = "value\(i)"
        }
        plistData["nonPrefixed"] = "ignored"

        let plistPath = homeDir + "Library/Preferences/com.hth.ChineseChess.plist"
        writePlist(plistData, to: plistPath)

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        #expect(count == 100)
        // 抽查几个
        #expect(defaults.string(forKey: "chinesechess.key0") == "value0")
        #expect(defaults.string(forKey: "chinesechess.key50") == "value50")
        #expect(defaults.string(forKey: "chinesechess.key99") == "value99")
        #expect(defaults.object(forKey: "nonPrefixed") == nil)
    }

    // MARK: - E6: 旧 plist 包含嵌套数据类型（NSDictionary/NSArray）

    @Test("E6: 嵌套数据类型正确迁移")
    func testNestedTypes() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        let plistPath = homeDir + "Library/Preferences/com.hth.ChineseChess.plist"
        writePlist([
            "chinesechess.nestedDict": ["a": 1, "b": 2] as [String: Any],
            "chinesechess.nestedArray": [1, 2, 3] as [Any],
        ], to: plistPath)

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        #expect(count == 2)
        let dict = defaults.dictionary(forKey: "chinesechess.nestedDict")
        #expect(dict?["a"] as? Int == 1)
        #expect(dict?["b"] as? Int == 2)
        let arr = defaults.array(forKey: "chinesechess.nestedArray") as? [Int]
        #expect(arr == [1, 2, 3])
    }

    // MARK: - E7: 迁移标记在旧 plist 中已存在（不提前标记）

    @Test("E7: 旧 plist 中已有 migrationDone_v1=true 不干扰新迁移")
    func testLegacyMigrationFlagIgnored() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        let plistPath = homeDir + "Library/Preferences/com.hth.ChineseChess.plist"
        writePlist([
            "chinesechess.migrationDone_v1": true,  // 旧标记，应被排除
            "chinesechess.language": "zh-Hans",
        ], to: plistPath)

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        // language 被迁移，migrationDone_v1 被排除
        #expect(count == 1)
        #expect(defaults.string(forKey: "chinesechess.language") == "zh-Hans")
        // 迁移标记由迁移逻辑设置，不是从旧 plist 继承
        #expect(defaults.bool(forKey: PreferencesMigration.migrationFlagKey))
    }

    // MARK: - E8: App 启动入口验证

    @Test("E8: migrateIfNeeded() 调用后迁移标记被设置")
    func testMigrateIfNeededSetsFlag() {
        // 这是集成测试：直接调用公开接口
        // 由于使用真实的 NSHomeDirectory，先确认标记状态
        let defaults = UserDefaults.standard
        // 如果已经迁移过（幂等），标记应该已经是 true
        // 我们只能验证调用不崩溃
        PreferencesMigration.migrateIfNeeded()
        #expect(defaults.bool(forKey: PreferencesMigration.migrationFlagKey),
               "migrateIfNeeded 调用后标记应被设置")
    }
}
