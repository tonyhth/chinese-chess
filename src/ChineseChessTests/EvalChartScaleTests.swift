import XCTest
@testable import ChineseChess

/// v6.3.2 热修回归：评估曲线量程对 mate 分数特判
/// 锁定症状指纹（2026-08-30 真局 A5A1D9A3）：末着 playerEval=-99999 将 range 砸到 ≈10 万，
/// 正常分压成贴顶直线（视觉"归零"）。修复后 mate 分不参与量程，曲线量程有界。
final class EvalChartScaleTests: XCTestCase {

    // MARK: 指纹①：mate 分数不压扁量程（复现原红的最小断言）

    func testMateScoreDoesNotCrushRange() {
        // 真局末段实际值：正常亏损 502/406/355/377 + 末着 -99999
        let scores = [502, 406, 355, 377, -99_999]
        let domain = EvalChartScale.yDomain(scores)
        // 修复前：min=-99999, max=502 → range=100501。修复后必须量程有界
        XCTAssertLessThanOrEqual(domain.max - domain.min, 2 * EvalChartScale.clampBound)
        // 非 mate 分原值参与量程（不被 clamp 改写口径：均 < 2000，原值保留）
        XCTAssertEqual(domain.max, 502)
        XCTAssertEqual(domain.min, -200)
    }

    func testPositiveMateAlsoExcluded() {
        let domain = EvalChartScale.yDomain([23, 99_999, 736])
        XCTAssertEqual(domain.min, -200)
        XCTAssertEqual(domain.max, 736)
    }

    // MARK: 指纹②：正常序列渲染口径不变（回归锚）

    func testNormalSequenceDomainUnchanged() {
        // 旧口径：minScore=min(min(scores),-200), maxScore=max(max(scores),200)
        let a = EvalChartScale.yDomain([23, 736]); XCTAssertEqual(a.min, -200); XCTAssertEqual(a.max, 736)
        let b = EvalChartScale.yDomain([-500, 300]); XCTAssertEqual(b.min, -500); XCTAssertEqual(b.max, 300)
        let c = EvalChartScale.yDomain([]); XCTAssertEqual(c.min, -200); XCTAssertEqual(c.max, 200)
    }

    func testNonMateClampToBound() {
        // 非 mate 但极端的评估（>2000）clamp 到边界参与量程
        XCTAssertEqual(EvalChartScale.yDomain([5000, 100]).max, EvalChartScale.clampBound)
        XCTAssertEqual(EvalChartScale.yDomain([-5000, 100]).min, -EvalChartScale.clampBound)
    }

    // MARK: mate 判定与钉边

    func testIsMateScore() {
        XCTAssertTrue(EvalChartScale.isMateScore(99_999))
        XCTAssertTrue(EvalChartScale.isMateScore(-99_999))
        XCTAssertFalse(EvalChartScale.isMateScore(2000))
        XCTAssertFalse(EvalChartScale.isMateScore(0))
    }

    func testPinnedScore() {
        let domain = (min: -200, max: 736)
        XCTAssertEqual(EvalChartScale.pinnedScore(99_999, domain: domain), 736)
        XCTAssertEqual(EvalChartScale.pinnedScore(-99_999, domain: domain), -200)
    }

    // MARK: 真局 fixture 回归（不走引擎，锉定输入形态 + 量程行为）

    /// fixture = 2026-08-29 洪涛真局（66 着将死终局，人机 lvl7）。
    /// 用 #filePath 相对定位（文件在 repo 内随 git 走，无需 bundle 资源注册）。
    private func loadTrueGame66() throws -> (moves: [GameMove], initialFEN: String) {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/truegame66.json")
        let data = try Data(contentsOf: url)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let movesData = try JSONSerialization.data(withJSONObject: obj["moves"]!)
        let moves = try JSONDecoder().decode([GameMove].self, from: movesData)
        return (moves, obj["initialFEN"] as? String ?? FENParser.standardInitial)
    }

    func testTrueGame66FixtureShape() throws {
        let (moves, _) = try loadTrueGame66()
        XCTAssertEqual(moves.count, 66)
        XCTAssertEqual(moves.last?.isCheckmate, true, "末着必须是将死着（终局形态锚）")
        XCTAssertEqual(moves.last?.notation, "車2进2")
    }

    func testTrueGame66FENRebuildEndgame() throws {
        let (moves, fen0) = try loadTrueGame66()
        let fens = FENRebuilder.computeAllFENs(initialFEN: fen0, moves: moves)
        XCTAssertEqual(fens.count, 67)
        // 将死末着（idx65）走前局面锚（C 层探针实测应答 99999 不拒收）
        XCTAssertEqual(fens[65], "2b1ka3/4a4/4b3n/2P1N4/p5P2/1C6P/PR2P2r1/4B4/4K4/2BA1A1c1 b - - 0 1")
    }

    func testTrueGame66EndgameCurveBounded() throws {
        _ = try loadTrueGame66()
        // 真局末段实测分值（probe-replay66.log idx56-64 玩家着）
        let endgameScores = [502, 406, 355, 377, -99_999]
        let domain = EvalChartScale.yDomain(endgameScores)
        // 指纹复现断言：修复前 range=100501 → 曲线压扁；修复后 ≤ 2*clampBound
        XCTAssertLessThanOrEqual(domain.max - domain.min, 2 * EvalChartScale.clampBound)
        // mate 点钉边后曲线可读：正常分的归一化间距不为 0 量级
        let range = max(domain.max - domain.min, 1)
        // 最高正常分（502）相对零线（domain.min=-200）的纵向分布：修复前整段压成 ≈0.6px 不可分辨
        let normalizedSpread = CGFloat(502 - domain.min) / CGFloat(range) * 80
        XCTAssertGreaterThan(normalizedSpread, 40, "正常分在 80px 图高上应有可分辨的纵向分布（修复前 ≈0.6px）")
    }
}
