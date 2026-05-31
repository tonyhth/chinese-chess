import Foundation

// MARK: - AI 引擎协议

protocol AIEngineProtocol {
    /// 计算最佳走法。内部会复制棋盘，不会修改传入的 board。
    func bestMove(for board: Board, difficulty: AIDifficulty) -> Move?
}

// MARK: - AI 引擎实现

struct AIEngine: AIEngineProtocol {

    func bestMove(for board: Board, difficulty: AIDifficulty) -> Move? {
        // R1: 入口处统一做深拷贝，确保不修改调用者的 board
        let workBoard = board.snapshot()
        switch difficulty {
        case .beginner:
            return randomMove(for: workBoard)
        case .easy:
            return randomMove(for: workBoard)  // Phase 1: 暂用随机，Phase 2a 实现 depth=2
        case .medium:
            return heuristicSearch(for: workBoard, depth: 2)
        case .hard:
            return iterativeDeepeningSearch(for: workBoard)
        case .master:
            return iterativeDeepeningSearch(for: workBoard)  // Phase 1: 暂用高级算法，Phase 2b 实现大师级
        }
    }

    // MARK: - 初级：随机合法走法

    private func randomMove(for board: Board) -> Move? {
        let moves = MoveValidator.allLegalMoves(for: .black, on: board)
        return moves.randomElement()
    }

    // MARK: - 中级：Minimax 深度 2，无 Alpha-Beta

    private func heuristicSearch(for board: Board, depth: Int) -> Move? {
        let moves = MoveValidator.allLegalMoves(for: .black, on: board)
        guard !moves.isEmpty else { return nil }

        var bestMove: Move?
        var bestScore = Int.min

        for move in moves {
            board.execute(move)
            let opponentMoves = MoveValidator.allLegalMoves(for: .red, on: board)
            var worstCase = Int.max
            if opponentMoves.isEmpty {
                if MoveValidator.isInCheck(.red, on: board) {
                    worstCase = +100000
                } else {
                    worstCase = 0
                }
            } else {
                for opMove in opponentMoves {
                    board.execute(opMove)
                    let score = evaluate(board)
                    worstCase = min(worstCase, score)
                    _ = board.undoLastMove()
                }
            }
            if worstCase > bestScore {
                bestScore = worstCase
                bestMove = move
            }
            _ = board.undoLastMove()
        }
        return bestMove
    }

    // MARK: - 高级：迭代加深 Minimax + Alpha-Beta

    private func iterativeDeepeningSearch(for board: Board) -> Move? {
        let totalPieces = board.pieces.count
        var maxDepth = 4
        if totalPieces <= 10 { maxDepth = 5 }

        var bestMoveSoFar: Move?
        let startTime = Date()

        for depth in 2...maxDepth {
            let elapsed = Date().timeIntervalSince(startTime) * 1000
            if elapsed > 1000 { break }
            if let move = searchAtDepth(board: board, depth: depth) {
                bestMoveSoFar = move
            }
        }
        return bestMoveSoFar
    }

    private func searchAtDepth(board: Board, depth: Int) -> Move? {
        let moves = MoveValidator.allLegalMoves(for: .black, on: board)
        let orderedMoves = orderMoves(moves)
        guard !orderedMoves.isEmpty else { return nil }

        var bestMove: Move?
        var bestScore = Int.min
        var alpha = Int.min
        let beta = Int.max

        for move in orderedMoves {
            board.execute(move)
            let score = minimax(board: board, depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: false)
            _ = board.undoLastMove()
            if score > bestScore {
                bestScore = score
                bestMove = move
            }
            alpha = max(alpha, bestScore)
        }
        return bestMove
    }

