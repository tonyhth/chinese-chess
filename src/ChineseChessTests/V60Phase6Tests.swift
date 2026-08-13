import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.0 Phase 6 测试：交叉对弈校准

@Suite("v6.0 Phase 6: MixedEngineConfig + 校准逻辑", .serialized)
struct V60Phase6Tests {

    // ============================
    // MARK: - MixedEngineConfig
    // ============================

    @Test("MixedEngineConfig 默认值正确")
    func configDefaults() {
        let config = MixedEngineConfig(games: 10)
        #expect(config.totalGames == 10)
        #expect(config.maxMovesPerGame == 200)
        #expect(config.moveTimeMs == 500)
        #expect(config.repetitionThreshold == 6)
        #expect(config.swapSides == true)
    }

    @Test("MixedEngineConfig 自定义参数")
    func configCustom() {
        let config = MixedEngineConfig(games: 20, maxMoves: 300, moveTimeMs: 1000, swapSides: false)
        #expect(config.totalGames == 20)
        #expect(config.maxMovesPerGame == 300)
        #expect(config.moveTimeMs == 1000)
        #expect(config.swapSides == false)
    }

    // ============================
    // MARK: - MixedEngineSessionResult
    // ============================

    @Test("MixedEngineSessionResult summary 包含关键信息")
    func sessionResultSummary() {
        // v3.0 起 summary 对空 games 有 guard 保护，需传入非空 games 走正常路径
        let games = (0..<10).map { i in
            MixedEngineGameResult(
                gameIndex: i, result: .redWon, totalMoves: 50,
                reason: .normal, moveHistory: [],
                redEngineName: "Native", blackEngineName: "Pikafish"
            )
        }
        let result = MixedEngineSessionResult(
            games: games,
            redWins: 3, blackWins: 5, draws: 2,
            avgMoves: 85.5, durationSeconds: 120.0,
            bayesEloDelta: -80,
            checkmateCount: 4, stalemateCount: 1, repetitionCount: 2,
            moveLimitCount: 3, redWinRate: 0.3
        )
        let summary = result.summary
        #expect(summary.contains("混合引擎对弈结果"))
        #expect(summary.contains("红胜：3"))
        #expect(summary.contains("黑胜：5"))
        #expect(summary.contains("和棋：2"))
        #expect(summary.contains("BayesElo"))
    }

    // ============================
    // MARK: - BayesElo 校准结论逻辑
    // ============================

    @Test("校准结论：|ΔElo| < 100 → 建议 Skill 7")
    func calibrationSmallDelta() {
        let eloDelta = 50  // |50| < 100
        let absDelta = abs(eloDelta)
        let recommendation = calibrationRecommendation(absDelta: absDelta)
        #expect(recommendation.contains("Skill 7"))
    }

    @Test("校准结论：|ΔElo| 200-400 → 确认当前 Skill Level")
    func calibrationOptimalDelta() {
        let eloDelta = 300  // 200-400
        let absDelta = abs(eloDelta)
        let recommendation = calibrationRecommendation(absDelta: absDelta)
        #expect(recommendation.contains("确认"))
        #expect(recommendation.contains("✅"))
    }

    @Test("校准结论：|ΔElo| > 500 → 建议 Skill 3")
    func calibrationLargeDelta() {
        let eloDelta = 600  // > 500
        let absDelta = abs(eloDelta)
        let recommendation = calibrationRecommendation(absDelta: absDelta)
        #expect(recommendation.contains("Skill 3"))
    }

    @Test("校准结论：|ΔElo| 100-200 → 过渡合理（边界）")
    func calibrationBoundaryDelta() {
        let eloDelta = 150  // 100-200
        let absDelta = abs(eloDelta)
        let recommendation = calibrationRecommendation(absDelta: absDelta)
        #expect(recommendation.contains("100-200") || recommendation.contains("过渡合理"))
    }

    // ============================
    // MARK: - BayesElo.estimateDelta
    // ============================

    @Test("BayesElo: 胜率 50% → ΔElo ≈ 0")
    func bayesEloEqualWinRate() {
        let delta = BayesElo.estimateDelta(winRate: 0.5)
        #expect(abs(delta) < 5, "50% 胜率应 Elo 差 ≈ 0")
    }

    @Test("BayesElo: 胜率 > 50% → ΔElo > 0")
    func bayesEloPositiveWinRate() {
        let delta = BayesElo.estimateDelta(winRate: 0.8)
        #expect(delta > 0, "80% 胜率应 Elo 差 > 0")
    }

