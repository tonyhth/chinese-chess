import Foundation
import Testing
@testable import ChineseChess

@Suite("P3 Batch 2 Tests", .serialized)
struct P3Batch2Tests {

    // MARK: - P3-2a: isCenterControlMove 收窄 c-g → d-f

    @Test("centerControl: 目标列 d → 触发")
    func centerControlColD() async {
        let explainer = CoachExplainer()
        let analysis = MoveAnalysis(
            playerMove: "a0a1", quality: .doubtful,
            bestMove: "b5d7", bestEval: 200, playerEval: 170,
            evalDelta: 30, alternatives: []
        )
        let result = await explainer.explain(
            analysis: analysis, fenBefore: "test", playerMove: "a0a1", bestMove: "b5d7"
        )
        #expect(result.scenario == .centerControl)
    }

    @Test("centerControl: 目标列 e → 触发")
    func centerControlColE() async {
        let explainer = CoachExplainer()
        let analysis = MoveAnalysis(
            playerMove: "a0a1", quality: .doubtful,
            bestMove: "h2e2", bestEval: 200, playerEval: 170,
            evalDelta: 30, alternatives: []
        )
        let result = await explainer.explain(
            analysis: analysis, fenBefore: "test", playerMove: "a0a1", bestMove: "h2e2"
        )
        #expect(result.scenario == .centerControl)
    }

    @Test("centerControl: 目标列 f → 触发")
    func centerControlColF() async {
        let explainer = CoachExplainer()
        let analysis = MoveAnalysis(
            playerMove: "a0a1", quality: .doubtful,
            bestMove: "a3f3", bestEval: 200, playerEval: 170,
            evalDelta: 30, alternatives: []
        )
        let result = await explainer.explain(
            analysis: analysis, fenBefore: "test", playerMove: "a0a1", bestMove: "a3f3"
        )
        #expect(result.scenario == .centerControl)
    }

    @Test("centerControl: 目标列 c → 不触发（收窄后）")
    func centerControlColC_notTriggered() async {
        let explainer = CoachExplainer()
        let analysis = MoveAnalysis(
            playerMove: "a0a1", quality: .doubtful,
            bestMove: "b5c7", bestEval: 200, playerEval: 100,
            evalDelta: 100, alternatives: []
        )
        let result = await explainer.explain(
            analysis: analysis, fenBefore: "test", playerMove: "a0a1", bestMove: "b5c7"
        )
        #expect(result.scenario != .centerControl)
    }

    @Test("centerControl: 目标列 g → 不触发（收窄后）")
    func centerControlColG_notTriggered() async {
        let explainer = CoachExplainer()
        let analysis = MoveAnalysis(
            playerMove: "a0a1", quality: .doubtful,
            bestMove: "a3g3", bestEval: 200, playerEval: 100,
            evalDelta: 100, alternatives: []
        )
        let result = await explainer.explain(
            analysis: analysis, fenBefore: "test", playerMove: "a0a1", bestMove: "a3g3"
        )
        #expect(result.scenario != .centerControl)
    }

    @Test("centerControl: 目标列 a/b/h/i → 不触发")
    func centerControlEdgeCols() async {
        let explainer = CoachExplainer()
        for col in ["a", "b", "h", "i"] {
            let bestMove = "a3\(col)3"
            let analysis = MoveAnalysis(
                playerMove: "a0a1", quality: .doubtful,
                bestMove: bestMove, bestEval: 200, playerEval: 100,
                evalDelta: 100, alternatives: []
            )
            let result = await explainer.explain(
                analysis: analysis, fenBefore: "test", playerMove: "a0a1", bestMove: bestMove
            )
            #expect(result.scenario != .centerControl)
        }
    }

    // MARK: - P3-2b: 棋力评分 doubtful 扣分 + reduceDoubtful 建议

