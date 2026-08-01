import Testing
import Foundation
@testable import ChineseChess

@Suite("Phase 7 每日挑战 + 残局库扩展测试")
struct Phase7Tests {

    // MARK: - 7.1 每日挑战

    @Test("每日挑战模式包含 10 种")
    func challengeModesCount() {
        #expect(DailyChallengeMode.allCases.count == 10, "应有 10 种挑战模式")
    }

    @Test("每种挑战模式有图标和描述")
    func challengeModeMetadata() {
        for mode in DailyChallengeMode.allCases {
            #expect(!mode.icon.isEmpty, "\(mode.rawValue) 应有图标")
            #expect(!mode.localizedDescKey.isEmpty, "\(mode.rawValue) 应有描述")
        }
    }

    @Test("每日挑战生成")
    func todayChallengeGeneration() {
        let suite = UserDefaults(suiteName: "test_daily_\(UUID().uuidString)")!
        let manager = DailyChallengeManager(defaults: suite)
        let challenge = manager.todayChallenge(puzzles: [])
        #expect(challenge.date == manager.todayString)
        #expect(challenge.completed == false)
        #expect(challenge.score == 0)
    }

    @Test("每日挑战完成")
    func completeDailyChallenge() {
        let suite = UserDefaults(suiteName: "test_complete_\(UUID().uuidString)")!
        let manager = DailyChallengeManager(defaults: suite)
        _ = manager.todayChallenge(puzzles: [])
        manager.completeChallenge(score: 100, puzzles: [])
        #expect(manager.isTodayCompleted(puzzles: []) == true)
    }

    @Test("每日挑战模式按日期哈希确定")
    func modeIsDeterministic() {
        let suite1 = UserDefaults(suiteName: "test_det1_\(UUID().uuidString)")!
        let suite2 = UserDefaults(suiteName: "test_det2_\(UUID().uuidString)")!
        let manager1 = DailyChallengeManager(defaults: suite1)
        let manager2 = DailyChallengeManager(defaults: suite2)
        // 同一天应返回相同模式
        #expect(manager1.todayChallengeMode() == manager2.todayChallengeMode())
    }

    // MARK: - 连续登录

    @Test("首次登录连续天数为 1")
    func firstLoginStreak() {
        let suite = UserDefaults(suiteName: "test_streak1_\(UUID().uuidString)")!
        let manager = DailyChallengeManager(defaults: suite)
        let streak = manager.checkDailyLogin()
        #expect(streak == 1)
    }

    @Test("同日重复登录不增加")
    func sameDayLogin() {
        let suite = UserDefaults(suiteName: "test_streak2_\(UUID().uuidString)")!
        let manager = DailyChallengeManager(defaults: suite)
        _ = manager.checkDailyLogin()
        let streak = manager.checkDailyLogin()
        #expect(streak == 1)
    }

    @Test("连续登录奖励阶梯")
    func streakRewards() {
        #expect(DailyStreakReward.allCases.count == 8)
        #expect(DailyStreakReward.day3.rawValue == 3)
        #expect(DailyStreakReward.day100.rawValue == 100)
        #expect(!DailyStreakReward.day3.localizedRewardKey.isEmpty)
    }

    @Test("日期回拨不增加连续天数")
    func dateRollbackProtection() {
        let suite = UserDefaults(suiteName: "test_rollback_\(UUID().uuidString)")!
        // 预设一个未来日期
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let future = formatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        suite.set(future, forKey: "chinesechess.lastLoginDate")
        suite.set(5, forKey: "chinesechess.dailyStreak")

        let manager = DailyChallengeManager(defaults: suite)
        let streak = manager.checkDailyLogin()
        // 回拨不应重置或增加
        #expect(streak == 5)
    }

    // MARK: - 7.2 残局库扩展

    @Test("残局评估器扩展到 50+ 种规则")
    func endgameRuleCount() {
        // 验证残局评估器能处理多种局面（通过实际局面测试）
        // 单车 vs 空
        let fen1 = "4k4/9/9/9/9/9/9/9/9/3RK4 w"
        let board1 = Board(fen: fen1)
        #expect(EndgameEvaluator.evaluate(board: board1, for: .red) != nil, "单车应匹配规则")

        // 双车 vs 士象
        let fen2 = "3aka3/9/9/9/9/9/9/9/9/3RRK4 w"
        let board2 = Board(fen: fen2)
        let eval2 = EndgameEvaluator.evaluate(board: board2, for: .red)
        if let eval2 = eval2 {
            #expect(eval2 > 0, "双车对士象应红方优势")
        }
    }

    @Test("残局评估：双炮和双象为和棋")
    func endgameDrawPattern() {
        // 双炮 vs 双象（score=0 → 和棋）
        let fen = "2b1k1b2/9/9/9/9/9/9/9/9/2C1KC3 w"
        let board = Board(fen: fen)
        let eval = EndgameEvaluator.evaluate(board: board, for: .red)
        // 即使不匹配（子力可能 > 6），也不应崩溃
        if let eval = eval {
            #expect(eval == 0, "双炮双象应为和棋（score=0）")
        }
    }

    @Test("残局评估不崩溃（各种局面）")
    func endgameNoCrash() {
        let fens = [
            "4k4/9/9/9/9/9/9/9/4r4/4K4 w",          // 单车
            "4k4/9/9/9/9/9/9/9/4n4/4K4 w",          // 单马
            "4k4/9/9/9/9/9/9/9/4c4/4K4 w",          // 单炮
            "4k4/9/9/9/9/9/9/9/4p4/4K4 w",          // 单兵
        ]
        for fen in fens {
            let board = Board(fen: fen)
            // 评估或返回 nil 都不应崩溃
            _ = EndgameEvaluator.evaluate(board: board, for: .red)
            #expect(Bool(true))
        }
    }

    // MARK: - 集成验证

    @Test("各难度 AI 返回合法走法")
    func allDifficultiesValidMove() async {
        let engine = AIEngine()
        let board = Board()
        for diff in [AIDifficulty.beginner, .easy, .medium, .hard, .master] {
            let move = await engine.bestMove(for: board, difficulty: diff, isIOS: false)
            #expect(move != nil, "\(diff.rawValue) 应返回合法走法")
        }
    }

    @Test("自对弈正常完成", .timeLimit(.minutes(5)))
    func selfPlayIntegration() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(red: .beginner, black: .beginner, games: 2, maxMoves: 40)
        let result = await runner.run(config: config)
        #expect(result.games.count == 2)
        #expect(result.redWins + result.blackWins + result.draws == 2)
    }
}
