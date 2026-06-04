import Testing
@testable import ChineseChess

@Suite("AI 引擎深度测试")
struct AIAdvancedTests {

    // MARK: - 三个难度都返回合法走法

    @Test("初级 AI 从残局返回合法走法")
    func easyFromEndgame() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let blackChariot = Piece(kind: .chariot, side: .black, position: Position(row: 5, col: 0))
        let board = Board(pieces: [rg, bg, blackChariot])
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = engine.bestMove(for: board, difficulty: .easy)
        #expect(move != nil)
        let captured = board.piece(at: move!.to)
        let mainMove = Move(piece: move!.piece, from: move!.from, to: move!.to, captured: captured)
        #expect(MoveValidator.isLegal(mainMove, on: board))
    }

    @Test("中级 AI 从残局返回合法走法")
    func mediumFromEndgame() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let blackChariot = Piece(kind: .chariot, side: .black, position: Position(row: 5, col: 0))
        let board = Board(pieces: [rg, bg, blackChariot])
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = engine.bestMove(for: board, difficulty: .medium)
        #expect(move != nil)
        let captured = board.piece(at: move!.to)
        let mainMove = Move(piece: move!.piece, from: move!.from, to: move!.to, captured: captured)
        #expect(MoveValidator.isLegal(mainMove, on: board))
    }

    @Test("高级 AI 从残局返回合法走法")
    func hardFromEndgame() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let blackChariot = Piece(kind: .chariot, side: .black, position: Position(row: 5, col: 0))
        let board = Board(pieces: [rg, bg, blackChariot])
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        let move = engine.bestMove(for: board, difficulty: .hard)
        #expect(move != nil)
        let captured = board.piece(at: move!.to)
        let mainMove = Move(piece: move!.piece, from: move!.from, to: move!.to, captured: captured)
        #expect(MoveValidator.isLegal(mainMove, on: board))
    }

    // MARK: - 高级难度不应送明显大子

    @Test("高级 AI 不送车")
    func hardDoesNotBlunderChariot() {
        // 黑方有车，红方有炮（可吃黑车）
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let blackChariot = Piece(kind: .chariot, side: .black, position: Position(row: 5, col: 0))
        let redCannon = Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1))
        let redSoldier = Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 0))  // 炮架
        let board = Board(pieces: [rg, bg, blackChariot, redCannon, redSoldier])
        board.setCurrentTurn(.black)
        let engine = AIEngine()

        // 多次运行取多数结果，避免随机性
        var chariotMovedToUnsafeCount = 0
        let iterations = 5
        for _ in 0..<iterations {
            let move = engine.bestMove(for: board, difficulty: .hard)
            #expect(move != nil)
            // 检查黑车是否走到了红炮可以吃它的位置
            // 红炮在 (7,1)，需要炮架才能吃
            // 简单检查：黑车不应主动走到红车或红炮的直接攻击范围
            if move!.piece.kind == .chariot {
                // 模拟走法后检查红方是否能一步吃掉黑车
                let snapshot = board.snapshot()
                let captured = snapshot.piece(at: move!.to)
                let mainMove = Move(piece: move!.piece, from: move!.from, to: move!.to, captured: captured)
                snapshot.execute(mainMove)
                let redMoves = MoveValidator.allLegalMoves(for: .red, on: snapshot)
                let canBeCaptured = redMoves.contains { $0.captured?.id == move!.piece.id }
                if canBeCaptured {
                    chariotMovedToUnsafeCount += 1
                }
            }
        }
        // 高级 AI 5 次中最多 1 次送车
        #expect(chariotMovedToUnsafeCount <= 1)
    }

    // MARK: - AI 走法是黑方棋子

    @Test("AI 返回当前行走方的走法")
    func aiReturnsCurrentSideMove() {
        let board = Board()
        board.setCurrentTurn(.black)
        let engine = AIEngine()
        for _ in 0..<10 {
            let move = engine.bestMove(for: board, difficulty: .easy)
            if let move {
                #expect(move.piece.side == .black)
            }
        }
    }

    // MARK: - AI 不修改原棋盘

    @Test("AI 不修改传入的棋盘")
    func aiDoesNotModifyOriginalBoard() {
        let board = Board()
        board.setCurrentTurn(.black)
        let originalPieceCount = board.pieces.count
        let originalTurn = board.currentTurn
        let engine = AIEngine()
        _ = engine.bestMove(for: board, difficulty: .medium)
        #expect(board.pieces.count == originalPieceCount)
        #expect(board.currentTurn == originalTurn)
    }
}
