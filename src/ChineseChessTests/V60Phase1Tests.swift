import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.0 Phase 1 测试：AIDifficulty 枚举完整性 + 存档兼容 + StatsManager 迁移

@Suite("v6.0 Phase 1: AIDifficulty 枚举完整性", .serialized)
struct AIDifficultyEnumTests {

    // ============================
    // MARK: - 维度 1：枚举完整性
    // ============================

    @Test("allCases 包含 10 个 case")
    func allCasesCount() {
        #expect(AIDifficulty.allCases.count == 10)
    }

    @Test("rawValue 输出 lvl1-lvl10")
    func rawValuesAreLvl1ToLvl10() {
        #expect(AIDifficulty.novice.rawValue == "lvl1")
        #expect(AIDifficulty.beginner.rawValue == "lvl2")
        #expect(AIDifficulty.amateurLow.rawValue == "lvl3")
        #expect(AIDifficulty.amateurMid.rawValue == "lvl4")
        #expect(AIDifficulty.amateurHigh.rawValue == "lvl5")
        #expect(AIDifficulty.amateurDan.rawValue == "lvl6")
        #expect(AIDifficulty.proApprentice.rawValue == "lvl7")
        #expect(AIDifficulty.proExpert.rawValue == "lvl8")
        #expect(AIDifficulty.proMaster.rawValue == "lvl9")
        #expect(AIDifficulty.grandmaster.rawValue == "lvl10")
    }

    @Test("rawValue 唯一性")
    func rawValuesAreUnique() {
        let rawValues = AIDifficulty.allCases.map { $0.rawValue }
        #expect(Set(rawValues).count == 10)
    }

    @Test("isProfessional：业余级返回 false")
    func isProfessionalAmateur() {
        #expect(AIDifficulty.novice.isProfessional == false)
        #expect(AIDifficulty.beginner.isProfessional == false)
        #expect(AIDifficulty.amateurLow.isProfessional == false)
        #expect(AIDifficulty.amateurMid.isProfessional == false)
        #expect(AIDifficulty.amateurHigh.isProfessional == false)
    }

    @Test("isProfessional：专业级返回 true")
    func isProfessionalPro() {
        #expect(AIDifficulty.amateurDan.isProfessional == true)
        #expect(AIDifficulty.proApprentice.isProfessional == true)
        #expect(AIDifficulty.proExpert.isProfessional == true)
        #expect(AIDifficulty.proMaster.isProfessional == true)
        #expect(AIDifficulty.grandmaster.isProfessional == true)
    }

    @Test("业余级和专业级互斥且覆盖全部 10 级")
    func professionalAmateurPartition() {
        let amateurs = AIDifficulty.allCases.filter { !$0.isProfessional }
        let pros = AIDifficulty.allCases.filter { $0.isProfessional }
        #expect(amateurs.count == 5)
        #expect(pros.count == 5)
    }

    @Test("skillLevel：业余级返回 nil")
    func skillLevelAmateurNil() {
        #expect(AIDifficulty.novice.skillLevel == nil)
        #expect(AIDifficulty.beginner.skillLevel == nil)
        #expect(AIDifficulty.amateurLow.skillLevel == nil)
        #expect(AIDifficulty.amateurMid.skillLevel == nil)
        #expect(AIDifficulty.amateurHigh.skillLevel == nil)
    }

    @Test("skillLevel：专业级返回正确值")
    func skillLevelProValues() {
        #expect(AIDifficulty.amateurDan.skillLevel == 0)     // v4.2 重映射
        #expect(AIDifficulty.proApprentice.skillLevel == 4) // v4.2 重映射
        #expect(AIDifficulty.proExpert.skillLevel == 7)    // v4.2 重映射
        #expect(AIDifficulty.proMaster.skillLevel == 10)   // v4.2 重映射
        #expect(AIDifficulty.grandmaster.skillLevel == 20)
    }

    @Test("fallbackToAmateur：所有专业级返回 .amateurHigh")
    func fallbackToAmateur() {
        #expect(AIDifficulty.amateurDan.fallbackToAmateur == .amateurHigh)
        #expect(AIDifficulty.proApprentice.fallbackToAmateur == .amateurHigh)
        #expect(AIDifficulty.proExpert.fallbackToAmateur == .amateurHigh)
        #expect(AIDifficulty.proMaster.fallbackToAmateur == .amateurHigh)
        #expect(AIDifficulty.grandmaster.fallbackToAmateur == .amateurHigh)
    }

