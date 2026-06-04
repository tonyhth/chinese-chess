import Foundation

@Observable
class StatsViewModel {
    private var _refreshTrigger = false
    var stats: GameStats {
        _ = _refreshTrigger  // 依赖触发器，保证读取时被追踪
        return StatsManager.shared.stats
    }

    /// 人机对战统计（按难度）
    func aiStats(for difficulty: AIDifficulty) -> WinLossDraw {
        stats.vsAI[difficulty.rawValue, default: WinLossDraw()]
    }

    /// 人机总胜率
    var totalAIWinRate: Double {
        let all = stats.vsAI.values.reduce(WinLossDraw()) { acc, next in
            WinLossDraw(wins: acc.wins + next.wins, losses: acc.losses + next.losses, draws: acc.draws + next.draws)
        }
        return all.winRate
    }

    /// 刷新统计
    func refresh() {
        _refreshTrigger.toggle()
    }

    /// 重置所有统计
    func resetAll() {
        StatsManager.shared.reset()
        _refreshTrigger.toggle()
    }
}
