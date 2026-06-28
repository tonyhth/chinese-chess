import Foundation

// MARK: - v3.6.0 Q3: 段位/成就通知

extension Notification.Name {
    static let rankPromoted = Notification.Name("com.chinesechess.rankPromoted")
    static let achievementUnlocked = Notification.Name("com.chinesechess.achievementUnlocked")
}

// MARK: - v3.0 Phase 6: 成就系统

/// 成就稀有度
enum AchievementRarity: String, Codable, CaseIterable {
    case bronze, silver, gold, diamond, hidden

    // 兼容旧中文 rawValue（数据迁移）
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "bronze", "铜": self = .bronze
        case "silver", "银": self = .silver
        case "gold", "金": self = .gold
        case "diamond", "钻石": self = .diamond
        case "hidden", "隐藏": self = .hidden
        default:
            NSLog("[i18n] Unknown rarity value: \(value), defaulting to bronze")
            self = .bronze
        }
    }

    var localizedName: String {
        switch self {
        case .bronze: return L10n.shared.t("rarity.bronze")
        case .silver: return L10n.shared.t("rarity.silver")
        case .gold: return L10n.shared.t("rarity.gold")
        case .diamond: return L10n.shared.t("rarity.diamond")
        case .hidden: return L10n.shared.t("rarity.hidden")
        }
    }

    var icon: String {
        switch self {
        case .bronze: return "🥉"
        case .silver: return "🥈"
        case .gold: return "🥇"
        case .diamond: return "💎"
        case .hidden: return "❓"
        }
    }
}

/// 成就定义
struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let nameKey: String
    let descriptionKey: String
    let rarity: AchievementRarity

    // 隐藏成就的描述在解锁前显示为 ????
    var displayDescription: String {
        rarity == .hidden ? "?????" : L10n.shared.t(descriptionKey)
    }
    var displayName: String {
        rarity == .hidden ? "?????" : L10n.shared.t(nameKey)
    }
}

// MARK: - 成就库（34 个）

enum AchievementLibrary {
    /// 铜牌成就（8个）— 新手目标
    static let bronze: [Achievement] = [
        Achievement(id: "first_game", nameKey: "achievement.first_game.name", descriptionKey: "achievement.first_game.desc", rarity: .bronze),
        Achievement(id: "first_win", nameKey: "achievement.first_win.name", descriptionKey: "achievement.first_win.desc", rarity: .bronze),
        Achievement(id: "tutorial_done", nameKey: "achievement.tutorial_done.name", descriptionKey: "achievement.tutorial_done.desc", rarity: .bronze),
        Achievement(id: "kill_mate_horse_cannon", nameKey: "achievement.kill_mate_horse_cannon.name", descriptionKey: "achievement.kill_mate_horse_cannon.desc", rarity: .bronze),
        Achievement(id: "kill_mate_double_rook", nameKey: "achievement.kill_mate_double_rook.name", descriptionKey: "achievement.kill_mate_double_rook.desc", rarity: .bronze),
        Achievement(id: "first_puzzle", nameKey: "achievement.first_puzzle.name", descriptionKey: "achievement.first_puzzle.desc", rarity: .bronze),
        Achievement(id: "first_draw_puzzle", nameKey: "achievement.first_draw_puzzle.name", descriptionKey: "achievement.first_draw_puzzle.desc", rarity: .bronze),
        Achievement(id: "chapter1_clear", nameKey: "achievement.chapter1_clear.name", descriptionKey: "achievement.chapter1_clear.desc", rarity: .bronze),
    ]

    /// 银牌成就（8个）— 进阶目标
    static let silver: [Achievement] = [
        Achievement(id: "win_10", nameKey: "achievement.win_10.name", descriptionKey: "achievement.win_10.desc", rarity: .silver),
        Achievement(id: "beat_medium", nameKey: "achievement.beat_medium.name", descriptionKey: "achievement.beat_medium.desc", rarity: .silver),
        Achievement(id: "beat_hard", nameKey: "achievement.beat_hard.name", descriptionKey: "achievement.beat_hard.desc", rarity: .silver),
        Achievement(id: "puzzles_5", nameKey: "achievement.puzzles_5.name", descriptionKey: "achievement.puzzles_5.desc", rarity: .silver),
        Achievement(id: "kill_ten_steps", nameKey: "achievement.kill_ten_steps.name", descriptionKey: "achievement.kill_ten_steps.desc", rarity: .silver),
        Achievement(id: "rank_scholar", nameKey: "achievement.rank_scholar.name", descriptionKey: "achievement.rank_scholar.desc", rarity: .silver),
        Achievement(id: "no_hint_win", nameKey: "achievement.no_hint_win.name", descriptionKey: "achievement.no_hint_win.desc", rarity: .silver),
        Achievement(id: "blitz_5min", nameKey: "achievement.blitz_5min.name", descriptionKey: "achievement.blitz_5min.desc", rarity: .silver),
        Achievement(id: "continuous_check", nameKey: "achievement.continuous_check.name", descriptionKey: "achievement.continuous_check.desc", rarity: .silver),
    ]

