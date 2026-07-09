import Foundation
import Testing
@testable import ChineseChess

// MARK: - v4.1 Phase 5: iOS 功能逻辑补充测试

// v5.0: OpeningTreeStore/OpeningTreeNode 已移除，旧测试归档到 _archive_v4/
// OpeningExplorerView 仍存在但内部重构为懒展开
/*
@Suite("v4.1 Phase 5: OpeningExplorer 数据加载", .serialized)
struct V41OpeningExplorerTests {

    @Test("OpeningTreeStore 共享实例存在")
    func storeSharedExists() {
        let store = OpeningTreeStore.shared
        #expect(store.roots.isEmpty == false, "roots 应非空（从预编译数据加载）")
    }

    @Test("OpeningTreeNode 结构完整")
    func nodeStructure() {
        let node = OpeningTreeNode(move: "h2e2", moveName: "炮二平五", weight: 100, children: [])
        #expect(node.move == "h2e2")
        #expect(node.moveName == "炮二平五")
        #expect(node.weight == 100)
    }

    @Test("OpeningExplorerView 类型存在")
    func explorerViewExists() {
        #expect(OpeningExplorerView.self != NSObject.self)
    }

    @Test("OpeningTreeStore 根节点有 children")
    func rootHasChildren() {
        let store = OpeningTreeStore.shared
        #expect(!store.roots.isEmpty, "roots 应有开局起步节点")
    }
}
*/

@Suite("v4.1 Phase 5: Analysis 引擎调用逻辑", .serialized)
struct V41AnalysisEngineTests {

    @Test("AnalysisViewModel 初始化状态")
    func analysisInitState() {
        let vm = AnalysisViewModel()
        #expect(vm.moves.isEmpty)
        #expect(vm.currentIndex == 0)
        #expect(vm.isAnalyzing == false)
    }

    @Test("AnalysisViewModel load 后 moves 非空")
    func analysisLoadMoves() {
        let vm = AnalysisViewModel()
        vm.load(moves: ["e2e4", "e9e8"], initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w")
        #expect(vm.moves.count == 2)
        #expect(vm.currentIndex == 0)
    }

    @Test("AnalysisViewModel firstMoverColor 从 FEN 推断")
    func analysisFirstMoverFromFEN() {
        let vm = AnalysisViewModel()
        // 红方先手（w）
        vm.load(moves: [], initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w")
        #expect(vm.firstMoverColor == .red, "FEN 中 w 表示红方先手")

        // 黑方先手（b）
        vm.load(moves: [], initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b")
        #expect(vm.firstMoverColor == .black, "FEN 中 b 表示黑方先手")
    }

    @Test("AnalysisViewModel isPlayerMove 判断")
    func analysisIsPlayerMove() {
        let vm = AnalysisViewModel()
        vm.load(moves: ["a", "b", "c", "d"], initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w")

        // 先手方（红），偶数 index 是玩家
        #expect(vm.isPlayerMove(at: 0) == true, "index 0 是先手方")
        #expect(vm.isPlayerMove(at: 1) == false, "index 1 是后手方")
        #expect(vm.isPlayerMove(at: 2) == true, "index 2 是先手方")
        #expect(vm.isPlayerMove(at: 3) == false, "index 3 是后手方")
    }

    @Test("AnalysisViewModel load 空 moves")
    func analysisLoadEmpty() {
        let vm = AnalysisViewModel()
        vm.load(moves: [], initialFEN: "")
        #expect(vm.moves.isEmpty)
        #expect(vm.analyses.isEmpty)
    }

    @Test("AnalysisViewModel load 后 analyses 数量匹配")
    func analysisCountMatches() {
        let vm = AnalysisViewModel()
        let moves = ["e2e4", "e9e8", "e4e5"]
        vm.load(moves: moves, initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w")
        #expect(vm.analyses.count == moves.count)
        #expect(vm.analyses.allSatisfy { $0 == nil }, "初始加载后 analyses 应全为 nil")
    }
}

@Suite("v4.1 Phase 5: Coach 段位推荐逻辑", .serialized)
struct V41CoachRecommenderTests {

    @Test("CoachExplainer 共享实例存在")
    func coachSharedExists() {
        let _ = CoachExplainer.shared
        #expect(Bool(true))
    }

    private func makeAnalysis(quality: MoveQuality, delta: Int) -> MoveAnalysis {
        MoveAnalysis(
            playerMove: "h2e2", quality: quality, bestMove: "h2e2",
            bestEval: 100, playerEval: 100 - delta, evalDelta: delta,
            alternatives: []
        )
    }

    @Test("GameReviewCard: 全部好棋 → 高评分")
    func reviewCardAllGood() async {
        let coach = CoachExplainer.shared
        let analyses: [MoveAnalysis?] = [
            makeAnalysis(quality: .brilliant, delta: 10),
            makeAnalysis(quality: .good, delta: 20),
        ]
        let card = await coach.generateReviewCard(analyses: analyses)
        #expect(card.totalMoves == 2)
        #expect(card.rating >= 4, "全好棋应获得 4+ 星评分")
    }

    @Test("GameReviewCard: 全部失误 → 低评分")
    func reviewCardAllBad() async {
        let coach = CoachExplainer.shared
        let analyses: [MoveAnalysis?] = [
            makeAnalysis(quality: .blunder, delta: 150),
            makeAnalysis(quality: .losing, delta: 300),
        ]
        let card = await coach.generateReviewCard(analyses: analyses)
        #expect(card.totalMoves == 2)
        #expect(card.rating <= 2, "全失误应获得 2 星以下评分")
        #expect(card.biggestBlunder != nil, "应有最大失误记录")
    }

    @Test("GameReviewCard: 空分析 → 默认 3 星")
    func reviewCardEmpty() async {
        let coach = CoachExplainer.shared
        let card = await coach.generateReviewCard(analyses: [])
        #expect(card.totalMoves == 0)
        #expect(card.rating == 3, "无分析数据应默认 3 星")
        #expect(card.biggestBlunder == nil, "无失误记录")
    }

    @Test("GameReviewCard: 混合棋步")
    func reviewCardMixed() async {
        let coach = CoachExplainer.shared
        let analyses: [MoveAnalysis?] = [
            makeAnalysis(quality: .brilliant, delta: 10),
            makeAnalysis(quality: .blunder, delta: 200),
            makeAnalysis(quality: .good, delta: 15),
            nil,
        ]
        let card = await coach.generateReviewCard(analyses: analyses)
        #expect(card.totalMoves == 3, "nil 条目不计入 totalMoves")
        #expect(card.biggestBlunder != nil)
        #expect(card.biggestBlunder?.moveIndex == 1, "最大失误应在 index 1")
    }
}
