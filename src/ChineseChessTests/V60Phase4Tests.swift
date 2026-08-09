import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.0 Phase 4 测试：棋力评估核心算法

@Suite("v6.0 Phase 4: Elo 估算算法", .serialized)
struct V60Phase4EloTests {

    // ============================
    // MARK: - eloFromDelta 单步映射
    // ============================

    @Test("delta=0 → Elo 2500（完美走法）")
    func delta0() {
        #expect(EloEstimator.eloFromDelta(0) == 2500)
    }

    @Test("delta=50 → Elo ~2032")
    func delta50() {
        let elo = EloEstimator.eloFromDelta(50)
        #expect(elo > 2000 && elo < 2100)
    }

    @Test("delta=300 → Elo ~1781")
    func delta300() {
        let elo = EloEstimator.eloFromDelta(300)
        #expect(elo > 1700 && elo < 1850)
    }

    @Test("delta=1000 → Elo 收敛（不超过 1700）")
    func delta1000() {
        let elo = EloEstimator.eloFromDelta(1000)
        #expect(elo > 1550 && elo < 1700)
    }

    @Test("delta 为负数 → Elo 2500（delta <= 0 保护）")
    func negativeDelta() {
        #expect(EloEstimator.eloFromDelta(-10) == 2500)
    }

    // ============================
    // MARK: - estimate 批量估算
    // ============================

    @Test("样本 < 20 → 保守值 + .low 置信度")
    func smallSample() {
        let result = EloEstimator.estimate(deltas: [10, 20, 30])
        #expect(result.confidence == .low)
        #expect(result.sampleSize == 3)
    }

    @Test("样本 40-79 → .medium 置信度")
    func mediumSample() {
        let deltas = Array(repeating: 50, count: 50)
        let result = EloEstimator.estimate(deltas: deltas)
        #expect(result.confidence == .medium)
    }

    @Test("样本 ≥ 80 → .high 置信度")
    func highSample() {
        let deltas = Array(repeating: 50, count: 100)
        let result = EloEstimator.estimate(deltas: deltas)
        #expect(result.confidence == .high)
    }

    @Test("截尾平均：极端值不拉偏")
    func trimmedMean() {
        // 100 个 delta=0（完美）+ 少数极端值
        var deltas = Array(repeating: 0, count: 100)
        deltas += [5000, 5000, 5000, 5000, 5000]  // 5 个极端败着
        let result = EloEstimator.estimate(deltas: deltas)
        // 截尾后应接近 delta=0 的 Elo（2500）
        // 5 个 5000 会被截掉（105 个去 10 个 → 剩 85 个，大部分是 0）
        #expect(result.estimate > 2300, "截尾后应接近完美走法 Elo")
    }

    @Test("置信区间下限 ≤ 估计值 ≤ 上限")
    func confidenceInterval() {
        let deltas = (0..<60).map { _ in Int.random(in: 0...200) }
        let result = EloEstimator.estimate(deltas: deltas)
        #expect(result.lowerBound <= result.estimate)
        #expect(result.estimate <= result.upperBound)
    }

    @Test("样本 < 20 → 返回固定保守值（estimate=1000, CI=600-1600）")
    func smallSampleFixedValue() {
        let result = EloEstimator.estimate(deltas: [5, 10])
        #expect(result.estimate == 1000)
        #expect(result.lowerBound == 600)
        #expect(result.upperBound == 1600)
    }

    // ============================
    // MARK: - 推荐级别映射
    // ============================

    @Test("Elo < 800 → .novice（1级）")
    func recommendLevel1() {
        let elo = EloEstimate(estimate: 500, lowerBound: 300, upperBound: 700, sampleSize: 100, confidence: .high)
        #expect(EloEstimator.recommendedLevel(from: elo) == .novice)
    }

    @Test("Elo 1500 → .amateurMid（4级）")
    func recommendLevel4() {
        let elo = EloEstimate(estimate: 1500, lowerBound: 1400, upperBound: 1600, sampleSize: 100, confidence: .high)
        #expect(EloEstimator.recommendedLevel(from: elo) == .amateurMid)
    }

    @Test("Elo 1800 → .amateurHigh（5级）")
    func recommendLevel5() {
        let elo = EloEstimate(estimate: 1800, lowerBound: 1700, upperBound: 1900, sampleSize: 100, confidence: .high)
        #expect(EloEstimator.recommendedLevel(from: elo) == .amateurHigh)
    }

    @Test("Elo 2000 → .amateurDan（6级）")
    func recommendLevel6() {
        let elo = EloEstimate(estimate: 2000, lowerBound: 1900, upperBound: 2100, sampleSize: 100, confidence: .high)
        #expect(EloEstimator.recommendedLevel(from: elo) == .amateurDan)
    }

