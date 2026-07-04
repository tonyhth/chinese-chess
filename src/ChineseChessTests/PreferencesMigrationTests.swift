import Testing
import Foundation
@testable import ChineseChess

// MARK: - PreferencesMigration 测试 (T1-T9)
//
// 测试策略：用临时目录模拟 homeDir，写真实 plist 文件，
// 用 UserDefaults(suiteName:) 做隔离，每次测试后清理。

@Suite("PreferencesMigration 迁移逻辑")
struct PreferencesMigrationTests {

    // MARK: - 辅助方法

    /// 创建临时目录结构，返回模拟 homeDir
    private func makeTempHome() -> String {
        let tempDir = NSTemporaryDirectory() + "PrefMigrationTest-\(UUID().uuidString)/"
        let prefsDir = tempDir + "Library/Preferences/"
        try? FileManager.default.createDirectory(
            atPath: prefsDir, withIntermediateDirectories: true
        )
        return tempDir
    }

    /// 写 plist 文件到指定路径
    private func writePlist(_ dict: [String: Any], to path: String) {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )
        (dict as NSDictionary).write(toFile: path, atomically: true)
    }

    /// 创建隔离的 UserDefaults（每次测试唯一 suiteName）
    private func makeDefaults() -> UserDefaults {
        let suiteName = "PrefMigrationTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    /// 清理临时目录
    private func cleanup(_ homeDir: String) {
        try? FileManager.default.removeItem(atPath: homeDir)
    }

    // MARK: - T1: 全新安装（无旧 plist）

    @Test("T1: 无旧 plist 时，仅设迁移标记，无实际迁移")
    func testNoLegacyPlist() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        #expect(count == 0, "无旧 plist 时不应迁移任何 key")
        #expect(defaults.bool(forKey: PreferencesMigration.migrationFlagKey), "迁移标记应设为 true")
    }

    // MARK: - T2: 有旧 plist + 当前无值 → 全部迁移

    @Test("T2: 有旧 plist + 当前无值 → 所有 chinesechess.* key 迁移")
    func testFullMigration() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        let plistPath = homeDir + "Library/Preferences/com.hth.ChineseChess.plist"
        writePlist([
            "chinesechess.language": "zh-Hans",
            "chinesechess.humanSide": "red",
            "chinesechess.tutorialCompleted": true,
            "chinesechess.stats": Data([1, 2, 3]),
        ], to: plistPath)

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        #expect(count == 4, "应迁移 4 个 key")
        #expect(defaults.string(forKey: "chinesechess.language") == "zh-Hans")
        #expect(defaults.string(forKey: "chinesechess.humanSide") == "red")
        #expect(defaults.bool(forKey: "chinesechess.tutorialCompleted") == true)
        #expect(defaults.data(forKey: "chinesechess.stats") == Data([1, 2, 3]))
        #expect(defaults.bool(forKey: PreferencesMigration.migrationFlagKey))
    }

    // MARK: - T3: 有旧 plist + 当前已有值 → 不覆盖

    @Test("T3: 当前已有值时，不被旧值覆盖")
    func testNoOverride() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        // 预设当前值
        defaults.set("en", forKey: "chinesechess.language")
        defaults.set(true, forKey: "chinesechess.tutorialCompleted")

        let plistPath = homeDir + "Library/Preferences/com.hth.ChineseChess.plist"
        writePlist([
            "chinesechess.language": "zh-Hans",
            "chinesechess.tutorialCompleted": false,
            "chinesechess.humanSide": "red",  // 当前未设置 → 应迁移
        ], to: plistPath)

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        #expect(count == 1, "只迁移当前未设置的 1 个 key")
        #expect(defaults.string(forKey: "chinesechess.language") == "en", "已有值不被覆盖")
        #expect(defaults.bool(forKey: "chinesechess.tutorialCompleted") == true, "已有值不被覆盖")
        #expect(defaults.string(forKey: "chinesechess.humanSide") == "red", "未设置的应被迁移")
    }

    // MARK: - T4: 两个旧 plist 都存在 → com.hth 优先

    @Test("T4: 两个旧 plist 都存在时，com.hth.ChineseChess 优先")
    func testMultipleLegacyPlistsPriority() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        let hthPath = homeDir + "Library/Preferences/com.hth.ChineseChess.plist"
        writePlist(["chinesechess.language": "zh-Hans"], to: hthPath)

        let hongtaoPath = homeDir + "Library/Preferences/com.hongtao.ChineseChess.plist"
        writePlist(["chinesechess.language": "en"], to: hongtaoPath)

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        #expect(count == 1, "com.hth 先迁移，com.hongtao 的同 key 被跳过")
        #expect(defaults.string(forKey: "chinesechess.language") == "zh-Hans", "应取 com.hth 的值")
    }

    // MARK: - T5: 二次启动 → 跳过迁移（幂等）

    @Test("T5: 二次调用迁移时跳过（幂等）")
    func testIdempotent() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        let plistPath = homeDir + "Library/Preferences/com.hth.ChineseChess.plist"
        writePlist(["chinesechess.language": "zh-Hans"], to: plistPath)

        // 第一次迁移
        let firstCount = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)
        #expect(firstCount == 1)

        // 第二次迁移
        let secondCount = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)
        #expect(secondCount == 0, "二次调用应跳过")
    }

    // MARK: - T6: 旧 plist 为空文件 → 安全跳过

    @Test("T6: 旧 plist 为空字典时安全跳过")
    func testEmptyPlist() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        let plistPath = homeDir + "Library/Preferences/com.hth.ChineseChess.plist"
        writePlist([:], to: plistPath)

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        #expect(count == 0, "空 plist 不应迁移任何 key")
        #expect(defaults.bool(forKey: PreferencesMigration.migrationFlagKey))
    }

    // MARK: - T7: 旧 plist 中 key 类型不匹配 → 安全跳过该 key

    @Test("T7: 类型不匹配的 key 仍被迁移（UserDefaults 接受 Any）")
    func testTypeMismatch() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        let plistPath = homeDir + "Library/Preferences/com.hth.ChineseChess.plist"
        // plist 中可以存任意可序列化类型
        writePlist([
            "chinesechess.language": "zh-Hans",
            "chinesechess.someArray": ["a", "b", "c"],
            "chinesechess.someNumber": 42,
        ], to: plistPath)

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        #expect(count == 3, "所有 chinesechess.* key 都应迁移")
        #expect(defaults.string(forKey: "chinesechess.language") == "zh-Hans")
        #expect(defaults.array(forKey: "chinesechess.someArray") as? [String] == ["a", "b", "c"])
        #expect(defaults.integer(forKey: "chinesechess.someNumber") == 42)
    }

    // MARK: - T8: 非 chinesechess.* 前缀的 key 不迁移

    @Test("T8: 非 chinesechess.* 前缀的 key 不迁移")
    func testNonPrefixedKeysNotMigrated() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        let plistPath = homeDir + "Library/Preferences/com.hth.ChineseChess.plist"
        writePlist([
            "chinesechess.language": "zh-Hans",
            "NSWindow Frame MainWindow": "0 0 800 600 0 0 1920 1080",
            "com.apple.ApplePreferencesKey": true,
            "someOtherKey": "value",
        ], to: plistPath)

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        #expect(count == 1, "只迁移 chinesechess.* 前缀的 key")
        #expect(defaults.string(forKey: "chinesechess.language") == "zh-Hans")
        #expect(defaults.object(forKey: "NSWindow Frame MainWindow") == nil)
        #expect(defaults.object(forKey: "com.apple.ApplePreferencesKey") == nil)
        #expect(defaults.object(forKey: "someOtherKey") == nil)
    }

    // MARK: - T9: migrationDone_v1 自身被排除

    @Test("T9: chinesechess.migrationDone_v1 被排除，不参与迁移")
    func testMigrationFlagExcluded() {
        let homeDir = makeTempHome()
        let defaults = makeDefaults()
        defer { cleanup(homeDir) }

        let plistPath = homeDir + "Library/Preferences/com.hth.ChineseChess.plist"
        writePlist([
            "chinesechess.language": "zh-Hans",
            "chinesechess.migrationDone_v1": true,  // 应被排除
        ], to: plistPath)

        let count = PreferencesMigration.migrate(homeDir: homeDir, defaults: defaults)

        // 只有 language 被迁移，migrationDone_v1 被排除
        // 迁移后 defaults 会设置 migrationDone_v1 = true（标记），但那不是迁移来的
        #expect(count == 1, "migrationDone_v1 不应计入迁移")
        #expect(defaults.string(forKey: "chinesechess.language") == "zh-Hans")
        #expect(defaults.bool(forKey: PreferencesMigration.migrationFlagKey), "标记由迁移逻辑设置，不是从旧 plist 迁移来的")
    }
}
