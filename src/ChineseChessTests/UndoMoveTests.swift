import Testing
@testable import ChineseChess

@Suite("悔棋测试")
struct UndoMoveTests {

    // MARK: - 基本悔棋

    @Test("悔棋恢复棋盘位置")
    func undoRestoresPositions() {
        let board = Board()
        // 红炮 (7,1) → (7,4)
        let cannon = board.piece(at: Position(row: 7, col: 1))!
        let move = Move(piece: cannon, from: cannon.position, to: Position(row: 7, col: 4), captured: nil)
        board.execute(move)

        let undone = board.undoLastMove()
        #expect(undone != nil)
        #expect(board.piece(at: Position(row: 7, col: 1))?.kind == .cannon)
        #expect(board.piece(at: Position(row: 7, col: 4)) == nil)
    }

    @Test("悔棋恢复轮次")
    func undoRestoresTurn() {
        let board = Board()
        #expect(board.currentTurn == .red)

        let cannon = board.piece(at: Position(row: 7, col: 1))!
        let move = Move(piece: cannon, from: cannon.position, to: Position(row: 7, col: 4), captured: nil)
        board.execute(move)
        #expect(board.currentTurn == .black)

        board.undoLastMove()
        #expect(board.currentTurn == .red)
    }

    // MARK: - 吃子悔棋

    @Test("悔棋恢复被吃棋子")
    func undoRestoresCapturedPiece() {
        let redChariot = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0), id: 150)
        let blackSoldier = Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 0), id: 27)
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let board = Board(pieces: [redChariot, blackSoldier, rg, bg])

        #expect(board.pieces.count == 4)

        let move = Move(piece: redChariot, from: redChariot.position, to: blackSoldier.position, captured: blackSoldier)
        board.execute(move)
        #expect(board.pieces.count == 3)

        board.undoLastMove()
        #expect(board.pieces.count == 4)
        // 被吃棋子恢复到原位
        let restored = board.piece(at: Position(row: 3, col: 0))
        #expect(restored != nil)
        #expect(restored?.kind == .soldier)
        #expect(restored?.side == .black)
        #expect(restored?.id == blackSoldier.id)
    }

    @Test("连续吃子后连续悔棋")
    func multipleCapturesAndUndos() {
        let redChariot = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0), id: 150)
        let blackSoldier1 = Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 0), id: 27)
        let blackSoldier2 = Piece(kind: .soldier, side: .black, position: Position(row: 2, col: 0), id: 220)
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let board = Board(pieces: [redChariot, blackSoldier1, blackSoldier2, rg, bg])

        // 第一步吃卒1
        let move1 = Move(piece: redChariot, from: Position(row: 5, col: 0), to: Position(row: 3, col: 0), captured: blackSoldier1)
        board.execute(move1)
        #expect(board.pieces.count == 4)

        // 第二步吃卒2
        let chariotAfter = board.piece(at: Position(row: 3, col: 0))!
        let move2 = Move(piece: chariotAfter, from: chariotAfter.position, to: Position(row: 2, col: 0), captured: blackSoldier2)
        board.execute(move2)
        #expect(board.pieces.count == 3)

        // 悔第二步
        board.undoLastMove()
        #expect(board.pieces.count == 4)
        #expect(board.piece(at: Position(row: 3, col: 0))?.kind == .chariot)
        #expect(board.piece(at: Position(row: 2, col: 0))?.kind == .soldier)

        // 悔第一步
        board.undoLastMove()
        #expect(board.pieces.count == 5)
        #expect(board.piece(at: Position(row: 5, col: 0))?.kind == .chariot)
    }

    // MARK: - 空历史悔棋

    @Test("空棋盘悔棋返回 nil")
    func undoOnEmptyHistory() {
        let board = Board()
        let result = board.undoLastMove()
        #expect(result == nil)
    }

    // MARK: - 悔棋后 moveHistory 正确

    @Test("悔棋后 moveHistory 减少")
    func undoReducesHistory() {
        let board = Board()
        #expect(board.moveHistory.isEmpty)

        let cannon = board.piece(at: Position(row: 7, col: 1))!
        let move1 = Move(piece: cannon, from: cannon.position, to: Position(row: 7, col: 4), captured: nil)
        board.execute(move1)
        #expect(board.moveHistory.count == 1)

        let cannon2 = board.piece(at: Position(row: 2, col: 1))!
        let move2 = Move(piece: cannon2, from: cannon2.position, to: Position(row: 2, col: 5), captured: nil)
        board.execute(move2)
        #expect(board.moveHistory.count == 2)

        board.undoLastMove()
        #expect(board.moveHistory.count == 1)

        board.undoLastMove()
        #expect(board.moveHistory.isEmpty)
    }
}