    private func minimax(board: Board, depth: Int, alpha: Int, beta: Int, isMaximizing: Bool) -> Int {
        if depth == 0 || isTerminal(board) {
            return evaluate(board)
        }

        let side: Side = isMaximizing ? .black : .red
        var moves = MoveValidator.allLegalMoves(for: side, on: board)
        if depth >= 2 { moves = orderMoves(moves) }

        if moves.isEmpty {
            if MoveValidator.isInCheck(side, on: board) {
                return isMaximizing ? -100000 : +100000
            }
            return 0
        }

        if isMaximizing {
            var maxEval = Int.min
            var a = alpha
            for move in moves {
                board.execute(move)
                let evalScore = minimax(board: board, depth: depth - 1, alpha: a, beta: beta, isMaximizing: false)
                _ = board.undoLastMove()
                maxEval = max(maxEval, evalScore)
                a = max(a, evalScore)
                if beta <= a { break }
            }
            return maxEval
        } else {
            var minEval = Int.max
            var b = beta
            for move in moves {
                board.execute(move)
                let evalScore = minimax(board: board, depth: depth - 1, alpha: alpha, beta: b, isMaximizing: true)
                _ = board.undoLastMove()
                minEval = min(minEval, evalScore)
                b = min(b, evalScore)
                if b <= alpha { break }
            }
            return minEval
        }
    }

    // MARK: - 终止判定

    private func isTerminal(_ board: Board) -> Bool {
        if board.generalPosition(of: .red) == nil { return true }
        if board.generalPosition(of: .black) == nil { return true }
        return false
    }

    // MARK: - 评估函数（黑方视角，正值有利于黑方）
    // Y1: 去掉 isCheckmate 检查，将死由 minimax 的 moves.isEmpty 逻辑处理

    private func evaluate(_ board: Board) -> Int {
        var materialScore = 0
        var positionScore = 0

        for piece in board.pieces {
            let value = piece.baseValue
            let posWeight = positionWeight(for: piece)
            if piece.side == .black {
                materialScore += value
                positionScore += posWeight
            } else {
                materialScore -= value
                positionScore -= posWeight
            }
        }

        return materialScore + positionScore
    }

    // MARK: - 位置权重表

    private func positionWeight(for piece: Piece) -> Int {
        let row = piece.position.row
        let col = piece.position.col

        switch piece.kind {
        case .general:  return generalPositionWeight(row: row, col: col, side: piece.side)
        case .advisor:  return advisorPositionWeight(row: row, col: col, side: piece.side)
        case .elephant: return elephantPositionWeight(row: row, col: col, side: piece.side)
        case .horse:    return horsePositionWeight(row: row, col: col, side: piece.side)
        case .chariot:  return chariotPositionWeight(row: row, col: col, side: piece.side)
        case .cannon:   return cannonPositionWeight(row: row, col: col, side: piece.side)
        case .soldier:  return soldierPositionWeight(row: row, col: col, side: piece.side)
        }
    }

    // 兵/卒位置权重（黑卒视角）
    private static let blackSoldierWeights: [[Int]] = [
        [0,  0,  0,  0,  0,  0,  0,  0,  0],
        [0,  0,  0,  0,  0,  0,  0,  0,  0],
        [0,  0,  0,  0,  0,  0,  0,  0,  0],
        [2,  0,  4,  0,  8,  0,  4,  0,  2],
        [6, 12, 18, 18, 20, 18, 18, 12,  6],
        [10, 20, 30, 34, 40, 34, 30, 20, 10],
        [14, 26, 42, 60, 80, 60, 42, 26, 14],
        [18, 36, 56, 80, 120, 80, 56, 36, 18],
        [0,  3,  6,  6,  6,  6,  6,  3,  0],
        [0,  0,  0,  0,  0,  0,  0,  0,  0]
    ]

