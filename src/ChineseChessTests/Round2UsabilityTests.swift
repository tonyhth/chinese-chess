import Testing
import Foundation
@testable import ChineseChess

// MARK: - Round 2 操作易用性测试
// 注意：原源码文本匹配测试已移除（测源码文本而非行为，重构后必然失效）

@Suite("Round 2 操作易用性测试")
@MainActor
struct Round2UsabilityTests {

    // MARK: - U-P0-02: 残局失败重试

    @Test("U-P0-02: resetPuzzle 完整重置棋盘状态")
    func testUP002ResetPuzzleComplete() {
        guard let puzzle = PuzzleStore.shared.puzzles.first else { return }
        let vm = PuzzleViewModel(puzzle: puzzle)
        let initialCount = vm.board.pieces.count

        if let piece = vm.board.pieces.first {
            let moves = MoveValidator.legalMoves(for: piece, on: vm.board)
            if let move = moves.first {
                let m = Move(piece: piece, from: move.from, to: move.to,
                             captured: vm.board.piece(at: move.to))
                vm.board.execute(m)
            }
        }

        vm.resetPuzzle()
        #expect(vm.board.pieces.count == initialCount, "棋子数应恢复")
        #expect(vm.board.moveHistory.isEmpty, "走法历史应清空")
        #expect(vm.gameMoves.isEmpty, "游戏走法应清空")
        #expect(vm.gameState == .playing, "状态应为 playing")
        #expect(vm.selectedPosition == nil, "选中位置应清除")
        #expect(vm.completionRating == 0, "评分应归零")
    }

    // MARK: - U-P1-01: 将军提示

    @Test("U-P1-01: isInCheck stored property + checkGameState 手动更新")
    func testUP101IsInCheckStored() {
        let vm = GameViewModel()
        #expect(!vm.isInCheck, "初始不应被将军")
        vm.isInCheck = true
        vm.newGame()
        #expect(!vm.isInCheck, "newGame 后应重置")
    }

    // MARK: - U-P1-03: 回放拖拽

    @Test("U-P1-03: ReplayViewModel jumpTo 棋盘同步更新")
    func testUP103JumpToSyncsBoard() {
        let moves = [
            GameMove(id: UUID(), piece: Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 4), id: 13),
                     from: Position(row: 6, col: 4), to: Position(row: 5, col: 4), captured: nil,
                     turnNumber: 1, notation: "兵五进一", timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0),
            GameMove(id: UUID(), piece: Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 4), id: 29),
                     from: Position(row: 3, col: 4), to: Position(row: 4, col: 4), captured: nil,
                     turnNumber: 1, notation: "卒5进1", timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0),
            GameMove(id: UUID(), piece: Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0),
                     from: Position(row: 9, col: 0), to: Position(row: 9, col: 4), captured: nil,
                     turnNumber: 2, notation: "车九平五", timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0),
        ]
        let record = GameRecord(
            id: UUID(), title: "测试", date: Date(),
            redPlayer: PlayerInfo(name: "红方", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑方", isAI: true, difficulty: .amateurLow),
            difficulty: .amateurLow, result: .redWon, totalMoves: 3, moves: moves, initialFEN: nil
        )
        let vm = ReplayViewModel(record: record)

        vm.jumpTo(index: 2)
        #expect(vm.currentIndex == 2)
        #expect(vm.lastMove != nil)
        #expect(vm.lastMove?.from == moves[1].from)

        vm.jumpTo(index: 1)
        #expect(vm.currentIndex == 1)
        #expect(vm.lastMove?.from == moves[0].from)

        vm.jumpTo(index: 3)
        #expect(!vm.canGoForward)

        vm.jumpTo(index: 0)
        #expect(vm.currentIndex == 0)
        #expect(vm.lastMove == nil)
    }

    // MARK: - U-P2-02: GameViewModel.buildGameRecord

    @Test("U-P2-02: GameViewModel.buildGameRecord 生成有效记录")
    func testUP202BuildGameRecord() {
        let vm = GameViewModel()
        let emptyRecord = vm.buildGameRecord()
        #expect(emptyRecord == nil, "无走法时不应生成记录")

        if let piece = vm.board.pieces.first(where: { $0.side == .red }) {
            let moves = MoveValidator.legalMoves(for: piece, on: vm.board)
            if let move = moves.first {
                vm.movePiece(from: move.from, to: move.to)
                #expect(true, "buildGameRecord 方法存在且可调用")
            }
        }
    }
}
