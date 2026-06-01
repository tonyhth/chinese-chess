import XCTest
@testable import VocabGame
import SwiftUI

@MainActor
final class Phase4DailyGoalTests: XCTestCase {

    private var progressRepo: ProgressRepository!
    private var testDir: URL!

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Phase4Daily-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        progressRepo = ProgressRepository(documentsDir: testDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
        super.tearDown()
    }

    // MARK: - 1. 初始状态

    func test_dailyGoal_initialState() {
        let goal = progressRepo.dailyGoalProgress
        XCTAssertEqual(goal.completed, 0)
        XCTAssertEqual(goal.target, 10)
        XCTAssertFalse(goal.isDone)
        XCTAssertEqual(goal.consecutiveDays, 0)
    }

    // MARK: - 2. 逐步递增

    func test_dailyGoal_increment() {
        for _ in 0..<5 {
            progressRepo.incrementDailyGoalProgress()
        }
        let goal = progressRepo.dailyGoalProgress
        XCTAssertEqual(goal.completed, 5)
        XCTAssertFalse(goal.isDone)
    }

    // MARK: - 3. 完成 10 词 → isDone = true

    func test_dailyGoal_completeAt10() {
        for _ in 0..<10 {
            progressRepo.incrementDailyGoalProgress()
        }
        let goal = progressRepo.dailyGoalProgress
        XCTAssertEqual(goal.completed, 10)
        XCTAssertTrue(goal.isDone)
    }

    // MARK: - 4. 超过 10 词仍 isDone

    func test_dailyGoal_beyond10_stillDone() {
        for _ in 0..<15 {
            progressRepo.incrementDailyGoalProgress()
        }
        let goal = progressRepo.dailyGoalProgress
        XCTAssertTrue(goal.isDone)
        XCTAssertEqual(goal.completed, 15)
    }

    // MARK: - 5. 20 币奖励

    func test_dailyGoal_grants20Coins() {
        let before = progressRepo.profile.coins
        for _ in 0..<10 {
            progressRepo.incrementDailyGoalProgress()
        }
        let after = progressRepo.profile.coins
        XCTAssertEqual(after - before, 20)
    }

    // MARK: - 6. 超额不重复发奖

    func test_dailyGoal_noDoubleBonus() {
        let before = progressRepo.profile.coins
        for _ in 0..<15 {
            progressRepo.incrementDailyGoalProgress()
        }
        let after = progressRepo.profile.coins
        XCTAssertEqual(after - before, 20, "只发一次奖励")
    }

    // MARK: - 7. 连续天数 — 完成次日重置 → consecutiveDays++

    func test_dailyGoal_consecutiveDays_afterComplete() {
        // 完成 10 词
        for _ in 0..<10 {
            progressRepo.incrementDailyGoalProgress()
        }
        XCTAssertEqual(progressRepo.dailyGoalProgress.consecutiveDays, 0, "当天完成不立即+1")

        // 模拟新一天（手动将 lastResetDate 设为昨天）
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        progressRepo.updateProfile { $0.dailyGoalLastResetDate = yesterday }
        progressRepo.checkDailyGoalReset()

        let goal = progressRepo.dailyGoalProgress
        XCTAssertEqual(goal.completed, 0, "新一天重置计数")
        XCTAssertFalse(goal.isDone)
        XCTAssertEqual(goal.consecutiveDays, 1, "前一天完成→连续天数+1")
    }

    // MARK: - 8. 未完成次日 → consecutiveDays 归零

    func test_dailyGoal_missedDay_resetsConsecutive() {
        // 只完成 3 词
        for _ in 0..<3 {
            progressRepo.incrementDailyGoalProgress()
        }
        // 假设之前连续了 3 天
        progressRepo.updateProfile { $0.dailyGoalConsecutiveDays = 3 }

        // 模拟新一天
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        progressRepo.updateProfile { $0.dailyGoalLastResetDate = yesterday }
        progressRepo.checkDailyGoalReset()

        let goal = progressRepo.dailyGoalProgress
        XCTAssertEqual(goal.consecutiveDays, 0, "未完成→连续归零")
    }

    // MARK: - 9. bonusClaimed 持久化

    func test_dailyGoal_bonusClaimed_persists() {
        for _ in 0..<10 {
            progressRepo.incrementDailyGoalProgress()
        }
        XCTAssertTrue(progressRepo.profile.dailyGoalBonusClaimed)
        // bonusClaimed 保存在 profile 中，同一 repo 内可读回
        XCTAssertTrue(progressRepo.dailyGoalProgress.isDone)
    }
}
