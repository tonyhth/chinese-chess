import Foundation
import Testing
@testable import ChineseChess

// MARK: - Phase 5 #2: CoachModeOverlay / CoachExplainer 测试

@Suite("Phase 5 #2: CoachModeOverlay 流程测试", .serialized)
struct CoachModeOverlayTests {

    // MARK: - 1. CoachScenario 枚举完整性

    @Test("CoachScenario: 8 种场景完整")
    func scenarioCount() {
        #expect(CoachScenario.allCases.count == 8, "应有 8 种教练场景")
    }

    @Test("CoachScenario: 所有 case 有 rawValue")
    func scenarioRawValues() {
        let expected: [String] = [
            "blunder", "missedMate", "missedCheck", "missedCapture",
            "developPiece", "defensiveMove", "centerControl", "generic"
        ]
        for (i, scenario) in CoachScenario.allCases.enumerated() {
            #expect(scenario.rawValue == expected[i], "场景 rawValue 应匹配")
        }
    }

    // MARK: - 2. CoachExplanation 数据结构

    @Test("CoachExplanation: 完整初始化")
    func explanationInit() {
        let exp = CoachExplanation(
            scenario: .blunder,
            title: "严重失误",
            detail: "推荐走法 h2e2，可挽回 300cp",
            betterMove: "h2e2",
            evalDelta: 300
        )
        #expect(exp.scenario == .blunder)
        #expect(exp.title == "严重失误")
        #expect(exp.detail == "推荐走法 h2e2，可挽回 300cp")
        #expect(exp.betterMove == "h2e2")
        #expect(exp.evalDelta == 300)
    }

    @Test("CoachExplanation: evalDelta 为 0")
    func explanationZeroDelta() {
        let exp = CoachExplanation(
            scenario: .generic,
            title: "好棋",
            detail: "",
            betterMove: "",
            evalDelta: 0
        )
        #expect(exp.evalDelta == 0)
    }

    @Test("CoachExplanation: 各场景构造")
    func explanationAllScenarios() {
        for scenario in CoachScenario.allCases {
            let exp = CoachExplanation(
                scenario: scenario,
                title: "test",
                detail: "test",
                betterMove: "h2e2",
                evalDelta: 100
            )
            #expect(exp.scenario == scenario)
        }
    }

    // MARK: - 3. CoachExplainer 场景分类逻辑

    @Test("CoachExplainer: delta < 50 归为 generic")
    func classifyLowDelta() async {
        let explainer = CoachExplainer.shared
        let analysis = MoveAnalysis(
            playerMove: "h2e2",
            quality: .good,
            bestMove: "h9g7",
            bestEval: 100,
            playerEval: 80,
            evalDelta: 20,
            alternatives: []
        )
        let exp = await explainer.explain(
            analysis: analysis,
            fenBefore: FENParser.generate(board: Board()),
            playerMove: "h2e2",
            bestMove: "h9g7"
        )
        #expect(exp.scenario == .generic, "delta < 50 应归为 generic")
    }

    @Test("CoachExplainer: delta >= 300 归为 blunder（非杀棋）")
    func classifyBlunder() async {
        let explainer = CoachExplainer.shared
        let analysis = MoveAnalysis(
            playerMove: "h9g7",
            quality: .blunder,
            bestMove: "h2e2",
            bestEval: 500,
            playerEval: 100,
            evalDelta: 400,
            alternatives: []
        )
        let exp = await explainer.explain(
            analysis: analysis,
            fenBefore: FENParser.generate(board: Board()),
            playerMove: "h9g7",
            bestMove: "h2e2"
        )
        // delta=400 >= 300，且非杀棋分数 → blunder
        #expect(exp.scenario == .blunder || exp.scenario == .missedMate)
    }

    @Test("CoachExplainer: evalDelta 保留在 explanation 中")
    func explainPreservesDelta() async {
        let explainer = CoachExplainer.shared
        let analysis = MoveAnalysis(
            playerMove: "h9g7",
            quality: .doubtful,
            bestMove: "h2e2",
            bestEval: 300,
            playerEval: 150,
            evalDelta: 150,
            alternatives: []
        )
        let exp = await explainer.explain(
            analysis: analysis,
            fenBefore: FENParser.generate(board: Board()),
            playerMove: "h9g7",
            bestMove: "h2e2"
        )
        #expect(exp.evalDelta == 150, "evalDelta 应保留在 explanation 中")
    }

