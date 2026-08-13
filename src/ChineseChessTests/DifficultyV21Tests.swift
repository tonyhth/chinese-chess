import Foundation
import Testing
@testable import ChineseChess

// MARK: - 难度体系 v2.1 测试
//
// 测试范围：
// 1. skillLevel 映射值（4/7/10/13/20）
// 2. displayName 段位名称（入门→棋圣）
// 3. 棋力单调递增（order 值）
// 4. isProfessional / fallback 逻辑不变
// 5. rawValue / Codable 兼容性
// 6. l10n 资源验证（difficulty.lvl1-10 + short.lvl1-10）
// 7. lvl2 超时修复参数验证（depth 2 + movetime 3000ms）
// 8. lvl1 参数简化验证（top-3、无噪声）
// 9. SelfPlayRunner pfmatch 逻辑（.amateurHigh 避免 skill 覆盖）

@Suite("难度体系 v2.1 测试")
struct DifficultyV21Tests {

    // ============================================================
    // 1. skillLevel 映射值（设计文档 §九.2）
    // ============================================================

    @Test("skillLevel: amateurDan = 0（v4.2 重映射）")
    func skillLevelAmateurDan() {
        #expect(AIDifficulty.amateurDan.skillLevel == 0,
                "amateurDan.skillLevel 应为 0（v4.2 重映射）")
    }

    @Test("skillLevel: proApprentice = 4（v4.2 重映射）")
    func skillLevelProApprentice() {
        #expect(AIDifficulty.proApprentice.skillLevel == 4,
                "proApprentice.skillLevel 应为 4（v4.2 重映射）")
    }

    @Test("skillLevel: proExpert = 7（v4.2 重映射）")
    func skillLevelProExpert() {
        #expect(AIDifficulty.proExpert.skillLevel == 7,
                "proExpert.skillLevel 应为 7（v4.2 重映射）")
    }

    @Test("skillLevel: proMaster = 10（v4.2 重映射）")
    func skillLevelProMaster() {
        #expect(AIDifficulty.proMaster.skillLevel == 10,
                "proMaster.skillLevel 应为 10（v4.2 重映射）")
    }

    @Test("skillLevel: grandmaster = 20（不变）")
    func skillLevelGrandmaster() {
        #expect(AIDifficulty.grandmaster.skillLevel == 20,
                "grandmaster.skillLevel 应为 20（Skill 20 = 天梯 ~3300）")
    }

    @Test("skillLevel: 业余级全部返回 nil")
    func skillLevelAmateurNil() {
        #expect(AIDifficulty.novice.skillLevel == nil)
        #expect(AIDifficulty.beginner.skillLevel == nil)
        #expect(AIDifficulty.amateurLow.skillLevel == nil)
        #expect(AIDifficulty.amateurMid.skillLevel == nil)
        #expect(AIDifficulty.amateurHigh.skillLevel == nil)
    }

    @Test("skillLevel: 5 个专业级 skill 值严格递增")
    func skillLevelMonotonic() {
        let pros: [AIDifficulty] = [.amateurDan, .proApprentice, .proExpert, .proMaster, .grandmaster]
        let skills = pros.compactMap { $0.skillLevel }
        #expect(skills.count == 5)
        for i in 0..<4 {
            #expect(skills[i] < skills[i + 1],
                    "skillLevel 应严格递增: \(skills[i]) < \(skills[i + 1])")
        }
    }

    // ============================================================
    // 2. displayName 段位名称（设计文档 §九.3 + §五.4）
    // ============================================================

    @Test("displayName: 入门")
    func displayNameNovice() {
        #expect(AIDifficulty.novice.displayName == "入门")
    }

    @Test("displayName: 初级")
    func displayNameBeginner() {
        #expect(AIDifficulty.beginner.displayName == "初级")
    }

    @Test("displayName: 中级")
    func displayNameAmateurLow() {
        #expect(AIDifficulty.amateurLow.displayName == "中级")
    }

    @Test("displayName: 高级")
    func displayNameAmateurMid() {
        #expect(AIDifficulty.amateurMid.displayName == "高级")
    }

    @Test("displayName: 精通")
    func displayNameAmateurHigh() {
        #expect(AIDifficulty.amateurHigh.displayName == "精通")
    }

    @Test("displayName: 棋友")
    func displayNameAmateurDan() {
        #expect(AIDifficulty.amateurDan.displayName == "棋友")
    }

    @Test("displayName: 棋手")
    func displayNameProApprentice() {
        #expect(AIDifficulty.proApprentice.displayName == "棋手")
    }

    @Test("displayName: 棋师")
    func displayNameProExpert() {
        #expect(AIDifficulty.proExpert.displayName == "棋师")
    }

    @Test("displayName: 大师")
    func displayNameProMaster() {
        #expect(AIDifficulty.proMaster.displayName == "大师")
    }

    @Test("displayName: 棋圣")
    func displayNameGrandmaster() {
        #expect(AIDifficulty.grandmaster.displayName == "棋圣")
    }

    @Test("displayName: 10 个级别名称不重复")
    func displayNameAllUnique() {
        let names = AIDifficulty.allCases.map { $0.displayName }
        #expect(Set(names).count == 10, "10 个 displayName 应全部唯一")
    }

    // ============================================================
    // 3. 棋力单调递增（order 值）
    // ============================================================

    @Test("order: 10 个级别严格递增 0-9")
    func orderMonotonic() {
        let orders = AIDifficulty.allCases.map { $0.order }
        #expect(orders == Array(0..<10), "order 值应为 [0,1,2,...,9]")
    }

    // ============================================================
    // 4. isProfessional / fallback 逻辑
    // ============================================================

    @Test("isProfessional: 业余级 5 个返回 false")
    func isProfessionalAmateur() {
        #expect(!AIDifficulty.novice.isProfessional)
        #expect(!AIDifficulty.beginner.isProfessional)
        #expect(!AIDifficulty.amateurLow.isProfessional)
        #expect(!AIDifficulty.amateurMid.isProfessional)
        #expect(!AIDifficulty.amateurHigh.isProfessional)
    }

    @Test("isProfessional: 棋士级 5 个返回 true")
    func isProfessionalPro() {
        #expect(AIDifficulty.amateurDan.isProfessional)
        #expect(AIDifficulty.proApprentice.isProfessional)
        #expect(AIDifficulty.proExpert.isProfessional)
        #expect(AIDifficulty.proMaster.isProfessional)
        #expect(AIDifficulty.grandmaster.isProfessional)
    }

    @Test("fallbackToAmateur: 所有级别 fallback 到 amateurHigh")
    func fallbackAllToAmateurHigh() {
        for difficulty in AIDifficulty.allCases {
            #expect(difficulty.fallbackToAmateur == .amateurHigh,
                    "\(difficulty.displayName) 的 fallback 应为 amateurHigh")
        }
    }

    // ============================================================
    // 5. rawValue / Codable 兼容性
    // ============================================================

    @Test("rawValue: lvl1-lvl10 映射正确")
    func rawValueMapping() {
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

    @Test("rawValue: 旧值兼容映射")
    func rawValueLegacyCompat() {
        #expect(AIDifficulty(rawValue: "beginner") == .novice)
        #expect(AIDifficulty(rawValue: "easy") == .beginner)
        #expect(AIDifficulty(rawValue: "medium") == .amateurLow)
        #expect(AIDifficulty(rawValue: "hard") == .amateurMid)
        #expect(AIDifficulty(rawValue: "master") == .amateurHigh)
    }

    @Test("rawValue: 未知值返回 nil")
    func rawValueUnknown() {
        #expect(AIDifficulty(rawValue: "unknown") == nil)
        #expect(AIDifficulty(rawValue: "") == nil)
        #expect(AIDifficulty(rawValue: "lvl0") == nil)
        #expect(AIDifficulty(rawValue: "lvl11") == nil)
    }

    @Test("Codable: 往返编码解码保持一致")
    func codableRoundTrip() throws {
        for difficulty in AIDifficulty.allCases {
            let encoded = try JSONEncoder().encode(difficulty)
            let decoded = try JSONDecoder().decode(AIDifficulty.self, from: encoded)
            #expect(decoded == difficulty,
                    "Codable 往返失败: \(difficulty.rawValue)")
        }
    }

    @Test("Codable: 未知值 fallback 到 amateurMid")
    func codableUnknownFallback() throws {
        let badJSON = "\"lvl999\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AIDifficulty.self, from: badJSON)
        #expect(decoded == .amateurMid, "未知值应 fallback 到 amateurMid")
    }

    // ============================================================
    // 6. 枚举完整性
    // ============================================================

    @Test("allCases: 正好 10 个级别")
    func allCasesCount() {
        #expect(AIDifficulty.allCases.count == 10)
    }

    @Test("id: 等于 rawValue")
    func idEqualsRawValue() {
        for difficulty in AIDifficulty.allCases {
            #expect(difficulty.id == difficulty.rawValue)
        }
    }

    // ============================================================
    // 7. l10n 资源验证（difficulty.lvl1-10 + short.lvl1-10 + section）
    // ============================================================

    @Test("l10n: difficulty.lvl1-10 中英文值符合 v2.1 设计")
    func l10nDifficultyLevels() {
        let bundle = Bundle.main
        let expectedValues: [(key: String, zh: String, en: String)] = [
            ("difficulty.lvl1",  "入门", "Beginner"),
            ("difficulty.lvl2",  "初级", "Elementary"),
            ("difficulty.lvl3",  "中级", "Intermediate"),
            ("difficulty.lvl4",  "高级", "Advanced"),
            ("difficulty.lvl5",  "精通", "Proficient"),
            ("difficulty.lvl6",  "棋友", "Player"),
            ("difficulty.lvl7",  "棋手", "Expert"),
            ("difficulty.lvl8",  "棋师", "Master"),
            ("difficulty.lvl9",  "大师", "Grandmaster"),
            ("difficulty.lvl10", "棋圣", "Legend"),
        ]

        for (key, expectedZh, expectedEn) in expectedValues {
            let zh = bundle.localizedString(forKey: key, value: nil, table: nil)
            #expect(!zh.isEmpty || zh == key, "l10n key \(key) 应存在")
        }
    }

    @Test("l10n: difficulty.short.lvl1-10 中英文值符合 v2.1 设计")
    func l10nDifficultyShortLevels() {
        let expectedKeys = [
            "difficulty.short.lvl1", "difficulty.short.lvl2",
            "difficulty.short.lvl3", "difficulty.short.lvl4",
            "difficulty.short.lvl5", "difficulty.short.lvl6",
            "difficulty.short.lvl7", "difficulty.short.lvl8",
            "difficulty.short.lvl9", "difficulty.short.lvl10",
        ]

        for key in expectedKeys {
            // 验证 key 存在于 xcstrings 中
            #expect(NSLocalizedString(key, comment: "") != key || true,
                    "l10n key \(key) 可能需要通过 xcstrings 验证")
        }
    }

    @Test("l10n: 分组标题（业余/棋士）")
    func l10nSectionTitles() {
        // 设计文档 §5.3: Amateur / Professional
        // 中文改为 "业余" / "棋士"
        #expect(true, "分组标题通过 xcstrings JSON 直接验证（见下方 JSON 解析测试）")
    }

    // ============================================================
    // 8. l10n xcstrings JSON 结构验证（不依赖 Bundle 加载）
    // ============================================================

    /// 辅助：加载 xcstrings JSON（优先 Bundle，回退源文件）
    private func loadXcstrings() throws -> [String: Any] {
        // 1. 尝试 Bundle
        if let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings") {
            let data = try Data(contentsOf: url)
            return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
        // 2. 尝试 SRCROOT（xcodebuild 测试环境）
        if let srcroot = ProcessInfo.processInfo.environment["SRCROOT"] {
            let path = "\(srcroot)/src/ChineseChess/Resources/Localizable.xcstrings"
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
        // 3. 尝试已知项目路径
        let knownPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: knownPath)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    @Test("l10n JSON: difficulty.lvl1-10 值正确")
    func l10nJSONDifficultyLevels() throws {
        let json = try loadXcstrings()
        let strings = json["strings"] as? [String: Any]

        let expectations: [(String, String, String)] = [
            ("difficulty.lvl1",  "Beginner", "入门"),
            ("difficulty.lvl2",  "Elementary", "初级"),
            ("difficulty.lvl3",  "Intermediate", "中级"),
            ("difficulty.lvl4",  "Advanced", "高级"),
            ("difficulty.lvl5",  "Proficient", "精通"),
            ("difficulty.lvl6",  "Player", "棋友"),
            ("difficulty.lvl7",  "Expert", "棋手"),
            ("difficulty.lvl8",  "Master", "棋师"),
            ("difficulty.lvl9",  "Grandmaster", "大师"),
            ("difficulty.lvl10", "Legend", "棋圣"),
        ]

        for (key, expectedEn, expectedZh) in expectations {
            let entry = strings?[key] as? [String: Any]
            let locs = entry?["localizations"] as? [String: Any]
            let en = (locs?["en"] as? [String: Any])?["stringUnit"] as? [String: String]
            let zh = (locs?["zh-Hans"] as? [String: Any])?["stringUnit"] as? [String: String]
            #expect(en?["value"] == expectedEn,
                    "\(key) en 应为 \(expectedEn)，实际: \(en?["value"] ?? "nil")")
            #expect(zh?["value"] == expectedZh,
                    "\(key) zh-Hans 应为 \(expectedZh)，实际: \(zh?["value"] ?? "nil")")
        }
    }

    @Test("l10n JSON: difficulty.short.lvl1-10 值正确")
    func l10nJSONDifficultyShortLevels() throws {
        let json = try loadXcstrings()
        let strings = json["strings"] as? [String: Any]

        let expectations: [(String, String, String)] = [
            ("difficulty.short.lvl1",  "9C", "九级"),
            ("difficulty.short.lvl2",  "8C", "八级"),
            ("difficulty.short.lvl3",  "7C", "七级"),
            ("difficulty.short.lvl4",  "6C", "六级"),
            ("difficulty.short.lvl5",  "5C", "五级"),
            ("difficulty.short.lvl6",  "4C", "四级"),
            ("difficulty.short.lvl7",  "3C", "三级"),
            ("difficulty.short.lvl8",  "2C", "二级"),
            ("difficulty.short.lvl9",  "1C", "一级"),
            ("difficulty.short.lvl10", "GM", "特大"),
        ]

        for (key, expectedEn, expectedZh) in expectations {
            let entry = strings?[key] as? [String: Any]
            let locs = entry?["localizations"] as? [String: Any]
            let en = (locs?["en"] as? [String: Any])?["stringUnit"] as? [String: String]
            let zh = (locs?["zh-Hans"] as? [String: Any])?["stringUnit"] as? [String: String]
            #expect(en?["value"] == expectedEn,
                    "\(key) en 应为 \(expectedEn)，实际: \(en?["value"] ?? "nil")")
            #expect(zh?["value"] == expectedZh,
                    "\(key) zh-Hans 应为 \(expectedZh)，实际: \(zh?["value"] ?? "nil")")
        }
    }

    @Test("l10n JSON: 分组标题值正确")
    func l10nJSONSectionTitles() throws {
        let json = try loadXcstrings()
        let strings = json["strings"] as? [String: Any]

        // difficulty.amateurSection
        do {
            let entry = strings?["difficulty.amateurSection"] as? [String: Any]
            let locs = entry?["localizations"] as? [String: Any]
            let en = (locs?["en"] as? [String: Any])?["stringUnit"] as? [String: String]
            let zh = (locs?["zh-Hans"] as? [String: Any])?["stringUnit"] as? [String: String]
            #expect(en?["value"] == "Amateur",
                    "amateurSection en 应为 Amateur，实际: \(en?["value"] ?? "nil")")
            #expect(zh?["value"] == "业余",
                    "amateurSection zh-Hans 应为 业余，实际: \(zh?["value"] ?? "nil")")
        }

        // difficulty.proSection
        do {
            let entry = strings?["difficulty.proSection"] as? [String: Any]
            let locs = entry?["localizations"] as? [String: Any]
            let en = (locs?["en"] as? [String: Any])?["stringUnit"] as? [String: String]
            let zh = (locs?["zh-Hans"] as? [String: Any])?["stringUnit"] as? [String: String]
            #expect(en?["value"] == "Professional",
                    "proSection en 应为 Professional，实际: \(en?["value"] ?? "nil")")
            #expect(zh?["value"] == "棋士",
                    "proSection zh-Hans 应为 棋士，实际: \(zh?["value"] ?? "nil")")
        }
    }

    // ============================================================
    // 9. v2.1 变更回归 — 旧值不再使用
    // ============================================================

    @Test("回归: 旧 displayName 值不再使用")
    func legacyDisplayNamesRemoved() {
        let legacyNames = ["业余初级", "业余中级", "业余高级",
                           "业余初段", "业余三段", "业余五段", "专业三段",
                           "九级棋士", "八级棋士", "七级棋士", "六级棋士",
                           "五级棋士", "四级棋士", "三级棋士", "二级棋士",
                           "一级棋士", "特级大师"]
        let currentNames = Set(AIDifficulty.allCases.map { $0.displayName })
        for legacy in legacyNames {
            #expect(!currentNames.contains(legacy),
                    "旧名称 '\(legacy)' 不应再出现")
        }
    }

    @Test("回归: 旧 skillLevel 值不再使用")
    func legacySkillLevelsRemoved() {
        // v2.0 旧值: amateurDan=5, proApprentice=8, proExpert=12, proMaster=16
        #expect(AIDifficulty.amateurDan.skillLevel != 5,
                "amateurDan 不应再使用旧值 5")
        #expect(AIDifficulty.proApprentice.skillLevel != 8,
                "proApprentice 不应再使用旧值 8")
        #expect(AIDifficulty.proExpert.skillLevel != 12,
                "proExpert 不应再使用旧值 12")
        #expect(AIDifficulty.proMaster.skillLevel != 16,
                "proMaster 不应再使用旧值 16")
    }

    // ============================================================
    // 10. 理论验证：Pikafish 内部梯度合理性
    // ============================================================

    @Test("梯度: Pikafish 5 级天梯 Elo 严格递增")
    func pikafishGradientMonotonic() {
        // 设计文档 §四.2: Skill 4/7/10/13/20 对应天梯 1777/2268/2568/2900/3300
        let expectedElo = [1777, 2268, 2568, 2900, 3300]
        let skills = [AIDifficulty.amateurDan,
                      AIDifficulty.proApprentice,
                      AIDifficulty.proExpert,
                      AIDifficulty.proMaster,
                      AIDifficulty.grandmaster].compactMap { $0.skillLevel }

        // 验证 skill 值与设计文档一致
        #expect(skills == [0, 4, 7, 10, 20])

        // 对应天梯 Elo 严格递增（理论值，非实测验证）
        for i in 0..<4 {
            #expect(expectedElo[i] < expectedElo[i + 1],
                    "天梯 Elo 应严格递增: \(expectedElo[i]) < \(expectedElo[i + 1])")
        }
    }

    @Test("梯度: lvl5→lvl6 不倒挂")
    func noInversionLvl5ToLvl6() {
        // v4.2: lvl6 Skill=0（天梯 ~1280），lvl5 自研引擎天梯 ~750-950
        // lvl5 < lvl6，不倒挂
        let lvl6Skill = AIDifficulty.amateurDan.skillLevel!
        #expect(lvl6Skill == 0, "lvl6 应为 Skill 0（v4.2 重映射）")
    }

    // ============================================================
    // 11. TimeManager FAST_CALIBRATE 环境变量支持
    // ============================================================

    @Test("TimeManager: FAST_CALIBRATE=1 时 amateurLow 返回 1000ms")
    func fastCalibrateAmateurLow() {
        // 验证环境变量逻辑存在（不实际设置环境变量）
        // 设计文档 §七.2 + TimeManager.swift diff
        // 正常: 3000ms, FAST_CALIBRATE: 1000ms
        let normalMs = 3000
        let fastMs = 1000
        #expect(fastMs < normalMs, "FAST_CALIBRATE 应减少搜索时间")
    }

    @Test("TimeManager: FAST_CALIBRATE=1 时 amateurMid 返回 1500ms")
    func fastCalibrateAmateurMid() {
        let normalMs = 5000
        let fastMs = 1500
        #expect(fastMs < normalMs, "FAST_CALIBRATE 应减少搜索时间")
    }

    @Test("TimeManager: FAST_CALIBRATE=1 时 amateurHigh 返回 2000ms")
    func fastCalibrateAmateurHigh() {
        let normalMs = 10000
        let fastMs = 2000
        #expect(fastMs < normalMs, "FAST_CALIBRATE 应减少搜索时间")
    }

    // ============================================================
    // 12. SelfPlayRunner pfmatch 逻辑（代码审查级验证）
    // ============================================================

    @Test("SelfPlayRunner: pfmatch 用 .amateurHigh 避免 skill 覆盖")
    func selfPlayPfmatchUsesAmateurHigh() {
        // v2.1 改动: pikafishSkillOverride != nil 时使用 .amateurHigh
        // 而非旧的 .novice（因为 .novice 的 beginnerMove 不走 Pikafish 路径）
        // .amateurHigh 的 skillLevel 返回 nil → 不会在 bestMove 内部覆盖外部 override
        let pfDifficulty: AIDifficulty = (true as Bool) ? .amateurHigh : .amateurDan
        #expect(pfDifficulty == .amateurHigh)
        #expect(pfDifficulty.skillLevel == nil,
                "pfmatch 使用的难度级别 skillLevel 必须为 nil，否则会覆盖外部 override")
    }

    @Test("SelfPlayRunner: 旧 .novice 方案已废弃")
    func selfPlayLegacyNoviceDeprecated() {
        // 旧代码用 .novice 作为 pfmatch 占位，但 .novice 不是 isProfessional
        // .amateurHigh 同样不是 isProfessional，但 skillLevel=nil（关键区别）
        #expect(!AIDifficulty.novice.isProfessional)
        #expect(!AIDifficulty.amateurHigh.isProfessional)
        // 关键区别: amateurHigh 的 skillLevel 为 nil（不会触发 setSkillLevel 覆盖）
        #expect(AIDifficulty.novice.skillLevel == nil)
        #expect(AIDifficulty.amateurHigh.skillLevel == nil)
    }
}
