//
//  SelectionConsistencyTests.swift
//  ChineseChessTests
//
//  v6.3 测试资产 · 选择态一致性断言链（Luke 08-28 派单，洪涛令）
//  ① 难度 enum tag↔显示名/短名映射全覆盖（10 级 × 长/短名）
//  ② DemoSpeed↔显示
//  ③ Settings 面（主题/语言/记谱格式/音效）
//  ④ 读档回显（存档含设置 → 读档 → UI 状态断言，v2.2.18 前科口径）
//
//  与 Cody 数据流扫描 / Ruby 模式 review 三线并行；嫌疑点出来后优先覆盖嫌疑路径。
//

import Testing
import Foundation
@testable import ChineseChess

@Suite("选择态一致性", .serialized)
final class SelectionConsistencyTests {

    // 语言状态隔离（v6.2 断言清偿簇1 规约）
    private let savedLang: String
    init() { savedLang = TestL10nSupport.injectZhHans() }
    deinit { TestL10nSupport.restore(savedLang) }

    // UserDefaults 隔离工具：改前备份、测后恢复
    private func withUDKey<T>(_ key: String, _ body: () throws -> T) rethrows -> T {
        let saved = UserDefaults.standard.object(forKey: key)
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        return try body()
    }

    // MARK: - ① 难度 enum tag ↔ 显示名/短名（10 级全覆盖）

    @Test("①-1 难度档位总数与顺序：10 级、order 严格递增、allCases 顺序 = 难度顺序")
    func difficultyOrdering() {
        #expect(AIDifficulty.allCases.count == 10)
        for (i, d) in AIDifficulty.allCases.enumerated() {
            #expect(d.order == i, "第 \(i) 档 \(d.rawValue) order 应为 \(i)，实际 \(d.order)")
        }
    }