    /// 金牌成就（7个）— 高手目标
    static let gold: [Achievement] = [
        Achievement(id: "win_50", nameKey: "achievement.win_50.name", descriptionKey: "achievement.win_50.desc", rarity: .gold),
        Achievement(id: "beat_master", nameKey: "achievement.beat_master.name", descriptionKey: "achievement.beat_master.desc", rarity: .gold),
        Achievement(id: "puzzles_20", nameKey: "achievement.puzzles_20.name", descriptionKey: "achievement.puzzles_20.desc", rarity: .gold),
        Achievement(id: "win_streak_5", nameKey: "achievement.win_streak_5.name", descriptionKey: "achievement.win_streak_5.desc", rarity: .gold),
        Achievement(id: "rank_juren", nameKey: "achievement.rank_juren.name", descriptionKey: "achievement.rank_juren.desc", rarity: .gold),
        Achievement(id: "comeback_king", nameKey: "achievement.comeback_king.name", descriptionKey: "achievement.comeback_king.desc", rarity: .gold),
        Achievement(id: "endgame_master", nameKey: "achievement.endgame_master.name", descriptionKey: "achievement.endgame_master.desc", rarity: .gold),
    ]

    /// 钻石成就（5个）— 大师目标
    static let diamond: [Achievement] = [
        Achievement(id: "win_100", nameKey: "achievement.win_100.name", descriptionKey: "achievement.win_100.desc", rarity: .diamond),
        Achievement(id: "rank_hanlin", nameKey: "achievement.rank_hanlin.name", descriptionKey: "achievement.rank_hanlin.desc", rarity: .diamond),
        Achievement(id: "puzzles_40", nameKey: "achievement.puzzles_40.name", descriptionKey: "achievement.puzzles_40.desc", rarity: .diamond),
        Achievement(id: "all_difficulties", nameKey: "achievement.all_difficulties.name", descriptionKey: "achievement.all_difficulties.desc", rarity: .diamond),
        Achievement(id: "win_streak_10", nameKey: "achievement.win_streak_10.name", descriptionKey: "achievement.win_streak_10.desc", rarity: .diamond),
    ]

    /// 隐藏成就（6个）— 特殊条件
    static let hidden: [Achievement] = [
        Achievement(id: "rank_sage", nameKey: "achievement.rank_sage.name", descriptionKey: "achievement.rank_sage.desc", rarity: .hidden),
        Achievement(id: "200_wins", nameKey: "achievement.200_wins.name", descriptionKey: "achievement.200_wins.desc", rarity: .hidden),
        Achievement(id: "all_puzzles", nameKey: "achievement.all_puzzles.name", descriptionKey: "achievement.all_puzzles.desc", rarity: .hidden),
        Achievement(id: "daily_7", nameKey: "achievement.daily_7.name", descriptionKey: "achievement.daily_7.desc", rarity: .hidden),
        Achievement(id: "first_blood", nameKey: "achievement.first_blood.name", descriptionKey: "achievement.first_blood.desc", rarity: .hidden),
        Achievement(id: "perfect_game_v2", nameKey: "achievement.perfect_game_v2.name", descriptionKey: "achievement.perfect_game_v2.desc", rarity: .hidden),
    ]

    /// 所有成就
    static let all: [Achievement] = bronze + silver + gold + diamond + hidden

    /// 按分类获取
    static func achievements(for rarity: AchievementRarity) -> [Achievement] {
        switch rarity {
        case .bronze: return bronze
        case .silver: return silver
        case .gold: return gold
        case .diamond: return diamond
        case .hidden: return hidden
        }
    }

    /// 根据 ID 查找
    static func find(id: String) -> Achievement? {
        all.first { $0.id == id }
    }

    /// 已退役的成就 ID（从库中移除但保留在老用户记录中）
    static let retired: Set<String> = [
        "play_red", "play_black", "use_hint", "draw_game",
        "win_streak_3", "quick_win", "comeback_win", "perfect_game"
    ]
}

// MARK: - 成就管理器

final class AchievementManager {
    static let shared = AchievementManager()

    private let store: PlayerProfileStore

    init(store: PlayerProfileStore = .shared) {
        self.store = store
    }

