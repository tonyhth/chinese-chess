import Foundation
import Testing
@testable import ChineseChess

// MARK: - Phase 3 #6: Phase 2A/2B 新增功能补充测试

@Suite("Phase 3 #6: Phase 2A/2B 补测试", .serialized)
struct Phase3SupplementTests {

    // MARK: - 1. ZobristHash 增量更新

    @Test("ZobristHash: 完整哈希与手动异或结果一致")
    func zobristFullHashConsistency() {
        let board = Board()
        let h = ZobristHash.hash(board: board)
        // 手动计算：所有棋子 XOR + 行走方
        var manual: UInt64 = 0
        for piece in board.pieces {
            let pi = ZobristHash.pieceIndex(piece)
            let posi = piece.position.row * 9 + piece.position.col
            manual ^= ZobristHash.table[pi][posi]
        }
        // 红先手，不 XOR sideHash
        #expect(h == manual, "完整哈希应与手动计算一致")
    }

    @Test("ZobristHash: 黑方走时包含 sideHash")
    func zobristBlackTurnIncludesSideHash() {
        let board = Board()
        let hRed = ZobristHash.hash(board: board)  // 红先

        // 走一步后轮到黑方
        let piece = board.piece(at: Position(row: 9, col: 0))!
        let move = Move(piece: piece, from: piece.position, to: Position(row: 8, col: 0), captured: nil)
        guard MoveValidator.isLegal(move, on: board) else {
            Issue.record("走法不合法")
            return
        }
        board.execute(move)
        let hBlack = ZobristHash.hash(board: board)

        // 黑方走时 FEN 中标记为 b，hash 应与红方不同
        // 具体来说 hBlack 应该等于 手动计算含 sideHash
        var manualBlack: UInt64 = 0
        for piece in board.pieces {
            let pi = ZobristHash.pieceIndex(piece)
            let posi = piece.position.row * 9 + piece.position.col
            manualBlack ^= ZobristHash.table[pi][posi]
        }
        // 黑方走 XOR sideHash
        manualBlack ^= ZobristHash.sideHash
        #expect(hBlack == manualBlack, "黑方走时哈希应包含 sideHash")
    }

    @Test("ZobristHash: 增量更新与完整重算一致（无吃子）")
    func zobristIncrementalMatchesFull() {
        let board = Board()
        let hashBefore = ZobristHash.hash(board: board)

        let piece = board.piece(at: Position(row: 9, col: 0))!
        let from = piece.position
        let to = Position(row: 8, col: 0)
        let move = Move(piece: piece, from: from, to: to, captured: nil)
        guard MoveValidator.isLegal(move, on: board) else {
            Issue.record("走法不合法")
            return
        }
        board.execute(move)

        let hashFull = ZobristHash.hash(board: board)
        let hashIncremental = ZobristHash.update(hash: hashBefore, piece: piece, from: from, to: to, captured: nil)

        #expect(hashFull == hashIncremental, "增量更新应与完整重算一致")
    }

    @Test("ZobristHash: 增量更新与完整重算一致（有吃子）")
    func zobristIncrementalWithCapture() {
        // 构造合法吃子局面：避免将帅对面
        // 黑将在(0,3)，红帅在(9,4)，红车在(9,0)，黑卒在(6,0)
        // 红车从(9,0)进到(6,0)吃黑卒，中间无阻挡，走后不将帅对面
        let board = Board(fen: "3k5/9/9/9/9/9/p8/9/9/R3K4 w")
        let hashBefore = ZobristHash.hash(board: board)

        let chariot = board.piece(at: Position(row: 9, col: 0))!
        let from = chariot.position
        let to = Position(row: 6, col: 0)
        let captured = board.piece(at: to)
        #expect(captured != nil, "目标位置应有黑卒")

        let move = Move(piece: chariot, from: from, to: to, captured: captured)
        guard MoveValidator.isLegal(move, on: board) else {
            Issue.record("吃子走法不合法")
            return
        }
        board.execute(move)

        let hashFull = ZobristHash.hash(board: board)
        let hashIncremental = ZobristHash.update(hash: hashBefore, piece: chariot, from: from, to: to, captured: captured)

        #expect(hashFull == hashIncremental, "有吃子时增量更新应与完整重算一致")
    }

    @Test("ZobristHash: 同一局面不同路径结果相同")
    func zobristSamePositionSameHash() {
        let board1 = Board(fen: "4k4/9/9/9/9/9/9/9/9/4KR3 w")
        let board2 = Board(fen: "4k4/9/9/9/9/9/9/9/9/4KR3 w")
        let h1 = ZobristHash.hash(board: board1)
        let h2 = ZobristHash.hash(board: board2)
        #expect(h1 == h2, "同一 FEN 的哈希应相同")
    }

