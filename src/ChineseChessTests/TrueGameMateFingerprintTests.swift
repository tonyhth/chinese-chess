import XCTest
@testable import ChineseChess

/// v6.3.3 热修指纹回归（Luke 派单）：决胜局（含 mate 转换）六维不塌陷。
/// 输入 = 洪涛 8/29 真局（truegame66 fixture 同源，66 步将死终局 lvl7）
/// 33 个玩家着的真实 ——机械提取自 evidence/probe-truegame-0830/probe-replay66.log。
/// 修复前：末着 mate delta 100568 → avgDelta/stddev 被砸穿（endgame 0 分 / consistency 0 分 / Elo 单步 -1200）。
final class TrueGameMateFingerprintTests: XCTestCase {

    // (quality, bestEval, playerEval, delta) × 33 着（idx 0..64 偶数）
    private static let realDeltas: [(MoveQuality, Int, Int, Int)] = [
        (.brilliant, 23, 23, 0), (.brilliant, 30, 24, 6), (.brilliant, 33, 29, 4),
        (.brilliant, 58, 61, 3), (.normal, 103, 10, 93), (.brilliant, 33, 24, 9),
        (.good, 25, -2, 27), (.good, 3, -10, 13), (.brilliant, 4, 0, 4),
        (.normal, 0, -56, 56), (.good, -4, -22, 18), (.normal, 75, 24, 51),
        (.good, 19, -4, 23), (.doubtful, -5, -273, 268), (.doubtful, -74, -243, 169),
        (.brilliant, -54, -63, 9), (.brilliant, 163, 161, 2), (.doubtful, 174, 61, 113),
        (.brilliant, 182, 182, 0), (.doubtful, 320, 172, 148), (.normal, 156, 66, 90),
        (.good, 127, 102, 25), (.normal, 262, 179, 83), (.normal, 324, 256, 68),
        (.doubtful, 413, 280, 133), (.brilliant, 449, 461, 12), (.good, 591, 550, 41),
        (.brilliant, 736, 731, 5), (.doubtful, 732, 502, 230), (.doubtful, 526, 406, 120),
        (.doubtful, 468, 355, 113), (.brilliant, 372, 377, 5),
        (.losing, 569, -99_999, 100_568),
    ]

    private func makeMoves(phase: GamePhase? = nil) -> [AssessedMove] {
        Self.realDeltas.enumerated().map { i, d in
            // 真实相位粗分：前 12 着 opening、中 21 着 middle、后 10 着（含 mate）endgame
            let ph: GamePhase = phase ?? (i < 12 ? .opening : (i >= Self.realDeltas.count - 10 ? .endgame : .middle))
            let analysis = MoveAnalysis(
                playerMove: "a0a2", quality: d.0, bestMove: "a0a1",
                bestEval: d.1, playerEval: d.2, evalDelta: d.3,
                alternatives: [], isQuickResult: false
            )
            return AssessedMove(
                index: i * 2, fenBefore: FENParser.standardInitial, playerMove: "a0a2",
                analysis: analysis, phase: ph, isBookMove: i < 3,
                hasCheckmateOpportunity: false, missedCheckmate: false
            )
        }
    }

    /// 决胜局指纹：含 mate 转换的残局维度不塌（修复前 avgDelta≈10166 → deltaScore=0）
    func testTrueGameEndgameNotCollapsed() {
        let r = SixDimensionScorer.evaluateEndgame(moves: makeMoves())
        XCTAssertGreaterThanOrEqual(r.score, 20, "真局残局（1 着将死 + 9 着常规）不应塌到 0")
    }

    /// 决胜局指纹：稳定性维度不塌（修复前 stddev≈28700 → 0 分）
    func testTrueGameConsistencyNotCollapsed() {
        let r = SixDimensionScorer.evaluateConsistency(moves: makeMoves())
        XCTAssertGreaterThan(r.score, 0, "真局 33 着含末着将死，稳定性维度应保留可读分")
    }

    /// 决胜局指纹：开局维度不受末段影响（口径不变锚）
    func testTrueGameOpeningUnaffected() {
        let r = SixDimensionScorer.evaluateOpening(moves: makeMoves())
        XCTAssertGreaterThanOrEqual(r.score, 20)
    }

    /// Elo 批量：33 着含 1 着 mate 不被单步砸穿（trimOutliers 截 10% ≈ 3 着救不回 5 着以上的塌陷面）
    func testTrueGameEloEstimateBounded() {
        let deltas = Self.realDeltas.map { $0.3 }
        let e = EloEstimator.estimate(deltas: deltas)
        XCTAssertGreaterThanOrEqual(e.estimate, 1000, "Elo 估算应保持人读区间（修复前单步 log(100569) 拖垮均值）")
    }

    /// 阈值同源锚：六维与展示层共用 90000
    func testMateThresholdUnified() {
        XCTAssertEqual(SixDimensionScorer.mateDeltaPenalty, 700)
        // normalizedDelta 阈值 = EvalChartScale.mateThreshold（同源常量）
        XCTAssertEqual(SixDimensionScorer.normalizedDelta(EvalChartScale.mateThreshold),
                       SixDimensionScorer.mateDeltaPenalty)
        XCTAssertEqual(SixDimensionScorer.normalizedDelta(EvalChartScale.mateThreshold - 1),
                       EvalChartScale.mateThreshold - 1)
    }
}
