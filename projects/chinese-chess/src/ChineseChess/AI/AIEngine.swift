import Foundation

// MARK: - AI 引擎协议

protocol AIEngineProtocol {
    /// 计算最佳走法。内部会复制棋盘，不会修改传入的 board。
    func bestMove(for board: Board, difficulty: AIDifficulty) -> Move?
}

// MARK: - AI 引擎实现

struct AIEngine: AIEngineProtocol {

    /// 开局库（延迟初始化，所有 AIEngine 实例共享）
    private static let openingBook = OpeningBook()
    /// 置换表
    private static let transpositionTable = TranspositionTable()

    func bestMove(for board: Board, difficulty: AIDifficulty) -> Move? {
        // 入口处统一做深拷贝，确保不修改调用者的 board
        let workBoard = board.snapshot()
        // 每次搜索清空置换表（避免跨局面污染）
        Self.transpositionTable.clear()

        switch difficulty {
        case .beginner:
            return safeRandomMove(for: workBoard)
        case .easy:
            return heuristicSearch(for: workBoard, depth: 2, useTT: false, useMoveOrder: false)
        case .medium:
            return mediumSearch(for: workBoard)
        case .hard:
            return iterativeDeepeningSearch(for: workBoard, maxDepth: 4)
        case .master:
            return iterativeDeepeningSearch(for: workBoard, maxDepth: 6)
        }
    }

    // MARK: - 新手：随机走法 + 安全过滤

    /// 新手级 AI：随机合法走法，过滤掉"送大子"的走法。
    /// 送大子判定：走后己方价值 ≥ 400（车/炮/马）的子被对方无条件吃掉。
    private func safeRandomMove(for board: Board) -> Move? {
        let side = board.currentTurn
        let moves = MoveValidator.allLegalMoves(for: side, on: board)
        guard !moves.isEmpty else { return nil }

        let opponentSide: Side = (side == .red) ? .black : .red

        // 过滤送大子
        let safeMoves = moves.filter { move in
            // 不涉及移动大子且不吃子，保留
            if move.piece.baseValue < 400 && move.captured == nil { return true }

            // 执行走法，检查对方能否吃掉该子
            board.execute(move)
            let targetPos = move.to
            let canRetake = MoveValidator.allLegalMoves(for: opponentSide, on: board).contains { opMove in
                opMove.captured?.id == move.piece.id && opMove.to == targetPos
            }
            _ = board.undoLastMove()

            // 如果走的是大子（≥400）且对方能无条件吃回，过滤掉
            if move.piece.baseValue >= 400 && canRetake && move.captured == nil {
                return false
            }
            return true
        }

        // 过滤后为空则回退到纯随机
        return (safeMoves.isEmpty ? moves : safeMoves).randomElement()
    }

    // MARK: - 初级：depth=2 + Alpha-Beta + MVV-LVA

    private func heuristicSearch(for board: Board, depth: Int, useTT: Bool, useMoveOrder: Bool) -> Move? {
        let side = board.currentTurn
        let moves = MoveValidator.allLegalMoves(for: side, on: board)
        guard !moves.isEmpty else { return nil }

        // 初级只用 MVV-LVA，不用 MoveOrderer 的将军检测
        let orderedMoves = orderMovesSimple(moves)

        var bestMove: Move?
        var bestScore = Int.min
        var alpha = Int.min
        let beta = Int.max
        let isMaximizing = (side == .black)

        for move in orderedMoves {
            board.execute(move)
            let score = minimax(board: board, depth: depth - 1, alpha: alpha, beta: beta,
                                isMaximizing: !isMaximizing, useTT: useTT, useMoveOrder: useMoveOrder)
            _ = board.undoLastMove()

            if isMaximizing {
                if score > bestScore {
                    bestScore = score
                    bestMove = move
                }
                alpha = max(alpha, bestScore)
            } else {
                // 红方视角取最小值，所以翻转
                let adjustedScore = -score
                if adjustedScore > bestScore {
                    bestScore = adjustedScore
                    bestMove = move
                }
            }
        }
        return bestMove
    }

    // MARK: - 中级：depth=4 + Alpha-Beta + 开局库 + 将军优先排序

    private func mediumSearch(for board: Board) -> Move? {
        // 检查开局库（前 10 步）
        let hash = ZobristHash.hash(board: board)
        if let iccsMove = Self.openingBook.lookup(zobristHash: hash),
           let move = Self.openingBook.parseICCSMove(iccsMove, on: board) {
            return move
        }

        // 未命中开局库，走 minimax depth=4
        return heuristicSearch(for: board, depth: 4, useTT: true, useMoveOrder: true)
    }

    // MARK: - 高级/大师：迭代加深 Alpha-Beta

    private func iterativeDeepeningSearch(for board: Board, maxDepth: Int) -> Move? {
        var bestMoveSoFar: Move?
        let startTime = Date()
        let timeLimitMs = (maxDepth >= 6) ? 5000 : 3000

        for depth in 2...maxDepth {
            let elapsed = Date().timeIntervalSince(startTime) * 1000
            if elapsed > Double(timeLimitMs) { break }
            if let move = searchAtDepth(board: board, depth: depth, startTime: startTime, timeLimitMs: timeLimitMs) {
                bestMoveSoFar = move
            }
        }
        return bestMoveSoFar
    }

