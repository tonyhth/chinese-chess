import Testing
@testable import ChineseChess

@Suite("Board Tests")
struct BoardTests {

    @Test("初始局面有 32 颗棋子")
    func initialPieceCount() {
        let board = Board()
        #expect(board.pieces.count == 32)
    }

    @Test("初始局面红方 16 颗，黑方 16 颗")
    func initialSideCount() {
        let board = Board()
        #expect(board.pieces(for: .red).count == 16)
        #expect(board.pieces(for: .black).count == 16)
    }

    @Test("执行和撤销走法")
    func executeAndUndo() {
        let board = Board()
        // 红炮 (7,1) → (7,4)
        let cannon = board.piece(at: Position(row: 7, col: 1))!
        let move = Move(piece: cannon, from: cannon.position, to: Position(row: 7, col: 4), captured: nil)
        board.execute(move)
        #expect(board.piece(at: Position(row: 7, col: 4)) != nil)
        #expect(board.piece(at: Position(row: 7, col: 1)) == nil)
        #expect(board.currentTurn == .black)

        let undone = board.undoLastMove()
        #expect(undone != nil)
        #expect(board.piece(at: Position(row: 7, col: 1)) != nil)
        #expect(board.piece(at: Position(row: 7, col: 4)) == nil)
        #expect(board.currentTurn == .red)
    }

    @Test("吃子后撤销恢复")
    func captureAndUndo() {
        let attacker = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0), id: 150)
        let target = Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 0), id: 27)
        let redGeneral = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let blackGeneral = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let board = Board(pieces: [attacker, target, redGeneral, blackGeneral])

        let move = Move(piece: attacker, from: attacker.position, to: target.position, captured: target)
        board.execute(move)
        #expect(board.pieces.count == 3)
        #expect(board.piece(at: Position(row: 3, col: 0))?.side == .red)

        board.undoLastMove()
        #expect(board.pieces.count == 4)
        #expect(board.piece(at: Position(row: 3, col: 0))?.side == .black)
    }

    @Test("snapshot 深拷贝互不影响")
    func snapshotIndependence() {
        let board = Board()
        let copy = board.snapshot()

        let cannon = copy.piece(at: Position(row: 7, col: 1))!
        let move = Move(piece: cannon, from: cannon.position, to: Position(row: 7, col: 4), captured: nil)
        copy.execute(move)

        // 原棋盘不受影响
        #expect(board.piece(at: Position(row: 7, col: 1)) != nil)
        #expect(copy.piece(at: Position(row: 7, col: 4)) != nil)
    }
}