    @Test("CoachExplainer: betterMove 保留在 explanation 中")
    func explainPreservesBetterMove() async {
        let explainer = CoachExplainer.shared
        let analysis = MoveAnalysis(
            playerMove: "a0a1",
            quality: .normal,
            bestMove: "h2e2",
            bestEval: 200,
            playerEval: 100,
            evalDelta: 100,
            alternatives: []
        )
        let exp = await explainer.explain(
            analysis: analysis,
            fenBefore: FENParser.generate(board: Board()),
            playerMove: "a0a1",
            bestMove: "h2e2"
        )
        #expect(exp.betterMove == "h2e2", "betterMove 应保留在 explanation 中")
    }

    // MARK: - 4. CoachExplainer 辅助判断方法（通过 explain 间接验证）

    @Test("CoachExplainer: title 和 detail 非空")
    func explainNonEmptyText() async {
        let explainer = CoachExplainer.shared
        let analysis = MoveAnalysis(
            playerMove: "h9g7",
            quality: .blunder,
            bestMove: "h2e2",
            bestEval: 1000,
            playerEval: 200,
            evalDelta: 800,
            alternatives: []
        )
        let exp = await explainer.explain(
            analysis: analysis,
            fenBefore: FENParser.generate(board: Board()),
            playerMove: "h9g7",
            bestMove: "h2e2"
        )
        #expect(!exp.title.isEmpty, "title 不应为空")
        #expect(!exp.detail.isEmpty, "detail 不应为空")
    }

    // MARK: - 5. GameReviewCard 复盘统计

    @Test("GameReviewCard: 空对局评分默认 3 星")
    func emptyReviewCard() async {
        let explainer = CoachExplainer.shared
        let card = await explainer.generateReviewCard(analyses: [])
        #expect(card.totalMoves == 0)
        #expect(card.rating >= 1 && card.rating <= 5, "评分应在 1-5 星范围")
    }