    private func searchAtDepth(board: Board, depth: Int, startTime: Date, timeLimitMs: Int) -> Move? {
        let side = board.currentTurn
        let moves = MoveValidator.allLegalMoves(for: side, on: board)
        let hash = ZobristHash.hash(board: board)
        let ttBestMove = Self.transpositionTable.probeBestMove(hash: hash)
        let orderedMoves = MoveOrderer.order(moves, on: board, ttBestMove: ttBestMove, checkLegal: depth >= 3)
        guard !orderedMoves.isEmpty else { return nil }

        var bestMove: Move?
        var bestScore = Int.min
        var alpha = Int.min
        let beta = Int.max
        let isMaximizing = (side == .black)

        for move in orderedMoves {
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
            if elapsed > timeLimitMs { break }

            board.execute(move)
            let score = minimax(board: board, depth: depth - 1, alpha: alpha, beta: beta,
                                isMaximizing: !isMaximizing, useTT: true, useMoveOrder: true)
            _ = board.undoLastMove()

            if isMaximizing {
                if score > bestScore {
                    bestScore = score
                    bestMove = move
                }
                alpha = max(alpha, bestScore)
            } else {
                let adjustedScore = -score
                if adjustedScore > bestScore {
                    bestScore = adjustedScore
                    bestMove = move
                }
            }
        }

        // 存入置换表
        let flag: TranspositionTable.TTFlag = (bestScore <= alpha) ? .upper : (bestScore >= beta) ? .lower : .exact
        Self.transpositionTable.store(hash: hash, depth: depth, score: bestScore, flag: flag, bestMove: bestMove)

        return bestMove
    }

    // MARK: - Minimax + Alpha-Beta 核心

    private func minimax(board: Board, depth: Int, alpha: Int, beta: Int,
                         isMaximizing: Bool, useTT: Bool, useMoveOrder: Bool) -> Int {
        // 置换表查找
        if useTT {
            let hash = ZobristHash.hash(board: board)
            if let result = Self.transpositionTable.lookup(hash: hash, depth: depth, alpha: alpha, beta: beta) {
                return result.score
            }
        }

        // 叶节点或终止
        if depth == 0 || isTerminal(board) {
            return evaluate(board)
        }

        let side: Side = isMaximizing ? .black : .red
        var moves = MoveValidator.allLegalMoves(for: side, on: board)

        if moves.isEmpty {
            return MoveValidator.isInCheck(side, on: board) ? (isMaximizing ? -100000 : +100000) : 0
        }

        // 走法排序
        if useMoveOrder {
            let hash = ZobristHash.hash(board: board)
            let ttBest = useTT ? Self.transpositionTable.probeBestMove(hash: hash) : nil
            moves = MoveOrderer.order(moves, on: board, ttBestMove: ttBest, checkLegal: depth >= 3)
        } else if depth >= 2 {
            moves = orderMovesSimple(moves)
        }

        if isMaximizing {
            var maxEval = Int.min
            var a = alpha
            for move in moves {
                board.execute(move)
                let evalScore = minimax(board: board, depth: depth - 1, alpha: a, beta: beta,
                                        isMaximizing: false, useTT: useTT, useMoveOrder: useMoveOrder)
                _ = board.undoLastMove()
                maxEval = max(maxEval, evalScore)
                a = max(a, evalScore)
                if beta <= a { break }
            }
            // 存入置换表
            if useTT {
                let hash = ZobristHash.hash(board: board)
                let flag: TranspositionTable.TTFlag = (maxEval <= alpha) ? .upper : (maxEval >= beta) ? .lower : .exact
                Self.transpositionTable.store(hash: hash, depth: depth, score: maxEval, flag: flag, bestMove: nil)
            }
            return maxEval
        } else {
            var minEval = Int.max
            var b = beta
            for move in moves {
                board.execute(move)
                let evalScore = minimax(board: board, depth: depth - 1, alpha: alpha, beta: b,
                                        isMaximizing: true, useTT: useTT, useMoveOrder: useMoveOrder)
                _ = board.undoLastMove()
                minEval = min(minEval, evalScore)
                b = min(b, evalScore)
                if b <= alpha { break }
            }
            // 存入置换表
            if useTT {
                let hash = ZobristHash.hash(board: board)
                let flag: TranspositionTable.TTFlag = (minEval <= alpha) ? .upper : (minEval >= beta) ? .lower : .exact
                Self.transpositionTable.store(hash: hash, depth: depth, score: minEval, flag: flag, bestMove: nil)
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

    private static let chariotEdgeRow: [Int] = [6, 8, 8, 12, 14, 12, 8, 8, 6]
    private static let chariotMidRow: [Int]  = [6, 10, 12, 16, 18, 16, 12, 10, 6]

    private func chariotPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let r = (side == .black) ? row : (9 - row)
        return (r == 0 || r == 9) ? Self.chariotEdgeRow[col] : Self.chariotMidRow[col]
    }

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

    private func advisorPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let localRow = (side == .black) ? row : (9 - row)
        if localRow == 1 && col == 4 { return 6 }
        if localRow >= 0 && localRow <= 2 && col >= 3 && col <= 5 { return 2 }
        return 0
    }

    private func elephantPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let localRow = (side == .black) ? row : (9 - row)
        if localRow == 2 && (col == 2 || col == 6) { return 4 }
        if localRow == 0 && (col == 2 || col == 6) { return 2 }
        if localRow == 2 && col == 4 { return 2 }
        return 0
    }

    // MARK: - 简单走法排序（MVV-LVA，用于初级）

    private func orderMovesSimple(_ moves: [Move]) -> [Move] {
        moves.map { move -> (Move, Int) in
            var score = 0
            if let captured = move.captured {
                score += 10000 + captured.baseValue * 10 - move.piece.baseValue
            }
            return (move, score)
        }.sorted { $0.1 > $1.1 }.map { $0.0 }
    }
}
