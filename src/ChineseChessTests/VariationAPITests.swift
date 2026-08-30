import XCTest
@testable import ChineseChess

/// v6.4 A-Phase2 验收锚（设计单 §5，Luke 钉死：锚 3 覆盖"预筛 nil + 老档 nil"两来源）
final class VariationAPITests: XCTestCase {

    private func makeAnalysis(variations: [Variation]?, quick: Bool = false,
                              evalDelta: Int = 120) -> MoveAnalysis {
        MoveAnalysis(playerMove: "h2e2", quality: .doubtful, bestMove: "b0c2",
                     bestEval: 200, playerEval: 80, evalDelta: evalDelta,
                     alternatives: [], isQuickResult: quick, variations: variations)
    }

    // MARK: 验收锚 1：三要素 lossCp 与定级同源（=evalDelta，无常量硬编码面）

    func testMoveReviewLossCpSameSourceAsGrading() {
        let vm = AnalysisViewModel()
        let a = makeAnalysis(variations: nil, evalDelta: 120)
        vm.loadForTest(moves: ["h2e2", "h9g7"], analyses: [a, nil])
        let r = vm.moveReview(atMove: 0)
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.lossCp, 120, "lossCp 必须 = evalDelta（定级同源）")
        XCTAssertFalse(r?.recommended.isEmpty ?? true)
    }

    // MARK: 验收锚 3：两种 nil 来源统一降级链路（Vera 钉死口径）

    func testNilVariationSourcesUnifiedDegrade() {
        let vm = AnalysisViewModel()
        // 来源 A：预筛命中步（quick=true，无 multiPV → variations 恒 nil）
        let quick = makeAnalysis(variations: nil, quick: true)
        // 来源 B：老档（无 variations 字段 → decode 后 nil；等价构造 = nil）
        let legacy = makeAnalysis(variations: nil, quick: false)
        vm.loadForTest(moves: ["h2e2", "h9g7"], analyses: [quick, legacy])
        XCTAssertEqual(vm.variations(atPosition: 1), [], "预筛 nil（k=1）→ 空数组走统一降级")
        XCTAssertEqual(vm.variations(atPosition: 2), [], "老档 nil（k=2）→ 空数组走统一降级")
    }

    /// 老档真实 decode 路径：无 variations 字段的 JSON → nil（字段级兼容不 bump schemaVersion）
    func testLegacyJSONDecodesWithoutVariations() throws {
        let legacyJSON = """
        {"playerMove":"h2e2","quality":2,"bestMove":"b0c2","bestEval":200,
         "playerEval":80,"evalDelta":120,"alternatives":[],"isQuickResult":false}
        """
        let a = try JSONDecoder().decode(MoveAnalysis.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(a.variations, "老档无 variations 字段 → nil")
        XCTAssertFalse(a.isQuickResult)
        // round-trip：带 variations 的新档
        let v = Variation(uci: "b0c2", sanZh: "马八进七", cpAfter: 35, rank: 1)
        let b = makeAnalysis(variations: [v])
        let data = try JSONEncoder().encode(b)
        let c = try JSONDecoder().decode(MoveAnalysis.self, from: data)
        XCTAssertEqual(c.variations?.first?.sanZh, "马八进七")
        XCTAssertEqual(c.variations?.first?.cpAfter, 35)
    }

    // MARK: 验收锚（k 域 v1.1 钉死）：k∈[1,N] 有效；k=0/k>N 返回 []

    func testKDomainBoundary() {
        let vm = AnalysisViewModel()
        let v = Variation(uci: "b0c2", sanZh: "马八进七", cpAfter: 35, rank: 1)
        vm.loadForTest(moves: ["h2e2", "h9g7"], analyses: [makeAnalysis(variations: [v]), nil])
        XCTAssertEqual(vm.variations(atPosition: 0), [], "k=0（首着前）→ []")
        XCTAssertEqual(vm.variations(atPosition: 1).count, 1, "k=1 → 第 1 着变招")
        XCTAssertEqual(vm.variations(atPosition: 2), [], "k=2 该着未分析（nil）→ []")
        XCTAssertEqual(vm.variations(atPosition: 99), [], "k>N（终局后）→ []")
    }

    // MARK: cpAfter 红方视角（v1.1 钉死：转换唯一发生点 = buildVariations）

    func testCpAfterRedPerspectiveConversion() {
        // 黑方行棋的局面（FEN 第 2 段 = b）：scoreCp 100（黑视角）→ cpAfter -100（红方视角）
        let blackFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b - - 0 1"
        let lines = [AnalysisLine(scoreCp: 100, depth: 12, bestMove: "b9c7", pv: "b9c7")]
        let vars = PositionAnalyzer.buildVariations(lines: lines, fenBefore: blackFEN)
        XCTAssertEqual(vars?.first?.cpAfter, -100, "黑行棋 → 红方视角取负")
        // 红方行棋：不取负
        let redFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
        let vars2 = PositionAnalyzer.buildVariations(lines: lines, fenBefore: redFEN)
        XCTAssertEqual(vars2?.first?.cpAfter, 100, "红行棋 → 原值")
        // sanZh 非空且 rank 从 1 起
        XCTAssertFalse(vars2?.first?.sanZh.isEmpty ?? true)
        XCTAssertEqual(vars2?.first?.rank, 1)
    }

    // MARK: coachingPayload 打包

    func testCoachingPayload() {
        let vm = AnalysisViewModel()
        let v = Variation(uci: "b0c2", sanZh: "马八进七", cpAfter: 35, rank: 1)
        vm.loadForTest(moves: ["h2e2", "h9g7"], analyses: [makeAnalysis(variations: [v]), nil])
        let p = vm.coachingPayload(atPosition: 1)
        XCTAssertEqual(p.positionIndex, 1)
        XCTAssertEqual(p.variations.count, 1)
        XCTAssertNotNil(p.moveReview, "k>=1 带第 k 着回顾")
        let p0 = vm.coachingPayload(atPosition: 0)
        XCTAssertEqual(p0.variations, [])
        XCTAssertNil(p0.moveReview, "k=0 无回顾")
    }
}
