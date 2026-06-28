import Foundation

// MARK: - v3.0 Phase 7: 每日挑战

/// 每日挑战模式
enum DailyChallengeMode: String, Codable, CaseIterable {
    case endgamePuzzle       // 残局挑战
    case materialAdvantage   // AI 让子
    case timeBlitz           // 限时 5 分钟
    case endgameStart        // 从残局开始对弈
    case solveMate           // 一步杀练习
    case masterChallenge     // 对战 master 难度
    case defendChallenge      // 劣势防守
    case comboKill           // 连续将军
    case cannonOnly          // 限制主力为炮
    case horseOnly           // 限制主力为马

    // 兼容旧中文 rawValue
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "endgamePuzzle", "每日残局": self = .endgamePuzzle
        case "materialAdvantage", "让子局": self = .materialAdvantage
        case "timeBlitz", "闪电局": self = .timeBlitz
        case "endgameStart", "残局起步": self = .endgameStart
        case "solveMate", "解杀棋": self = .solveMate
        case "masterChallenge", "大师挑战": self = .masterChallenge
        case "defendChallenge", "防守挑战": self = .defendChallenge
        case "comboKill", "连杀挑战": self = .comboKill
        case "cannonOnly", "炮镇全局": self = .cannonOnly
        case "horseOnly", "马踏连营": self = .horseOnly
        default:
            NSLog("[i18n] Unknown daily challenge type: \(value), defaulting to endgamePuzzle")
            self = .endgamePuzzle
        }
    }

    var localizedTitle: String {
        L10n.shared.t("daily.type.\(rawValue).title")
    }

    var localizedDesc: String {
        L10n.shared.t("daily.type.\(rawValue).desc")
    }

    var icon: String {
        switch self {
        case .endgamePuzzle: return "puzzlepiece"
        case .materialAdvantage: return "handicap"
        case .timeBlitz: return "bolt"
        case .endgameStart: return "flag"
        case .solveMate: return "target"
        case .masterChallenge: return "crown"
        case .defendChallenge: return "shield"
        case .comboKill: return "flame"
        case .cannonOnly: return "scope"
        case .horseOnly: return "figure.equestrian.sports"
        }
    }
}

/// 每日挑战数据
struct DailyChallenge: Codable, Equatable {
    let date: String           // YYYY-MM-DD
    let mode: DailyChallengeMode
    let puzzleId: String?      // 关联的残局 ID（如有）
    let targetDifficulty: AIDifficulty
    let completed: Bool
    let score: Int             // 完成得分
}

/// 连续登录奖励阶梯
enum DailyStreakReward: Int, CaseIterable {
    case day3 = 3
    case day7 = 7
    case day14 = 14
    case day30 = 30
    case day45 = 45
    case day60 = 60
    case day70 = 70
    case day100 = 100

    var localizedReward: String {
        L10n.shared.t("daily.streak.day\(rawValue).reward")
    }

    // v3.0 gap fix: 实际解锁内容描述
    var localizedDesc: String {
        L10n.shared.t("daily.streak.day\(rawValue).desc")
    }

    // Q4: 奖励类型标识（更新后）
    var rewardType: String {
        switch self {
        case .day3: return "puzzle_progress_boost"   // 残局进度×2
        case .day7: return "extra_hints"             // 每日额外提示+3
        case .day14: return "piece_style"            // 专属棋子样式
        case .day30: return "blitz_time_bonus"       // 闪电局时间+1分钟
        case .day45: return "double_score"            // 每日挑战双倍积分
        case .day60: return "master_no_penalty"       // 大师挑战失败不扣统计
        case .day70: return "chapter7_early_unlock"   // 第七章提前解锁
        case .day100: return "custom_board_theme"     // 自定义棋盘配色
        }
    }
}

// MARK: - 每日挑战管理器

final class DailyChallengeManager {
    static let shared = DailyChallengeManager()

    private let defaults: UserDefaults
    private let challengeKey = "chinesechess.dailyChallenge"
    private let lastLoginKey = "chinesechess.lastLoginDate"
    private let streakKey = "chinesechess.dailyStreak"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - 日期工具

