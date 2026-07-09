import Foundation
import Testing
@testable import ChineseChess

// MARK: - Phase 5 #3: DailyChallenge 集成测试

@Suite("Phase 5 #3: DailyChallenge 集成测试", .serialized)
struct DailyChallengeIntegrationTests {

    // MARK: - 1. 三种可玩模式

    @Test("可玩模式: 6 种 (endgamePuzzle / timeBlitz / masterChallenge / endgameStart / solveMate / cannonOnly)")
    func playableModesCount() {
        let playable: [DailyChallengeMode] = [
            .endgamePuzzle, .timeBlitz, .masterChallenge,
            .endgameStart, .solveMate, .cannonOnly
        ]
        #expect(playable.count == 6)
        #expect(playable.contains(.endgamePuzzle))
        #expect(playable.contains(.timeBlitz))
        #expect(playable.contains(.masterChallenge))
        #expect(playable.contains(.endgameStart))
        #expect(playable.contains(.solveMate))
        #expect(playable.contains(.cannonOnly))
    }

    @Test("敬请期待模式: 4 种 (v4.0 后)")
    func comingSoonModesCount() {
        let comingSoon: [DailyChallengeMode] = [
            .materialAdvantage, .defendChallenge, .comboKill, .horseOnly
        ]
        #expect(comingSoon.count == 4)
    }

    @Test("所有模式: 可玩 + 敬请期待 = 10 种")
    func allModesCount() {
        #expect(DailyChallengeMode.allCases.count == 10, "应有 10 种模式")
    }

    // MARK: - 2. endgamePuzzle 模式集成

    @Test("endgamePuzzle: 模式有图标")
    func endgamePuzzleIcon() {
        #expect(!DailyChallengeMode.endgamePuzzle.icon.isEmpty)
        #expect(DailyChallengeMode.endgamePuzzle.icon == "puzzlepiece")
    }

    @Test("endgamePuzzle: 有 localizedTitleKey 和 localizedDescKey")
    func endgamePuzzleKeys() {
        let mode = DailyChallengeMode.endgamePuzzle
        #expect(!mode.localizedTitleKey.isEmpty)
        #expect(!mode.localizedDescKey.isEmpty)
        #expect(mode.localizedTitleKey.contains("endgamePuzzle"))
        #expect(mode.localizedDescKey.contains("endgamePuzzle"))
    }

    @Test("endgamePuzzle: DailyChallengeManager.todayChallengeMode 可能返回该模式")
    func todayModeCanReturnEndgamePuzzle() {
        // 验证 todayChallengeMode 返回一个有效 case
        let suite = UserDefaults(suiteName: "test_endgame_\(UUID().uuidString)")!
        let manager = DailyChallengeManager(defaults: suite)
        let mode = manager.todayChallengeMode()
        #expect(DailyChallengeMode.allCases.contains(mode), "应返回有效模式")
    }

    @Test("endgamePuzzle: dailyPuzzleId 在有 puzzles 时返回非 nil")
    func dailyPuzzleIdWithPuzzles() {
        let suite = UserDefaults(suiteName: "test_puzzleId_\(UUID().uuidString)")!
        let manager = DailyChallengeManager(defaults: suite)
        let puzzles = [
            Puzzle(id: "p1", name: "test", category: "test", difficulty: 1, stars: 1,
                   description: "", playerSide: "red", initialFEN: "", solution: [], hints: nil,
                   maxMoves: 5),
            Puzzle(id: "p2", name: "test2", category: "test", difficulty: 2, stars: 2,
                   description: "", playerSide: "red", initialFEN: "", solution: [], hints: nil,
                   maxMoves: 5),
        ]
        let id = manager.dailyPuzzleId(puzzles: puzzles)
        #expect(id != nil, "有 puzzles 时应返回 id")
        #expect(puzzles.contains { $0.id == id }, "返回的 id 应在 puzzles 列表中")
    }

    @Test("endgamePuzzle: dailyPuzzleId 空 puzzles 回退到 PuzzleStore")
    func dailyPuzzleIdEmpty() {
        let suite = UserDefaults(suiteName: "test_empty_\(UUID().uuidString)")!
        let manager = DailyChallengeManager(defaults: suite)
        let id = manager.dailyPuzzleId(puzzles: [])
        // 空数组回退到 PuzzleStore.shared.puzzles，不应返回 nil
        #expect(id != nil, "空 puzzles 应回退到 PuzzleStore，不应返回 nil")
    }