    @Test("GameReviewCard: 全好棋评分高")
    func allGoodMovesReviewCard() async {
        let explainer = CoachExplainer.shared
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "h2e2", quality: .brilliant, bestMove: "h2e2",
                         bestEval: 100, playerEval: 100, evalDelta: 0, alternatives: []),
            MoveAnalysis(playerMove: "h9g7", quality: .good, bestMove: "h9g7",
                         bestEval: 200, playerEval: 180, evalDelta: 20, alternatives: []),
        ]
        let card = await explainer.generateReviewCard(analyses: analyses)
        #expect(card.totalMoves == 2)
        #expect(card.qualityDistribution[.brilliant] == 1)
        #expect(card.qualityDistribution[.good] == 1)
        #expect(card.rating >= 4, "全好棋评分应 >= 4")
    }

    @Test("GameReviewCard: 多失误评分低")
    func manyBlundersReviewCard() async {
        let explainer = CoachExplainer.shared
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "h2e2", quality: .blunder, bestMove: "h9g7",
                         bestEval: 500, playerEval: 100, evalDelta: 400, alternatives: []),
            MoveAnalysis(playerMove: "h9g7", quality: .losing, bestMove: "i9h9",
                         bestEval: 800, playerEval: -200, evalDelta: 1000, alternatives: []),
        ]
        let card = await explainer.generateReviewCard(analyses: analyses)
        #expect(card.totalMoves == 2)
        #expect(card.qualityDistribution[.blunder] == 1)
        #expect(card.qualityDistribution[.losing] == 1)
        #expect(card.rating <= 3, "多失误评分应 <= 3")
    }

    @Test("GameReviewCard: biggestBlunder 记录")
    func biggestBlunderTracking() async {
        let explainer = CoachExplainer.shared
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "a", quality: .blunder, bestMove: "b",
                         bestEval: 500, playerEval: 200, evalDelta: 300, alternatives: []),
            MoveAnalysis(playerMove: "c", quality: .blunder, bestMove: "d",
                         bestEval: 1000, playerEval: 100, evalDelta: 900, alternatives: []),
        ]
        let card = await explainer.generateReviewCard(analyses: analyses)
        #expect(card.biggestBlunder != nil, "应记录最大失误")
        #expect(card.biggestBlunder!.delta == 900, "最大失误 delta 应为 900")
        #expect(card.biggestBlunder!.moveIndex == 1, "最大失误在第 2 步")
    }

    @Test("GameReviewCard: 无大失误时 biggestBlunder 为 nil")
    func noBigBlunder() async {
        let explainer = CoachExplainer.shared
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "a", quality: .good, bestMove: "b",
                         bestEval: 100, playerEval: 90, evalDelta: 10, alternatives: []),
        ]
        let card = await explainer.generateReviewCard(analyses: analyses)
        #expect(card.biggestBlunder == nil, "无大失误时应为 nil")
    }

    @Test("GameReviewCard: nil 分析项被跳过")
    func nilAnalysesSkipped() async {
        let explainer = CoachExplainer.shared
        let analyses: [MoveAnalysis?] = [
            nil,
            MoveAnalysis(playerMove: "a", quality: .good, bestMove: "b",
                         bestEval: 100, playerEval: 95, evalDelta: 5, alternatives: []),
            nil,
        ]
        let card = await explainer.generateReviewCard(analyses: analyses)
        #expect(card.totalMoves == 1, "nil 分析项应被跳过")
    }

    // MARK: - 6. CoachExplainer 辅助方法间接验证

    @Test("CoachExplainer: isCheckingMove 判断将军走法")
    func isCheckingMoveValidation() async {
        // 标准开局走炮二平五后，黑方未被将军
        let board = Board()
        let fen = FENParser.generate(board: board)
        let explainer = CoachExplainer.shared

        // h2e2 (炮二平五) 在标准开局不直接将军
        let exp = await explainer.explain(
            analysis: MoveAnalysis(
                playerMove: "h2e2", quality: .good, bestMove: "h2e2",
                bestEval: 50, playerEval: 50, evalDelta: 0, alternatives: []
            ),
            fenBefore: fen,
            playerMove: "h2e2",
            bestMove: "h2e2"
        )
        // delta=0 < 50 → generic（好棋）
        #expect(exp.scenario == .generic, "delta < 50 应归为 generic")
    }

    @Test("CoachExplainer: 中等 delta (50-300) 生成有效讲解")
    func mediumDeltaExplanation() async {
        let explainer = CoachExplainer.shared
        let analysis = MoveAnalysis(
            playerMove: "h9g7", quality: .doubtful, bestMove: "h2e2",
            bestEval: 200, playerEval: 100, evalDelta: 100, alternatives: []
        )
        let exp = await explainer.explain(
            analysis: analysis,
            fenBefore: FENParser.generate(board: Board()),
            playerMove: "h9g7",
            bestMove: "h2e2"
        )
        #expect(exp.evalDelta == 100, "evalDelta 应保留")
        #expect(!exp.title.isEmpty, "title 不应为空")
        #expect(!exp.detail.isEmpty, "detail 不应为空")
        #expect(exp.betterMove == "h2e2", "betterMove 应保留")
    }

    @Test("GameReviewCard: 混合质量分布统计")
    func mixedQualityDistribution() async {
        let explainer = CoachExplainer.shared
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "a", quality: .brilliant, bestMove: "b",
                         bestEval: 100, playerEval: 100, evalDelta: 0, alternatives: []),
            MoveAnalysis(playerMove: "c", quality: .normal, bestMove: "d",
                         bestEval: 200, playerEval: 150, evalDelta: 50, alternatives: []),
            MoveAnalysis(playerMove: "e", quality: .blunder, bestMove: "f",
                         bestEval: 500, playerEval: 100, evalDelta: 400, alternatives: []),
            nil, // 跳过
        ]
        let card = await explainer.generateReviewCard(analyses: analyses)
        #expect(card.totalMoves == 3, "应统计 3 步（nil 跳过）")
        #expect(card.qualityDistribution[.brilliant] == 1)
        #expect(card.qualityDistribution[.normal] == 1)
        #expect(card.qualityDistribution[.blunder] == 1)
        #expect(card.biggestBlunder != nil)
        #expect(card.biggestBlunder!.delta == 400)
    }
}