    private static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }

    var todayString: String {
        Self.dateString(from: Date())
    }

    // MARK: - 每日挑战生成

    /// 根据日期哈希生成今日挑战模式
    /// v3.0 Phase 7 fix: 使用确定性哈希（djb2），避免 String.hashValue 跨启动不稳定
    func todayChallengeMode() -> DailyChallengeMode {
        let hash = Self.deterministicHash(todayString)
        return DailyChallengeMode.allCases[hash % DailyChallengeMode.allCases.count]
    }

    /// 今日挑战难度（3 天轮换：easy → medium → hard）
    func todayDifficulty() -> AIDifficulty {
        let hash = Self.deterministicHash(todayString)
        let difficulties: [AIDifficulty] = [.easy, .medium, .hard]
        return difficulties[hash % difficulties.count]
    }

    /// v3.0 gap fix: 从残局库按日期哈希选取今日残局 ID
    func dailyPuzzleId() -> String? {
        let puzzles = PuzzleStore.shared.puzzles
        guard !puzzles.isEmpty else { return nil }
        let hash = Self.deterministicHash(todayString)
        return puzzles[hash % puzzles.count].id
    }

    /// v3.0 gap fix: 获取今日残局数据
    func dailyPuzzle() -> Puzzle? {
        guard let id = dailyPuzzleId() else { return nil }
        return PuzzleStore.shared.puzzles.first { $0.id == id }
    }

    /// 确定性字符串哈希（djb2 算法），跨启动结果一致
    private static func deterministicHash(_ str: String) -> Int {
        var hash: UInt64 = 5381
        for byte in str.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return Int(hash % UInt64(Int.max))
    }

    /// 生成今日挑战
    func todayChallenge() -> DailyChallenge {
        // 检查是否已存在
        if let existing = getChallenge(for: todayString) {
            return existing
        }

        // v3.0 gap fix: 从残局库按日期哈希选取真实 puzzleId
        let puzzleId = dailyPuzzleId()

        let challenge = DailyChallenge(
            date: todayString,
            mode: todayChallengeMode(),
            puzzleId: puzzleId,
            targetDifficulty: todayDifficulty(),
            completed: false,
            score: 0
        )
        saveChallenge(challenge)
        return challenge
    }

    // MARK: - 挑战完成

    func completeChallenge(score: Int) {
        var challenge = todayChallenge()
        // Q4 P2: bonusDoubleScore — 每日挑战双倍积分
        let finalScore = PlayerProfileStore.shared.profile.bonusDoubleScore ? score * 2 : score
        challenge = DailyChallenge(
            date: challenge.date,
            mode: challenge.mode,
            puzzleId: challenge.puzzleId,
            targetDifficulty: challenge.targetDifficulty,
            completed: true,
            score: finalScore
        )
        saveChallenge(challenge)
    }

    var isTodayCompleted: Bool {
        todayChallenge().completed
    }

    // MARK: - 连续登录

    /// 检查并更新连续登录天数
    /// 返回新的连续天数（0 = 中断）
    @discardableResult
    func checkDailyLogin() -> Int {
        let today = todayString
        let lastLogin = defaults.string(forKey: lastLoginKey)

        // 防篡告：大幅回拨不发奖励
        if let last = lastLogin, last > today {
            // 系统时间回拨，不更新
            return defaults.integer(forKey: streakKey)
        }

        if lastLogin == today {
            // 今天已登录
            return defaults.integer(forKey: streakKey)
        }

        // 计算连续天数
        var newStreak = 1
        if let last = lastLogin {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            if let lastDate = formatter.date(from: last),
               let todayDate = formatter.date(from: today) {
                let calendar = Calendar.current
                let diff = calendar.dateComponents([.day], from: lastDate, to: todayDate).day ?? 0
                if diff == 1 {
                    newStreak = defaults.integer(forKey: streakKey) + 1
                } else if diff <= 0 {
                    newStreak = defaults.integer(forKey: streakKey)
                }
                // diff > 1 = 中断，重置为 1
            }
        }

        defaults.set(today, forKey: lastLoginKey)
        defaults.set(newStreak, forKey: streakKey)

        return newStreak
    }

    var currentStreak: Int {
        defaults.integer(forKey: streakKey)
    }

    /// 检查是否解锁了连续登录奖励
    func checkStreakReward() -> DailyStreakReward? {
        let streak = currentStreak
        // 返回最高已达到的阶梯
        for reward in DailyStreakReward.allCases.reversed() {
            if streak >= reward.rawValue {
                return reward
            }
        }
        return nil
    }

    // v3.0 gap fix: 领取连续登录奖励（实际解锁逻辑）
    private let claimedRewardsKey = "chinesechess.claimedStreakRewards"

    /// 检查并领取所有已达到但未领取的连续登录奖励
    /// 返回新领取的奖励列表
    @discardableResult
    func claimPendingRewards() -> [DailyStreakReward] {
        let streak = currentStreak
        var claimed = claimedRewards
        var newlyClaimed: [DailyStreakReward] = []

        for reward in DailyStreakReward.allCases {
            if streak >= reward.rawValue && !claimed.contains(reward.rawValue) {
                newlyClaimed.append(reward)
                claimed.append(reward.rawValue)
            }
        }

        if !newlyClaimed.isEmpty {
            defaults.set(claimed, forKey: claimedRewardsKey)
            applyRewards(newlyClaimed)
        }

        return newlyClaimed
    }

    /// 已领取的奖励 rawValue 列表
    private var claimedRewards: [Int] {
        defaults.array(forKey: claimedRewardsKey) as? [Int] ?? []
    }

    /// Q4: 实际应用奖励解锁
    private func applyRewards(_ rewards: [DailyStreakReward]) {
        let store = PlayerProfileStore.shared

        for reward in rewards {
            switch reward.rewardType {
            case "puzzle_progress_boost":
                // day3: 残局进度×2（已通过 bonusPuzzlesUnlocked 实现）
                store.update { $0.bonusPuzzlesUnlocked = true }

            case "extra_hints":
                // day7: 每日额外提示+3
                store.update { $0.bonusExtraHints += 3 }

            case "piece_style":
                // day14: 解锁专属棋子样式
                store.update { $0.bonusPieceStyle = true }

            case "blitz_time_bonus":
                // day30: 闪电局时间+60秒
                store.update { $0.bonusBlitzTimeBonus += 60 }

            case "double_score":
                // day45: 每日挑战双倍积分
                store.update { $0.bonusDoubleScore = true }

            case "master_no_penalty":
                // day60: 大师挑战失败不扣统计
                store.update { $0.bonusMasterNoPenalty = true }

            case "chapter7_early_unlock":
                // day70: 第七章提前解锁（跳过段位检查）
                store.update { $0.bonusChapter7EarlyUnlock = true }

            case "custom_board_theme":
                // day100: 自定义棋盘配色
                store.update { $0.bonusSpecialTheme = true }

            default:
                break
            }
        }
    }

    // MARK: - 持久化

    private func saveChallenge(_ challenge: DailyChallenge) {
        var all = allChallenges
        all[challenge.date] = challenge
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: challengeKey)
        }
    }

    private func getChallenge(for date: String) -> DailyChallenge? {
        allChallenges[date]
    }

    private var allChallenges: [String: DailyChallenge] {
        guard let data = defaults.data(forKey: challengeKey) else { return [:] }
        return (try? JSONDecoder().decode([String: DailyChallenge].self, from: data)) ?? [:]
    }

    // MARK: - 历史统计

    /// 获取最近 N 天的挑战记录
    func recentChallenges(days: Int) -> [DailyChallenge] {
        let all = allChallenges
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")

        let calendar = Calendar.current
        let today = Date()
        var results: [DailyChallenge] = []

        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dateStr = Self.dateString(from: date)
                if let challenge = all[dateStr] {
                    results.append(challenge)
                }
            }
        }
        return results
    }

    var totalCompleted: Int {
        allChallenges.values.filter { $0.completed }.count
    }
}