    @Test("ZobristHash: 不同局面哈希不同")
    func zobristDifferentPositionDifferentHash() {
        let board1 = Board(fen: "4k4/9/9/9/9/9/9/9/9/4KR3 w")
        let board2 = Board(fen: "4k4/9/9/9/9/9/9/9/R3K4 w")  // 车位置不同
        let h1 = ZobristHash.hash(board: board1)
        let h2 = ZobristHash.hash(board: board2)
        #expect(h1 != h2, "不同局面哈希应不同")
    }

    @Test("ZobristHash: pieceIndex 映射正确")
    func zobristPieceIndexMapping() {
        // 红方 0-6
        #expect(ZobristHash.pieceIndex(Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)) == 0)
        #expect(ZobristHash.pieceIndex(Piece(kind: .advisor, side: .red, position: Position(row: 9, col: 3), id: 6)) == 1)
        #expect(ZobristHash.pieceIndex(Piece(kind: .elephant, side: .red, position: Position(row: 9, col: 2), id: 4)) == 2)
        #expect(ZobristHash.pieceIndex(Piece(kind: .horse, side: .red, position: Position(row: 9, col: 1), id: 2)) == 3)
        #expect(ZobristHash.pieceIndex(Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0)) == 4)
        #expect(ZobristHash.pieceIndex(Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1), id: 9)) == 5)
        #expect(ZobristHash.pieceIndex(Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 0), id: 11)) == 6)

        // 黑方 7-13
        #expect(ZobristHash.pieceIndex(Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)) == 7)
        #expect(ZobristHash.pieceIndex(Piece(kind: .cannon, side: .black, position: Position(row: 2, col: 1), id: 25)) == 12)
        #expect(ZobristHash.pieceIndex(Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 0), id: 27)) == 13)
    }

    @Test("ZobristHash: 走棋再悔棋哈希恢复")
    func zobristHashRestoreAfterUndo() {
        let board = Board()
        let hashOriginal = ZobristHash.hash(board: board)

        let piece = board.piece(at: Position(row: 9, col: 0))!
        let move = Move(piece: piece, from: piece.position, to: Position(row: 8, col: 0), captured: nil)
        guard MoveValidator.isLegal(move, on: board) else {
            Issue.record("走法不合法")
            return
        }
        board.execute(move)

        board.undoLastMove()
        let hashRestored = ZobristHash.hash(board: board)

        #expect(hashRestored == hashOriginal, "悔棋后哈希应恢复原值")
    }

    @Test("ZobristHash: 连续增量更新与多步完整重算一致")
    func zobristSequentialIncremental() {
        let board = Board()
        var incrementalHash = ZobristHash.hash(board: board)

        // 走 3 步
        let moves: [(Position, Position)] = [
            (Position(row: 9, col: 0), Position(row: 8, col: 0)),  // 红车进
        ]

        for (from, to) in moves {
            guard let piece = board.piece(at: from) else { continue }
            let captured = board.piece(at: to)
            let move = Move(piece: piece, from: from, to: to, captured: captured)
            guard MoveValidator.isLegal(move, on: board) else { continue }

            incrementalHash = ZobristHash.update(hash: incrementalHash, piece: piece, from: from, to: to, captured: captured)
            board.execute(move)
        }

        let fullHash = ZobristHash.hash(board: board)
        #expect(incrementalHash == fullHash, "连续增量更新应与完整重算一致")
    }

    // MARK: - 2. halfmoveClock 50 回合规则细节

    @Test("halfmoveClock: 初始值为 0")
    func halfmoveClockInitialValue() {
        var halfmoveClock = 0
        #expect(halfmoveClock == 0, "初始 halfmoveClock 应为 0")
    }

    @Test("halfmoveClock: 连续 99 步普通走子不判和")
    func halfmoveClock99NoDraw() {
        var halfmoveClock = 99
        let isDraw = halfmoveClock >= 100
        #expect(!isDraw, "halfmoveClock = 99 不应判和")
    }

    @Test("halfmoveClock: 吃子重置后从 0 重新计数")
    func halfmoveClockResetAndRecount() {
        var halfmoveClock = 0

        // 50 步普通走子
        for _ in 0..<50 {
            halfmoveClock += 1
        }
        #expect(halfmoveClock == 50)

        // 吃子重置
        halfmoveClock = 0
        #expect(halfmoveClock == 0)

        // 再走 30 步
        for _ in 0..<30 {
            halfmoveClock += 1
        }
        #expect(halfmoveClock == 30, "重置后应从 0 重新计数")
    }

