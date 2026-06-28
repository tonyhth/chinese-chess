import Foundation

// MARK: - v3.0 Phase 6: 段位系统

/// 7 级段位
enum Rank: String, Codable, CaseIterable, Comparable {
    case student       // 起始
    case scholar       // 5 胜
    case juren         // 15 胜
    case jinshi        // 30 胜 + 5 残局
    case hanlin        // 50 胜 + 10 残局
    case master        // 100 胜 + 20 残局
    case sage          // 200 胜 + 40 残局

    // 兼容旧中文 rawValue
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "student", "学童": self = .student
        case "scholar", "秀才": self = .scholar
        case "juren", "举人": self = .juren
        case "jinshi", "进士": self = .jinshi
        case "hanlin", "翰林": self = .hanlin
        case "master", "国手": self = .master
        case "sage", "棋圣": self = .sage
        default:
            NSLog("[i18n] Unknown rank value: \(value), defaulting to student")
            self = .student
        }
    }

    var localizedTitle: String {
        switch self {
        case .student: return L10n.shared.t("rank.student")
        case .scholar: return L10n.shared.t("rank.scholar")
        case .juren: return L10n.shared.t("rank.juren")
        case .jinshi: return L10n.shared.t("rank.jinshi")
        case .hanlin: return L10n.shared.t("rank.hanlin")
        case .master: return L10n.shared.t("rank.master")
        case .sage: return L10n.shared.t("rank.sage")
        }
    }

    /// 升级所需胜场
    var requiredWins: Int {
        switch self {
        case .student: return 0
        case .scholar: return 5
        case .juren: return 15
        case .jinshi: return 30
        case .hanlin: return 50
        case .master: return 100
        case .sage: return 200
        }
    }

    /// 升级所需残局通关数
    var requiredPuzzles: Int {
        switch self {
        case .student, .scholar, .juren: return 0
        case .jinshi: return 5
        case .hanlin: return 10
        case .master: return 20
        case .sage: return 40
        }
    }

    /// 下一个段位（棋圣为最高）
    var next: Rank? {
        let all = Rank.allCases
        guard let idx = all.firstIndex(of: self), idx < all.count - 1 else { return nil }
        return all[idx + 1]
    }

    /// 段位序号（0-6）
    var order: Int {
        Rank.allCases.firstIndex(of: self) ?? 0
    }

    /// 段位图标（SF Symbol）
    var icon: String {
        switch self {
        case .student: return "graduationcap"
        case .scholar: return "book"
        case .juren: return "scroll"
        case .jinshi: return "doc.text"
        case .hanlin: return "crown"
        case .master: return "star.fill"
        case .sage: return "rosette"
        }
    }

    // Comparable
    static func < (lhs: Rank, rhs: Rank) -> Bool {
        lhs.order < rhs.order
    }
}

// MARK: - 玩家档案

struct PlayerProfile: Codable, Equatable {
    var rank: Rank = .student
    var totalWins: Int = 0
    var totalLosses: Int = 0
    var totalDraws: Int = 0
    var puzzlesCompleted: Int = 0
    var completedTutorials: Bool = false
    var unlockedAchievements: [String] = []  // Achievement.id 列表
    var dailyStreak: Int = 0
    var lastPlayDate: String? = nil  // ISO 日期

    // v3.0 gap fix: 连续登录奖励解锁字段
    var bonusUnlockedThemes: [String] = []    // 通过连续登录解锁的主题 rawValue
    var bonusPuzzlesUnlocked: Bool = false    // 额外残局解锁
    var bonusPieceStyle: Bool = false         // 专属棋子样式
    var bonusSpecialTheme: Bool = false       // 棋圣专属主题

    // v3.6.0 Q3: 成就系统改造新增字段
    var currentWinStreak: Int = 0              // 当前连胜
    var maxWinStreak: Int = 0                  // 最大连胜
    var beatenDifficulties: Set<String> = []   // 已击败的难度 ID
    var bonusExtraHints: Int = 0               // 每日额外提示次数（由成就解锁增加）