    @Test("displayName：10 个中文名正确 (v2.1)")
    func displayNames() {
        #expect(AIDifficulty.novice.displayName == "入门")
        #expect(AIDifficulty.beginner.displayName == "初级")
        #expect(AIDifficulty.amateurLow.displayName == "中级")
        #expect(AIDifficulty.amateurMid.displayName == "高级")
        #expect(AIDifficulty.amateurHigh.displayName == "精通")
        #expect(AIDifficulty.amateurDan.displayName == "棋友")
        #expect(AIDifficulty.proApprentice.displayName == "棋手")
        #expect(AIDifficulty.proExpert.displayName == "棋师")
        #expect(AIDifficulty.proMaster.displayName == "大师")
        #expect(AIDifficulty.grandmaster.displayName == "棋圣")
    }

    @Test("order：0-9 递增")
    func orderSequential() {
        let orders = AIDifficulty.allCases.map { $0.order }
        #expect(orders == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    }

    @Test("init(rawValue:)：新 rawValue 正确映射")
    func initFromNewRawValues() {
        #expect(AIDifficulty(rawValue: "lvl1") == .novice)
        #expect(AIDifficulty(rawValue: "lvl10") == .grandmaster)
        #expect(AIDifficulty(rawValue: "lvl5") == .amateurHigh)
    }

    @Test("init(rawValue:)：未知值返回 nil")
    func initFromUnknownRawValue() {
        #expect(AIDifficulty(rawValue: "unknown") == nil)
        #expect(AIDifficulty(rawValue: "") == nil)
    }
}

// MARK: - 维度 2：存档兼容迁移

@Suite("v6.0 Phase 1: 存档兼容迁移", .serialized)
struct SaveMigrationTests {

    // ============================
    // MARK: - 旧 rawValue 兼容映射（v4.2 legacyMap）
    // ============================

    @Test("旧 beginner → .novice（1级），不是 .beginner（2级）")
    func legacyBeginner() throws {
        let json = "\"beginner\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AIDifficulty.self, from: json)
        #expect(decoded == .novice)
    }

    @Test("旧 easy → .beginner（2级）")
    func legacyEasy() throws {
        let json = "\"easy\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AIDifficulty.self, from: json)
        #expect(decoded == .beginner)
    }

    @Test("旧 medium → .amateurLow（3级）")
    func legacyMedium() throws {
        let json = "\"medium\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AIDifficulty.self, from: json)
        #expect(decoded == .amateurLow)
    }

    @Test("旧 hard → .amateurMid（4级）")
    func legacyHard() throws {
        let json = "\"hard\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AIDifficulty.self, from: json)
        #expect(decoded == .amateurMid)
    }

    @Test("旧 master → .amateurHigh（5级），不升到 amateurDan")
    func legacyMaster() throws {
        let json = "\"master\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AIDifficulty.self, from: json)
        #expect(decoded == .amateurHigh)
    }

    // ============================
    // MARK: - 未知值 fallback
    // ============================

    @Test("未知 rawValue → fallback .amateurMid")
    func unknownRawValueFallback() throws {
        let json = "\"unknown\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AIDifficulty.self, from: json)
        #expect(decoded == .amateurMid)
    }

    @Test("空字符串 → fallback .amateurMid")
    func emptyStringFallback() throws {
        let json = "\"\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AIDifficulty.self, from: json)
        #expect(decoded == .amateurMid)
    }

    @Test("大小写敏感：Beginner 不等于 beginner → fallback")
    func caseSensitive() throws {
        let json = "\"Beginner\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AIDifficulty.self, from: json)
        #expect(decoded == .amateurMid)
    }

    // ============================
    // MARK: - 新 rawValue 正常加载
    // ============================

    @Test("新 rawValue lvl1-lvl10 正常解码")
    func newRawValuesDecode() throws {
        let pairs: [(String, AIDifficulty)] = [
            ("lvl1", .novice), ("lvl2", .beginner), ("lvl3", .amateurLow),
            ("lvl4", .amateurMid), ("lvl5", .amateurHigh), ("lvl6", .amateurDan),
            ("lvl7", .proApprentice), ("lvl8", .proExpert), ("lvl9", .proMaster),
            ("lvl10", .grandmaster)
        ]
        for (raw, expected) in pairs {
            let json = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try JSONDecoder().decode(AIDifficulty.self, from: json)
            #expect(decoded == expected, "Failed for rawValue \(raw)")
        }
    }

    // ============================
    // MARK: - 编解码 round-trip
    // ============================

    @Test("编码后再解码 round-trip 一致")
    func encodingRoundTrip() throws {
        for difficulty in AIDifficulty.allCases {
            let encoded = try JSONEncoder().encode(difficulty)
            let decoded = try JSONDecoder().decode(AIDifficulty.self, from: encoded)
            #expect(decoded == difficulty, "Round-trip failed for \(difficulty)")
        }
    }