    @Test("Elo 2600 → .proExpert（8级）")
    func recommendLevel8() {
        let elo = EloEstimate(estimate: 2600, lowerBound: 2500, upperBound: 2700, sampleSize: 100, confidence: .high)
        #expect(EloEstimator.recommendedLevel(from: elo) == .proExpert)
    }

    @Test("Elo 3000+ → .grandmaster（10级）")
    func recommendLevel10() {
        let elo = EloEstimate(estimate: 3100, lowerBound: 2950, upperBound: 3250, sampleSize: 100, confidence: .high)
        #expect(EloEstimator.recommendedLevel(from: elo) == .grandmaster)
    }

    // ============================
    // MARK: - 边界值
    // ============================

    @Test("推荐级别边界值：800 → 1级 vs 801 → 2级")
    func recommendBoundary800() {
        let elo800 = EloEstimate(estimate: 800, lowerBound: 700, upperBound: 900, sampleSize: 100, confidence: .high)
        let elo801 = EloEstimate(estimate: 801, lowerBound: 700, upperBound: 900, sampleSize: 100, confidence: .high)
        #expect(EloEstimator.recommendedLevel(from: elo800) == .novice)
        #expect(EloEstimator.recommendedLevel(from: elo801) == .beginner)
    }

    @Test("推荐级别边界值：2900 → 9级 vs 2901+ → 10级")
    func recommendBoundary2900() {
        let elo2900 = EloEstimate(estimate: 2900, lowerBound: 2800, upperBound: 3000, sampleSize: 100, confidence: .high)
        let elo2901 = EloEstimate(estimate: 2901, lowerBound: 2800, upperBound: 3000, sampleSize: 100, confidence: .high)
        #expect(EloEstimator.recommendedLevel(from: elo2900) == .proMaster)
        #expect(EloEstimator.recommendedLevel(from: elo2901) == .grandmaster)
    }
}

// MARK: - 六维评分

@Suite("v6.0 Phase 4: 六维评分", .serialized)
struct V60Phase4DimensionTests {

    // 辅助：构造 MoveAnalysis
    private func makeAnalysis(delta: Int, quality: MoveQuality) -> MoveAnalysis {
        MoveAnalysis(
            playerMove: "a0a1", quality: quality, bestMove: "b0b1",
            bestEval: 100, playerEval: 100 - delta, evalDelta: delta,
            alternatives: [], isQuickResult: false
        )
    }

    // 辅助：构造 AssessedMove
    private func makeMove(delta: Int, quality: MoveQuality, phase: GamePhase,
                          isBook: Bool = false, hasMate: Bool = false, missedMate: Bool = false) -> AssessedMove {
        AssessedMove(
            index: 0, fenBefore: "", playerMove: "a0a1",
            analysis: makeAnalysis(delta: delta, quality: quality),
            phase: phase, isBookMove: isBook,
            hasCheckmateOpportunity: hasMate, missedCheckmate: missedMate
        )
    }

    // ============================
    // MARK: - 权重验证
    // ============================

    @Test("overall 加权总分 = opening×0.15 + tactics×0.25 + endgame×0.20 + consistency×0.20 + checkmate×0.20")
    func overallWeightedScore() {
        let dims = SixDimensionScores(
            opening: .init(score: 100, label: "", detail: "", metrics: [:]),
            tactics: .init(score: 80, label: "", detail: "", metrics: [:]),
            endgame: .init(score: 60, label: "", detail: "", metrics: [:]),
            consistency: .init(score: 70, label: "", detail: "", metrics: [:]),
            checkmate: .init(score: 50, label: "", detail: "", metrics: [:])
        )
        // 100×0.15 + 80×0.25 + 60×0.20 + 70×0.20 + 50×0.20
        // = 15 + 20 + 12 + 14 + 10 = 71
        #expect(dims.overall == 71)
    }

    // ============================
    // MARK: - 开局水平
    // ============================

    @Test("开局：全部开局库走法 + delta=0 → 高分")
    func openingPerfect() {
        let moves = (0..<10).map { _ in makeMove(delta: 0, quality: .brilliant, phase: .opening, isBook: true) }
        let result = SixDimensionScorer.evaluateOpening(moves: moves)
        #expect(result.score >= 85)
    }

    @Test("开局：无开局数据 → 默认 50 分")
    func openingNoData() {
        let moves = [makeMove(delta: 0, quality: .brilliant, phase: .middle)]
        let result = SixDimensionScorer.evaluateOpening(moves: moves)
        #expect(result.score == 50)
    }

    // ============================
    // MARK: - 中盘战术
    // ============================