    /// 解锁成就（如果尚未解锁）
    /// 返回 true 表示新解锁
    @discardableResult
    func unlock(_ achievementId: String) -> Bool {
        let current = store.profile
        if current.unlockedAchievements.contains(achievementId) { return false }
        _ = store.update { profile in
            if !profile.unlockedAchievements.contains(achievementId) {
                profile.unlockedAchievements.append(achievementId)
            }
        }

        // Q3: 成就解锁奖励
        if let achievement = AchievementLibrary.find(id: achievementId) {
            applyUnlockReward(achievement)
        }

        // Q3: 成就可能触发段位升级
        checkRankPromotion()

        // Q3: 发送通知
        NotificationCenter.default.post(
            name: .achievementUnlocked, object: achievementId
        )

        return true
    }

    /// Q3: 应用成就解锁奖励
    private func applyUnlockReward(_ achievement: Achievement) {
        switch achievement.rarity {
        case .silver:
            _ = store.update { $0.bonusExtraHints += 1 }
        case .gold:
            _ = store.update { $0.bonusExtraHints += 2 }
        case .diamond:
            _ = store.update { $0.bonusPieceStyle = true }
        case .hidden:
            _ = store.update { $0.bonusSpecialTheme = true }
        case .bronze:
            break  // 段位贡献已通过 effectiveWins 处理
        }
    }

    /// Q3: 检查段位升级
    private func checkRankPromotion() {
        let profile = store.profile
        if let newRank = profile.checkRankUp() {
            _ = store.update { $0.rank = newRank }
            NotificationCenter.default.post(
                name: .rankPromoted, object: newRank
            )
        }
    }

    /// 批量检查并解锁
    /// 返回新解锁的成就 ID 列表
    @discardableResult
    func checkAndUnlock(profile: PlayerProfile) -> [String] {
        var newlyUnlocked: [String] = []
        let unlocked = Set(profile.unlockedAchievements)

        // 首局
        let totalGames = profile.totalWins + profile.totalLosses + profile.totalDraws
        if totalGames >= 1 && !unlocked.contains("first_game") {
            newlyUnlocked.append("first_game")
        }
        // 首胜
        if profile.totalWins >= 1 && !unlocked.contains("first_win") {
            newlyUnlocked.append("first_win")
        }
        // 教程完成
        if profile.completedTutorials && !unlocked.contains("tutorial_done") {
            newlyUnlocked.append("tutorial_done")
        }
        // 10 胜
        if profile.totalWins >= 10 && !unlocked.contains("win_10") {
            newlyUnlocked.append("win_10")
        }
        // 50 胜
        if profile.totalWins >= 50 && !unlocked.contains("win_50") {
            newlyUnlocked.append("win_50")
        }
        // 100 胜
        if profile.totalWins >= 100 && !unlocked.contains("win_100") {
            newlyUnlocked.append("win_100")
        }
        // 200 胜
        if profile.totalWins >= 200 && !unlocked.contains("200_wins") {
            newlyUnlocked.append("200_wins")
        }
        // 残局
        if profile.puzzlesCompleted >= 1 && !unlocked.contains("first_puzzle") {
            newlyUnlocked.append("first_puzzle")
        }
        if profile.puzzlesCompleted >= 5 && !unlocked.contains("puzzles_5") {
            newlyUnlocked.append("puzzles_5")
        }
        if profile.puzzlesCompleted >= 20 && !unlocked.contains("puzzles_20") {
            newlyUnlocked.append("puzzles_20")
        }
        if profile.puzzlesCompleted >= 40 && !unlocked.contains("puzzles_40") {
            newlyUnlocked.append("puzzles_40")
        }
        // 段位成就
        if profile.rank >= .scholar && !unlocked.contains("rank_scholar") {
            newlyUnlocked.append("rank_scholar")
        }
        if profile.rank >= .juren && !unlocked.contains("rank_juren") {
            newlyUnlocked.append("rank_juren")
        }
        if profile.rank >= .hanlin && !unlocked.contains("rank_hanlin") {
            newlyUnlocked.append("rank_hanlin")
        }
        if profile.rank >= .sage && !unlocked.contains("rank_sage") {
            newlyUnlocked.append("rank_sage")
        }
        // 连续对弈
        if profile.dailyStreak >= 7 && !unlocked.contains("daily_7") {
            newlyUnlocked.append("daily_7")
        }

        for id in newlyUnlocked {
            unlock(id)
        }

        return newlyUnlocked
    }

    /// 已解锁数量
    func unlockedCount(profile: PlayerProfile) -> Int {
        profile.unlockedAchievements.count
    }

    /// 总进度
    func progress(profile: PlayerProfile) -> Double {
        Double(unlockedCount(profile: profile)) / Double(AchievementLibrary.all.count)
    }

    /// 检查某成就是否已解锁
    func isUnlocked(_ id: String, profile: PlayerProfile) -> Bool {
        profile.unlockedAchievements.contains(id)
    }
}
