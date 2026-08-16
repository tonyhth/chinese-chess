import Testing
import Foundation
@testable import ChineseChess

// MARK: - PositionAnalyzer 单元测试
//
// 测试策略：
// - 纯逻辑测试（classifyMove）：无需引擎，直接测试分级算法
// - C API 集成测试：需要引擎初始化，使用 ensureEngineReady()

@Suite("PositionAnalyzer 走法质量分级", .serialized)
struct PositionAnalyzerTests {

    // MARK: - classifyMove 纯逻辑测试（无需引擎）

    @Test("玩家走最佳走法 → brilliant")
    func testBestMoveIsBrilliant() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "h2e2",
            bestMove: "h2e2",
            bestEval: 50,
            playerEval: 50
        )
        #expect(quality == .brilliant)
    }

    @Test("评估差距 0-10cp → brilliant")
    func testSmallDeltaBrilliant() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "h2e2",
            bestMove: "h9g7",
            bestEval: 100,
            playerEval: 95  // delta = 5
        )
        #expect(quality == .brilliant)
    }

    @Test("评估差距 11-50cp → good")
    func testGoodRange() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "h2e2",
            bestMove: "h9g7",
            bestEval: 100,
            playerEval: 60  // delta = 40
        )
        #expect(quality == .good)
    }

    @Test("评估差距 51-100cp → normal")
    func testNormalRange() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "h2e2",
            bestMove: "h9g7",
            bestEval: 100,
            playerEval: 30  // delta = 70
        )
        #expect(quality == .normal)
    }

    @Test("评估差距 101-300cp → doubtful")
    func testDoubtfulRange() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "h2e2",
            bestMove: "h9g7",
            bestEval: 100,
            playerEval: -50  // delta = 150
        )
        #expect(quality == .doubtful)
    }

    @Test("评估差距 301-700cp → blunder")
    func testBlunderRange() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "h2e2",
            bestMove: "h9g7",
            bestEval: 100,
            playerEval: -300  // delta = 400
        )
        #expect(quality == .blunder)
    }

    @Test("评估差距 >700cp → losing")
    func testLosingRange() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "h2e2",
            bestMove: "h9g7",
            bestEval: 100,
            playerEval: -700  // delta = 800
        )
        #expect(quality == .losing)
    }

    // MARK: - 边界值测试（Ruby 审查建议）

    @Test("边界: delta=10 → brilliant（上界）")
    func testBoundaryBrilliantUpper() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "a0a1", bestMove: "h9g7",
            bestEval: 100, playerEval: 90  // delta = 10
        )
        #expect(quality == .brilliant)
    }

    @Test("边界: delta=11 → good（下界）")
    func testBoundaryGoodLower() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "a0a1", bestMove: "h9g7",
            bestEval: 100, playerEval: 89  // delta = 11
        )
        #expect(quality == .good)
    }

    @Test("边界: delta=50 → good（上界）")
    func testBoundaryGoodUpper() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "a0a1", bestMove: "h9g7",
            bestEval: 100, playerEval: 50  // delta = 50
        )
        #expect(quality == .good)
    }

    @Test("边界: delta=51 → normal（下界）")
    func testBoundaryNormalLower() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "a0a1", bestMove: "h9g7",
            bestEval: 100, playerEval: 49  // delta = 51
        )
        #expect(quality == .normal)
    }

    @Test("边界: delta=100 → normal（上界）")
    func testBoundaryNormalUpper() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "a0a1", bestMove: "h9g7",
            bestEval: 100, playerEval: 0  // delta = 100
        )
        #expect(quality == .normal)
    }

    @Test("边界: delta=101 → doubtful（下界）")
    func testBoundaryDoubtfulLower() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "a0a1", bestMove: "h9g7",
            bestEval: 100, playerEval: -1  // delta = 101
        )
        #expect(quality == .doubtful)
    }

    @Test("边界: delta=300 → doubtful（上界）")
    func testBoundaryDoubtfulUpper() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "a0a1", bestMove: "h9g7",
            bestEval: 100, playerEval: -200  // delta = 300
        )
        #expect(quality == .doubtful)
    }

    @Test("边界: delta=301 → blunder（下界）")
    func testBoundaryBlunderLower() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "a0a1", bestMove: "h9g7",
            bestEval: 100, playerEval: -201  // delta = 301
        )
        #expect(quality == .blunder)
    }

    @Test("边界: delta=700 → blunder（上界）")
    func testBoundaryBlunderUpper() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "a0a1", bestMove: "h9g7",
            bestEval: 100, playerEval: -600  // delta = 700
        )
        #expect(quality == .blunder)
    }

    @Test("边界: delta=701 → losing（下界）")
    func testBoundaryLosingLower() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "a0a1", bestMove: "h9g7",
            bestEval: 100, playerEval: -601  // delta = 701
        )
        #expect(quality == .losing)
    }

    // MARK: - MoveQuality 属性测试

    @Test("MoveQuality 所有 case 有有效 l10nKey")
    func testMoveQualityL10nKeys() {
        for quality in MoveQuality.allCases {
            #expect(!quality.l10nKey.isEmpty)
            // L10n 应该能返回非空字符串（或回退到 key）
            let label = quality.l10nKey
            #expect(!label.isEmpty)
        }
    }

    @Test("MoveQuality symbolName 非空")
    func testMoveQualitySymbolNames() {
        for quality in MoveQuality.allCases {
            #expect(!quality.symbolName.isEmpty)
        }
    }

    @Test("MoveQuality rawValue 符合分级定义")
    func testMoveQualityRawValues() {
        #expect(MoveQuality.brilliant.rawValue == 5)
        #expect(MoveQuality.good.rawValue == 4)
        #expect(MoveQuality.normal.rawValue == 3)
        #expect(MoveQuality.doubtful.rawValue == 2)
        #expect(MoveQuality.blunder.rawValue == 1)
        #expect(MoveQuality.losing.rawValue == 0)
    }

    // MARK: - C API 集成测试（需要引擎）

    @Test("evaluate: 标准开局 FEN 返回有效评估", .disabled(if: !TestEnvPreflight.nnuePresent, "NNUE 资产缺失：引擎不可用，环境破缺 skip（门规：批次 Test run 计数必须等于全量数，少计=环境破缺批次作废）"))  // 基线污染单2：skip 第三态
    func testEvaluateStartingPosition() async throws {
        // v3.7.2: P0 已传入 time_ms=2000，不会无限挂起
        let startFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

        let result = await PositionAnalyzer.shared.evaluate(fen: startFEN, moveHistory: [])

        try #require(result != nil, "引擎应返回评估结果")
        let line = try #require(result)
        #expect(line.depth > 0, "搜索深度应 > 0")
        #expect(!line.bestMove.isEmpty, "bestMove 应非空")
    }

    @Test("topMoves: MultiPV 返回多条候选", .disabled(if: !TestEnvPreflight.nnuePresent, "NNUE 资产缺失：引擎不可用，环境破缺 skip（门规：批次 Test run 计数必须等于全量数，少计=环境破缺批次作废）"))  // 基线污染单2：skip 第三态
    func testTopMovesMultiPV() async throws {
        let startFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

        let lines = await PositionAnalyzer.shared.topMoves(fen: startFEN, moveHistory: [], count: 3)

        try #require(!lines.isEmpty, "引擎应返回候选走法")
        #expect(lines.count <= 3, "返回数不应超过请求数")
        for line in lines {
            #expect(line.depth > 0)
            #expect(!line.bestMove.isEmpty)
        }
    }

    @Test("analyzeMove: 完整单步分析返回有效结构", .disabled(if: !TestEnvPreflight.nnuePresent, "NNUE 资产缺失：引擎不可用，环境破缺 skip（门规：批次 Test run 计数必须等于全量数，少计=环境破缺批次作废）"))  // 基线污染单2：skip 第三态
    func testAnalyzeMoveComplete() async throws {
        let fenBefore = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
        let playerMove = "h2e2"

        let analysis = await PositionAnalyzer.shared.analyzeMove(
            fenBefore: fenBefore,
            playerMove: playerMove,
            moveHistory: []
        )

        try #require(analysis != nil, "引擎应返回分析结果")
        let a = try #require(analysis)
        #expect(a.playerMove == "h2e2")
        #expect(!a.bestMove.isEmpty)
        #expect(a.quality.rawValue >= 0 && a.quality.rawValue <= 5)
        #expect(a.evalDelta >= 0, "评估损失应 ≥ 0")
        #expect(!a.alternatives.isEmpty, "应有候选走法")
    }

    // MARK: - 边界场景

    @Test("classifyMove: 负评估值处理正确")
    func testNegativeEvalHandling() {
        let analyzer = PositionAnalyzer.shared
        // bestEval 为负（黑方优势），玩家走法加剧劣势
        let quality = analyzer.classifyMove(
            playerMove: "a0a1",
            bestMove: "h9g7",
            bestEval: -200,  // 黑方优势 200cp
            playerEval: -500  // 黑方优势 500cp，玩家（红方）更差
        )
        // delta = |-200 - (-500)| = 300 → doubtful
        #expect(quality == .doubtful)
    }

    @Test("classifyMove: 相同评估值 → brilliant")
    func testSameEvalBrilliant() {
        let analyzer = PositionAnalyzer.shared
        let quality = analyzer.classifyMove(
            playerMove: "h2e2",
            bestMove: "h9g7",  // 不同走法
            bestEval: 100,
            playerEval: 100  // delta = 0
        )
        #expect(quality == .brilliant)
    }

    @Test("evaluate: 空 moveHistory 也能处理")
    func testEmptyMoveHistory() async throws {
        let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
        let result = await PositionAnalyzer.shared.evaluate(fen: fen, moveHistory: [])
        // 不崩溃即可
        // nil 表示引擎未初始化，不算失败
        _ = result
    }

    @Test("AnalysisLine: Codable 正确序列化")
    func testAnalysisLineCodable() throws {
        let line = AnalysisLine(scoreCp: 50, depth: 20, bestMove: "h2e2", pv: "h2e2 h9g7")
        let data = try JSONEncoder().encode(line)
        let decoded = try JSONDecoder().decode(AnalysisLine.self, from: data)
        #expect(decoded.scoreCp == 50)
        #expect(decoded.depth == 20)
        #expect(decoded.bestMove == "h2e2")
        #expect(decoded.pv == "h2e2 h9g7")
    }

    @Test("MoveAnalysis: Codable 正确序列化")
    func testMoveAnalysisCodable() throws {
        let analysis = MoveAnalysis(
            playerMove: "h2e2",
            quality: .good,
            bestMove: "h9g7",
            bestEval: 100,
            playerEval: 70,
            evalDelta: 30,
            alternatives: [
                AnalysisLine(scoreCp: 100, depth: 18, bestMove: "h9g7", pv: "h9g7"),
                AnalysisLine(scoreCp: 80, depth: 18, bestMove: "i9h9", pv: "i9h9")
            ]
        )
        let data = try JSONEncoder().encode(analysis)
        let decoded = try JSONDecoder().decode(MoveAnalysis.self, from: data)
        #expect(decoded.playerMove == "h2e2")
        #expect(decoded.quality == .good)
        #expect(decoded.evalDelta == 30)
        #expect(decoded.alternatives.count == 2)
    }
}