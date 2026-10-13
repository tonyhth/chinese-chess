import Foundation

// MARK: - 棋子类型
enum PieceKind: String, CaseIterable, Codable {
    case general   // 将/帅
    case advisor   // 士/仕
    case elephant  // 象/相
    case horse     // 马
    case chariot   // 车
    case cannon    // 炮
    case soldier   // 兵/卒
}

// MARK: - 阵营
enum Side: String, Codable {
    case red
    case black
}

// MARK: - 游戏状态
enum GameState: String, Equatable, Codable {
    case playing
    case redWon
    case blackWon
    case draw
}

// MARK: - AI 难度（v6.0: 10 级统一棋力系统）
enum AIDifficulty: CaseIterable, Codable {
    // 业余级（自研引擎）
    case novice        // 1级 入门
    case beginner      // 2级 初级
    case amateurLow    // 3级 中级
    case amateurMid    // 4级 高级
    case amateurHigh   // 5级 精通

    // 棋士级（Pikafish Skill Level）
    case amateurDan    // 6级 棋友 (Skill 0)
    case proApprentice // 7级 棋手 (Skill 4)
    case proExpert     // 8级 棋师 (Skill 7)
    case proMaster     // 9级 大师 (Skill 10)
    case grandmaster   // 10级 棋圣 (Skill 20)

    // MARK: - rawValue（持久化用，lvl1-lvl10）

    var rawValue: String {
        switch self {
        case .novice:        return "lvl1"
        case .beginner:      return "lvl2"
        case .amateurLow:    return "lvl3"
        case .amateurMid:    return "lvl4"
        case .amateurHigh:   return "lvl5"
        case .amateurDan:    return "lvl6"
        case .proApprentice: return "lvl7"
        case .proExpert:     return "lvl8"
        case .proMaster:     return "lvl9"
        case .grandmaster:   return "lvl10"
        }
    }

    // MARK: - init(rawValue:)（含旧值兼容映射）

    init?(rawValue: String) {
        // 新 rawValue 映射
        switch rawValue {
        case "lvl1":  self = .novice
        case "lvl2":  self = .beginner
        case "lvl3":  self = .amateurLow
        case "lvl4":  self = .amateurMid
        case "lvl5":  self = .amateurHigh
        case "lvl6":  self = .amateurDan
        case "lvl7":  self = .proApprentice
        case "lvl8":  self = .proExpert
        case "lvl9":  self = .proMaster
        case "lvl10": self = .grandmaster
        // 旧 rawValue 兼容映射（v2.0-v5.x 存档）
        case "beginner": self = .novice       // 旧 1级新手 → 新 1级入门
        case "easy":     self = .beginner     // 旧 2级初级 → 新 2级初级
        case "medium":   self = .amateurLow   // 旧 3级中级 → 新 3级业余初级
        case "hard":     self = .amateurMid   // 旧 4级高级 → 新 4级业余中级
        case "master":   self = .amateurHigh  // 旧 5级大师 → 新 5级业余高级
        default: return nil
        }
    }