    @Test("中盘：全部精妙 → 高分")
    func tacticsAllBrilliant() {
        let moves = (0..<10).map { _ in makeMove(delta: 5, quality: .brilliant, phase: .middle) }
        let result = SixDimensionScorer.evaluateTactics(moves: moves)
        #expect(result.score >= 80)
    }

    @Test("中盘：全部败着 → 低分")
    func tacticsAllBlunders() {
        let moves = (0..<10).map { _ in makeMove(delta: 800, quality: .losing, phase: .middle) }
        let result = SixDimensionScorer.evaluateTactics(moves: moves)
        #expect(result.score <= 20)
    }

    // ============================
    // MARK: - 残局功底
    // ============================

    @Test("残局：无残局数据 → 默认 50 分")
    func endgameNoData() {
        let moves = [makeMove(delta: 0, quality: .brilliant, phase: .opening)]
        let result = SixDimensionScorer.evaluateEndgame(moves: moves)
        #expect(result.score == 50)
    }

    // ============================
    // MARK: - 稳定性
    // ============================

    @Test("稳定性：步数不足 10 → 默认 50 分")
    func consistencyTooFewMoves() {
        let moves = (0..<5).map { _ in makeMove(delta: 0, quality: .good, phase: .middle) }
        let result = SixDimensionScorer.evaluateConsistency(moves: moves)
        #expect(result.score == 50)
    }

    @Test("稳定性：所有 delta=0 → 高分（stddev=0）")
    func consistencyPerfect() {
        let moves = (0..<30).map { _ in makeMove(delta: 0, quality: .brilliant, phase: .middle) }
        let result = SixDimensionScorer.evaluateConsistency(moves: moves)
        #expect(result.score >= 90)
    }

    // ============================
    // MARK: - 杀棋敏感度
    // ============================

    @Test("杀棋：无机会 → 默认 50 分")
    func checkmateNoOpportunity() {
        let moves = [makeMove(delta: 0, quality: .brilliant, phase: .middle, hasMate: false)]
        let result = SixDimensionScorer.evaluateCheckmate(moves: moves)
        #expect(result.score == 50)
    }

    @Test("杀棋：全部发现 → 100 分")
    func checkmateAllFound() {
        let moves = (0..<5).map { _ in makeMove(delta: 10, quality: .brilliant, phase: .middle, hasMate: true, missedMate: false) }
        let result = SixDimensionScorer.evaluateCheckmate(moves: moves)
        #expect(result.score == 100)
    }

    @Test("杀棋：全部错过 → 0 分")
    func checkmateAllMissed() {
        let moves = (0..<5).map { _ in makeMove(delta: 100, quality: .normal, phase: .middle, hasMate: true, missedMate: true) }
        let result = SixDimensionScorer.evaluateCheckmate(moves: moves)
        #expect(result.score == 0)
    }

    // ============================
    // MARK: - 优势/短板 + 建议
    // ============================

    @Test("优势检测：score >= 70 的维度被标为优势")
    func strengthsDetected() {
        let dims = SixDimensionScores(
            opening: .init(score: 85, label: "优秀", detail: "", metrics: [:]),
            tactics: .init(score: 90, label: "优秀", detail: "", metrics: [:]),
            endgame: .init(score: 40, label: "待提升", detail: "", metrics: [:]),
            consistency: .init(score: 75, label: "良好", detail: "", metrics: [:]),
            checkmate: .init(score: 30, label: "待提升", detail: "", metrics: [:])
        )
        let strengths = SixDimensionScorer.generateStrengths(dims)
        #expect(strengths.count == 3)  // opening + tactics + consistency
    }

    @Test("短板检测：score < 50 的维度被标为短板")
    func weaknessesDetected() {
        let dims = SixDimensionScores(
            opening: .init(score: 85, label: "优秀", detail: "", metrics: [:]),
            tactics: .init(score: 90, label: "优秀", detail: "", metrics: [:]),
            endgame: .init(score: 40, label: "待提升", detail: "", metrics: [:]),
            consistency: .init(score: 75, label: "良好", detail: "", metrics: [:]),
            checkmate: .init(score: 30, label: "待提升", detail: "", metrics: [:])
        )
        let weaknesses = SixDimensionScorer.generateWeaknesses(dims)
        #expect(weaknesses.count == 2)  // endgame + checkmate
    }

    @Test("训练建议：checkmate < 60 生成杀棋练习建议")
    func suggestionForLowCheckmate() {
        let dims = SixDimensionScores(
            opening: .init(score: 80, label: "", detail: "", metrics: [:]),
            tactics: .init(score: 80, label: "", detail: "", metrics: [:]),
            endgame: .init(score: 80, label: "", detail: "", metrics: [:]),
            consistency: .init(score: 80, label: "", detail: "", metrics: [:]),
            checkmate: .init(score: 40, label: "", detail: "", metrics: [:])
        )
        let elo = EloEstimate(estimate: 1500, lowerBound: 1400, upperBound: 1600, sampleSize: 100, confidence: .high)
        let suggestions = SixDimensionScorer.generateSuggestions(dims, elo: elo)
        #expect(suggestions.contains { $0.dimension == "杀棋敏感度" })
    }