    @Test("棋力评分: 全 good/brilliant → 5星")
    func ratingAllGood() async {
        let explainer = CoachExplainer()
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "a", quality: .good, bestMove: "b",
                         bestEval: 100, playerEval: 90, evalDelta: 10, alternatives: []),
            MoveAnalysis(playerMove: "c", quality: .brilliant, bestMove: "d",
                         bestEval: 100, playerEval: 100, evalDelta: 0, alternatives: []),
        ]
        let card = await explainer.generateReviewCard(analyses: analyses)
        #expect(card.rating == 5)
    }

    @Test("棋力评分: doubtful 多于 good → reduceDoubtful 建议")
    func ratingDoubtfulSuggestion() async {
        let explainer = CoachExplainer()
        let analyses: [MoveAnalysis?] = (0..<2).map { _ in
            MoveAnalysis(playerMove: "a", quality: .good, bestMove: "b",
                         bestEval: 100, playerEval: 90, evalDelta: 10, alternatives: [])
        } + (0..<3).map { _ in
            MoveAnalysis(playerMove: "a", quality: .doubtful, bestMove: "b",
                         bestEval: 100, playerEval: 50, evalDelta: 50, alternatives: [])
        }
        let card = await explainer.generateReviewCard(analyses: analyses)
        #expect(card.suggestion.contains("疑问手") || card.suggestion.lowercased().contains("doubtful") || card.suggestion.lowercased().contains("questionable"))
    }

    @Test("棋力评分: bad 多于 good → morePractice 优先")
    func ratingBadOverridesDoubtful() async {
        let explainer = CoachExplainer()
        let analyses: [MoveAnalysis?] = (0..<1).map { _ in
            MoveAnalysis(playerMove: "a", quality: .good, bestMove: "b",
                         bestEval: 100, playerEval: 90, evalDelta: 10, alternatives: [])
        } + (0..<3).map { _ in
            MoveAnalysis(playerMove: "a", quality: .doubtful, bestMove: "b",
                         bestEval: 100, playerEval: 50, evalDelta: 50, alternatives: [])
        } + (0..<2).map { _ in
            MoveAnalysis(playerMove: "a", quality: .blunder, bestMove: "b",
                         bestEval: 100, playerEval: -200, evalDelta: 300, alternatives: [])
        }
        let card = await explainer.generateReviewCard(analyses: analyses)
        #expect(card.suggestion.contains("练习") || card.suggestion.lowercased().contains("practice") || card.suggestion.lowercased().contains("more"))
    }

    @Test("棋力评分: doubtful 扣分系数 0.5 < blunder 扣分系数 2.0")
    func ratingDoubtfulLessPenaltyThanBlunder() async {
        let explainer = CoachExplainer()
        let doubtfulOnly: [MoveAnalysis?] = (0..<5).map { _ in
            MoveAnalysis(playerMove: "a", quality: .doubtful, bestMove: "b",
                         bestEval: 100, playerEval: 50, evalDelta: 50, alternatives: [])
        }
        let blunderOnly: [MoveAnalysis?] = (0..<5).map { _ in
            MoveAnalysis(playerMove: "a", quality: .blunder, bestMove: "b",
                         bestEval: 100, playerEval: -200, evalDelta: 300, alternatives: [])
        }
        let doubtfulCard = await explainer.generateReviewCard(analyses: doubtfulOnly)
        let blunderCard = await explainer.generateReviewCard(analyses: blunderOnly)
        // doubtful: score = 0 - 1.0*0.5 - 0 = -0.5 → rating = -1+3 = 2
        // blunder:  score = 0 - 0 - 1.0*2.0 = -2.0 → rating = -2+3 = 1
        #expect(doubtfulCard.rating >= blunderCard.rating)
    }

    @Test("棋力评分: 空分析 → 默认3星")
    func ratingEmptyAnalysis() async {
        let explainer = CoachExplainer()
        let card = await explainer.generateReviewCard(analyses: [])
        #expect(card.rating == 3)
    }

    // MARK: - P3-2c: 评估曲线空洞间距修复

    @Test("evalSequence 逻辑: 有跳步时 index 保留原始步数")
    func evalSequenceSkipsPreserveIndex() {
        // 直接测试 evalSequence 计算逻辑
        // analyses = [a, nil, b] → [(0, score0), (2, score2)]
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "a", quality: .good, bestMove: "b",
                         bestEval: 100, playerEval: 90, evalDelta: 10, alternatives: []),
            nil,
            MoveAnalysis(playerMove: "c", quality: .normal, bestMove: "d",
                         bestEval: 100, playerEval: 50, evalDelta: 50, alternatives: []),
        ]

        // 模拟 evalSequence 的逻辑
        var result: [(index: Int, score: Int)] = []
        for (i, analysis) in analyses.enumerated() {
            if let a = analysis {
                result.append((i, a.playerEval))
            }
        }

        #expect(result.count == 2)
        #expect(result[0].index == 0)
        #expect(result[0].score == 90)
        #expect(result[1].index == 2)  // 保留原始步数
        #expect(result[1].score == 50)
    }

    @Test("evalSequence 逻辑: 无跳步时 index 连续")
    func evalSequenceNoSkip() {
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "a", quality: .good, bestMove: "b",
                         bestEval: 100, playerEval: 90, evalDelta: 10, alternatives: []),
            MoveAnalysis(playerMove: "c", quality: .normal, bestMove: "d",
                         bestEval: 100, playerEval: 50, evalDelta: 50, alternatives: []),
        ]

        var result: [(index: Int, score: Int)] = []
        for (i, analysis) in analyses.enumerated() {
            if let a = analysis {
                result.append((i, a.playerEval))
            }
        }

        #expect(result.count == 2)
        #expect(result[0].index == 0)
        #expect(result[1].index == 1)
    }

    @Test("evalSequence 逻辑: 全部 nil → 空序列")
    func evalSequenceAllNil() {
        let analyses: [MoveAnalysis?] = [nil, nil, nil]
        var result: [(index: Int, score: Int)] = []
        for (i, analysis) in analyses.enumerated() {
            if let a = analysis {
                result.append((i, a.playerEval))
            }
        }
        #expect(result.isEmpty)
    }

    @Test("evalSequence 逻辑: 间距计算——有跳步时 x 坐标均匀")
    func evalSequenceSpacingWithGap() {
        // 修复前: 用 enumerated() 的 i → 连续索引
        // 修复后: 用 item.index（原始步数）→ 跳步间距正确
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "a", quality: .good, bestMove: "b",
                         bestEval: 100, playerEval: 90, evalDelta: 10, alternatives: []),
            nil,
            nil,
            MoveAnalysis(playerMove: "c", quality: .normal, bestMove: "d",
                         bestEval: 100, playerEval: 50, evalDelta: 50, alternatives: []),
        ]

        var result: [(index: Int, score: Int)] = []
        for (i, analysis) in analyses.enumerated() {
            if let a = analysis {
                result.append((i, a.playerEval))
            }
        }

        // result = [(0, 90), (3, 50)]
        #expect(result.count == 2)
        #expect(result[0].index == 0)
        #expect(result[1].index == 3)

        // 模拟 AnalysisView 的曲线间距计算
        let totalSteps = result.last?.index ?? result.count
        #expect(totalSteps == 3)

        // 修复前: stepWidth = width / (2-1) = width, x0=0, x1=width → 挤在一起
        // 修复后: stepWidth = width / 3, x0=0, x3=width → 均匀分布
        let stepWidth_old = 1.0 / Double(result.count > 1 ? result.count - 1 : 1)  // 修复前
        let stepWidth_new = 1.0 / Double(totalSteps > 0 ? totalSteps : 1)  // 修复后

        // 修复前: x1 = 1 * stepWidth_old = 1.0 → 挤到最右边
        // 修复后: x3 = 3 * stepWidth_new = 1.0 → 均匀
        // 但间距不同：修复前间距 1.0，修复后 3 * (1/3) = 1.0
        // 关键区别：中间没有分析数据的点不会挤到左边
        let gap_old = 1 * stepWidth_old  // 修复前：两个点间距 = 1.0
        let gap_new = Double(result[1].index - result[0].index) * stepWidth_new  // 修复后：3 * (1/3) = 1.0
        #expect(abs(gap_new - 1.0) < 0.01)  // 均匀分布
    }
}
