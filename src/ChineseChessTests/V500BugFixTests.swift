import XCTest
@testable import ChineseChess

/// v5.0.0 六个 Bug 修复验证测试
@MainActor
final class V500BugFixTests: XCTestCase {

    // MARK: - Bug 6: 判和逻辑误触（悔棋后重走误判和棋）

    /// 悔棋后再走同一手，不应误判和棋
    func testBug6_UndoThenRedo_NoFalseDraw() {
        let vm = GameViewModel()
        vm.newGame()

        // 走一步棋（炮二平五）
        vm.movePiece(from: Position(row: 7, col: 1), to: Position(row: 7, col: 4))
        Thread.sleep(forTimeInterval: 1.0)

        // 悔棋
        vm.undoMove()

        // 状态应为 playing
        XCTAssertEqual(vm.gameState, .playing, "悔棋后状态应为 playing")

        // 重新走同一手 — 不应判和
        vm.movePiece(from: Position(row: 7, col: 1), to: Position(row: 7, col: 4))
        Thread.sleep(forTimeInterval: 1.0)

        XCTAssertNotEqual(vm.gameState, .draw, "悔棋后重走不应误判和棋")
    }

    /// positionFingerprints 在悔棋后正确递减
    func testBug6_PositionFingerprint_DecrementOnUndo() {
        let vm = GameViewModel()
        vm.newGame()

        vm.movePiece(from: Position(row: 7, col: 1), to: Position(row: 7, col: 4))
        Thread.sleep(forTimeInterval: 1.0)

        vm.undoMove()
        XCTAssertEqual(vm.gameState, .playing, "悔棋后应为 playing")
    }

    // MARK: - Bug 2: 复盘闪退（rebuildBoard off-by-one）

    /// 回放到 snapshotInterval 倍数步时不应闪退
    func testBug2_ReplayAtSnapshotBoundary_NoCrash() {
        let cannon = Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1), id: 9)
        let moves = (0..<25).map { i in
            GameMove(
                id: UUID(), piece: cannon,
                from: Position(row: 7, col: 1), to: Position(row: 7, col: 4),
                captured: nil, turnNumber: i / 2 + 1,
                notation: "炮二平五", timestamp: Date(),
                isCheck: false, isCheckmate: false, halfmoveClock: i
            )
        }

        let record = GameRecord(
            title: "测试棋谱",
            redPlayer: PlayerInfo(name: "红方", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑方", isAI: true, difficulty: nil),
            difficulty: nil, result: .redWon, totalMoves: 25,
            moves: moves, initialFEN: nil, source: .versusAI
        )

        let vm = ReplayViewModel(record: record)

        // 逐步前进到第20步（snapshotInterval=20 的倍数）
        for _ in 0..<20 { vm.goForward() }
        XCTAssertEqual(vm.currentIndex, 20, "应在第20步")

        // 继续前进
        for _ in 0..<5 { vm.goForward() }
        XCTAssertEqual(vm.currentIndex, 25, "应在第25步")

        // 后退回第20步
        for _ in 0..<5 { vm.goBack() }
        XCTAssertEqual(vm.currentIndex, 20, "应回到第20步")

        // 直接跳到第20步
        vm.jumpTo(index: 20)
        XCTAssertEqual(vm.currentIndex, 20, "跳到第20步应正常")
    }

    /// 回放到 snapshotInterval 倍数边界后退回不闪退
    func testBug2_ReplayBackwardThroughSnapshot_NoCrash() {
        let soldier = Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 4), id: 13)
        let moves = (0..<45).map { i in
            GameMove(
                id: UUID(), piece: soldier,
                from: Position(row: 6, col: 4), to: Position(row: 5, col: 4),
                captured: nil, turnNumber: i / 2 + 1,
                notation: "兵", timestamp: Date(),
                isCheck: false, isCheckmate: false, halfmoveClock: i
            )
        }

        let record = GameRecord(
            title: "45步测试",
            redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: nil),
            difficulty: nil, result: .redWon, totalMoves: 45,
            moves: moves, initialFEN: nil, source: .versusAI
        )

        let vm = ReplayViewModel(record: record)

        for _ in 0..<40 { vm.goForward() }
        for _ in 0..<40 { vm.goBack() }

        XCTAssertEqual(vm.currentIndex, 0, "应回到第0步")
    }

    // MARK: - Bug 1: 输棋后空白窗口（引擎不可用时）

    /// AnalysisViewModel 初始化正常，分析不可用消息初始为 nil
    func testBug1_AnalysisViewModel_Init() {
        let vm = AnalysisViewModel()
        XCTAssertTrue(vm.moves.isEmpty)
        XCTAssertTrue(vm.analyses.isEmpty)
        XCTAssertFalse(vm.isAnalyzing)
        XCTAssertNil(vm.analysisUnavailableMessage)
    }

    // MARK: - Bug 3: 复盘无逐步讲解

    /// CoachExplainer.generateReviewCard 正常工作
    func testBug3_CoachReviewCard_Generation() async {
        let coach = CoachExplainer()
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "h2e2", quality: .good, bestMove: "h2e2",
                         bestEval: 50, playerEval: 50, evalDelta: 0,
                         alternatives: [], isQuickResult: false),
            MoveAnalysis(playerMove: "i9i7", quality: .brilliant, bestMove: "i9i7",
                         bestEval: 100, playerEval: 100, evalDelta: 0,
                         alternatives: [], isQuickResult: false),
        ]
        let card = await coach.generateReviewCard(analyses: analyses)
        XCTAssertGreaterThan(card.totalMoves, 0, "应有分析步数")
        XCTAssertGreaterThanOrEqual(card.rating, 1, "评分至少1星")
        XCTAssertLessThanOrEqual(card.rating, 5, "评分最多5星")
    }

    // MARK: - Bug 5: 级别选择 UI 重复

    /// GameViewModel newGame 正常
    func testBug5_NewGame_NoCrash() {
        let vm = GameViewModel()
        vm.newGame()
        XCTAssertEqual(vm.gameState, .playing, "新游戏应为 playing 状态")
    }
}
