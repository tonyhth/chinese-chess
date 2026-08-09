import Foundation

// MARK: - 胜率统计模型

struct WinLossDraw: Codable, Equatable {
    var wins: Int = 0
    var losses: Int = 0
    var draws: Int = 0

    var total: Int { wins + losses + draws }
    var winRate: Double {
        total == 0 ? 0 : Double(wins) / Double(total)
    }
}

struct GameStats: Codable, Equatable {
    var vsAI: [String: WinLossDraw] = [:]   // AIDifficulty.rawValue -> WinLossDraw
    var puzzlesCompleted: Int = 0
    var puzzlesTotal: Int = 0
}

// MARK: - 统计管理器

final class StatsManager {
    static let shared = StatsManager()

    private let defaults: UserDefaults
    private let statsKey = "chinesechess.stats"
    private let migrationVersionKey = "chinesechess.stats.migration.v6"

    private init() {
        self.defaults = .standard
        migrateLegacyStatsIfNeeded()
    }

    /// 测试用初始化器，允许注入隔离的 UserDefaults
    init(defaults: UserDefaults) {
        self.defaults = defaults
        migrateLegacyStatsIfNeeded()
    }

    // MARK: - v6.0 旧统计 key 迁移

    /// 将旧枚举 rawValue key（beginner/easy/medium/hard/master）迁移到新 key（lvl1-lvl5）
    private func migrateLegacyStatsIfNeeded() {
        // 防重复迁移
        if defaults.bool(forKey: migrationVersionKey) { return }

        var s = stats
        let legacyMap: [(String, String)] = [
            ("beginner", "lvl1"),
            ("easy",     "lvl2"),
            ("medium",   "lvl3"),
            ("hard",     "lvl4"),
            ("master",   "lvl5"),
        ]

        var changed = false
        for (oldKey, newKey) in legacyMap {
            if let record = s.vsAI[oldKey] {
                // 合并到新 key（新 key 已有数据则累加）
                var existing = s.vsAI[newKey] ?? WinLossDraw()
                existing.wins += record.wins
                existing.losses += record.losses
                existing.draws += record.draws
                s.vsAI[newKey] = existing
                s.vsAI.removeValue(forKey: oldKey)
                changed = true
            }
        }

        if changed {
            save(s)
        }
        defaults.set(true, forKey: migrationVersionKey)
    }

    // MARK: - 读取

    var stats: GameStats {
        guard let data = defaults.data(forKey: statsKey) else {
            return GameStats()
        }
        guard let decoded = try? JSONDecoder().decode(GameStats.self, from: data) else {
            return GameStats()
        }
        return decoded
    }

    // MARK: - 人机统计

    func recordWin(for difficulty: AIDifficulty) {
        var s = stats
        let key = difficulty.rawValue
        var record = s.vsAI[key, default: WinLossDraw()]
        record.wins += 1
        s.vsAI[key] = record
        save(s)
    }

    func recordLoss(for difficulty: AIDifficulty) {
        var s = stats
        let key = difficulty.rawValue
        var record = s.vsAI[key, default: WinLossDraw()]
        record.losses += 1
        s.vsAI[key] = record
        save(s)
    }

    func recordDraw(for difficulty: AIDifficulty) {
        var s = stats
        let key = difficulty.rawValue
        var record = s.vsAI[key, default: WinLossDraw()]
        record.draws += 1
        s.vsAI[key] = record
        save(s)
    }

    // MARK: - 重置

    func reset() {
        save(GameStats())
    }

    // MARK: - 内部

    private func save(_ stats: GameStats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        defaults.set(data, forKey: statsKey)
    }
}