    @Test("编码输出 rawValue（lvl1-lvl10 格式）")
    func encodingOutputsNewFormat() throws {
        for difficulty in AIDifficulty.allCases {
            let encoded = try JSONEncoder().encode(difficulty)
            let str = String(data: encoded, encoding: .utf8)!
            // 应编码为 "lvlX" 格式，不是旧 case 名
            #expect(str.contains("lvl"))
            #expect(!str.contains("beginner") || difficulty == .beginner) // .beginner 的 rawValue 是 "lvl2"
        }
    }

    // ============================
    // MARK: - 混合存档场景
    // ============================

    @Test("混合存档：beginner + proExpert 分别正确映射")
    func mixedArchive() throws {
        struct TestRecord: Codable {
            let difficulty: AIDifficulty
        }

        let oldJson = """
        {"difficulty": "beginner"}
        """.data(using: .utf8)!
        let newJson = """
        {"difficulty": "lvl8"}
        """.data(using: .utf8)!

        let oldRecord = try JSONDecoder().decode(TestRecord.self, from: oldJson)
        let newRecord = try JSONDecoder().decode(TestRecord.self, from: newJson)

        #expect(oldRecord.difficulty == .novice)      // 旧 beginner → 1 级
        #expect(newRecord.difficulty == .proExpert)   // lvl8 → 8 级
    }
}

// MARK: - 维度 3：StatsManager 迁移

@Suite("v6.0 Phase 1: StatsManager 迁移", .serialized)
struct StatsMigrationTests {

    /// 辅助：创建隔离的 UserDefaults suite
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test.stats.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test("旧 beginner 统计迁移到 lvl1（novice）")
    func migrateBeginnerToLvl1() {
        let defaults = makeDefaults()
        // 注入旧数据
        var stats = GameStats()
        stats.vsAI["beginner"] = WinLossDraw(wins: 3, losses: 2, draws: 1)
        let data = try! JSONEncoder().encode(stats)
        defaults.set(data, forKey: "chinesechess.stats")

        let manager = StatsManager(defaults: defaults)
        let migrated = manager.stats

        #expect(migrated.vsAI["lvl1"]?.wins == 3)
        #expect(migrated.vsAI["lvl1"]?.losses == 2)
        #expect(migrated.vsAI["lvl1"]?.draws == 1)
        #expect(migrated.vsAI["beginner"] == nil)
    }

    @Test("旧 easy 统计迁移到 lvl2（beginner）")
    func migrateEasyToLvl2() {
        let defaults = makeDefaults()
        var stats = GameStats()
        stats.vsAI["easy"] = WinLossDraw(wins: 5, losses: 1, draws: 0)
        let data = try! JSONEncoder().encode(stats)
        defaults.set(data, forKey: "chinesechess.stats")

        let manager = StatsManager(defaults: defaults)
        let migrated = manager.stats

        #expect(migrated.vsAI["lvl2"]?.wins == 5)
        #expect(migrated.vsAI["easy"] == nil)
    }

    @Test("旧 medium 统计迁移到 lvl3（amateurLow）")
    func migrateMediumToLvl3() {
        let defaults = makeDefaults()
        var stats = GameStats()
        stats.vsAI["medium"] = WinLossDraw(wins: 2, losses: 4, draws: 3)
        let data = try! JSONEncoder().encode(stats)
        defaults.set(data, forKey: "chinesechess.stats")

        let manager = StatsManager(defaults: defaults)
        let migrated = manager.stats

        #expect(migrated.vsAI["lvl3"]?.draws == 3)
        #expect(migrated.vsAI["medium"] == nil)
    }

    @Test("旧 hard 统计迁移到 lvl4（amateurMid）")
    func migrateHardToLvl4() {
        let defaults = makeDefaults()
        var stats = GameStats()
        stats.vsAI["hard"] = WinLossDraw(wins: 1, losses: 5, draws: 2)
        let data = try! JSONEncoder().encode(stats)
        defaults.set(data, forKey: "chinesechess.stats")

        let manager = StatsManager(defaults: defaults)
        let migrated = manager.stats

        #expect(migrated.vsAI["lvl4"]?.losses == 5)
        #expect(migrated.vsAI["hard"] == nil)
    }