    private func soldierPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let r = (side == .black) ? row : (9 - row)
        return Self.blackSoldierWeights[r][col]
    }

    // 马：中心 > 边缘
    private static let blackHorseWeights: [[Int]] = [
        [0,  2,  4,  4,  0,  4,  4,  2,  0],
        [2,  8, 12, 12, 12, 12, 12,  8,  2],
        [4, 12, 16, 18, 18, 18, 16, 12,  4],
        [6, 16, 22, 24, 26, 24, 22, 16,  6],
        [8, 18, 26, 30, 32, 30, 26, 18,  8],
        [8, 18, 26, 30, 32, 30, 26, 18,  8],
        [6, 16, 22, 24, 26, 24, 22, 16,  6],
        [4, 12, 16, 18, 18, 18, 16, 12,  4],
        [2,  8, 12, 12, 12, 12, 12,  8,  2],
        [0,  2,  4,  4,  0,  4,  4,  2,  0]
    ]

    private func horsePositionWeight(row: Int, col: Int, side: Side) -> Int {
        let r = (side == .black) ? row : (9 - row)
        return Self.blackHorseWeights[r][col]
    }

    // Y3: 车位置权重简化 — 用行号映射代替 10 行重复数组
    private static let chariotEdgeRow: [Int] = [6, 8, 8, 12, 14, 12, 8, 8, 6]
    private static let chariotMidRow: [Int]  = [6, 10, 12, 16, 18, 16, 12, 10, 6]

    private func chariotPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let r = (side == .black) ? row : (9 - row)
        return (r == 0 || r == 9) ? Self.chariotEdgeRow[col] : Self.chariotMidRow[col]
    }

    // 炮
    private static let blackCannonWeights: [[Int]] = [
        [0,  2,  4,  6,  8,  6,  4,  2,  0],
        [2,  4,  8, 12, 14, 12,  8,  4,  2],
        [4,  8, 12, 16, 18, 16, 12,  8,  4],
        [4, 10, 16, 20, 22, 20, 16, 10,  4],
        [6, 12, 18, 24, 26, 24, 18, 12,  6],
        [6, 12, 18, 24, 26, 24, 18, 12,  6],
        [4, 10, 16, 20, 22, 20, 16, 10,  4],
        [4,  8, 12, 16, 18, 16, 12,  8,  4],
        [2,  4,  8, 12, 14, 12,  8,  4,  2],
        [0,  2,  4,  6,  8,  6,  4,  2,  0]
    ]

    private func cannonPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let r = (side == .black) ? row : (9 - row)
        return Self.blackCannonWeights[r][col]
    }

    // 将/帅：九宫中心最优
    private func generalPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let weights: [[Int]] = [
            [0, 0, 0, 2, 4, 2, 0, 0, 0],
            [0, 0, 0, 4, 8, 4, 0, 0, 0],
            [0, 0, 0, 2, 4, 2, 0, 0, 0]
        ]
        let localRowIdx = (side == .black) ? row : (9 - row)
        if localRowIdx >= 0 && localRowIdx <= 2 && col >= 3 && col <= 5 {
            return weights[localRowIdx][col]
        }
        return 0
    }

    // 士/仕
    private func advisorPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let localRow = (side == .black) ? row : (9 - row)
        if localRow == 1 && col == 4 { return 6 }
        if localRow >= 0 && localRow <= 2 && col >= 3 && col <= 5 { return 2 }
        return 0
    }

    // 象/相
    private func elephantPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let localRow = (side == .black) ? row : (9 - row)
        if localRow == 2 && (col == 2 || col == 6) { return 4 }
        if localRow == 0 && (col == 2 || col == 6) { return 2 }
        if localRow == 2 && col == 4 { return 2 }
        return 0
    }

    // Y2: 走法排序只用 MVV-LVA，不做 execute+undo 的将军检查
    private func orderMoves(_ moves: [Move]) -> [Move] {
        moves.map { move -> (Move, Int) in
            var score = 0
            if let captured = move.captured {
                score += 10000 + captured.baseValue * 10 - move.piece.baseValue
            }
            return (move, score)
        }.sorted { $0.1 > $1.1 }.map { $0.0 }
    }
}
