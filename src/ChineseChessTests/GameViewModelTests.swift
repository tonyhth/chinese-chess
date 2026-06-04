import Testing
@testable import ChineseChess

@Suite("GameViewModel Interaction Tests")
struct GameViewModelTests {

    @Test("选中棋子后移动到空位")
    func selectAndMoveToEmpty() {
        let vm = GameViewModel()
        // 红炮在 (7,1)，前方 (7,4) 是空位
        let cannonPos = Position(row: 7, col: 1)
        let targetPos = Position(row: 7, col: 4)

        // 选中炮
        vm.selectPiece(at: cannonPos)
        #expect(vm.selectedPosition == cannonPos)
        #expect(vm.legalMovesForSelected.contains(targetPos))

        // 移动到空位
        vm.selectPiece(at: targetPos)
        #expect(vm.selectedPosition == nil)  // 移动后清空选中
        #expect(vm.board.piece(at: targetPos)?.kind == .cannon)
        #expect(vm.board.piece(at: cannonPos) == nil)
        #expect(vm.currentTurn == .black)
    }

    @Test("选中棋子吃对方棋子")
    func selectAndCapture() {
        let vm = GameViewModel()
        // 设置场景：红车在 (5,0)，黑卒在 (3,0)
        let board = Board(pieces: [
            Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0)),
            Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 0)),
            Piece(kind: .general, side: .red, position: Position(row: 9, col: 3)),
            Piece(kind: .general, side: .black, position: Position(row: 0, col: 5))
        ])
        vm.board = board

        vm.selectPiece(at: Position(row: 5, col: 0))
        vm.selectPiece(at: Position(row: 3, col: 0))

        #expect(vm.board.piece(at: Position(row: 3, col: 0))?.kind == .chariot)
        #expect(vm.board.piece(at: Position(row: 3, col: 0))?.side == .red)
        #expect(vm.capturedPieces.red.count == 1)
    }

    @Test("选中棋子后点击非法位置不移动")
    func selectAndInvalidMove() {
        let vm = GameViewModel()
        // 红帅在 (9,4)，非法位置比如 (9,0)
        vm.selectPiece(at: Position(row: 9, col: 4))
        vm.selectPiece(at: Position(row: 9, col: 0))

        // 帅不应移动到 (9,0)
        #expect(vm.board.piece(at: Position(row: 9, col: 4))?.kind == .general)
    }

    @Test("点击空位取消选中")
    func clickEmptyDeselect() {
        let vm = GameViewModel()
        // 选中红炮
        vm.selectPiece(at: Position(row: 7, col: 1))
        #expect(vm.selectedPosition != nil)

        // 点击一个既没有棋子也不在 legalMoves 中的位置
        vm.selectPiece(at: Position(row: 0, col: 0))
        #expect(vm.selectedPosition == nil)
        #expect(vm.legalMovesForSelected.isEmpty)
    }

    @Test("新局重置状态")
    func newGameResets() {
        let vm = GameViewModel()
        vm.selectPiece(at: Position(row: 7, col: 1))
        vm.newGame()

        #expect(vm.selectedPosition == nil)
        #expect(vm.legalMovesForSelected.isEmpty)
        #expect(vm.capturedPieces.red.isEmpty)
        #expect(vm.capturedPieces.black.isEmpty)
        #expect(vm.gameState == .playing)
        #expect(vm.currentTurn == .red)
        #expect(vm.board.pieces.count == 32)
    }

    @Test("黑方回合点击无响应")
    func blackTurnIgnored() {
        let vm = GameViewModel()
        // 手动走到黑方回合
        let cannon = vm.board.piece(at: Position(row: 7, col: 1))!
        let move = Move(piece: cannon, from: cannon.position, to: Position(row: 7, col: 4), captured: nil)
        vm.board.execute(move)
        // board.currentTurn 已翻转为 .black

        // 尝试选红方棋子
        vm.selectPiece(at: Position(row: 6, col: 0))
        #expect(vm.selectedPosition == nil)
    }

    @Test("悔棋恢复棋盘状态")
    func undoRestoresBoard() {
        let vm = GameViewModel()
        // 选中并走一步（走完后 AI 也会走，所以走 2 步）
        let fromPos = Position(row: 7, col: 1)
        let toPos = Position(row: 7, col: 4)

        let originalPiece = vm.board.piece(at: fromPos)
        vm.selectPiece(at: fromPos)
        vm.selectPiece(at: toPos)

        // 走完后 AI 也会走一步，所以 moveHistory 有 2 步
        // 但 AI 是异步的，直接测 undo 逻辑需要等 AI 完成
        // 简化：直接在 board 上走两步然后 undo
        let vm2 = GameViewModel()
        let c = vm2.board.piece(at: fromPos)!
        let m1 = Move(piece: c, from: fromPos, to: toPos, captured: nil)
        vm2.board.execute(m1)
        vm2.capturedPieces.red = []  // 无吃子

        // 模拟 AI 走一步
        let aiCannon = vm2.board.piece(at: Position(row: 2, col: 1))
        if let aiC = aiCannon {
            let m2 = Move(piece: aiC, from: aiC.position, to: Position(row: 2, col: 4), captured: nil)
            vm2.board.execute(m2)
        }

        let historyCount = vm2.board.moveHistory.count
        vm2.undoMove()

        // 撤销了两步
        #expect(vm2.board.moveHistory.count == historyCount - 2)
        #expect(vm2.currentTurn == .red)
    }
}
