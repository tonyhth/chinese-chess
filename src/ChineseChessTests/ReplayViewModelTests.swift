import XCTest
@testable import ChineseChess

// MARK: - v3.7.5 回放 Bug 修复测试
//
// 测试范围：
// 1. rebuildBoard snapshot 循环范围修复验证
// 2. Board.execute id 匹配问题验证（P0 回归）
// 3. goForward / goToEnd / jumpTo / goBack 一致性

@MainActor
final class ReplayBoardRebuildTests: XCTestCase {

    // ============================================================
    // 辅助方法
    // ============================================================

    private func makeInitialBoard() -> Board {
        Board(fen: FENParser.standardInitial)
    }

    /// 构造一条有 N 步走法的 GameRecord
    /// 关键：GameMove.piece 的 id 来自推演用 board，与 ReplayViewModel 内部新建 board 的棋子 id 不同
    private func makeRecord(moves count: Int) -> (GameRecord, Board) {
        let board = makeInitialBoard()
        var gameMoves: [GameMove] = []

        for i in 0..<count {
            let side: Side = (i % 2 == 0) ? .red : .black
            let allMoves = MoveValidator.allLegalMoves(for: side, on: board)
            guard let mv = allMoves.first else { break }
            board.execute(mv)
            gameMoves.append(GameMove(
                id: UUID(),
                piece: mv.piece,
                from: mv.from,
                to: mv.to,
                captured: mv.captured,
                turnNumber: i / 2 + 1,
                notation: "",
                timestamp: Date(),
                isCheck: false,
                isCheckmate: false,
                halfmoveClock: 0
            ))
        }

        let record = GameRecord(
            title: "测试",
            redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: .amateurLow),
            difficulty: .amateurLow,
            result: .redWon,
            totalMoves: gameMoves.count,
            moves: gameMoves,
            initialFEN: FENParser.standardInitial,
            source: .versusAI
        )
        return (record, board)
    }

    // ============================================================
    // P0: Board.execute id 匹配验证
    // ============================================================

    /// v3.9 修正：Piece.id 已从 UUID 改为稳定 Int（0-31），
    /// 同一 FEN 创建的 Board 实例，相同位置棋子 id 应相同。
    /// 此测试验证 ID 稳定性（之前断言 UUID 不同已过时）。
    func testBoard_FENDifferentUUIDs() {
        let fen = FENParser.standardInitial
        let board1 = Board(fen: fen)
        let board2 = Board(fen: fen)

        // 检查同一位置棋子的 id
        let pos = Position(row: 9, col: 0)  // 红方左车
        let p1 = board1.piece(at: pos)!
        let p2 = board2.piece(at: pos)!

        // v3.9: Piece.id 是稳定 Int，同一位置应相同
        XCTAssertEqual(p1.id, p2.id,
                       "从同一 FEN 创建的不同 Board 实例，相同位置棋子 id 应相同（稳定 Int）")
    }

    /// v3.9 修正：Piece.id 是稳定 Int，不同 Board 实例同一位置棋子 id 匹配。
    /// execute 应正确执行走法。此测试验证 ID 稳定性修复。
    func testBoard_Execute_RequiresMatchingID() {
        let board1 = Board(fen: FENParser.standardInitial)
        let board2 = Board(fen: FENParser.standardInitial)

        // 从 board1 获取一个合法走法
        let moves = MoveValidator.allLegalMoves(for: .red, on: board1)
        guard let mv = moves.first else {
            XCTFail("初始局面应有合法走法")
            return
        }

        // 在 board2 上执行这个走法（piece.id 来自 board1）
        let moveForBoard2 = Move(
            piece: mv.piece,        // id 来自 board1，但同一位置 id 相同
            from: mv.from,
            to: mv.to,
            captured: mv.captured   // id 来自 board1（如有）
        )
        board2.execute(moveForBoard2)

        // v3.9: id 是稳定 Int，应该匹配，execute 应成功执行
        let pieceMoved = board2.piece(at: mv.from)
        XCTAssertNil(pieceMoved,
                     "id 匹配时 execute 应正确移动棋子，from 位置应为空")
    }

    // ============================================================
    // P0: goForward 回归验证
    // ============================================================

    /// 新代码 goForward 使用 move.piece（id 来自创建 GameRecord 时的 board）
    /// ReplayViewModel 内部新建 Board 的棋子 id 不同 → execute 不生效
    func testGoForward_PieceIDMismatch_Regression() {
        let (record, expectedBoard) = makeRecord(moves: 3)
        let vm = ReplayViewModel(record: record)

        vm.goForward()
        vm.goForward()
        vm.goForward()

        XCTAssertEqual(vm.currentIndex, 3, "currentIndex 应走到 3")

        // 如果 execute 没有正确执行，棋盘仍是初始状态（32 棋子）
        let initial = makeInitialBoard()
        if vm.board.pieces.count == initial.pieces.count {
            // 棋子数与初始一致，检查是否位置也一致（说明什么都没移动）
            var allAtInitial = true
            for piece in initial.pieces {
                let actual = vm.board.piece(at: piece.position)
                if actual?.kind != piece.kind || actual?.side != piece.side {
                    allAtInitial = false
                    break
                }
            }
            if allAtInitial {
                XCTFail("P0 回归：goForward 后棋盘仍为初始状态，Board.execute 因 id 不匹配未生效")
            }
        }
    }

    // ============================================================
    // 棋盘状态正确性验证（v3.7.5 回归修复后深度测试）
    // ============================================================

    /// goForward 逐步走到最后 → 棋盘应与真实推演完全一致
    func testGoForward_BoardStateMatchesReal() {
        let (record, finalBoard) = makeRecord(moves: 25)
        let vm = ReplayViewModel(record: record)

        while vm.canGoForward { vm.goForward() }

        XCTAssertEqual(vm.board.pieces.count, finalBoard.pieces.count,
                       "逐步走到最后，棋子数应与真实推演一致")
        for expected in finalBoard.pieces {
            let actual = vm.board.piece(at: expected.position)
            XCTAssertEqual(actual?.kind, expected.kind,
                           "位置 \(expected.position) 棋子类型应一致")
            XCTAssertEqual(actual?.side, expected.side,
                           "位置 \(expected.position) 棋子方应一致")
        }
    }

    /// goToEnd → 棋盘应与真实推演完全一致
    func testGoToEnd_BoardStateMatchesReal() {
        let (record, finalBoard) = makeRecord(moves: 25)
        let vm = ReplayViewModel(record: record)

        vm.goToEnd()

        XCTAssertEqual(vm.board.pieces.count, finalBoard.pieces.count,
                       "goToEnd 后棋子数应与真实推演一致")
        for expected in finalBoard.pieces {
            let actual = vm.board.piece(at: expected.position)
            XCTAssertEqual(actual?.kind, expected.kind,
                           "goToEnd 后位置 \(expected.position) 棋子类型应一致")
            XCTAssertEqual(actual?.side, expected.side)
        }
    }

    /// 逐步走 vs goToEnd 棋盘状态一致
    func testStepByStep_EqualsGoToEnd_BoardState() {
        let (record, _) = makeRecord(moves: 25)

        let vm1 = ReplayViewModel(record: record)
        while vm1.canGoForward { vm1.goForward() }

        let vm2 = ReplayViewModel(record: record)
        vm2.goToEnd()

        XCTAssertEqual(vm1.board.pieces.count, vm2.board.pieces.count)
        for piece in vm1.board.pieces {
            let p2 = vm2.board.piece(at: piece.position)
            XCTAssertEqual(p2?.kind, piece.kind,
                           "逐步走 vs goToEnd，位置 \(piece.position) 应一致")
            XCTAssertEqual(p2?.side, piece.side)
        }
    }

    /// jumpTo 跨快照边界 → 棋盘状态正确
    func testJumpTo_BoardState_AcrossSnapshot() {
        let (record, _) = makeRecord(moves: 25)

        // 逐步走到 22 作为基准（跨 snapshotInterval=20 边界）
        let refVM = ReplayViewModel(record: record)
        for _ in 0..<22 { refVM.goForward() }

        // jumpTo 到 22
        let vm = ReplayViewModel(record: record)
        vm.jumpTo(index: 22)

        XCTAssertEqual(vm.board.pieces.count, refVM.board.pieces.count,
                       "jumpTo(22) 棋子数应与逐步走到 22 一致")
        for piece in refVM.board.pieces {
            let actual = vm.board.piece(at: piece.position)
            XCTAssertEqual(actual?.kind, piece.kind,
                           "jumpTo(22) 位置 \(piece.position) 棋子应一致")
            XCTAssertEqual(actual?.side, piece.side)
        }
    }

    /// goBack 从末尾回退 → 棋盘状态正确
    func testGoBack_BoardState_FromEnd() {
        let (record, _) = makeRecord(moves: 25)

        // 基准：逐步走到 20
        let refVM = ReplayViewModel(record: record)
        for _ in 0..<20 { refVM.goForward() }

        // goToEnd → 回退 5 步到 20
        let vm = ReplayViewModel(record: record)
        vm.goToEnd()
        for _ in 0..<5 { vm.goBack() }

        XCTAssertEqual(vm.currentIndex, 20)
        XCTAssertEqual(vm.board.pieces.count, refVM.board.pieces.count,
                       "回退到 20 的棋盘应与逐步走到 20 一致")
        for piece in refVM.board.pieces {
            let actual = vm.board.piece(at: piece.position)
            XCTAssertEqual(actual?.kind, piece.kind,
                           "回退到 20，位置 \(piece.position) 棋子应一致")
            XCTAssertEqual(actual?.side, piece.side)
        }
    }

    /// 恰好 20 步（snapshotInterval 边界）— jumpTo 后棋盘正确
    func testJumpTo_ExactlySnapshotInterval_BoardState() {
        let (record, finalBoard) = makeRecord(moves: 20)

        // 先逐步走建立快照
        let setupVM = ReplayViewModel(record: record)
        while setupVM.canGoForward { setupVM.goForward() }

        // 新 VM jumpTo(20) 使用快照
        let vm = ReplayViewModel(record: record)
        vm.jumpTo(index: 20)

        XCTAssertEqual(vm.board.pieces.count, finalBoard.pieces.count)
        for expected in finalBoard.pieces {
            let actual = vm.board.piece(at: expected.position)
            XCTAssertEqual(actual?.kind, expected.kind,
                           "jumpTo(20) 位置 \(expected.position) 棋子应一致")
        }
    }

    /// 混合操作后棋盘正确
    func testMixedNavigation_BoardState() {
        let (record, finalBoard) = makeRecord(moves: 25)
        let vm = ReplayViewModel(record: record)

        vm.goForward()   // 1
        vm.goForward()   // 2
        vm.goForward()   // 3
        vm.jumpTo(index: 15)
        vm.goForward()   // 16
        vm.goBack()      // 15
        vm.goToEnd()     // 25

        XCTAssertEqual(vm.board.pieces.count, finalBoard.pieces.count,
                       "混合操作后棋子数应与真实推演一致")
        for expected in finalBoard.pieces {
            let actual = vm.board.piece(at: expected.position)
            XCTAssertEqual(actual?.kind, expected.kind,
                           "混合操作后位置 \(expected.position) 棋子应一致")
            XCTAssertEqual(actual?.side, expected.side)
        }
    }

    // ============================================================
    // 基础导航功能（currentIndex 相关，不受 id 问题影响）
    // ============================================================

    func testGoToStart() {
        let (record, _) = makeRecord(moves: 10)
        let vm = ReplayViewModel(record: record)
        vm.goToEnd()
        vm.goToStart()

        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertNil(vm.lastMove)
    }

    func testJumpTo_Boundaries() {
        let (record, _) = makeRecord(moves: 10)
        let vm = ReplayViewModel(record: record)

        vm.jumpTo(index: 0)
        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertNil(vm.lastMove)

        vm.jumpTo(index: 10)
        XCTAssertEqual(vm.currentIndex, 10)
        XCTAssertNotNil(vm.lastMove)
    }

    func testJumpTo_OutOfRange() {
        let (record, _) = makeRecord(moves: 5)
        let vm = ReplayViewModel(record: record)

        vm.jumpTo(index: -1)
        XCTAssertEqual(vm.currentIndex, 0, "负数应 clamp 到 0")

        vm.jumpTo(index: 100)
        XCTAssertEqual(vm.currentIndex, 5, "超过 moves.count 应 clamp")
    }

    func testEmptyRecord() {
        let record = GameRecord(
            title: "空",
            redPlayer: PlayerInfo(name: "r", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "b", isAI: true, difficulty: .amateurLow),
            difficulty: .amateurLow,
            result: .redWon,
            totalMoves: 0,
            moves: [],
            initialFEN: nil,
            source: .versusAI
        )
        let vm = ReplayViewModel(record: record)

        vm.goToEnd()
        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertFalse(vm.canGoForward)
        XCTAssertFalse(vm.canGoBack)
    }

    func testSingleMove() {
        let (record, _) = makeRecord(moves: 1)
        let vm = ReplayViewModel(record: record)

        vm.goForward()
        XCTAssertEqual(vm.currentIndex, 1)
        XCTAssertNotNil(vm.lastMove)
    }

    func testMixedNavigation_IndexConsistency() {
        let (record, _) = makeRecord(moves: 25)
        let vm = ReplayViewModel(record: record)

        vm.goForward()
        vm.goForward()
        vm.goForward()
        XCTAssertEqual(vm.currentIndex, 3)

        vm.jumpTo(index: 15)
        XCTAssertEqual(vm.currentIndex, 15)

        vm.goForward()
        XCTAssertEqual(vm.currentIndex, 16)

        vm.goBack()
        XCTAssertEqual(vm.currentIndex, 15)

        vm.goToEnd()
        XCTAssertEqual(vm.currentIndex, 25)

        vm.goToStart()
        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertNil(vm.lastMove)
    }

    // ============================================================
    // canGoForward / canGoBack
    // ============================================================

    func testCanGoForward_Back() {
        let (record, _) = makeRecord(moves: 5)
        let vm = ReplayViewModel(record: record)

        XCTAssertTrue(vm.canGoForward)
        XCTAssertFalse(vm.canGoBack)

        vm.goToEnd()
        XCTAssertFalse(vm.canGoForward)
        XCTAssertTrue(vm.canGoBack)

        vm.goToStart()
        XCTAssertTrue(vm.canGoForward)
        XCTAssertFalse(vm.canGoBack)
    }
}