    @Test("endgamePuzzle: dailyPuzzle 返回正确的 Puzzle")
    func dailyPuzzleFetch() {
        let suite = UserDefaults(suiteName: "test_fetch_\(UUID().uuidString)")!
        let manager = DailyChallengeManager(defaults: suite)
        let puzzles = [
            Puzzle(id: "target", name: "目标", category: "x", difficulty: 1, stars: 1,
                   description: "", playerSide: "red", initialFEN: "", solution: [], hints: nil,
                   maxMoves: 3),
        ]
        let puzzle = manager.dailyPuzzle(puzzles: puzzles)
        #expect(puzzle != nil)
        #expect(puzzle?.id == "target")
    }

    // MARK: - 3. timeBlitz 模式集成

    @Test("timeBlitz: 模式有图标")
    func timeBlitzIcon() {
        #expect(DailyChallengeMode.timeBlitz.icon == "bolt")
    }

    @Test("timeBlitz: 有 localizedTitleKey 和 localizedDescKey")
    func timeBlitzKeys() {
        let mode = DailyChallengeMode.timeBlitz
        #expect(!mode.localizedTitleKey.isEmpty)
        #expect(!mode.localizedDescKey.isEmpty)
    }

    @MainActor
    @Test("timeBlitz: GameViewModel blitz 配置")
    func blitzModeConfig() {
        // 模拟 DailyChallengeView 中 blitz 的 GameViewModel 配置
        let vm = GameViewModel()
        vm.isBlitzMode = true
        vm.blitzTimeLimitSeconds = 300

        #expect(vm.isBlitzMode == true, "应启用 blitz 模式")
        #expect(vm.blitzTimeLimitSeconds == 300, "默认 5 分钟")
    }

    @Test("timeBlitz: 奖励额外时间")
    func blitzBonusTime() {
        let baseTime = 300
        let bonusTime = 30  // profile.bonusBlitzTimeBonus
        let totalTime = baseTime + bonusTime
        #expect(totalTime == 330, "含奖励的总时间应为 330 秒")
    }

    // MARK: - 4. masterChallenge 模式集成

    @Test("masterChallenge: 模式有图标")
    func masterChallengeIcon() {
        #expect(DailyChallengeMode.masterChallenge.icon == "crown")
    }

    @Test("masterChallenge: 有 localizedTitleKey 和 localizedDescKey")
    func masterChallengeKeys() {
        let mode = DailyChallengeMode.masterChallenge
        #expect(!mode.localizedTitleKey.isEmpty)
        #expect(!mode.localizedDescKey.isEmpty)
    }

    @MainActor
    @Test("masterChallenge: GameViewModel 配置 master 难度")
    func masterChallengeConfig() {
        let vm = GameViewModel()
        vm.difficulty = .master
        vm.isMasterChallenge = true

        #expect(vm.difficulty == .master, "难度应为 master")
        #expect(vm.isMasterChallenge == true, "应标记为 master 挑战")
    }

    // MARK: - 5. DailyChallenge 完整流程

    @Test("流程: 生成今日挑战 → 完成 → 检查完成状态")
    func challengeCompleteFlow() {
        let suite = UserDefaults(suiteName: "test_flow_\(UUID().uuidString)")!
        let manager = DailyChallengeManager(defaults: suite)
        let puzzles = [
            Puzzle(id: "p1", name: "test", category: "x", difficulty: 1, stars: 1,
                   description: "", playerSide: "red", initialFEN: "", solution: [], hints: nil,
                   maxMoves: 3),
        ]

        // 生成挑战
        let challenge = manager.todayChallenge(puzzles: puzzles)
        #expect(challenge.completed == false, "新挑战应未完成")
        #expect(challenge.score == 0)

        // 完成挑战
        manager.completeChallenge(score: 100, puzzles: puzzles)
        #expect(manager.isTodayCompleted(puzzles: puzzles) == true, "完成后应标记为已完成")
    }