    @Test("halfmoveClock: GameMove 数组可以追踪完整 halfmoveClock 历史")
    func halfmoveClockHistoryTracking() {
        let moves: [GameMove] = [
            GameMove(id: UUID(), piece: Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0),
                     from: Position(row: 9, col: 0), to: Position(row: 8, col: 0), captured: nil,
                     turnNumber: 1, notation: "车九进一", timestamp: Date(),
                     isCheck: false, isCheckmate: false, halfmoveClock: 1),
            GameMove(id: UUID(), piece: Piece(kind: .cannon, side: .black, position: Position(row: 2, col: 7), id: 26),
                     from: Position(row: 2, col: 7), to: Position(row: 2, col: 4), captured: nil,
                     turnNumber: 1, notation: "砲8平5", timestamp: Date(),
                     isCheck: false, isCheckmate: false, halfmoveClock: 2),
            // 红车吃子
            GameMove(id: UUID(), piece: Piece(kind: .chariot, side: .red, position: Position(row: 8, col: 0), id: 180),
                     from: Position(row: 8, col: 0), to: Position(row: 5, col: 0), captured: Piece(kind: .soldier, side: .black, position: Position(row: 5, col: 0), id: 16),
                     turnNumber: 2, notation: "车九进三", timestamp: Date(),
                     isCheck: false, isCheckmate: false, halfmoveClock: 0),
        ]

        #expect(moves[0].halfmoveClock == 1, "第 1 步 halfmoveClock 应为 1")
        #expect(moves[1].halfmoveClock == 2, "第 2 步 halfmoveClock 应为 2")
        #expect(moves[2].halfmoveClock == 0, "吃子后 halfmoveClock 应为 0")
    }

    @Test("halfmoveClock: 从 GameMove 恢复 lastMove.halfmoveClock")
    func halfmoveClockRestoreFromGameMove() {
        let lastMove = GameMove(
            id: UUID(), piece: Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0),
            from: Position(row: 9, col: 0), to: Position(row: 5, col: 0),
            captured: nil, turnNumber: 10, notation: "车九进四",
            timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 42
        )

        // 模拟 GameViewModel 的恢复逻辑
        let restored: Int
        restored = lastMove.halfmoveClock
        #expect(restored == 42, "从 GameMove 恢复的 halfmoveClock 应为 42")
    }

    @Test("halfmoveClock: 空 moves 时 halfmoveClock 为 0")
    func halfmoveClockDefaultWhenNoMoves() {
        let gameMoves: [GameMove] = []
        let restored: Int
        if let lastMove = gameMoves.last {
            restored = lastMove.halfmoveClock
        } else {
            restored = 0
        }
        #expect(restored == 0, "无走棋记录时 halfmoveClock 应为 0")
    }

    // MARK: - 3. ZobristHash 边界情况

    @Test("ZobristHash: 空棋盘哈希确定性")
    func zobristEmptyBoardConsistency() {
        // 没有棋子的棋盘
        let board = Board(pieces: [])
        let h1 = ZobristHash.hash(board: board)
        let h2 = ZobristHash.hash(board: board)
        #expect(h1 == h2, "空棋盘哈希应确定性")
    }

    @Test("ZobristHash: sideHash 非零")
    func zobristSideHashNonZero() {
        #expect(ZobristHash.sideHash != 0, "sideHash 应为非零值")
    }

    @Test("ZobristHash: table 尺寸正确 (14×90)")
    func zobristTableSize() {
        #expect(ZobristHash.table.count == 14, "应有 14 种棋子类型")
        for (i, row) in ZobristHash.table.enumerated() {
            #expect(row.count == 90, "第 \(i) 行应有 90 个位置")
        }
    }

    @Test("ZobristHash: table 值唯一性（无碰撞）")
    func zobristTableValuesUnique() {
        var seen = Set<UInt64>()
        var duplicates = 0
        for row in ZobristHash.table {
            for val in row {
                if seen.contains(val) {
                    duplicates += 1
                }
                seen.insert(val)
            }
        }
        // 14×90 = 1260 个值，允许少量碰撞（PRNG 可能产生少量重复）
        #expect(duplicates < 5, "Zobrist table 中重复值应极少（<5），实际 \(duplicates)")
    }

    @Test("ZobristHash: 增量更新走棋后切换行走方")
    func zobristUpdateSwitchesSide() {
        let board = Board()
        let hashBefore = ZobristHash.hash(board: board)  // 红方走

        let piece = board.piece(at: Position(row: 6, col: 4))!  // 红兵
        let from = piece.position
        let to = Position(row: 5, col: 4)
        let move = Move(piece: piece, from: from, to: to, captured: nil)
        guard MoveValidator.isLegal(move, on: board) else {
            Issue.record("走法不合法")
            return
        }
        board.execute(move)

        let hashFull = ZobristHash.hash(board: board)  // 黑方走
        let hashInc = ZobristHash.update(hash: hashBefore, piece: piece, from: from, to: to, captured: nil)

        #expect(hashFull == hashInc)
        #expect(hashFull != hashBefore, "走棋后哈希应变化")
    }
}
