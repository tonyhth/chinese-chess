import Testing
@testable import ChineseChess

@Suite("集成测试：完整对局流程", .serialized)
struct IntegrationTests {

    @Test("开局走法合法性验证")
    func openingMoveLegality() {
        let board = Board()
        let redMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        // 开局红方应该有合理的合法走法数
        #expect(redMoves.count > 30)  // 实际约 44 个

        // 所有走法都是合法的
        for move in redMoves {
            #expect(MoveValidator.isLegal(move, on: board))
        }
    }

    @Test("多步走棋后 AI 响应")
    func multiStepGameWithAI() async {
        let board = Board()
        let engine = AIEngine()

        // 红方走炮二平五
        let cannon = board.piece(at: Position(row: 7, col: 1))!
        let move1 = Move(piece: cannon, from: Position(row: 7, col: 1), to: Position(row: 7, col: 4), captured: nil)
        #expect(MoveValidator.isLegal(move1, on: board))
        board.execute(move1)

        // 黑方 AI 走
        let aiMove1 = await engine.bestMove(for: board, difficulty: .beginner)
        #expect(aiMove1 != nil)
        let captured1 = board.piece(at: aiMove1!.to)
        let mainMove1 = Move(piece: aiMove1!.piece, from: aiMove1!.from, to: aiMove1!.to, captured: captured1)
        #expect(MoveValidator.isLegal(mainMove1, on: board))
        board.execute(mainMove1)

        // 红方走马八进七
        let horse = board.piece(at: Position(row: 9, col: 1))!
        let move2 = Move(piece: horse, from: Position(row: 9, col: 1), to: Position(row: 7, col: 2), captured: nil)
        #expect(MoveValidator.isLegal(move2, on: board))
        board.execute(move2)

        // 黑方 AI 走
        let aiMove2 = await engine.bestMove(for: board, difficulty: .beginner)
        #expect(aiMove2 != nil)
        let captured2 = board.piece(at: aiMove2!.to)
        let mainMove2 = Move(piece: aiMove2!.piece, from: aiMove2!.from, to: aiMove2!.to, captured: captured2)
        #expect(MoveValidator.isLegal(mainMove2, on: board))
        board.execute(mainMove2)

        // 棋盘应仍有 32 颗棋子（无吃子发生——大概率）
        // 注意：AI 可能会吃子，所以只验证棋盘状态一致性
        #expect(board.currentTurn == .red)  // 回到红方
        #expect(board.moveHistory.count == 4)
    }

    @Test("吃子流程：吃子 → 记录 → 悔棋 → 恢复")
    func captureUndoFlow() async {
        let board = Board()
        let engine = AIEngine()

        // 红方走车
        let chariot = board.piece(at: Position(row: 9, col: 0))!
        let move1 = Move(piece: chariot, from: Position(row: 9, col: 0), to: Position(row: 8, col: 0), captured: nil)
        board.execute(move1)

        // 黑方走
        let aiMove1 = await engine.bestMove(for: board, difficulty: .beginner)!
        let c1 = board.piece(at: aiMove1.to)
        board.execute(Move(piece: aiMove1.piece, from: aiMove1.from, to: aiMove1.to, captured: c1))

        // 红方继续走车
        let chariot2 = board.piece(at: Position(row: 8, col: 0))!
        let move2 = Move(piece: chariot2, from: Position(row: 8, col: 0), to: Position(row: 7, col: 0), captured: nil)
        board.execute(move2)

        // 黑方走
        let aiMove2 = await engine.bestMove(for: board, difficulty: .beginner)!
        let c2 = board.piece(at: aiMove2.to)
        board.execute(Move(piece: aiMove2.piece, from: aiMove2.from, to: aiMove2.to, captured: c2))

        let countBeforeUndo = board.pieces.count
        let historyBefore = board.moveHistory.count

        // 悔两步（一轮）
        board.undoLastMove()
        board.undoLastMove()

        #expect(board.pieces.count >= countBeforeUndo - 1)  // 可能吃子了
        #expect(board.moveHistory.count == historyBefore - 2)
    }

    @Test("10 回合对局不崩溃")
    func tenRoundGameDoesNotCrash() async {
        let board = Board()
        let engine = AIEngine()

        for _ in 0..<10 {
            // 红方走一个合法走法
            let redMoves = MoveValidator.allLegalMoves(for: .red, on: board)
            guard let redMove = redMoves.first else { break }
            board.execute(redMove)

            // 检查游戏是否结束
            if MoveValidator.isCheckmate(.black, on: board) || MoveValidator.isStalemate(.black, on: board) {
                break
            }

            // 黑方 AI 走
            guard let blackMove = await engine.bestMove(for: board, difficulty: .beginner) else { break }
            let captured = board.piece(at: blackMove.to)
            let mainMove = Move(piece: blackMove.piece, from: blackMove.from, to: blackMove.to, captured: captured)
            #expect(MoveValidator.isLegal(mainMove, on: board))
            board.execute(mainMove)

            if MoveValidator.isCheckmate(.red, on: board) || MoveValidator.isStalemate(.red, on: board) {
                break
            }
        }

        // 验证棋盘状态一致
        #expect(board.currentTurn == .red)
        #expect(!board.moveHistory.isEmpty)
    }

    @Test("残局 AI 高级难度能走")
    func hardEndgameCompletes() async {
        // 简单残局：黑方车马 vs 红方帅
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let bc = Piece(kind: .chariot, side: .black, position: Position(row: 5, col: 0), id: 16)
        let bh = Piece(kind: .horse, side: .black, position: Position(row: 0, col: 1), id: 18)
        let board = Board(pieces: [rg, bg, bc, bh])
        let engine = AIEngine()

        let move = await engine.bestMove(for: board, difficulty: .amateurMid)
        #expect(move != nil)
        let captured = board.piece(at: move!.to)
        let mainMove = Move(piece: move!.piece, from: move!.from, to: move!.to, captured: captured)
        #expect(MoveValidator.isLegal(mainMove, on: board))
    }
}