    @Test("①-4b 公共数据源锢定：amateur+professional 拼接 == allCases 且逐元素 isProfessional 吻合（Ruby P2 登记条）")
    func difficultyPublicDataSources() {
        let combined = AIDifficulty.amateurLevels + AIDifficulty.professionalLevels
        #expect(combined == AIDifficulty.allCases,
                "两数组拼接应等于 allCases（顺序一致）；否则 UI 词表静默漂移")
        for d in AIDifficulty.amateurLevels {
            #expect(!d.isProfessional, "\(d.rawValue) 在 amateurLevels 但 isProfessional=true")
        }
        for d in AIDifficulty.professionalLevels {
            #expect(d.isProfessional, "\(d.rawValue) 在 professionalLevels 但 isProfessional=false")
        }
        #expect(Set(AIDifficulty.amateurLevels).count == AIDifficulty.amateurLevels.count,
                "amateurLevels 不应有重复元素")
        #expect(Set(AIDifficulty.professionalLevels).count == AIDifficulty.professionalLevels.count,
                "professionalLevels 不应有重复元素")
    }

    @Test("①-2 rawValue 持久化 tag：lvl1-lvl10 与 case 一一对应、init(rawValue:) 双向无损")
    func difficultyRawValueRoundtrip() {
        for (i, d) in AIDifficulty.allCases.enumerated() {
            #expect(d.rawValue == "lvl\(i + 1)", "\(d) rawValue 应为 lvl\(i+1)，实际 \(d.rawValue)")
            #expect(AIDifficulty(rawValue: d.rawValue) == d, "lvl\(i+1) 应无损还原为 \(d)")
            #expect(d.id == d.rawValue)
        }
        // 未知值 → nil（不静默映射）
        #expect(AIDifficulty(rawValue: "lvl0") == nil)
        #expect(AIDifficulty(rawValue: "lvl11") == nil)
        #expect(AIDifficulty(rawValue: "") == nil)
    }

    @Test("①-3 旧存档 rawValue 兼容映射（v2.0-v5.x）：五旧值映射到位")
    func difficultyLegacyMapping() {
        #expect(AIDifficulty(rawValue: "beginner") == .novice)
        #expect(AIDifficulty(rawValue: "easy") == .beginner)
        #expect(AIDifficulty(rawValue: "medium") == .amateurLow)
        #expect(AIDifficulty(rawValue: "hard") == .amateurMid)
        #expect(AIDifficulty(rawValue: "master") == .amateurHigh)
    }

    @Test("①-4 中文名（短名）：10 档全覆盖、非空、互不重复")
    func difficultyDisplayNameCN() {
        var seen = Set<String>()
        for d in AIDifficulty.allCases {
            let name = d.displayName
            #expect(!name.isEmpty, "\(d.rawValue) 中文名不得为空")
            #expect(!seen.contains(name), "中文名重复：\(name)（\(d.rawValue)）")
            seen.insert(name)
        }
        // 顺序锚（防档位错位——选择态一致性的核心断言）
        let names = AIDifficulty.allCases.map(\.displayName)
        #expect(names == ["入门", "初级", "中级", "高级", "精通",
                          "棋友", "棋手", "棋师", "大师", "棋圣"])
    }

    @Test("①-5 英文名：10 档全覆盖、非空、互不重复、与中文名同序对齐（P1-2: 经 l10n en 表单源）")
    func difficultyDisplayNameEN() {
        L10n.shared.setLanguage("en")
        defer { L10n.shared.setLanguage("zh-Hans") }
        var seen = Set<String>()
        for d in AIDifficulty.allCases {
            let name = d.displayName
            #expect(!name.isEmpty, "\(d.rawValue) 英文名不得为空")
            #expect(!seen.contains(name), "英文名重复：\(name)（\(d.rawValue)）")
            seen.insert(name)
        }
        let en = AIDifficulty.allCases.map(\.displayName)
        #expect(en == ["Beginner", "Elementary", "Intermediate", "Advanced", "Proficient",
                       "Player", "Expert", "Master", "Grandmaster", "Legend"])
    }

    @Test("①-6 Settings Picker tag ↔ l10n 长名：difficulty.lvl1-10 键全存在且非空（zh/en 双语）")
    func difficultyL10nKeys() {
        let l10n = L10n.shared
        for d in AIDifficulty.allCases {
            let key = "difficulty.\(d.rawValue)"   // difficulty.lvl1 ... difficulty.lvl10
            let zh = l10n.t(key)
            #expect(zh != key, "zh-Hans 缺键：\(key)")
            #expect(!zh.isEmpty, "\(key) zh-Hans 值为空")
        }
        L10n.shared.setLanguage("en")
        for d in AIDifficulty.allCases {
            let key = "difficulty.\(d.rawValue)"
            let en = l10n.t(key)
            #expect(en != key, "en 缺键：\(key)")
            #expect(!en.isEmpty, "\(key) en 值为空")
        }
        L10n.shared.setLanguage("zh-Hans")
    }

    @Test("①-7 专业级口径：isProfessional ⇔ skillLevel 非 nil，五专业级 Skill 值对表")
    func difficultyProfessionalConsistency() {
        for d in AIDifficulty.allCases {
            #expect(d.isProfessional == (d.skillLevel != nil),
                    "\(d.rawValue) isProfessional 与 skillLevel 口径冲突")
        }
        #expect(AIDifficulty.amateurDan.skillLevel == 0)     // v4 重映射（4→0）
        #expect(AIDifficulty.proApprentice.skillLevel == 4)  // v4 重映射（7→4）
        #expect(AIDifficulty.proExpert.skillLevel == 7)      // v4 重映射（10→7）
        #expect(AIDifficulty.proMaster.skillLevel == 10)     // v4 重映射（13→10）
        #expect(AIDifficulty.grandmaster.skillLevel == 20)
        for d in AIDifficulty.allCases where !d.isProfessional {
            #expect(d.skillLevel == nil)
        }
    }

    @Test("①-8 l10n 长名 ↔ displayName 同源一致（P1-2 后 displayName 即 l10n 单源读取，本测试锚定 key 映射正确性）")
    func difficultyL10nNameConsistency() {
        for d in AIDifficulty.allCases {
            let key = "difficulty.\(d.rawValue)"
            #expect(L10n.shared.t(key) == d.displayName,
                    "\(key) zh 值「\(L10n.shared.t(key))」应与 displayName「\(d.displayName)」同源一致")
        }
        L10n.shared.setLanguage("en")
        defer { L10n.shared.setLanguage("zh-Hans") }
        for d in AIDifficulty.allCases {
            let key = "difficulty.\(d.rawValue)"
            #expect(L10n.shared.t(key) == d.displayName,
                    "\(key) en 值「\(L10n.shared.t(key))」应与 displayName「\(d.displayName)」同源一致")
        }
    }

    // MARK: - ② DemoSpeed ↔ 显示

    @Test("②-1 DemoSpeed 档位全集与数值：4 档 0.5/1/2/3，CaseIterable 顺序单调")
    func demoSpeedCases() {
        #expect(DemoSpeed.allCases.count == 4)
        #expect(DemoSpeed.allCases.map(\.rawValue) == [0.5, 1.0, 2.0, 3.0])
    }

    @Test("②-2 DemoSpeed label ↔ rawValue 一致：0.5x/1x/2x/3x，非空互异")
    func demoSpeedLabels() {
        let labels = DemoSpeed.allCases.map(\.label)
        #expect(labels == ["0.5x", "1x", "2x", "3x"])
        var seen = Set<String>()
        for l in labels {
            #expect(!l.isEmpty)
            #expect(!seen.contains(l), "速度档 label 重复：\(l)")
            seen.insert(l)
        }
        // label 数值 = rawValue（显示不撒谎）：整档显示整数，0.5 档显示一位小数
        for s in DemoSpeed.allCases {
            let expected = s.rawValue == s.rawValue.rounded()
                ? String(Int(s.rawValue))
                : String(s.rawValue)
            #expect(s.label == "\(expected)x", "\(s) label 应与 rawValue \(s.rawValue) 一致")
        }
    }

    @Test("②-3 DemoSpeed 派生量：stepInterval=1/x、commentaryDuration=max(0.8, 2/x)")
    func demoSpeedDerived() {
        #expect(DemoSpeed.slow.stepInterval == 2.0)
        #expect(DemoSpeed.normal.stepInterval == 1.0)
        #expect(DemoSpeed.fast.stepInterval == 0.5)
        #expect(abs(DemoSpeed.turbo.stepInterval - 1.0 / 3.0) < 1e-9)
        // turbo 2/3≈0.667 触发 0.8 下限钳制
        #expect(abs(DemoSpeed.turbo.commentaryDuration - 0.8) < 1e-9)
        #expect(DemoSpeed.fast.commentaryDuration == 1.0)
        #expect(DemoSpeed.normal.commentaryDuration == 2.0)
        #expect(DemoSpeed.slow.commentaryDuration == 4.0)
    }

    // MARK: - ③ Settings 面

    @Test("③-1 主题全集：5 主题 rawValue 双向无损、displayName 非空互异")
    func boardThemeMapping() {
        #expect(BoardTheme.allCases.count == 5)
        var seen = Set<String>()
        for t in BoardTheme.allCases {
            #expect(BoardTheme(rawValue: t.rawValue) == t, "\(t.rawValue) 应无损还原")
            #expect(!t.displayName.isEmpty, "\(t.rawValue) displayName 为空")
            #expect(!seen.contains(t.displayName), "主题显示名重复：\(t.displayName)")
            seen.insert(t.displayName)
        }
    }

    @Test("③-2 主题解锁口径：requiredRank nil ⇔ isUnlockedByDefault（选择态与解锁态不矛盾）")
    func boardThemeUnlockConsistency() {
        for t in BoardTheme.allCases {
            #expect(t.isUnlockedByDefault == (t.requiredRank == nil))
        }
        #expect(BoardTheme.classicWood.isUnlockedByDefault)
        #expect(BoardTheme.inkStone.isUnlockedByDefault)
        #expect(!BoardTheme.crimson.isUnlockedByDefault)
    }

    @Test("③-3 主题 l10n 键：theme.classicWood / theme.inkStone 双语在位")
    func boardThemeL10n() {
        #expect(L10n.shared.t("theme.classicWood") != "theme.classicWood")
        #expect(L10n.shared.t("theme.inkStone") != "theme.inkStone")
        L10n.shared.setLanguage("en")
        #expect(L10n.shared.t("theme.classicWood") != "theme.classicWood")
        #expect(L10n.shared.t("theme.inkStone") != "theme.inkStone")
        L10n.shared.setLanguage("zh-Hans")
    }

    @Test("③-4 主题持久化：ThemeManager.currentTheme 恒为合法 case（读档态不悬空）")
    func themeManagerStateValidity() {
        #expect(BoardTheme.allCases.contains(ThemeManager.shared.currentTheme),
                "currentTheme \(ThemeManager.shared.currentTheme.rawValue) 不在 allCases 内")
    }

    @Test("③-5 语言设置持久化：setLanguage 落 UserDefaults 且语言态即时切换")
    func languagePersistence() {
        withUDKey("chinesechess.language") {
            L10n.shared.setLanguage("en")
            #expect(UserDefaults.standard.string(forKey: "chinesechess.language") == "en")
            #expect(L10n.shared.language == "en")
            L10n.shared.setLanguage("zh-Hans")
            #expect(UserDefaults.standard.string(forKey: "chinesechess.language") == "zh-Hans")
            #expect(L10n.shared.language == "zh-Hans")
        }
    }

    @Test("③-6 记谱格式设置 → 行为一致：chinese/iccs 双态下 NotationGenerator 输出分叉且正确")
    func notationFormatBehavior() {
        let board = Board()
        let cannon = board.piece(at: Position(row: 7, col: 1))!
        let move = Move(piece: cannon, from: Position(row: 7, col: 1),
                        to: Position(row: 7, col: 4), captured: nil)

        withUDKey("chinesechess.notationFormat") {
            UserDefaults.standard.set("chinese", forKey: "chinesechess.notationFormat")
            let zh = NotationGenerator.notation(for: move, on: board)
            #expect(zh == "炮八平五", "中文格式应输出 炮八平五，实际 \(zh)")

            UserDefaults.standard.set("iccs", forKey: "chinesechess.notationFormat")
            let iccs = NotationGenerator.notation(for: move, on: board)
            #expect(iccs == "b2e2", "ICCS 格式应输出 b2e2，实际 \(iccs)")

            // 未设置（首次启动）→ 默认 chinese
            UserDefaults.standard.removeObject(forKey: "chinesechess.notationFormat")
            let def = NotationGenerator.notation(for: move, on: board)
            #expect(def == "炮八平五", "缺省应回退中文格式，实际 \(def)")
        }
    }

    @Test("③-7 音效开关：isMuted 可写可读、默认路径无异常")
    func soundToggle() {
        let engine = SoundEngine.shared
        let original = engine.isMuted
        defer { engine.isMuted = original }
        engine.isMuted = true
        // 异步队列写：短自旋等同步（上限 1s，防挂）
        let deadline = Date().addingTimeInterval(1.0)
        while !engine.isMuted && Date() < deadline { usleep(10_000) }
        #expect(engine.isMuted, "isMuted=true 应可读回")
        engine.isMuted = false
        let deadline2 = Date().addingTimeInterval(1.0)
        while engine.isMuted && Date() < deadline2 { usleep(10_000) }
        #expect(!engine.isMuted, "isMuted=false 应可读回")
    }

    // MARK: - ④ 读档回显（v2.2.18 前科口径：存档含设置 → 读档 → 状态断言）

    private func makeRecord(difficulty: AIDifficulty?) -> GameRecord {
        let board = Board()
        let cannon = board.piece(at: Position(row: 7, col: 1))!
        let move = GameMove(
            id: UUID(),
            piece: cannon,
            from: Position(row: 7, col: 1),
            to: Position(row: 7, col: 4),
            captured: nil,
            turnNumber: 1,
            notation: "炮八平五",
            timestamp: Date(),
            isCheck: false,
            isCheckmate: false,
            halfmoveClock: 0
        )
        return GameRecord(
            title: "读档回显测试",
            redPlayer: PlayerInfo(name: "玩家", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "AI-大师", isAI: true, difficulty: difficulty),
            difficulty: difficulty,
            result: .redWon,
            totalMoves: 1,
            moves: [move]
        )
    }

    @Test("④-1 存档→读档 难度回显：10 档全量 Codable 往返无损")
    func recordDifficultyRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for d in AIDifficulty.allCases {
            let record = makeRecord(difficulty: d)
            let data = try encoder.encode(record)
            let loaded = try decoder.decode(GameRecord.self, from: data)
            #expect(loaded.difficulty == d, "\(d.rawValue) 存读档后难度漂移为 \(String(describing: loaded.difficulty))")
            #expect(loaded.blackPlayer.difficulty == d)
            // UI 回显口径（GameHistoryView 摘要行）：displayName 即用户所见
            #expect(loaded.difficulty?.displayName == d.displayName)
        }
    }

    @Test("④-2 nil 难度（导入档）回显：保持 nil 不漂移、不崩溃")
    func recordNilDifficultyRoundtrip() throws {
        let record = makeRecord(difficulty: nil)
        let data = try JSONEncoder().encode(record)
        let loaded = try JSONDecoder().decode(GameRecord.self, from: data)
        #expect(loaded.difficulty == nil)
        #expect(loaded.blackPlayer.difficulty == nil)
    }

    @Test("④-3 旧存档难度字符串：五旧值按兼容映射还原（不落 nil、不 fallback）")
    func recordLegacyDifficultyDecode() throws {
        // 手工 JSON：v2.0-v5.x 时代 difficulty 字段为旧字符串
        let legacyPairs: [(String, AIDifficulty)] = [
            ("beginner", .novice), ("easy", .beginner), ("medium", .amateurLow),
            ("hard", .amateurMid), ("master", .amateurHigh),
        ]
        for (raw, expected) in legacyPairs {
            let json = """
            {"id":"\(UUID().uuidString)","title":"旧档","date":"2024-01-01T00:00:00Z",
             "redPlayer":{"name":"玩家","isAI":false},
             "blackPlayer":{"name":"AI","isAI":true},
             "difficulty":"\(raw)","result":"redWon","totalMoves":0,"moves":[]}
            """
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode(GameRecord.self, from: Data(json.utf8))
            #expect(loaded.difficulty == expected,
                    "旧值 \(raw) 应回显为 \(expected.rawValue)，实际 \(String(describing: loaded.difficulty))")
        }
    }

    @Test("④-4 未知难度字符串：Codable fallback .amateurMid（不崩溃、UI 有可见回显）")
    func recordUnknownDifficultyFallback() throws {
        let json = """
        {"id":"\(UUID().uuidString)","title":"异常档","date":"2024-01-01T00:00:00Z",
         "redPlayer":{"name":"玩家","isAI":false},
         "blackPlayer":{"name":"AI","isAI":true},
         "difficulty":"lvl99","result":"redWon","totalMoves":0,"moves":[]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = try decoder.decode(GameRecord.self, from: Data(json.utf8))
        #expect(loaded.difficulty == .amateurMid, "未知难度应 fallback .amateurMid，实际 \(String(describing: loaded.difficulty))")
        // 用户可见：摘要行显示「–」以外的合法名
        #expect(!loaded.difficulty!.displayName.isEmpty)
    }

    @Test("④-5 主题持久化读档：currentTheme 写入即落盘、重启还原不漂移（走真实 didSet 路径）")
    func themePersistenceRoundtrip() {
        let manager = ThemeManager.shared
        let originalTheme = manager.currentTheme
        defer { manager.currentTheme = originalTheme }
        for t in BoardTheme.allCases {
            manager.currentTheme = t
            let persisted = UserDefaults.standard.string(forKey: "chinesechess.theme")
            #expect(persisted == t.rawValue,
                    "主题 \(t.rawValue) didSet 落盘失败，实际 \(String(describing: persisted))")
            // 重启还原路径（init 同款）：rawValue→case 无损
            #expect(persisted.flatMap(BoardTheme.init(rawValue:)) == t)
        }
    }

    // MARK: - ⑤ Ruby 审计嫌疑路径覆盖（P1/P2，特征化证据）
    // 待 Luke 定返工批次：修复落地后此节用例需同步改预期（红→绿切换点）

    /// Ruby P1-1（语言 Picker get/set 不对称，“跟随系统”永不回显）——已修复后正向断言：
    /// 修复 = Picker get 改读 preferredLanguage（UD 原始值），set(nil)→clearLanguage 不再重写键。
    /// 修复前特征化证据见 known-issues/返工单；本用例现为修复行为锢定。
    @Test("⑤-1 [P1-1 已修] preferredLanguage 回显语义：set→非 nil，clear→nil（跟随系统可命中）")
    func clearLanguageSymptom() {
        // set 显式选择 → 持久层非 nil，回显具体语言
        L10n.shared.setLanguage("en")
        #expect(L10n.shared.preferredLanguage == "en")

        // clear 跟随系统 → 键被清除（不再被 systemLang 重写），回显 nil → tag(nil) 命中
        L10n.shared.clearLanguage()
        #expect(L10n.shared.preferredLanguage == nil,
                "P1-1 修复锢定：clearLanguage 后 UD 键应为 nil（旧实现被 setLanguage(system) 重写）")

        // 运行态 language 仍解析为可用语言（翻译链不因跟随系统断掉）
        #expect(!L10n.shared.language.isEmpty)
    }

    // MARK: - ⑥ 引擎开关守卫（P1-① v6.2 阻塞档，Luke 初裁升级）

    /// 开关 off + 专业级组合：用户选择自研引擎时不再被架空强拉 Pikafish。
    /// validate 应视为可用（走自研）、engineFor 应返回自研引擎——与状态栏显示（读开关）一致。
    @Test("⑥-1 [P1-① 已修] 开关 off + 专业级：validate 可用 + engineFor 走自研（选择不被架空）")
    @MainActor
    func engineSwitchGuardProfessional() async {
        let original = EngineConfigStore.shared.useEmbeddedEngine
        defer { EngineConfigStore.shared.useEmbeddedEngine = original }

        // 开关 off + 大师级：validate 不应为专业级强拉 Pikafish（原症状：unavailable/隐式重启）
        EngineConfigStore.shared.useEmbeddedEngine = false
        let availability = await EngineRouter.shared.validateEngineAvailability(for: .proMaster)
        if case .unavailable = availability {
            Issue.record("P1-① 修复锢定失败：开关 off + 专业级不应触发 Pikafish 不可用（应直接走自研）")
        }

        // engineFor 应返回自研引擎（与状态栏显示同源：开关 off → 自研）
        let engine = EngineRouter.shared.engineFor(difficulty: .proMaster)
        #expect(engine is AIEngine, "开关 off + 专业级应走自研 AIEngine，实际 \(type(of: engine))")
    }
}

// MARK: - ⑤ 独立 suite 已合并入主 suite（跨 suite L10n 竞态消除）
// 删除原 SelectionConsistencyAuditSuspectTests，避免 .serialized 无法阻止跨 suite deinit/init 交错