    @Test("旧 master 统计迁移到 lvl5（amateurHigh），不与 hard 合并")
    func migrateMasterToLvl5() {
        let defaults = makeDefaults()
        var stats = GameStats()
        stats.vsAI["hard"] = WinLossDraw(wins: 1, losses: 1, draws: 1)
        stats.vsAI["master"] = WinLossDraw(wins: 2, losses: 2, draws: 2)
        let data = try! JSONEncoder().encode(stats)
        defaults.set(data, forKey: "chinesechess.stats")

        let manager = StatsManager(defaults: defaults)
        let migrated = manager.stats

        // hard → lvl4，master → lvl5，分别迁移
        #expect(migrated.vsAI["lvl4"]?.wins == 1)   // hard → lvl4
        #expect(migrated.vsAI["lvl5"]?.wins == 2)   // master → lvl5
        #expect(migrated.vsAI["lvl5"]?.losses == 2)
        #expect(migrated.vsAI["lvl5"]?.draws == 2)
        #expect(migrated.vsAI["hard"] == nil)
        #expect(migrated.vsAI["master"] == nil)
    }

    @Test("迁移后旧 key 被删除")
    func oldKeysRemoved() {
        let defaults = makeDefaults()
        var stats = GameStats()
        stats.vsAI["beginner"] = WinLossDraw(wins: 1, losses: 0, draws: 0)
        stats.vsAI["easy"] = WinLossDraw(wins: 0, losses: 1, draws: 0)
        stats.vsAI["medium"] = WinLossDraw(wins: 0, losses: 0, draws: 1)
        stats.vsAI["hard"] = WinLossDraw(wins: 1, losses: 1, draws: 0)
        stats.vsAI["master"] = WinLossDraw(wins: 0, losses: 0, draws: 1)
        let data = try! JSONEncoder().encode(stats)
        defaults.set(data, forKey: "chinesechess.stats")

        let manager = StatsManager(defaults: defaults)
        let migrated = manager.stats

        #expect(migrated.vsAI["beginner"] == nil)
        #expect(migrated.vsAI["easy"] == nil)
        #expect(migrated.vsAI["medium"] == nil)
        #expect(migrated.vsAI["hard"] == nil)
        #expect(migrated.vsAI["master"] == nil)
    }

    @Test("新 key 已有数据时累加（不覆盖）")
    func accumulateWithExisting() {
        let defaults = makeDefaults()
        var stats = GameStats()
        stats.vsAI["beginner"] = WinLossDraw(wins: 3, losses: 0, draws: 0)
        stats.vsAI["lvl1"] = WinLossDraw(wins: 2, losses: 1, draws: 0)
        let data = try! JSONEncoder().encode(stats)
        defaults.set(data, forKey: "chinesechess.stats")

        let manager = StatsManager(defaults: defaults)
        let migrated = manager.stats

        // 旧 beginner (3W) + 已有 lvl1 (2W 1L) = 5W 1L
        #expect(migrated.vsAI["lvl1"]?.wins == 5)
        #expect(migrated.vsAI["lvl1"]?.losses == 1)
        #expect(migrated.vsAI["beginner"] == nil)
    }

    @Test("无旧 key 时正常执行（no-op）")
    func noOpWhenNoLegacyKeys() {
        let defaults = makeDefaults()
        var stats = GameStats()
        stats.vsAI["lvl1"] = WinLossDraw(wins: 1, losses: 0, draws: 0)
        let data = try! JSONEncoder().encode(stats)
        defaults.set(data, forKey: "chinesechess.stats")

        let manager = StatsManager(defaults: defaults)
        let migrated = manager.stats

        #expect(migrated.vsAI["lvl1"]?.wins == 1)
        #expect(migrated.vsAI.count == 1)
    }

    @Test("重复迁移幂等（第二次不再迁移）")
    func idempotentMigration() {
        let defaults = makeDefaults()
        var stats = GameStats()
        stats.vsAI["beginner"] = WinLossDraw(wins: 3, losses: 0, draws: 0)
        let data = try! JSONEncoder().encode(stats)
        defaults.set(data, forKey: "chinesechess.stats")

        // 第一次迁移
        let manager1 = StatsManager(defaults: defaults)
        let after1 = manager1.stats
        #expect(after1.vsAI["lvl1"]?.wins == 3)
        #expect(after1.vsAI["beginner"] == nil)

        // 第二次创建实例（应不重复迁移）
        let manager2 = StatsManager(defaults: defaults)
        let after2 = manager2.stats
        #expect(after2.vsAI["lvl1"]?.wins == 3)  // 不变
        #expect(after2.vsAI["beginner"] == nil)   // 仍为 nil
    }

    @Test("新数据写入使用 lvl 格式 key")
    func newRecordUsesLvlKey() {
        let defaults = makeDefaults()
        let manager = StatsManager(defaults: defaults)

        manager.recordWin(for: .novice)
        manager.recordLoss(for: .grandmaster)
        manager.recordDraw(for: .amateurMid)

        let stats = manager.stats
        #expect(stats.vsAI["lvl1"]?.wins == 1)
        #expect(stats.vsAI["lvl10"]?.losses == 1)
        #expect(stats.vsAI["lvl4"]?.draws == 1)
    }
}