    @Test("评分标签：85+ = 优秀，70-84 = 良好，50-69 = 一般，<50 = 待提升")
    func scoreLabels() {
        #expect(SixDimensionScores.ScoreBreakdown.scoreLabel(90) == "优秀")
        #expect(SixDimensionScores.ScoreBreakdown.scoreLabel(75) == "良好")
        #expect(SixDimensionScores.ScoreBreakdown.scoreLabel(60) == "一般")
        #expect(SixDimensionScores.ScoreBreakdown.scoreLabel(30) == "待提升")
    }
}

// MARK: - 持久化

@Suite("v6.0 Phase 4: AssessmentStore 持久化", .serialized)
struct V60Phase4StoreTests {

    private func makeDefaults() -> UserDefaults {
        let suiteName = "test.assessment.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private func makeReport() -> StrengthReport {
        StrengthReport(
            eloEstimate: EloEstimate(estimate: 1500, lowerBound: 1400, upperBound: 1600, sampleSize: 80, confidence: .high),
            recommendedLevel: .amateurMid,
            dimensions: SixDimensionScores(
                opening: .init(score: 70, label: "良好", detail: "", metrics: [:]),
                tactics: .init(score: 65, label: "一般", detail: "", metrics: [:]),
                endgame: .init(score: 55, label: "一般", detail: "", metrics: [:]),
                consistency: .init(score: 80, label: "良好", detail: "", metrics: [:]),
                checkmate: .init(score: 40, label: "待提升", detail: "", metrics: [:])
            ),
            moveStats: MoveStatistics(totalMoves: 80, qualityDistribution: [.brilliant: 10, .good: 30, .normal: 30, .blunder: 10], avgDelta: 45.0)
        )
    }

    @Test("save + lastReport round-trip 一致")
    func saveAndRead() {
        let defaults = makeDefaults()
        let store = AssessmentStore(defaults: defaults)
        let report = makeReport()
        store.save(report)

        let loaded = store.lastReport
        #expect(loaded != nil)
        #expect(loaded?.eloEstimate.estimate == 1500)
        #expect(loaded?.recommendedLevel == .amateurMid)
    }

    @Test("clear 后 lastReport 为 nil")
    func clearRemovesReport() {
        let defaults = makeDefaults()
        let store = AssessmentStore(defaults: defaults)
        store.save(makeReport())
        #expect(store.lastReport != nil)

        store.clear()
        #expect(store.lastReport == nil)
    }

    @Test("空存储 lastReport 返回 nil")
    func emptyStoreReturnsNil() {
        let defaults = makeDefaults()
        let store = AssessmentStore(defaults: defaults)
        #expect(store.lastReport == nil)
    }

    @Test("持久化 round-trip：含 dimensions + moveStats")
    func fullRoundTrip() {
        let defaults = makeDefaults()
        let store = AssessmentStore(defaults: defaults)
        let report = makeReport()
        store.save(report)
        let loaded = store.lastReport!

        #expect(loaded.dimensions.overall == report.dimensions.overall)
        #expect(loaded.moveStats.totalMoves == 80)
        #expect(loaded.moveStats.avgDelta == 45.0)
        #expect(loaded.moveStats.brilliantRate > 0)
    }
}

// MARK: - 评估状态机

@Suite("v6.0 Phase 4: AssessmentSession 状态机", .serialized)
@MainActor
struct V60Phase4SessionTests {

    @Test("初始状态为 idle")
    func initialState() {
        let session = AssessmentSession()
        #expect(session.state == .idle)
    }

    @Test("reset 后回到 idle + 清空数据")
    func resetClears() {
        let session = AssessmentSession()
        session.assessedMoves = []
        session.reset()
        #expect(session.state == .idle)
        #expect(session.assessedMoves.isEmpty)
    }

    @Test("AssessmentState Equatable")
    func stateEquatable() {
        #expect(AssessmentState.idle == .idle)
        #expect(AssessmentState.idle != .selectingMode)
        #expect(AssessmentState.failed("err") == .failed("other"))  // 设计中只比较 case
    }

    @Test("AssessmentProgress.description 有内容")
    func progressDescription() {
        let p = AssessmentProgress(currentGame: 1, totalGames: 3, currentMove: 15, totalMoves: 40)
        #expect(!p.description.isEmpty)
        #expect(p.description.contains("1/3"))
    }
}
