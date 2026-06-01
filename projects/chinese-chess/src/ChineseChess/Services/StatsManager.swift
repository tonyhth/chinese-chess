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

struct PVPStats: Codable, Equatable {
    var totalGames: Int = 0
    var draws: Int = 0
}

struct GameStats: Codable, Equatable {
    var vsAI: [String: WinLossDraw] = [:]   // AIDifficulty.rawValue -> WinLossDraw
    var pvp: PVPStats = PVPStats()
    var puzzlesCompleted: Int = 0
    var puzzlesTotal: Int = 0
}

// MARK: - 统计管理器

final class StatsManager {
    static let shared = StatsManager()

    private let defaults: UserDefaults
    private let statsKey = "chinesechess.stats"

    private init() {
        self.defaults = .standard
    }

    /// 测试用初始化器，允许注入隔离的 UserDefaults
    init(defaults: UserDefaults) {
        self.defaults = defaults
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

    // MARK: - 人人对战统计

    func recordPVPGame(draw: Bool) {
        var s = stats
        s.pvp.totalGames += 1
        if draw {
            s.pvp.draws += 1
        }
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
