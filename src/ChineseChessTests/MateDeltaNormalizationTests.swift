import XCTest
@testable import ChineseChess

/// v6.3.2 热修链回归（Ruby P1-1）：mate 分数不污染六维评分/Elo 管线
/// 锁定指纹：将死终局 evalDelta≈100568 直接进 avgDelta/stddev/eloFromDelta
/// → 开局/残局 deltaScore 打 0 分、consistency 塌陷、单步 Elo 砸 1200+ 分。
final class MateDeltaNormalizationTests: XCTestCase {

    private func makeMove(evalDelta: Int, phase: GamePhase = .endgame,
                          quality: MoveQuality = .losing) -> AssessedMove {
        let analysis = MoveAnalysis(
            playerMove: "e4e5", quality: quality, bestMove: "a0a1",
            bestEval: 569, playerEval: 569 - evalDelta, evalDelta: evalDelta,
            alternatives: [], isQuickResult: false
        )
        return AssessedMove(
            index: 0, fenBefore: FENParser.standardInitial, playerMove: "e4e5",
            analysis: analysis, phase: phase, isBookMove: false,
            hasCheckmateOpportunity: false, missedCheckmate: false
        )
    }

    // MARK: 归一化口径

    func testNormalizedDelta() {
        // 真局指纹值：bestEval=569 / playerEval=-99999 → delta=100568
        XCTAssertEqual(SixDimensionScorer.normalizedDelta(100_568), SixDimensionScorer.mateDeltaPenalty)
        XCTAssertEqual(SixDimensionScorer.normalizedDelta(-100_568), SixDimensionScorer.mateDeltaPenalty)
        XCTAssertEqual(SixDimensionScorer.normalizedDelta(120), 120)
        XCTAssertEqual(SixDimensionScorer.normalizedDelta(89_999), 89_999)
    }

    // MARK: 维度 2：残局 avgDelta 不被 mate 砸塌

    func testEndgameScoreSurvivesMateDelta() {
        // 10 着正常（delta=30）+ 1 着将死（delta=100568）
        let moves = (0..<10).map { _ in makeMove(evalDelta: 30, quality: .good) }
            + [makeMove(evalDelta: 100_568)]
        let r = SixDimensionScorer.evaluateEndgame(moves: moves)
        // 修复前：avgDelta≈9126 → deltaScore=0；修复后 avgDelta≈91 → deltaScore≈60-30=30 起
        XCTAssertGreaterThanOrEqual(r.score, 25, "含 1 着将死的残局评分不应塌到 0（修复前 deltaScore=0）")
    }

    // MARK: 维度 4：consistency 的 stddev/连续失误不被 mate 污染

    func testConsistencySurvivesMateDelta() {
        // 10 着 delta=20 稳定 + 1 着将死
        var moves = (0..<10).map { _ in makeMove(evalDelta: 20, phase: .middle, quality: .good) }
        moves.append(makeMove(evalDelta: 100_568, phase: .middle))
        let r = SixDimensionScorer.evaluateConsistency(moves: moves)
        // 修复前：stddev≈30200 → consistencyScore=0；修复后归一后 stddev≈225 → 有分
        XCTAssertGreaterThan(r.score, 0, "单着将死不应把稳定性维度砸到 0")
    }

    // MARK: Elo：mate 单步不砸 1200+ 分

    func testEloFromMateDeltaBounded() {
        let mateElo = EloEstimator.eloFromDelta(100_568)
        let normalBadElo = EloEstimator.eloFromDelta(700)
        // 修复前：2500-120*ln(100569)≈1284（vs delta=700 的 1692，单步砸 400+，多步更惨）
        XCTAssertEqual(mateElo, normalBadElo, accuracy: 0.001, "mate delta 应按重损惩罚口径计（700cp），非 log(99999)")
        // 正常口径不变锚
        XCTAssertEqual(EloEstimator.eloFromDelta(0), 2500)
        XCTAssertEqual(EloEstimator.eloFromDelta(100), 2500 - 120 * log(101), accuracy: 0.001)
    }
}
