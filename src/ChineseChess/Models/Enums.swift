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
    // 业余序列（载体单源见 s2Spec.usesPikafish：lvl1-a 自研 hard-d1，lvl2-5 Pikafish）
    case novice        // 1级 入门
    case beginner      // 2级 初级
    case amateurLow    // 3级 中级
    case amateurMid    // 4级 高级
    case amateurHigh   // 5级 精通

    // 棋士序列（Pikafish 载体；skill/movetime/ladderElo 三轴刻度单源=s2Spec 梯表，勿在此硬编码——O-T1 旧刻度尾注已撤）
    case amateurDan    // 6级 棋友
    case proApprentice // 7级 棋手
    case proExpert     // 8级 棋师
    case proMaster     // 9级 大师
    case grandmaster   // 10级 棋圣

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
        // T-1013-OC-03 P1-2（Luke 裁定选项 a）：AIDifficulty Codable 保持纯解码（类型级迁移钩子已撤——
        // 迁移收窄至真实用户数据加载边界，见 GameRecord/RecordSummary 的 s2Migrated 标记单次应用）
        if let value = AIDifficulty(rawValue: raw) {
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

    /// Pikafish Skill Level（Batch3 渐升梯重锚后=单源派生 s2Spec.skill：lvl2-10 Pikafish 档均有值，lvl1-a 自研 nil）。
    /// 旧 lvl6-10 硬编码通道（0/4/7/10/20，v4 重映射）随 2026-10-24 方案 A 重锚退役——梯表为唯一真相源（洪涛单源纪律）；
    /// 专业级 UI 分组口径见 isProfessional（与引擎刻度有意分离）
    var skillLevel: Int? { s2Spec.skill }

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
    /// true=选项 b Pikafish skill0+movetime≤1000ms（隔离可换，洪涛裁定⑥定案（T-1015-OC-01），一键切）。
    /// Batch3 重锚回填（plan v1.1 注记④）：b 形态行=梯表 lvl1 豁免位 s0@1000/ladderElo 1000（方案 A 采定表；
    /// 丹妮 10-24 22:4x 确认 movetime 首值 1000 系定稿，转达 500 系笔误）；开关本身维持现状，Luke 裁否权不变
    static var lvl1UsesPikafish = false

    /// S2 锁表参数（T-1023 P3 Batch3 渐升梯重锚，2026-10-24 洪涛裁定方案 A；真相源=t1023-remediation-plan v1.1 §五首项表
    /// + T-1026 §三方案 A 定稿/§四链式 ladderElo，s0=1000 基）：
    /// 三轴单源——skill 严格递增 s0/s2/s4/s5/s7/s9/s11/s14/s17/s20 ｜ movetime lvl2 起非降 500→5000 ｜ ladderElo 非降 1000→≈3170；
    /// lvl1=豁免位（裁定⑥ movetime≤1000ms 锁值，ladderExempt）；调用处禁散落字面量（单源纪律，Ruby 审查点）。
    /// 消费转正：lvl6-9 过渡位镜像通道（skillLevel/mapDifficulty 旧映射）退役，全部 Pikafish 档 depth=0+预算从表
    /// （EmbeddedPikafishEngine.bestMove s2LockTable=usesPikafish）；段距 ≥100 门按方案 A 放宽为非降（C7 边承载）
    var s2Spec: S2LevelSpec {
        switch self {
        case .novice:
            // lvl1 豁免位：a=自研预算帽（AIEngine noviceSearch/noviceSearchScored 消费，P3-② 单源化）；
            // b=梯表 lvl1 行（Pikafish s0@1000，豁免档裁定⑥锁值）
            return Self.lvl1UsesPikafish
                ? S2LevelSpec(usesPikafish: true, skill: 0, budgetMs: 1000, ladderElo: 1000, transitionSlot: false, ladderExempt: true)
                : S2LevelSpec(usesPikafish: false, skill: nil, budgetMs: 2000, ladderElo: 1000, transitionSlot: false, ladderExempt: true)
        case .beginner:      return S2LevelSpec(usesPikafish: true, skill: 2, budgetMs: 500, ladderElo: 1338, transitionSlot: false, ladderExempt: false)   // lvl2 s2@500
        case .amateurLow:    return S2LevelSpec(usesPikafish: true, skill: 4, budgetMs: 700, ladderElo: 1712, transitionSlot: false, ladderExempt: false)   // lvl3 s4@700
        case .amateurMid:    return S2LevelSpec(usesPikafish: true, skill: 5, budgetMs: 1000, ladderElo: 1801, transitionSlot: false, ladderExempt: false)  // lvl4 s5@1000
        case .amateurHigh:   return S2LevelSpec(usesPikafish: true, skill: 7, budgetMs: 1400, ladderElo: 2056, transitionSlot: false, ladderExempt: false)  // lvl5 s7@1400
        case .amateurDan:    return S2LevelSpec(usesPikafish: true, skill: 9, budgetMs: 2000, ladderElo: 2336, transitionSlot: true, ladderExempt: false)   // lvl6 s9@2000（过渡位标志保留=UI 分组语义，消费已转正单源）
        case .proApprentice: return S2LevelSpec(usesPikafish: true, skill: 11, budgetMs: 2800, ladderElo: 2473, transitionSlot: true, ladderExempt: false)  // lvl7 s11@2800
        // C7 薄弱边（lvl8↔lvl9，s14→s17 微差，T-1026 实测）：产品面以「高段渐进感」文案承载（高段打磨语义），
        // 加局复核入缓裁池候后批（plan v1.1 §七）；本批以代码注记落位，UI 文案改写候具体文案令（L10n 锁表零触碰）
        case .proExpert:     return S2LevelSpec(usesPikafish: true, skill: 14, budgetMs: 3600, ladderElo: 2627, transitionSlot: true, ladderExempt: false)  // lvl8 s14@3600
        case .proMaster:     return S2LevelSpec(usesPikafish: true, skill: 17, budgetMs: 4400, ladderElo: 2700, transitionSlot: true, ladderExempt: false)  // lvl9 s17@4400
        case .grandmaster:   return S2LevelSpec(usesPikafish: true, skill: 20, budgetMs: 5000, ladderElo: 3170, transitionSlot: false, ladderExempt: false) // lvl10 s20@5000 官方锚延续
        }
    }

    /// 引擎载体路由面（EngineRouter.engineFor 分派依据）：
    /// ⚠️ 与 isProfessional（UI 分组/进度语义）有意分离——S2 后 lvl2-5 载体=Pikafish 但仍属业余序列
    var usesPikafishEngine: Bool { s2Spec.usesPikafish }

    /// T-1013-OC-03 P1-2（Luke 裁定选项 a）：S2 迁移映射——挂点收窄至用户数据加载边界
    /// （GameRecord/RecordSummary 的 s2Migrated 标记单次应用），不入 AIDifficulty Codable 类型级
    /// （类型级钩子致新值腐蚀/旧档改写/设置面无落点三连——Ruby P1-2 + Luke 裁定）。
    /// 实码锚终值（Checkpoint 1 裁定 08:59）：生产实码 v4.2 重映射 lvl6=s0/lvl7=s4/lvl8=s7/lvl9=s10 →
    /// 新锁表 lvl2=s0/lvl3=s4/lvl4=s7/lvl5=s10 全同锚零漂移；自研 old4/5≈1777→lvl3。
    /// （Batch3 注记：2026-10-24 方案 A 梯表重锚后本映射保持冻结——用户数据迁移锚不随梯表重锚变动；
    /// 就近档语义按新梯表复核仍成立：旧 lvl6(s0)→新 lvl2(s2) 差距 1 档内合规）
    static let s2MigrationMap: [String: String] = [
        "lvl4": "lvl3",   // 自研 old4≈old5（B5 实测）≈1777 → 新 lvl3 同锚就近（偏差≤1 档合规）
        "lvl5": "lvl3",   // 自研 old5 下限 1777（plan-b §1.3）→ 新 lvl3 同锚零漂移
        "lvl6": "lvl2",   // 实码 s0 → 新 lvl2 同锚零漂移
        "lvl7": "lvl3",   // 实码 s4 → 新 lvl3 同锚零漂移
        "lvl8": "lvl4",   // 实码 s7 → 新 lvl4 同锚零漂移
        "lvl9": "lvl5"    // 实码 s10 → 新 lvl5 同锚零漂移
    ]

    /// 原始键迁移（未命中=原样返回：v2.0-v5.x 兼容键与 lvl1-3/lvl10 等不受影响）
    static func s2MigratedRaw(_ raw: String) -> String {
        s2MigrationMap[raw] ?? raw
    }

    /// AIDifficulty 便捷迁移（nil 透传；未命中键原样）
    static func s2Migrated(_ d: AIDifficulty?) -> AIDifficulty? {
        guard let d else { return nil }
        return AIDifficulty(rawValue: s2MigratedRaw(d.rawValue)) ?? d
    }

    /// T-1013-OC-03 P1-1（Ruby 全审修后重走）：skill 应用决策纯函数（可回归测试）——返回应推送的 skill（nil=不推）。
    /// 优先级：外部 override 存活（非 nil）=不插手（calibrate/pfmatch 盘面）> 单源梯表 spec.skill
    /// （Batch3 重锚转正：全 Pikafish 档唯一来源；旧 difficulty.skillLevel 硬编码通道已退役为单源派生，无第二真相源）。
    /// 脏检查：期望==已应用则不推（局中切档即时生效的关键：
    /// 旧 lastSkillOverride 守卫在首手置位后恒真，切档后期望值更新被吞=P1-1 滞留实锤位）
    static func s2SkillToApply(difficulty: AIDifficulty, externalOverride: Int?, lastApplied: Int?) -> Int? {
        guard externalOverride == nil else { return nil }
        guard let desired = difficulty.s2Spec.skill else { return nil }
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