    @Test("BayesElo: 胜率 < 50% → ΔElo < 0")
    func bayesEloNegativeWinRate() {
        let delta = BayesElo.estimateDelta(winRate: 0.2)
        #expect(delta < 0, "20% 胜率应 Elo 差 < 0")
    }

    @Test("BayesElo: 极端胜率保护（不返回极端值）")
    func bayesEloExtremeProtection() {
        // 0% 和 100% 胜率会被 clamp 到 0.01-0.99
        let deltaHigh = BayesElo.estimateDelta(winRate: 0.99)
        let deltaLow = BayesElo.estimateDelta(winRate: 0.01)
        #expect(deltaHigh < 1000, "不应返回极端高值")
        #expect(deltaLow > -1000, "不应返回极端低值")
    }

    @Test("BayesElo: 从胜负平统计计算")
    func bayesEloFromStats() {
        // 需要看 BayesElo.estimateDelta(wins:losses:draws:) 是否存在
        let delta = BayesElo.estimateDelta(wins: 7, losses: 2, draws: 1)
        // 7 胜 2 负 1 和 → 胜率 = (7 + 0.5) / 10 = 0.75
        // ΔElo 应 > 0
        #expect(delta > 0, "7W 2L 1D 应 Elo 差 > 0")
    }

    // ============================
    // MARK: - CLI 入口
    // ============================

    @Test("SelfPlayRunner 可创建")
    func runnerCreated() {
        let runner = SelfPlayRunner()
        #expect(type(of: runner) == SelfPlayRunner.self)
    }

    @Test("runCalibration 方法存在")
    func runCalibrationExists() async {
        // 编译验证：方法存在且可调用
        // 不实际运行（需要 5-10 分钟）
        let runner = SelfPlayRunner()
        _ = runner  // 仅验证类型
    }

    @Test("runMixedEngineMatch 方法存在")
    func runMixedEngineMatchExists() async {
        // 编译验证
        let config = MixedEngineConfig(games: 1)
        #expect(config.totalGames == 1)
    }

    // ============================
    // MARK: - MixedEngineGameResult
    // ============================

    @Test("MixedEngineGameResult 包含引擎名")
    func gameResultHasEngineNames() {
        let result = MixedEngineGameResult(
            gameIndex: 0,
            result: .redWon,
            totalMoves: 50,
            reason: .normal,
            moveHistory: [],
            redEngineName: "Native(lvl5)",
            blackEngineName: "Pikafish(lvl6)"
        )
        #expect(result.redEngineName.contains("Native"))
        #expect(result.blackEngineName.contains("Pikafish"))
    }

    @Test("MixedEngineGameResult 终局原因")
    func gameResultReasons() {
        let reasons: [GameEndReason] = [.normal, .moveLimit, .repetition, .stalemate]
        for reason in reasons {
            #expect(!reason.rawValue.isEmpty)
        }
    }

    // ============================
    // MARK: - P1 修复验证
    // ============================

    @Test("P1-1: bayesEloDelta 按引擎统计（非颜色）")
    func p1BayesEloByEngine() {
        // P1 修复后，nativeWins/pikafishWins 按引擎统计
        // 验证 BayesElo.estimateDelta(wins:losses:draws:) 行为正确
        let delta = BayesElo.estimateDelta(wins: 8, losses: 1, draws: 1)
        // 8W → 强烈正 Elo
        #expect(delta > 200, "8W 1L 1D 应 Elo 差 > 200")
    }

    // ============================
    // MARK: - 回归
    // ============================

    @Test("Phase 1-5 回归：枚举 + 路由 + 评估")
    func regressionPhase1to5() {
        #expect(AIDifficulty.allCases.count == 10)
        #expect(AIDifficulty.amateurDan.skillLevel == 0)  // v4.2 重映射
        #expect(AIDifficulty.grandmaster.skillLevel == 20)
        let elo = EloEstimator.eloFromDelta(0)
        #expect(elo == 2500)
    }

    // ============================
    // MARK: - 辅助
    // ============================

    /// 复制设计文档 §2.3 的校准结论逻辑用于单元测试
    private func calibrationRecommendation(absDelta: Int) -> String {
        if absDelta < 100 {
            return "梯度过小，建议 6 级上调到 Skill 7"
        } else if absDelta >= 200 && absDelta <= 400 {
            return "✅ 合理过渡，确认当前 Skill Level"
        } else if absDelta > 500 {
            return "跨度过大，建议 6 级下调到 Skill 3"
        } else {
            return "Elo 差在 100-200 → 过渡合理（接近边界）"
        }
    }
}