    // MARK: - 自定义 Codable（未知值 fallback 到 .amateurMid）

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        // T-1013-OC-03 S2：持久化键迁移（v2.2 §3.2 M-C′ 全表强度就近；仅解码路径消费，
        // init(rawValue:) 不受污染——防 --calibrate CLI 的 lvlN 直构语义被迁移污染）
        let migrated = Self.s2MigrationMap[raw] ?? raw
        if let value = AIDifficulty(rawValue: migrated) {
            self = value
        } else {
            // 未知值 fallback
            self = .amateurMid
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    // MARK: - 计算属性

    /// P2-4：难度选择器公共数据源（iOS 菜单 / macOS Picker 两实现共用，词汇表单点）
    static let amateurLevels: [AIDifficulty] = [.novice, .beginner, .amateurLow, .amateurMid, .amateurHigh]
    static let professionalLevels: [AIDifficulty] = [.amateurDan, .proApprentice, .proExpert, .proMaster, .grandmaster]

    /// 候裁开关（Checkpoint 1 提案②随附，08:53 已报 dashboard）：true=过渡期选择器隐藏 lvl6-9
    /// （迁移后无用户驻留、与 lvl2-5 同参数重复且 lvl6=s0 对 lvl5=s10 过渡倒挂；重锚定案后回填）；
    /// Luke 裁否改 false 即回全表
    static let transitionProfessionalPickerHidden = true

    /// T-1013-OC-03 过渡期专业级选择器可见集（消费点：SettingsView/ToolbarView）
    static var visibleProfessionalLevels: [AIDifficulty] {
        transitionProfessionalPickerHidden ? [.grandmaster] : professionalLevels
    }

    /// 是否为专业级（使用 Pikafish 引擎）
    var isProfessional: Bool {
        self == .amateurDan || self == .proApprentice || self == .proExpert
        || self == .proMaster || self == .grandmaster
    }

    /// Pikafish Skill Level（仅专业级有值）
    var skillLevel: Int? {
        switch self {
        case .amateurDan:    return 0   // lvl6: v4 重映射（从 4 改为 0）
        case .proApprentice: return 4   // lvl7: v4 重映射（从 7 改为 4）
        case .proExpert:     return 7   // lvl8: v4 重映射（从 10 改为 7）
        case .proMaster:     return 10  // lvl9: v4 重映射（从 13 改为 10）
        case .grandmaster:   return 20  // lvl10: 不变
        default:             return nil
        }
    }

    // MARK: - T-1013-OC-03 S2 难度体系 v2.2 单源参数表（v65-v3 §8①：skill/预算映射表单源，禁散落 if）

    /// S2 载体（v2.2 §2.1）：自研 AIEngine / Pikafish（skill 刻度）
    enum S2Carrier {
        case selfResearch
        case pikafish
    }

    /// 单源参数表行：usesPikafish=true 时 skill=UCI Skill Level、budgetMs=UCI timeLimitMs 缺省；
    /// selfResearch 时 budgetMs=自研引擎预算帽。ladderElo=天梯折算锚（单调门自检源）；
    /// transitionSlot=v2.2 §2.3 过渡位（lvl6-9 维持现行实现，重锚=开放设计位；门检/选择器按候裁提案处理）
    struct S2LevelSpec: Equatable {
        let usesPikafish: Bool
        let skill: Int?
        let budgetMs: Int
        let ladderElo: Int
        let transitionSlot: Bool
        /// lvl1 豁免教学档（v2.2：L1→L2 不计档距门，天梯未标定，门检排除）
        let ladderExempt: Bool
    }

    /// lvl1 载体形态开关（v2.2 §2.1 五缺口④）：false=选项 a 自研 hard-d1 维持【默认基线】；
    /// true=选项 b Pikafish skill0+movetime≤1000ms（隔离可换，洪涛产品面裁量未落，一键切）
    static var lvl1UsesPikafish = false

    /// S2 锁表参数（v0.3.1 §2.1/§2.3）：lvl2-5=s0/s4/s7/s10（R2 锚）@5000/5000/5000/10000；
    /// lvl6-9=现行实现维持（过渡位）；lvl10=s20 官方锚延续；lvl1=默认 a（自研 hard-d1，豁免档）
    var s2Spec: S2LevelSpec {
        switch self {
        case .novice:
            // lvl1-a budgetMs=自研预算帽（AIEngine noviceSearch/noviceSearchScored 消费，P3-② 单源化）
            return Self.lvl1UsesPikafish
                ? S2LevelSpec(usesPikafish: true, skill: 0, budgetMs: 1000, ladderElo: 1000, transitionSlot: false, ladderExempt: true)
                : S2LevelSpec(usesPikafish: false, skill: nil, budgetMs: 2000, ladderElo: 1000, transitionSlot: false, ladderExempt: true)
        case .beginner:      return S2LevelSpec(usesPikafish: true, skill: 0, budgetMs: 5000, ladderElo: 1280, transitionSlot: false, ladderExempt: false)
        case .amateurLow:    return S2LevelSpec(usesPikafish: true, skill: 4, budgetMs: 5000, ladderElo: 1777, transitionSlot: false, ladderExempt: false)
        case .amateurMid:    return S2LevelSpec(usesPikafish: true, skill: 7, budgetMs: 5000, ladderElo: 2268, transitionSlot: false, ladderExempt: false)
        case .amateurHigh:   return S2LevelSpec(usesPikafish: true, skill: 10, budgetMs: 10000, ladderElo: 2568, transitionSlot: false, ladderExempt: false)
        // P3-② 披露：以下 4 过渡位行=声明镜像（skill/budgetMs 实际消费走 skillLevel/mapDifficulty 旧通道，
        // 数值与现行实现一致已亲验——单源对此 4 行为文档性；重锚定案后由后续单转正消费）
        case .amateurDan:    return S2LevelSpec(usesPikafish: true, skill: 0, budgetMs: 5000, ladderElo: 1280, transitionSlot: true, ladderExempt: false)
        case .proApprentice: return S2LevelSpec(usesPikafish: true, skill: 4, budgetMs: 6000, ladderElo: 1777, transitionSlot: true, ladderExempt: false)
        case .proExpert:     return S2LevelSpec(usesPikafish: true, skill: 7, budgetMs: 7000, ladderElo: 2268, transitionSlot: true, ladderExempt: false)
        case .proMaster:     return S2LevelSpec(usesPikafish: true, skill: 10, budgetMs: 8000, ladderElo: 2568, transitionSlot: true, ladderExempt: false)
        case .grandmaster:   return S2LevelSpec(usesPikafish: true, skill: 20, budgetMs: 10000, ladderElo: 3300, transitionSlot: false, ladderExempt: false)
        }
    }

    /// 引擎载体路由面（EngineRouter.engineFor 分派依据）：
    /// ⚠️ 与 isProfessional（UI 分组/进度语义）有意分离——S2 后 lvl2-5 载体=Pikafish 但仍属业余序列
    var usesPikafishEngine: Bool { s2Spec.usesPikafish }

    /// S2 迁移映射表（v2.2 §3.2 M-C′ 全表强度就近；持久化键迁移，仅 Codable 解码路径消费，
    /// 不入 init(rawValue:)——防 --calibrate CLI 的 lvlN 直构语义被迁移污染）
    /// ⚠️ 候裁标注（Checkpoint 1 提案①，08:53 已报 dashboard）：锚前提=生产实码 v4.2 重映射
    /// （lvl6=s0/lvl7=s4/lvl8=s7/lvl9=s10，Enums 上方注释），非规格文本的 v2.1 设计表
    /// （s4/s7/s10/s13）。Luke 裁规格字面版则换表：lvl6→lvl3/lvl7→lvl4/lvl8→lvl5/lvl9 不迁移
    private static let s2MigrationMap: [String: String] = [
        "lvl4": "lvl3",   // 自研 old4≈old5（B5 实测）≈1777 → 新 lvl3 同锚就近（偏差≤1 档合规）
        "lvl5": "lvl3",   // 自研 old5 下限 1777（plan-b §1.3）→ 新 lvl3 同锚零漂移
        "lvl6": "lvl2",   // 实码 s0 → 新 lvl2 同锚零漂移（规格字面版=lvl3，候裁）
        "lvl7": "lvl3",   // 实码 s4 → 新 lvl3 同锚零漂移
        "lvl8": "lvl4",   // 实码 s7 → 新 lvl4 同锚零漂移
        "lvl9": "lvl5"    // 实码 s10 → 新 lvl5 同锚零漂移（规格字面版=候重锚挂起，实码锚下免挂起）
    ]

    /// T-1013-OC-03 P1-1（Ruby 全审修后重走）：skill 应用决策纯函数（可回归测试）——返回应推送的 skill（nil=不推）。
    /// 优先级：外部 override 存活（非 nil）=不插手（calibrate/pfmatch 盘面）> difficulty.skillLevel（lvl6-10 旧语义）
    /// > 锁表 spec.skill（lvl2-5 非过渡位）；脏检查：期望==已应用则不推（局中切档即时生效的关键：
    /// 旧 lastSkillOverride 守卫在首手置位后恒真，切档后期望值更新被吞=P1-1 滞留实锤位）
    static func s2SkillToApply(difficulty: AIDifficulty, externalOverride: Int?, lastApplied: Int?) -> Int? {
        guard externalOverride == nil else { return nil }
        let spec = difficulty.s2Spec
        let desired: Int?
        if let skill = difficulty.skillLevel {
            desired = skill
        } else if spec.usesPikafish && !spec.transitionSlot {
            desired = spec.skill
        } else {
            desired = nil
        }
        guard let desired else { return nil }
        return desired == lastApplied ? nil : desired
    }

    /// 专业级不可用时 fallback 到最近的自研级别
    var fallbackToAmateur: AIDifficulty {
        .amateurHigh
    }

    /// 显示名（P1-2 修复：单源 l10n 词表，key = difficulty.<rawValue>；
    /// 原硬编码中文词表 B 与 Settings/Toolbar 词表 A 混显）
    var displayName: String {
        L10n.shared.t("difficulty.\(rawValue)")
    }

    /// 难度排序值（0-9，用于比较）
    var order: Int {
        switch self {
        case .novice:        return 0
        case .beginner:      return 1
        case .amateurLow:    return 2
        case .amateurMid:    return 3
        case .amateurHigh:   return 4
        case .amateurDan:    return 5
        case .proApprentice: return 6
        case .proExpert:     return 7
        case .proMaster:     return 8
        case .grandmaster:   return 9
        }
    }

    /// v0.4.2 §Y N-out：噪声轴整体出局，五档全零（Luke 10-01 12:57 裁，T-1001-2）
    /// noisyEvaluate 机制保留：0 幅=无操作（guard leafNoise > 0 直返 raw，lvl5 等价性锚点扩为全档）
    var leafNoiseAmplitude: Int {
        switch self {
        case .novice:        return 0  // lvl1（§Y N-out 全零）
        case .beginner:      return 0  // lvl2
        case .amateurLow:    return 0  // lvl3
        case .amateurMid:    return 0  // lvl4
        case .amateurHigh:   return 0  // lvl5
        case .amateurDan, .proApprentice, .proExpert, .proMaster, .grandmaster:
            return 0  // 专业级不走自研引擎
        }
    }

    /// 难度 ID（用于存储，同 rawValue）
    var id: String { rawValue }
}


