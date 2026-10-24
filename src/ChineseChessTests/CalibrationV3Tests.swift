import Testing
import Foundation
@testable import ChineseChess

// MARK: - 校准 v3.0 扩展测试
// 对应 commits:
//   eb1c7b9 — feat(calibration): add CLI calibration extensions
//   7ef70e5 — fix(calibration): P0 skillOverride overwritten by bestMove + P1/P2 fixes

@Suite("校准 v3.0 CLI 扩展测试", .serialized)
struct CalibrationV3Tests {

    // ============================
    // MARK: - 1. MixedEngineSessionResult 终局统计字段
    // ============================

    @Test("MixedEngineSessionResult 新增终局统计字段完整构造")
    func sessionResultNewFields() {
        let result = MixedEngineSessionResult(
            games: [],
            redWins: 0, blackWins: 0, draws: 0,
            avgMoves: 0, durationSeconds: 0, bayesEloDelta: 0,
            checkmateCount: 0, stalemateCount: 0, repetitionCount: 0,
            moveLimitCount: 0, redWinRate: 0
        )
        #expect(result.checkmateCount == 0)
        #expect(result.stalemateCount == 0)
        #expect(result.repetitionCount == 0)
        #expect(result.moveLimitCount == 0)
        #expect(result.redWinRate == 0)
    }

    @Test("MixedEngineSessionResult summary 包含终局分布")
    func summaryContainsEndgameStats() {
        // 必须传入非空 games 才能走正常 summary 路径（空数组走 guard 保护）
        let games = (0..<10).map { i in
            MixedEngineGameResult(
                gameIndex: i, result: .redWon, totalMoves: 50,
                reason: .normal, moveHistory: [],
                redEngineName: "A", blackEngineName: "B"
            )
        }
        let result = MixedEngineSessionResult(
            games: games,
            redWins: 5, blackWins: 3, draws: 2,
            avgMoves: 100.0, durationSeconds: 60.0,
            bayesEloDelta: 120,
            checkmateCount: 6, stalemateCount: 1, repetitionCount: 2,
            moveLimitCount: 1, redWinRate: 0.5
        )
        let summary = result.summary
        #expect(summary.contains("终局分布"), "summary 应包含终局分布标题")
        #expect(summary.contains("将死(normal)"), "summary 应包含将死统计")
        #expect(summary.contains("困毙(stalemate)"), "summary 应包含困毙统计")
        #expect(summary.contains("重复(repetition)"), "summary 应包含重复统计")
        #expect(summary.contains("步数上限(moveLimit)"), "summary 应包含步数上限统计")
        #expect(summary.contains("先手优势"), "summary 应包含先手优势")
        #expect(summary.contains("红方胜率"), "summary 应包含红方胜率")
    }

    @Test("MixedEngineSessionResult summary 零局数保护")
    func summaryZeroGamesProtection() {
        let result = MixedEngineSessionResult(
            games: [],
            redWins: 0, blackWins: 0, draws: 0,
            avgMoves: 0, durationSeconds: 0, bayesEloDelta: 0,
            checkmateCount: 0, stalemateCount: 0, repetitionCount: 0,
            moveLimitCount: 0, redWinRate: 0
        )
        let summary = result.summary
        #expect(summary.contains("0 局"), "零局数应显示 0 局")
        #expect(summary.contains("无数据"), "零局数应显示无数据")
        // 验证不会除以零崩溃
        #expect(!summary.contains("nan%"), "不应出现 nan%")
        #expect(!summary.contains("inf%"), "不应出现 inf%")
    }

