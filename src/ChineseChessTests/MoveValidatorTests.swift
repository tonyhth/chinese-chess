import Testing
@testable import ChineseChess

@Suite("MoveValidator Tests")
struct MoveValidatorTests {

    // 辅助：创建两个将帅不在同列的最小棋盘
    private func makeBoard(redGeneralCol: Int = 3, blackGeneralCol: Int = 5, extra: [Piece] = []) -> Board {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: redGeneralCol), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: blackGeneralCol), id: 24)
        return Board(pieces: [rg, bg] + extra)
    }

    @Test("初始局面红方车在边路可上下走")
    func chariotInitialMoves() {
        let board = Board()
        let chariot = board.piece(at: Position(row: 9, col: 0))!
        let moves = MoveValidator.legalMoves(for: chariot, on: board)
        let targets = moves.map { $0.to }
        #expect(targets.contains(Position(row: 8, col: 0)))
        #expect(targets.contains(Position(row: 7, col: 0)))
    }

    @Test("马日字移动")
    func horseMove() {
        let horse = TestPieceFactory.makePiece(kind: .horse, side: .red, position: Position(row: 5, col: 3))
        let board = makeBoard(extra: [horse])
        let moves = MoveValidator.legalMoves(for: horse, on: board)
        #expect(moves.count >= 4)
    }

    @Test("蹩马腿检查")
    func horseBlocked() {
        let horse = TestPieceFactory.makePiece(kind: .horse, side: .red, position: Position(row: 5, col: 3))
        let blocker = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 4, col: 3))
        let board = makeBoard(extra: [horse, blocker])
        let moves = MoveValidator.legalMoves(for: horse, on: board)
        let targetPositions = Set(moves.map { $0.to })
        // (3,2) 和 (3,4) 被蹩腿
        #expect(!targetPositions.contains(Position(row: 3, col: 2)))
        #expect(!targetPositions.contains(Position(row: 3, col: 4)))
    }

    @Test("象田字 + 不过河 + 塞象眼")
    func elephantMove() {
        let elephant = TestPieceFactory.makePiece(kind: .elephant, side: .red, position: Position(row: 7, col: 2))
        let board = makeBoard(extra: [elephant])
        let moves = MoveValidator.legalMoves(for: elephant, on: board)
        let targets = Set(moves.map { $0.to })
        #expect(targets.contains(Position(row: 5, col: 0)))
        #expect(targets.contains(Position(row: 5, col: 4)))
        #expect(targets.contains(Position(row: 9, col: 0)))
        #expect(targets.contains(Position(row: 9, col: 4)))
    }

    @Test("炮移动和吃子")
    func cannonMove() {
        let cannon = Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1), id: 9)
        let mount = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 7, col: 3))
        let target = TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 7, col: 5))
        let board = makeBoard(extra: [cannon, mount, target])
        let moves = MoveValidator.legalMoves(for: cannon, on: board)
        let targets = moves.map { $0.to }
        #expect(targets.contains(Position(row: 7, col: 0)))
        #expect(targets.contains(Position(row: 7, col: 2)))
        let captureMove = moves.first { $0.to == Position(row: 7, col: 5) }
        #expect(captureMove != nil)
        #expect(captureMove?.captured != nil)
    }

    @Test("兵/卒未过河只能前进")
    func soldierNotCrossedRiver() {
        let soldier = Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 0), id: 11)
        let board = makeBoard(extra: [soldier])
        let moves = MoveValidator.legalMoves(for: soldier, on: board)
        let targets = moves.map { $0.to }
        #expect(targets == [Position(row: 5, col: 0)])
    }

    @Test("兵/卒过河后可前进和左右")
    func soldierCrossedRiver() {
        let soldier = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 4, col: 0))
        let board = makeBoard(extra: [soldier])
        let moves = MoveValidator.legalMoves(for: soldier, on: board)
        let targets = Set(moves.map { $0.to })
        #expect(targets.contains(Position(row: 3, col: 0)))  // 前进
        #expect(targets.contains(Position(row: 4, col: 1)))  // 右
        #expect(!targets.contains(Position(row: 5, col: 0)))  // 不能后退
    }

    @Test("将帅对面规则")
    func generalFacingRule() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let board = Board(pieces: [rg, bg])
        #expect(MoveValidator.isInCheck(.red, on: board))
        #expect(MoveValidator.isInCheck(.black, on: board))

        let blocker = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 5, col: 4))
        let board2 = Board(pieces: [rg, bg, blocker])
        #expect(!MoveValidator.isInCheck(.red, on: board2))
    }

    @Test("移子导致将帅对面 = 非法走法")
    func movingRevealsGeneralsFacing() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let soldier = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 5, col: 4))
        let board = Board(pieces: [rg, bg, soldier])
        let move = Move(piece: soldier, from: Position(row: 5, col: 4), to: Position(row: 5, col: 3), captured: nil)
        #expect(!MoveValidator.isLegal(move, on: board))
    }

    @Test("士/仕九宫斜行")
    func advisorMove() {
        let advisor = TestPieceFactory.makePiece(kind: .advisor, side: .red, position: Position(row: 8, col: 3))
        let board = makeBoard(extra: [advisor])
        let moves = MoveValidator.legalMoves(for: advisor, on: board)
        let targets = Set(moves.map { $0.to })
        #expect(targets.contains(Position(row: 9, col: 4)))
        #expect(targets.contains(Position(row: 7, col: 4)))
    }

    @Test("送将 = 非法")
    func movingIntoCheck() {
        let rg = TestPieceFactory.redGeneral(9, 3)
        let bg = TestPieceFactory.blackGeneral(0, 5)
        let blackChariot = TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 9, col: 0))
        let board = Board(pieces: [rg, bg, blackChariot])
        let move = Move(piece: rg, from: Position(row: 9, col: 3), to: Position(row: 9, col: 2), captured: nil)
        #expect(!MoveValidator.isLegal(move, on: board))
    }

    @Test("车直线移动不越子")
    func chariotCannotJump() {
        let chariot = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let blocker = TestPieceFactory.makePiece(kind: .soldier, side: .red, position: Position(row: 3, col: 0))
        let board = makeBoard(extra: [chariot, blocker])
        let moves = MoveValidator.legalMoves(for: chariot, on: board)
        let targets = Set(moves.map { $0.to })
        #expect(targets.contains(Position(row: 4, col: 0)))
        // blocker 是红方棋子，不能吃
        #expect(!targets.contains(Position(row: 3, col: 0)))
        // 不能越过 blocker
        #expect(!targets.contains(Position(row: 2, col: 0)))
    }
}
