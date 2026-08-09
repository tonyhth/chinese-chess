import Testing
import Foundation
@testable import ChineseChess

// MARK: - Phase 5.2: StatsViewModel 统计准确性测试

@Suite("StatsViewModel 统计准确性")
struct StatsViewModelTests {

    // MARK: - 辅助

    /// 创建隔离的 StatsManager + StatsViewModel
    private func makeSUT() -> (StatsManager, StatsViewModel) {
        let suite = "test-stats-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let manager = StatsManager(defaults: defaults)
        // StatsViewModel 读取 StatsManager.shared，无法直接注入
        // 所以我们直接测试 StatsManager 的逻辑准确性
        return (manager, StatsViewModel())
    }

    // MARK: - WinLossDraw 测试

    @Test("WinLossDraw winRate 计算 — 全胜")
    func winRateAllWins() {
        let wld = WinLossDraw(wins: 10, losses: 0, draws: 0)
        #expect(wld.winRate == 1.0)
    }

    @Test("WinLossDraw winRate 计算 — 全负")
    func winRateAllLosses() {
        let wld = WinLossDraw(wins: 0, losses: 5, draws: 0)
        #expect(wld.winRate == 0.0)
    }

    @Test("WinLossDraw winRate 计算 — 混合")
    func winRateMixed() {
        let wld = WinLossDraw(wins: 3, losses: 2, draws: 1)
        #expect(wld.total == 6)
        #expect(wld.winRate == 0.5)  // 3/6 = 0.5
    }

    @Test("WinLossDraw winRate — 空记录")
    func winRateEmpty() {
        let wld = WinLossDraw()
        #expect(wld.total == 0)
        #expect(wld.winRate == 0.0)  // 除零保护
    }

    // MARK: - StatsManager 记录测试

    @Test("recordWin 增加胜场")
    func recordWin() {
        let (manager, _) = makeSUT()
        manager.recordWin(for: .amateurHigh)
        let stats = manager.stats
        let record = stats.vsAI[AIDifficulty.amateurHigh.rawValue]
        #expect(record?.wins == 1)
        #expect(record?.losses == 0)
    }

    @Test("recordLoss 增加负场")
    func recordLoss() {
        let (manager, _) = makeSUT()
        manager.recordLoss(for: .amateurLow)
        let stats = manager.stats
        let record = stats.vsAI[AIDifficulty.amateurLow.rawValue]
        #expect(record?.losses == 1)
        #expect(record?.wins == 0)
    }

    @Test("recordDraw 增加平场")
    func recordDraw() {
        let (manager, _) = makeSUT()
        manager.recordDraw(for: .amateurMid)
        let stats = manager.stats
        let record = stats.vsAI[AIDifficulty.amateurMid.rawValue]
        #expect(record?.draws == 1)
    }

    @Test("多次记录累积正确")
    func multipleRecords() {
        let (manager, _) = makeSUT()
        manager.recordWin(for: .beginner)
        manager.recordWin(for: .beginner)
        manager.recordLoss(for: .beginner)
        manager.recordDraw(for: .beginner)

        let record = manager.stats.vsAI[AIDifficulty.beginner.rawValue]
        #expect(record?.wins == 2)
        #expect(record?.losses == 1)
        #expect(record?.draws == 1)
        #expect(record?.total == 4)
    }

    @Test("reset 清空所有统计")
    func resetClears() {
        let (manager, _) = makeSUT()
        manager.recordWin(for: .beginner)
        manager.recordLoss(for: .amateurHigh)
        manager.reset()

        let stats = manager.stats
        #expect(stats.vsAI.isEmpty)
    }

    @Test("不同难度的统计独立")
    func independentDifficulties() {
        let (manager, _) = makeSUT()
        manager.recordWin(for: .beginner)
        manager.recordLoss(for: .amateurHigh)

        let stats = manager.stats
        let easyRecord = stats.vsAI[AIDifficulty.beginner.rawValue]
        let masterRecord = stats.vsAI[AIDifficulty.amateurHigh.rawValue]

        #expect(easyRecord?.wins == 1)
        #expect(easyRecord?.losses == 0)
        #expect(masterRecord?.wins == 0)
        #expect(masterRecord?.losses == 1)
    }
}
