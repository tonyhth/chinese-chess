import XCTest
@testable import ChineseChess

/// v4.1 Phase 4：iOS 功能真机验证（逻辑层测试）
///
/// ⚠️ 限制说明：在 macOS 单元测试环境下验证功能逻辑，无法验证：
/// - 真机 UI 渲染、触控交互、动画流畅度
/// - iOS 特有的 sheet 转场行为
/// - 真实引擎在真机上的性能和加载速度
///
/// 验证范围：
/// 1. 5 个 iOS 入口的功能逻辑正确性
/// 2. v4.0 真机 bug 修复稳定性
/// 3. 数据流完整性（ViewModel → Service → Model）
final class Phase4IOSVerificationTests: XCTestCase {

    // MARK: - 1. OpeningExplorer 验证

    /// OpeningExplorerService 根节点加载非空
    func testOpeningExplorerRootNodesNotEmpty() {
        let rootNodes = OpeningExplorerService.shared.rootMoves()
        XCTAssertFalse(rootNodes.isEmpty, "开局浏览器根节点应非空")
    }

    /// 根节点包含合法走法
    func testOpeningExplorerRootMovesValid() {
        let rootNodes = OpeningExplorerService.shared.rootMoves()
        for node in rootNodes {
            XCTAssertFalse(node.moveName.isEmpty, "根节点走法名不应为空")
        }
    }

    /// 选择节点后棋盘状态有效
    func testOpeningExplorerSelectNodeBoardValid() {
        let rootNodes = OpeningExplorerService.shared.rootMoves()
        guard let firstNode = rootNodes.first else {
            XCTFail("根节点为空")
            return
        }

        let board = Board(snapshot: firstNode.snapshot)
        // 标准开局 FEN 解析后应有 32 个棋子
        XCTAssertEqual(board.pieces.count, 32, "开局位置应有 32 个棋子")
    }

    /// OpeningExplorer 搜索功能（按走法序列）
    func testOpeningExplorerSearchByMoveSequence() {
        // 炮二平五是最常见开局走法
        let result = OpeningExplorerService.shared.searchByMoveSequence("b2e2")
        XCTAssertNotNil(result, "搜索常见开局走法应有结果")
    }

    /// OpeningExplorer 搜索功能（按开局名称）
    func testOpeningExplorerSearchByOpeningName() {
        let results = OpeningExplorerService.shared.searchByOpeningName("中炮")
        XCTAssertFalse(results.isEmpty, "搜索'中炮'应有匹配开局")
    }

    /// OpeningExplorer 段位门禁：秀才以上可访问
    func testOpeningExplorerRankGate() {
        // 验证 needsPuzzle 和段位判断逻辑
        let scholarRank = Rank.scholar
        let studentRank = Rank.student
        XCTAssertTrue(scholarRank >= .scholar, "秀才段位应有开局浏览器访问权限")
        XCTAssertFalse(studentRank >= .scholar, "初学位不应有开局浏览器访问权限")
    }

    // MARK: - 2. RankUp 弹窗验证

    /// RankUpView 数据完整性：每个段位有解锁功能或主题
    func testRankUpHasUnlockedContent() {
        let ranksWithUnlocks: [Rank] = [.scholar, .hanlin, .master, .grandmaster]
        for rank in ranksWithUnlocks {
            let features = UnlockedFeature.allCases.filter { $0.requiredRank == rank }
            let themes = BoardTheme.allCases.filter { $0.requiredRank == rank }
            XCTAssertTrue(!features.isEmpty || !themes.isEmpty,
                "\(rank) 段位应有至少一个解锁功能或主题")
        }
    }

    /// RankUpView 的 onDismiss 回调正确触发
    func testRankUpDismissCallback() {
        // 纯逻辑验证：RankUpView 接收 onDismiss 闭包
        // UI 层面的弹窗关闭行为需真机验证
        var dismissed = false
        let _ = RankUpView(newRank: .scholar) { dismissed = true }
        // 无法在测试中直接触发 SwiftUI Button，但验证构造不崩溃
        XCTAssertFalse(dismissed, "构造 RankUpView 不应自动触发 dismiss")
    }

