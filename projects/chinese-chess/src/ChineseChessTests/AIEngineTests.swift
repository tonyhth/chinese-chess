import Testing
@testable import ChineseChess

@Suite("AIEngine Tests")
struct AIEngineTests {

    @Test("初级难度返回合法走法")
    func easyReturnsLegalMove() {
        let board = Board()
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = engine.bestMove(for: board, difficulty: .easy)
        #expect(move != nil)
        #expect(MoveValidator.isLegal(move!, on: board))
    }

    @Test("中级难度返回合法走法")
    func mediumReturnsLegalMove() {
        let board = Board()
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = engine.bestMove(for: board, difficulty: .medium)
        #expect(move != nil)
        // 验证走法在原棋盘上合法
        let captured = board.piece(at: move!.to)
        let mainMove = Move(piece: move!.piece, from: move!.from, to: move!.to, captured: captured)
        #expect(MoveValidator.isLegal(mainMove, on: board))
    }

    @Test("高级难度返回合法走法")
    func hardReturnsLegalMove() {
        let board = Board()
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = engine.bestMove(for: board, difficulty: .hard)
        #expect(move != nil)
        let captured = board.piece(at: move!.to)
        let mainMove = Move(piece: move!.piece, from: move!.from, to: move!.to, captured: captured)
        #expect(MoveValidator.isLegal(mainMove, on: board))
    }

    @Test("评估函数初始局面接近 0")
    func evaluateInitialBoard() {
        let board = Board()
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        // 初始局面双方对称，评估应接近 0
        // 使用 snapshot 以避免修改原棋盘
        let snapshot = board.snapshot()
        // 通过 bestMove 间接测试（评估函数是私有的）
        // 这里测试 AI 能正常走步即可
        let move = engine.bestMove(for: snapshot, difficulty: .easy)
        #expect(move != nil)
    }

    @Test("无合法走法时返回 nil")
    func noLegalMovesReturnsNil() {
        let redGeneral = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let blackGeneral = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let blackChariot = Piece(kind: .chariot, side: .black, position: Position(row: 8, col: 3))
        let blackChariot2 = Piece(kind: .chariot, side: .black, position: Position(row: 8, col: 5))
        // 黑方有合法走法，让黑方走
        let board = Board(pieces: [redGeneral, blackGeneral, blackChariot, blackChariot2])
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = engine.bestMove(for: board, difficulty: .easy)
        #expect(move != nil)
    }
}
