import Foundation

// MARK: - v3.0 Phase 6: 成就系统

/// 成就稀有度
enum AchievementRarity: String, Codable, CaseIterable {
    case bronze = "铜"
    case silver = "银"
    case gold = "金"
    case diamond = "钻石"
    case hidden = "隐藏"

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
    let name: String
    let description: String
    let rarity: AchievementRarity

    // 隐藏成就的描述在解锁前显示为 ????
    var displayDescription: String {
        rarity == .hidden ? "?????" : description
    }
    var displayName: String {
        rarity == .hidden ? "?????" : name
    }
}

// MARK: - 成就库（34 个）

enum AchievementLibrary {
    /// 铜牌成就（8个）— 新手目标
    static let bronze: [Achievement] = [
        Achievement(id: "first_game", name: "初出茅庐", description: "完成第一局对弈", rarity: .bronze),
        Achievement(id: "first_win", name: "旗开得胜", description: "获得第一场胜利", rarity: .bronze),
        Achievement(id: "tutorial_done", name: "学业初成", description: "完成新手教程", rarity: .bronze),
        Achievement(id: "play_red", name: "红方先锋", description: "执红对弈 5 局", rarity: .bronze),
        Achievement(id: "play_black", name: "黑方守将", description: "执黑对弈 5 局", rarity: .bronze),
        Achievement(id: "first_puzzle", name: "初涉残局", description: "通过第一个残局", rarity: .bronze),
        Achievement(id: "use_hint", name: "虚心求教", description: "使用 3 次提示", rarity: .bronze),
        Achievement(id: "draw_game", name: "和为贵", description: "达成一次和棋", rarity: .bronze),
    ]

    /// 银牌成就（8个）— 进阶目标
    static let silver: [Achievement] = [
        Achievement(id: "win_10", name: "十战十胜", description: "累计获胜 10 局", rarity: .silver),
        Achievement(id: "beat_medium", name: "中等克星", description: "战胜中级 AI", rarity: .silver),
        Achievement(id: "beat_hard", name: "硬核挑战者", description: "战胜高级 AI", rarity: .silver),
        Achievement(id: "puzzles_5", name: "残局新秀", description: "通过 5 个残局", rarity: .silver),
        Achievement(id: "win_streak_3", name: "三连胜", description: "连续获胜 3 局", rarity: .silver),
        Achievement(id: "rank_scholar", name: "金榜题名", description: "升至秀才段位", rarity: .silver),
        Achievement(id: "no_hint_win", name: "自力更生", description: "不使用提示获胜一局", rarity: .silver),
        Achievement(id: "quick_win", name: "速战速决", description: "30 步内获胜", rarity: .silver),
    ]

    /// 金牌成就（8个）— 高手目标
    static let gold: [Achievement] = [
        Achievement(id: "win_50", name: "百战雄师", description: "累计获胜 50 局", rarity: .gold),
        Achievement(id: "beat_master", name: "棋逢对手", description: "战胜大师级 AI", rarity: .gold),
        Achievement(id: "puzzles_20", name: "残局大师", description: "通过 20 个残局", rarity: .gold),
        Achievement(id: "win_streak_5", name: "五连霸主", description: "连续获胜 5 局", rarity: .gold),
        Achievement(id: "rank_juren", name: "乡试头名", description: "升至举人段位", rarity: .gold),
        Achievement(id: "comeback_win", name: "绝地反击", description: "子力劣势下获胜", rarity: .gold),
        Achievement(id: "perfect_game", name: "完美对局", description: "不丢一子获胜", rarity: .gold),
        Achievement(id: "endgame_master", name: "残局圣手", description: "10 步内解残局", rarity: .gold),
    ]

    /// 钻石成就（5个）— 大师目标
    static let diamond: [Achievement] = [
        Achievement(id: "win_100", name: "战神", description: "累计获胜 100 局", rarity: .diamond),
        Achievement(id: "rank_hanlin", name: "翰林学士", description: "升至翰林段位", rarity: .diamond),
        Achievement(id: "puzzles_40", name: "残局宗师", description: "通过 40 个残局", rarity: .diamond),
        Achievement(id: "all_difficulties", name: "全能战士", description: "战胜所有难度 AI", rarity: .diamond),
        Achievement(id: "win_streak_10", name: "十连绝杀", description: "连续获胜 10 局", rarity: .diamond),
    ]

    /// 隐藏成就（5个）— 特殊条件
    static let hidden: [Achievement] = [
        Achievement(id: "rank_sage", name: "棋道至尊", description: "升至棋圣段位", rarity: .hidden),
        Achievement(id: "200_wins", name: "千秋霸业", description: "累计获胜 200 局", rarity: .hidden),
        Achievement(id: "all_puzzles", name: "破局之王", description: "通关所有残局", rarity: .hidden),
        Achievement(id: "daily_7", name: "七日不辍", description: "连续 7 天对弈", rarity: .hidden),
        Achievement(id: "first_blood", name: "先声夺人", description: "第一步就将军", rarity: .hidden),
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
        return true
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