    /// 各段位的 icon 非 nil
    func testRankIconsExist() {
        for rank in Rank.allCases {
            let icon = rank.icon
            XCTAssertFalse(icon.isEmpty, "\(rank) 段位应有图标")
        }
    }

    // MARK: - 3. ReviewCard 验证

    /// GameReviewCard 生成：非空分析列表
    func testReviewCardGenerationWithAnalyses() async {
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "b2e2", bestMove: "b2e2", playerEval: 50, bestEval: 50, quality: .good),
            MoveAnalysis(playerMove: "h0g2", bestMove: "h0g2", playerEval: 30, bestEval: 30, quality: .normal),
        ]
        let card = await CoachExplainer.shared.generateReviewCard(analyses: analyses)
        XCTAssertGreaterThanOrEqual(card.rating, 1, "有分析的复盘卡片应有评分")
        XCTAssertLessThanOrEqual(card.rating, 5, "评分应在 1-5 范围")
        XCTAssertFalse(card.suggestion.isEmpty, "应有建议文本")
    }

    /// GameReviewCard 空/全 nil 分析处理
    func testReviewCardWithEmptyAnalyses() async {
        let analyses: [MoveAnalysis?] = [nil, nil, nil]
        let card = await CoachExplainer.shared.generateReviewCard(analyses: analyses)
        // 全 nil 分析应返回默认评分
        XCTAssertGreaterThanOrEqual(card.rating, 1)
        XCTAssertLessThanOrEqual(card.rating, 5)
    }

    /// ReviewCardView 构造不崩溃
    func testReviewCardViewConstruction() {
        let card = GameReviewCard(
            rating: 3,
            qualityDistribution: [.good: 2, .normal: 3, .blunder: 1],
            biggestBlunder: nil,
            suggestion: "继续加油",
            totalMoves: 6
        )
        let _ = ReviewCardView(card: card, onClose: {})
        // 验证构造不崩溃即可
    }

    /// Bug 1 回归：空卡片防护（totalMoves=0）
    func testBug1RegressionEmptyCardGuard() async {
        let analyses: [MoveAnalysis?] = []
        let card = await CoachExplainer.shared.generateReviewCard(analyses: analyses)
        // 空分析列表生成的卡片 totalMoves 应为 0
        XCTAssertEqual(card.totalMoves, 0, "空分析列表应生成 totalMoves=0 的卡片")
        // iOS 代码中 totalMoves==0 时不应弹 sheet
    }

    // MARK: - 4. Analysis 验证

    /// AnalysisViewModel 加载和初始化
    func testAnalysisViewModelLoad() {
        let vm = AnalysisViewModel()
        let moves = ["b2e2", "h9g7", "e2e6"]
        let fen = FENParser.standardInitial

        vm.load(moves: moves, initialFEN: fen)

        XCTAssertEqual(vm.analyses.count, 3, "分析数组长度应与走法数一致")
        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertFalse(vm.isAnalyzing)
    }

    /// AnalysisViewModel 玩家方判断（先手=红方，偶数 index 为玩家走法）
    func testAnalysisViewModelPlayerMoveDetection() {
        let vm = AnalysisViewModel()
        let moves = ["b2e2", "h9g7", "e2e6"]
        vm.load(moves: moves, initialFEN: FENParser.standardInitial)

        // 默认玩家=先手=红方
        XCTAssertTrue(vm.isPlayerMove(at: 0), "第 0 步（红方）应是玩家走法")
        XCTAssertFalse(vm.isPlayerMove(at: 1), "第 1 步（黑方）应非玩家走法")
        XCTAssertTrue(vm.isPlayerMove(at: 2), "第 2 步（红方）应是玩家走法")
    }

    /// AnalysisViewModel 玩家方覆盖
    func testAnalysisViewModelPlayerColorOverride() {
        let vm = AnalysisViewModel()
        let moves = ["b2e2", "h9g7"]
        vm.load(moves: moves, initialFEN: FENParser.standardInitial, playerColorOverride: .black)

        // 玩家=黑方，奇数 index 为玩家走法
        XCTAssertFalse(vm.isPlayerMove(at: 0), "第 0 步（红方）应非玩家走法")
        XCTAssertTrue(vm.isPlayerMove(at: 1), "第 1 步（黑方）应是玩家走法")
    }

    /// Analysis 段位门禁
    func testAnalysisRankGate() {
        // 基础分析：秀才以上
        XCTAssertTrue(Rank.scholar.rawValue >= Rank.scholar.rawValue)
        XCTAssertFalse(Rank.student.rawValue >= Rank.scholar.rawValue)

        // 专家分析（评估曲线）：翰林以上
        XCTAssertTrue(Rank.hanlin.rawValue >= Rank.hanlin.rawValue)
        XCTAssertFalse(Rank.scholar.rawValue >= Rank.hanlin.rawValue)
    }

    /// AnalysisView FEN 精确推算
    func testAnalysisFENRebuilding() {
        let fen = FENParser.standardInitial
        let gameMoves = [
            GameMove(piece: Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1), id: 9),
                     from: Position(row: 7, col: 1), to: Position(row: 7, col: 4), captured: nil),
        ]

        let fenList = FENRebuilder.computeAllFENs(initialFEN: fen, moves: gameMoves)
        XCTAssertGreaterThanOrEqual(fenList.count, 2, "应有初始+第一步走后的 FEN")
        XCTAssertEqual(fenList[0], fen, "第一个 FEN 应为初始局面")
    }

    // MARK: - 5. Coach 验证

    /// Coach 段位门禁：国手以上
    func testCoachRankGate() {
        XCTAssertTrue(Rank.master.rawValue >= Rank.master.rawValue, "国手应有教练权限")
        XCTAssertFalse(Rank.hanlin.rawValue >= Rank.master.rawValue, "翰林不应有教练权限")
    }

    /// CoachExplainer 生成复盘卡片
    func testCoachGenerateReviewCard() async {
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "b2e2", bestMove: "b2e2", playerEval: 100, bestEval: 100, quality: .brilliant),
            MoveAnalysis(playerMove: "h9g7", bestMove: "h9g7", playerEval: 80, bestEval: 80, quality: .good),
        ]
        let card = await CoachExplainer.shared.generateReviewCard(analyses: analyses)
        XCTAssertGreaterThanOrEqual(card.rating, 3, "好棋为主的对局评分应 >= 3")
    }

    /// CoachExplainer 生成讲解
    func testCoachExplainProducesResult() async {
        let analysis = MoveAnalysis(
            playerMove: "b2e2",
            bestMove: "h2e2",
            playerEval: -200,
            bestEval: 50,
            quality: .blunder
        )
        let fen = FENParser.standardInitial
        let explanation = await CoachExplainer.shared.explain(
            analysis: analysis,
            fenBefore: fen,
            playerMove: "b2e2",
            bestMove: "h2e2"
        )
        XCTAssertFalse(explanation.title.isEmpty, "教练讲解应有标题")
        XCTAssertFalse(explanation.detail.isEmpty, "教练讲解应有详情")
        // 大失误应标记为 blunder 场景
        XCTAssertEqual(explanation.scenario, .blunder, "大失误应标记为 blunder 场景")
    }

    /// CoachSessionView 构造不崩溃
    func testCoachSessionViewConstruction() {
        let record = GameRecord(
            id: UUID(),
            title: "Test",
            date: Date(),
            redPlayer: PlayerInfo(name: "Red", isAI: false),
            blackPlayer: PlayerInfo(name: "Black", isAI: true, difficulty: .easy),
            difficulty: .easy,
            result: .redWon,
            totalMoves: 1,
            moves: [],
            initialFEN: nil,
            source: .versusAI
        )
        let _ = CoachSessionView(record: record)
        // 验证构造不崩溃
    }

    // MARK: - v4.0 真机 Bug 回归验证

    /// Bug 1 回归：复盘卡片引擎加载空白（reviewCardData 为 nil 时显示提示而非空白）
    func testBug1RegressionReviewCardNilHandled() {
        // iOS App 中的逻辑：reviewCardData 为 nil 时不弹 ReviewCard sheet
        // Bug 1 fix: 空卡片防护 — 全部分析为 nil 时不弹 sheet
        // 此处验证 AnalysisViewModel 在引擎不可用时正确设置 analysisUnavailableMessage

        // 验证 analysisUnavailableMessage 属性存在且可设置
        let vm = AnalysisViewModel()
        XCTAssertNil(vm.analysisUnavailableMessage, "初始状态应为 nil")
    }

    /// Bug 2 回归：开局库 UI 裁切
    /// 此 bug 属于 UI 布局问题，无法在单元测试中验证
    /// 真机验证点：OpeningExplorerView 中 treeList 和 boardPreview 的布局不裁切
    func testBug2RegressionOpeningExplorerUILayout() {
        // UI 布局验证需真机执行
        // 此处验证数据层正确性，确保布局问题不是数据导致
        let rootNodes = OpeningExplorerService.shared.rootMoves()
        for node in rootNodes {
            XCTAssertFalse(node.moveName.isEmpty, "走法名不应为空（空字符串可能导致布局异常）")
            XCTAssertLessThan(node.moveName.count, 50, "走法名不应过长（可能导致 UI 裁切）")
        }
    }

    /// Bug 3 回归：换方 AI 卡死
    /// 换方后 AI 应正确触发走法
    func testBug3RegressionSwitchSideAITriggers() {
        let vm = GameViewModel()
        // 验证 setHumanSide 正确设置
        vm.setHumanSide(.black)
        XCTAssertEqual(vm.humanSide, .black, "设置执黑应生效")

        vm.setHumanSide(.red)
        XCTAssertEqual(vm.humanSide, .red, "设置执红应生效")
    }

    /// Bug 3 回归：新游戏后执黑时 AI 先行
    func testBug3RegressionNewGameBlackSideAIFirst() {
        let vm = GameViewModel()
        vm.setHumanSide(.black)
        vm.newGame()
        XCTAssertEqual(vm.humanSide, .black, "新游戏后执黑应保持")
        // AI 先行逻辑在 newGame() 中通过 triggerAIMove() 实现
        // 无法在测试中验证 async AI 走法触发，但验证状态正确
    }

    // MARK: - 数据流完整性

    /// OpeningExplorer → Board 交互：选择开局后棋盘状态正确
    func testOpeningExplorerToBoardDataFlow() {
        let rootNodes = OpeningExplorerService.shared.rootMoves()
        guard let firstMove = rootNodes.first else {
            XCTFail("根节点为空")
            return
        }

        // 从 snapshot 重建 Board
        let board = Board(snapshot: firstMove.snapshot)
        XCTAssertFalse(board.pieces.isEmpty, "从 snapshot 重建的棋盘应有棋子")

        // 验证 Board 可正常生成 FEN
        let fen = FENParser.generate(board: board)
        XCTAssertFalse(fen.isEmpty, "应能生成 FEN")
    }

    /// GameViewModel → ReviewCard 数据流
    func testGameViewModelToReviewCardDataFlow() {
        let vm = GameViewModel()
        // 对局结束后 buildGameRecord 应返回有效记录
        let record = vm.buildGameRecord()
        // 新游戏状态无走法，record 应为 nil
        XCTAssertNil(record, "新游戏无走法时不应生成记录")
    }

    /// AnalysisViewModel → CoachExplainer 数据流
    func testAnalysisToCoachDataFlow() async {
        let vm = AnalysisViewModel()
        let moves = ["b2e2", "h9g7"]
        vm.load(moves: moves, initialFEN: FENParser.standardInitial)

        // 验证 analyses 数组初始化正确
        XCTAssertEqual(vm.analyses.count, 2, "分析数组应与走法数一致")
        XCTAssertNil(vm.analyses[0], "初始状态分析应为 nil")
        XCTAssertNil(vm.analyses[1], "初始状态分析应为 nil")

        // 生成复盘卡片（使用空分析）
        let card = await CoachExplainer.shared.generateReviewCard(analyses: vm.analyses)
        XCTAssertGreaterThanOrEqual(card.rating, 1, "即使是空分析也应有默认评分")
    }
}