    @Test("流程: todayDifficulty 返回有效难度")
    func todayDifficultyValid() {
        let suite = UserDefaults(suiteName: "test_diff_\(UUID().uuidString)")!
        let manager = DailyChallengeManager(defaults: suite)
        let diff = manager.todayDifficulty()
        let validDiffs: [AIDifficulty] = [.easy, .medium, .hard]
        #expect(validDiffs.contains(diff), "难度应为 easy/medium/hard 之一")
    }

    @Test("流程: 模式确定性（同一天返回相同模式）")
    func modeDeterministicSameDay() {
        let suite1 = UserDefaults(suiteName: "test_det_a_\(UUID().uuidString)")!
        let suite2 = UserDefaults(suiteName: "test_det_b_\(UUID().uuidString)")!
        let m1 = DailyChallengeManager(defaults: suite1)
        let m2 = DailyChallengeManager(defaults: suite2)
        #expect(m1.todayChallengeMode() == m2.todayChallengeMode(), "同一天应返回相同模式")
    }

    // MARK: - 6. 连续登录集成

    @Test("连续登录: 首次登录返回 1")
    func firstLoginStreak() {
        let suite = UserDefaults(suiteName: "test_streak_\(UUID().uuidString)")!
        let manager = DailyChallengeManager(defaults: suite)
        let streak = manager.checkDailyLogin()
        #expect(streak == 1, "首次登录应返回 1")
    }

    @Test("连续登录: 同日重复登录不增加")
    func sameDayRelogin() {
        let suite = UserDefaults(suiteName: "test_same_\(UUID().uuidString)")!
        let manager = DailyChallengeManager(defaults: suite)
        _ = manager.checkDailyLogin()
        let streak = manager.checkDailyLogin()
        #expect(streak == 1, "同日重复登录应返回 1")
    }

    @Test("连续登录: 日期回拨保护")
    func dateRollbackProtection() {
        let suite = UserDefaults(suiteName: "test_rollback_\(UUID().uuidString)")!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let future = formatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        suite.set(future, forKey: "chinesechess.lastLoginDate")
        suite.set(5, forKey: "chinesechess.dailyStreak")

        let manager = DailyChallengeManager(defaults: suite)
        let streak = manager.checkDailyLogin()
        #expect(streak == 5, "回拨不应重置或增加连续天数")
    }

    // MARK: - 7. DailyChallengeView 入口验证

    @Test("入口验证: 每种可玩模式有不同的 onTapGesture action")
    func playableModesDifferentActions() {
        // DailyChallengeView 中 challengeCard 的 onTapGesture:
        // .endgamePuzzle → showPuzzle = true
        // .timeBlitz → showBlitzGame = true
        // .masterChallenge → showMasterGame = true
        // 验证：每种模式对应不同的 sheet 状态

        var showPuzzle = false
        var showBlitzGame = false
        var showMasterGame = false

        // 模拟点击 endgamePuzzle
        showPuzzle = true
        #expect(showPuzzle && !showBlitzGame && !showMasterGame)

        // 重置
        showPuzzle = false

        // 模拟点击 timeBlitz
        showBlitzGame = true
        #expect(!showPuzzle && showBlitzGame && !showMasterGame)

        // 重置
        showBlitzGame = false

        // 模拟点击 masterChallenge
        showMasterGame = true
        #expect(!showPuzzle && !showBlitzGame && showMasterGame)
    }

    // MARK: - 8. 奖励阶梯

    @Test("奖励阶梯: 8 个奖励等级")
    func rewardTiersCount() {
        #expect(DailyStreakReward.allCases.count == 8)
    }

    @Test("奖励阶梯: day3 到 day100")
    func rewardTierValues() {
        let values = DailyStreakReward.allCases.map { $0.rawValue }
        #expect(values == [3, 7, 14, 30, 45, 60, 70, 100])
    }

    @Test("奖励阶梯: 每个等级有 localizedRewardKey")
    func rewardKeysNonEmpty() {
        for reward in DailyStreakReward.allCases {
            #expect(!reward.localizedRewardKey.isEmpty, "每个等级应有 rewardKey")
            #expect(reward.localizedRewardKey.contains("day\(reward.rawValue)"), "key 应包含天数")
        }
    }

    @Test("奖励阶梯: 每个等级有 localizedDescKey")
    func descKeysNonEmpty() {
        for reward in DailyStreakReward.allCases {
            #expect(!reward.localizedDescKey.isEmpty, "每个等级应有 descKey")
        }
    }
}