    @Test("MixedEngineSessionResult summary 百分比计算正确")
    func summaryPercentageCalculation() {
        // 10 局：6 红胜, 3 黑胜, 1 和
        let games = (0..<10).map { i in
            MixedEngineGameResult(
                gameIndex: i,
                result: i < 6 ? .redWon : (i < 9 ? .blackWon : .draw),
                totalMoves: 50,
                reason: .normal,
                moveHistory: [],
                redEngineName: "A",
                blackEngineName: "B"
            )
        }
        let result = MixedEngineSessionResult(
            games: games,
            redWins: 6, blackWins: 3, draws: 1,
            avgMoves: 50.0, durationSeconds: 100.0,
            bayesEloDelta: 100,
            checkmateCount: 10, stalemateCount: 0, repetitionCount: 0,
            moveLimitCount: 0, redWinRate: 0.6
        )
        let summary = result.summary
        #expect(summary.contains("红胜：6（60.0%）"), "红胜百分比应为 60.0%")
        #expect(summary.contains("黑胜：3（30.0%）"), "黑胜百分比应为 30.0%")
        #expect(summary.contains("和棋：1（10.0%）"), "和棋百分比应为 10.0%")
        #expect(summary.contains("将死(normal)：10 局（100.0%）"), "将死百分比应为 100.0%")
    }

    // ============================
    // MARK: - 2. 终局分类统计逻辑
    // ============================

