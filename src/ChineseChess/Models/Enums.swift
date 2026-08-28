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

    /// 难度 ID（用于存储，同 rawValue）
    var id: String { rawValue }
}