    // MARK: - 自定义解码（P1-3 修复）
    // v3.0 新增字段对旧存档不存在对应 key，用 decodeIfPresent + 默认值兜底
    // 防止旧用户升级后 JSONDecoder 抛 keyNotFound 导致档案被静默重置
    private enum CodingKeys: String, CodingKey {
        case rank, totalWins, totalLosses, totalDraws, puzzlesCompleted
        case completedTutorials, unlockedAchievements, dailyStreak, lastPlayDate
        case bonusUnlockedThemes, bonusPuzzlesUnlocked, bonusPieceStyle, bonusSpecialTheme
        case currentWinStreak, maxWinStreak, beatenDifficulties, bonusExtraHints
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rank = try c.decodeIfPresent(Rank.self, forKey: .rank) ?? .student
        totalWins = try c.decodeIfPresent(Int.self, forKey: .totalWins) ?? 0
        totalLosses = try c.decodeIfPresent(Int.self, forKey: .totalLosses) ?? 0
        totalDraws = try c.decodeIfPresent(Int.self, forKey: .totalDraws) ?? 0
        puzzlesCompleted = try c.decodeIfPresent(Int.self, forKey: .puzzlesCompleted) ?? 0
        completedTutorials = try c.decodeIfPresent(Bool.self, forKey: .completedTutorials) ?? false
        unlockedAchievements = try c.decodeIfPresent([String].self, forKey: .unlockedAchievements) ?? []
        dailyStreak = try c.decodeIfPresent(Int.self, forKey: .dailyStreak) ?? 0
        lastPlayDate = try c.decodeIfPresent(String.self, forKey: .lastPlayDate)
        // v3.0 gap fix 新字段 — 旧存档没有这些 key
        bonusUnlockedThemes = try c.decodeIfPresent([String].self, forKey: .bonusUnlockedThemes) ?? []
        bonusPuzzlesUnlocked = try c.decodeIfPresent(Bool.self, forKey: .bonusPuzzlesUnlocked) ?? false
        bonusPieceStyle = try c.decodeIfPresent(Bool.self, forKey: .bonusPieceStyle) ?? false
        bonusSpecialTheme = try c.decodeIfPresent(Bool.self, forKey: .bonusSpecialTheme) ?? false
        // v3.6.0 Q3 新字段
        currentWinStreak = try c.decodeIfPresent(Int.self, forKey: .currentWinStreak) ?? 0
        maxWinStreak = try c.decodeIfPresent(Int.self, forKey: .maxWinStreak) ?? 0
        beatenDifficulties = try c.decodeIfPresent(Set<String>.self, forKey: .beatenDifficulties) ?? []
        bonusExtraHints = try c.decodeIfPresent(Int.self, forKey: .bonusExtraHints) ?? 0
    }

    var totalGames: Int { totalWins + totalLosses + totalDraws }
    var winRate: Double { totalGames == 0 ? 0 : Double(totalWins) / Double(totalGames) }

    // MARK: - Q3: 成就→段位联动

    /// 成就贡献的虚拟胜场数（总上限 ~7）
    var achievementBonusWins: Int {
        var bonus = 0
        if unlockedAchievements.contains("tutorial_done") { bonus += 1 }
        if unlockedAchievements.contains("beat_medium") { bonus += 1 }
        if unlockedAchievements.contains("beat_hard") { bonus += 2 }
        if unlockedAchievements.contains("beat_master") { bonus += 3 }
        return bonus
    }

    /// 成就贡献的虚拟残局通关数（总上限 ~9）
    var achievementBonusPuzzles: Int {
        var bonus = 0
        if unlockedAchievements.contains("first_puzzle") { bonus += 1 }
        if unlockedAchievements.contains("chapter1_clear") { bonus += 3 }
        if unlockedAchievements.contains("endgame_master") { bonus += 5 }
        return bonus
    }

    /// 有效胜场数（含成就加成）
    var effectiveWins: Int { totalWins + achievementBonusWins }
    /// 有效残局通关数（含成就加成）
    var effectivePuzzles: Int { puzzlesCompleted + achievementBonusPuzzles }

    /// 每日总提示次数（上限 10）
    var totalDailyHints: Int {
        let base = 3
        return min(base + bonusExtraHints, 10)
    }

    /// 检查是否满足升级条件
    func canPromote(to target: Rank) -> Bool {
        effectiveWins >= target.requiredWins && effectivePuzzles >= target.requiredPuzzles
    }

    /// 检查并返回应升到的段位（累计制不降级）
    func checkRankUp() -> Rank? {
        var bestRank = rank
        for candidate in Rank.allCases {
            if candidate > bestRank && canPromote(to: candidate) {
                bestRank = candidate
            }
        }
        return bestRank > rank ? bestRank : nil
    }
}

// MARK: - 玩家档案存储

final class PlayerProfileStore {
    static let shared = PlayerProfileStore()

    private let defaults: UserDefaults
    private let key = "chinesechess.playerProfile"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var profile: PlayerProfile {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(PlayerProfile.self, from: data) else {
            return PlayerProfile()
        }
        return decoded
    }

    func save(_ profile: PlayerProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }

    func update(_ transform: (inout PlayerProfile) -> Void) -> PlayerProfile {
        var p = profile
        transform(&p)
        save(p)
        return p
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}

// MARK: - 段位进度计算

extension PlayerProfile {
    /// 当前段位到下一段位的进度（0.0 - 1.0）
    var rankProgress: Double {
        guard let next = rank.next else { return 1.0 }  // 棋圣已满
        let currentWins = rank.requiredWins
        let targetWins = next.requiredWins
        let winsProgress = Double(effectiveWins - currentWins) / Double(max(1, targetWins - currentWins))
        let currentPuzzles = rank.requiredPuzzles
        let targetPuzzles = next.requiredPuzzles
        let puzzlesProgress = targetPuzzles > currentPuzzles
            ? Double(effectivePuzzles - currentPuzzles) / Double(targetPuzzles - currentPuzzles)
            : 1.0
        return min(1.0, min(winsProgress, puzzlesProgress))
    }
}