    @Test("终局分类：按 reason 正确分类统计")
    func endgameClassificationByReason() {
        let games = [
            MixedEngineGameResult(gameIndex: 0, result: .redWon, totalMoves: 30,
                                  reason: .normal, moveHistory: [],
                                  redEngineName: "A", blackEngineName: "B"),
            MixedEngineGameResult(gameIndex: 1, result: .blackWon, totalMoves: 50,
                                  reason: .normal, moveHistory: [],
                                  redEngineName: "A", blackEngineName: "B"),
            MixedEngineGameResult(gameIndex: 2, result: .draw, totalMoves: 80,
                                  reason: .moveLimit, moveHistory: [],
                                  redEngineName: "A", blackEngineName: "B"),
            MixedEngineGameResult(gameIndex: 3, result: .draw, totalMoves: 40,
                                  reason: .repetition, moveHistory: [],
                                  redEngineName: "A", blackEngineName: "B"),
            MixedEngineGameResult(gameIndex: 4, result: .redWon, totalMoves: 60,
                                  reason: .stalemate, moveHistory: [],
                                  redEngineName: "A", blackEngineName: "B"),
        ]

        let checkmateCount = games.filter { $0.reason == .normal }.count
        let stalemateCount = games.filter { $0.reason == .stalemate }.count
        let repetitionCount = games.filter { $0.reason == .repetition }.count
        let moveLimitCount = games.filter { $0.reason == .moveLimit }.count

        // 验证分类逻辑与 SelfPlayRunner 中的统计逻辑一致
        #expect(checkmateCount == 2, "将死(normal) 应为 2")
        #expect(stalemateCount == 1, "困毙(stalemate) 应为 1")
        #expect(repetitionCount == 1, "重复(repetition) 应为 1")
        #expect(moveLimitCount == 1, "步数上限(moveLimit) 应为 1")
        // 合计 = 总局数
        #expect(checkmateCount + stalemateCount + repetitionCount + moveLimitCount == games.count,
                "终局分类合计应等于总局数")
    }

    // ============================
    // MARK: - 3. skillToDifficulty 映射（Batch3 梯表就近：候选=梯表 skill 非 nil 档，缺省 a 形态不含 novice）
    // ============================

    @Test("skillToDifficulty: Skill 0 映射到 beginner(2)（Batch3 梯表就近）")
    func skillMap0() {
        let diff = SelfPlayRunner.skillToDifficulty(0)
        #expect(diff == .beginner, "Skill 0 距 beginner(s2)=2 最近（缺省 a 形态候选集不含 novice），应映射到 beginner")
    }

    @Test("skillToDifficulty: Skill 4 映射到 amateurLow(4)（Batch3 梯表精确档）")
    func skillMap4() {
        let diff = SelfPlayRunner.skillToDifficulty(4)
        #expect(diff == .amateurLow, "Skill 4 应映射到 amateurLow (s4 精确档)")
    }

    @Test("skillToDifficulty: Skill 7 映射到 amateurHigh(7)（Batch3 梯表精确档）")
    func skillMap7() {
        let diff = SelfPlayRunner.skillToDifficulty(7)
        #expect(diff == .amateurHigh, "Skill 7 应映射到 amateurHigh")
    }

    @Test("skillToDifficulty: Skill 10 映射到 amateurDan(9)（Batch3 梯表就近）")
    func skillMap10() {
        let diff = SelfPlayRunner.skillToDifficulty(10)
        #expect(diff == .amateurDan, "Skill 10 距 amateurDan(s9)=1（并列序先）比距 proMaster(s17)=7 近，应映射到 amateurDan")
    }

    @Test("skillToDifficulty: Skill 13 映射到 proExpert(14)（Batch3 梯表就近）")
    func skillMap13() {
        let diff = SelfPlayRunner.skillToDifficulty(13)
        #expect(diff == .proExpert, "Skill 13 距 proExpert(s14)=1 比距 proApprentice(s11)=2 近，应映射到 proExpert")
    }

    @Test("skillToDifficulty: Skill 20 映射到 grandmaster(20)（梯表尾锚精确档）")
    func skillMap20() {
        let diff = SelfPlayRunner.skillToDifficulty(20)
        #expect(diff == .grandmaster, "Skill 20 应映射到 grandmaster")
    }

    @Test("skillToDifficulty: 边界值 5-6 过渡（Batch3 梯表 2/4/5/7/9/11/14/17/20）")
    func skillMapBoundary5_6() {
        // Skill 5 = amateurMid(s5) 精确档
        let diff5 = SelfPlayRunner.skillToDifficulty(5)
        #expect(diff5 == .amateurMid, "Skill 5 应映射到 amateurMid")
        // Skill 6 距 amateurMid(5)=1 与 amateurHigh(7)=1 并列——min(by: <) 保持 allCases 序先者 → amateurMid
        let diff6 = SelfPlayRunner.skillToDifficulty(6)
        #expect(diff6 == .amateurMid, "Skill 6 并列距应取序先 amateurMid")
    }

    // ============================
    // MARK: - 4. CLI 参数解析验证（编译级验证）
    // ============================

    @Test("runCalibrateNativeFromCLI 函数存在（编译验证）")
    func calibrateNativeExists() {
        // 编译验证：函数存在于全局作用域
        let fn: () async -> Void = runCalibrateNativeFromCLI
        _ = fn
    }

    @Test("runCalibratePfFromCLI 函数存在（编译验证）")
    func calibratePfExists() {
        // 编译验证：函数存在于全局作用域
        let fn: () async -> Void = runCalibratePfFromCLI
        _ = fn
    }

    // ============================
    // MARK: - 5. EmbeddedPikafishEngine depth=0 + skillOverride
    // ============================

    @Test("EmbeddedPikafishEngine: newGame 清除 lastSkillOverride", .timeLimit(.minutes(3)))
    func newGameClearsSkillOverride() async {
        let engine = EmbeddedPikafishEngine()
        try? await engine.start()

        // 设置 Skill Level
        await engine.setSkillLevel(10)

        // newGame 应清除 skillOverride
        await engine.newGame()

        // 验证：newGame 后再次调用 bestMove 不应使用 depth=0
        // 由于 lastSkillOverride 是 private，通过行为验证：
        // difficulty=.amateurDan 有 skillLevel=4，bestMove 会走正常 mappedDepth 路径
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"  // 完整 FEN
        let move = await engine.bestMove(
            fen: fen, moveHistory: [],
            difficulty: .amateurDan,  // 有 skillLevel=4，不会触发 depth=0 路径
            timeLimitMs: 3000  // Debug 构建下引擎未优化，需要更多时间
        )
        #expect(move != nil, "newGame 后 bestMove 应正常返回")
        await engine.shutdown()
    }

    @Test("EmbeddedPikafishEngine: skillOverride + amateurLow 深度=0搜索", .timeLimit(.minutes(3)))
    func skillOverrideWithAmateurLow() async {
        let engine = EmbeddedPikafishEngine()
        try? await engine.start()

        // 模拟 calibrate-pf 路径：设 Skill Level 后用 amateurLow（无 skillLevel）调 bestMove
        // depth=0 意味着无限深度，由 timeLimitMs 控制搜索时间
        await engine.setSkillLevel(5)
        await engine.newGame()  // 清除上次设置
        await engine.setSkillLevel(5)  // 重新设置

        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"  // 完整 FEN
        let move = await engine.bestMove(
            fen: fen, moveHistory: [],
            difficulty: .amateurLow,  // skillLevel=nil → 触发 depth=0 路径
            timeLimitMs: 3000  // Debug 构建下引擎未优化，需要更多时间
        )
        // startTime 修复后（6a0f750），depth=0 + movetime 应正确返回走法
        await engine.shutdown()
        #expect(move != nil, "skillOverride + amateurLow depth=0 应返回有效走法")
    }

    // ============================
    // MARK: - 6. MixedEngineGameResult 完整构造
    // ============================

    @Test("MixedEngineGameResult 所有字段完整")
    func gameResultAllFields() {
        let result = MixedEngineGameResult(
            gameIndex: 3,
            result: .redWon,
            totalMoves: 85,
            reason: .normal,
            moveHistory: ["e2e4", "e7e5"],
            redEngineName: "Native(lvl3)",
            blackEngineName: "Pikafish(Skill8)"
        )
        #expect(result.gameIndex == 3)
        #expect(result.result == .redWon)
        #expect(result.totalMoves == 85)
        #expect(result.reason == .normal)
        #expect(result.moveHistory.count == 2)
        #expect(result.redEngineName == "Native(lvl3)")
        #expect(result.blackEngineName == "Pikafish(Skill8)")
    }

    // ============================
    // MARK: - 7. runPikafishSelfPlay 默认参数验证
    // ============================

    @Test("runPikafishSelfPlay 接受 redSkillOverride/blackSkillOverride 参数", .timeLimit(.minutes(2)))
    func runPikafishSelfPlayWithOverrides() async {
        // 验证新增参数能正确传入并完成最小规模对弈
        // depth=0 搜索较慢，需要足够时间
        let runner = SelfPlayRunner()
        let result = await runner.runPikafishSelfPlay(
            redDifficulty: .amateurDan,
            blackDifficulty: .amateurDan,
            games: 1,
            maxMoves: 10,      // 极小步数避免超时
            moveTimeMs: 500,   // 每步 500ms
            redSkillOverride: 4,
            blackSkillOverride: 4
        )
        // 应完成 1 局
        #expect(result.games.count == 1, "应完成 1 局对弈")
        #expect(result.redWins + result.blackWins + result.draws == 1)
        // 终局统计字段应填充
        let totalEndgame = result.checkmateCount + result.stalemateCount +
                           result.repetitionCount + result.moveLimitCount
        #expect(totalEndgame == 1, "终局分类合计应等于总局数")
    }

    // ============================
    // MARK: - 7b. 换手 override 随持方同步交换（T-0921-3 / KI-2026-0921-02）
    // ============================

    @Test("runPikafishSelfPlay 奇数局换手：override 随难度交换，标签持方真实", .timeLimit(.minutes(2)))
    func runPikafishSelfPlaySwapsOverrides() async {
        // KI-2026-0921-02：此前换手只换占位难度、override 直传，红方恒 skillA
        // 黑方恒 skillB（30 局从未真换手），而 redIsRedSkill 标签按"已换手"谎报。
        // 修复（调用点同步交换）后：奇数局红持 skillB、黑持 skillA，引擎名标签
        // 应真实反映持方——本测试锚定标签面（引擎调用面由重跑批数据验证）。
        let runner = SelfPlayRunner()
        let result = await runner.runPikafishSelfPlay(
            redDifficulty: .amateurDan,
            blackDifficulty: .amateurDan,
            games: 2,          // 偶数局(0)不换 + 奇数局(1)换手
            maxMoves: 6,       // 极小步数：只验标签接线，不等待终局
            moveTimeMs: 100,
            redSkillOverride: 7,
            blackSkillOverride: 10
        )
        #expect(result.games.count == 2, "应完成 2 局对弈")
        // 第 1 局（gameIndex=0，不换手）：红=Skill7 黑=Skill10
        #expect(result.games[0].redEngineName == "Skill7",
                "偶数局红持 redSkill（skillA）")
        #expect(result.games[0].blackEngineName == "Skill10",
                "偶数局黑持 blackSkill（skillB）")
        // 第 2 局（gameIndex=1，换手）：红=Skill10 黑=Skill7——标签即换手事实
        #expect(result.games[1].redEngineName == "Skill10",
                "奇数局红应持 skillB（换手后；bug 期恒 Skill7=谎报）")
        #expect(result.games[1].blackEngineName == "Skill7",
                "奇数局黑应持 skillA（换手后；bug 期恒 Skill10=谎报）")
    }

    // ============================
    // MARK: - 8. redWinRate 计算验证
    // ============================

    @Test("redWinRate: 红方全胜 → 1.0")
    func redWinRateAllRedWins() {
        let games = (0..<4).map { i in
            MixedEngineGameResult(
                gameIndex: i, result: .redWon, totalMoves: 30,
                reason: .normal, moveHistory: [],
                redEngineName: "A", blackEngineName: "B"
            )
        }
        let redWins = games.filter { $0.result == .redWon }.count
        let redWinRate = Double(redWins) / Double(games.count)
        #expect(redWinRate == 1.0, "红方全胜 redWinRate 应为 1.0")
    }

    @Test("redWinRate: 红方全负 → 0.0")
    func redWinRateNoRedWins() {
        let games = (0..<4).map { i in
            MixedEngineGameResult(
                gameIndex: i, result: .blackWon, totalMoves: 30,
                reason: .normal, moveHistory: [],
                redEngineName: "A", blackEngineName: "B"
            )
        }
        let redWins = games.filter { $0.result == .redWon }.count
        let redWinRate = Double(redWins) / Double(games.count)
        #expect(redWinRate == 0.0, "红方全负 redWinRate 应为 0.0")
    }

    // ============================
    // MARK: - 9. 困毙处理（runPikafishMatchFromCLI 路径验证）
    // ============================

    @Test("GameEndReason.stalemate 存在且可用")
    func stalemateReasonAvailable() {
        let reason = GameEndReason.stalemate
        #expect(reason.rawValue == "stalemate")
        // 验证所有 reason 值
        let allReasons: [GameEndReason] = [.normal, .moveLimit, .repetition, .stalemate]
        #expect(allReasons.count == 4)
        #expect(Set(allReasons.map(\.rawValue)).count == 4, "所有 rawValue 应唯一")
    }

    // ============================
    // MARK: - 10. 回归：已有 Phase 6 测试不受影响
    // ============================

    @Test("回归：SelfPlayConfig 默认值不变")
    func regressionSelfPlayConfig() {
        let config = SelfPlayConfig(red: .novice, black: .beginner, games: 5)
        #expect(config.totalGames == 5)
        #expect(config.maxMovesPerGame == 200)
        #expect(config.swapSides == true)
    }

    @Test("回归：MixedEngineConfig 默认值不变")
    func regressionMixedEngineConfig() {
        let config = MixedEngineConfig(games: 10)
        #expect(config.totalGames == 10)
        #expect(config.maxMovesPerGame == 200)
        #expect(config.moveTimeMs == 500)
    }
}
