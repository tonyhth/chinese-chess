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
        // 不在每次 bestMove 清空 TT，保留 IDS 跨深度缓存。
        // TT 内部用 hash 做完整性校验，不同局面不会误命中。

        switch difficulty {
        case .beginner:
            return safeRandomMove(for: workBoard)
        case .easy:
            return rootSearch(for: workBoard, depth: 2, useTT: false, useMoveOrder: false)
        case .medium:
            return mediumSearch(for: workBoard)
        case .hard:
            return hardSearch(for: workBoard)
        case .master:
            return masterSearch(for: workBoard)
        }
    }

    // MARK: - 新手：随机走法 + 安全过滤

    /// 新手级 AI：随机合法走法，过滤掉"送大子"的走法。
    /// 送大子判定：走后己方价值 ≥ 400（车/炮/马）的子被对方直接攻击。
    /// 优化：用 isInCheck 式的攻击检测替代全量走法生成。
    private func safeRandomMove(for board: Board) -> Move? {
        let side = board.currentTurn
        let moves = MoveValidator.allLegalMoves(for: side, on: board)
        guard !moves.isEmpty else { return nil }

        let opponentSide: Side = (side == .red) ? .black : .red

        // 过滤送大子：检查走后该子是否被对方直接攻击
        let safeMoves = moves.filter { move in
            // 不涉及移动大子且不吃子，保留
            if move.piece.baseValue < 400 && move.captured == nil { return true }

            // 执行走法，检查目标位置是否被对方攻击
            board.execute(move)
            let targetPos = move.to
            let threatened = board.pieces(for: opponentSide).contains { op in
                MoveValidator.canAttack(piece: op, target: targetPos, on: board)
            }
            _ = board.undoLastMove()

            // 如果走的是大子（≥400）且被威胁且没吃子，过滤掉
            if move.piece.baseValue >= 400 && threatened && move.captured == nil {
                return false
            }
            return true
        }

        // 过滤后为空则回退到纯随机
        return (safeMoves.isEmpty ? moves : safeMoves).randomElement()
    }

    // MARK: - Negamax 根搜索（统一接口）

    /// Negamax + Alpha-Beta 根节点搜索。
    /// 评估函数始终返回当前行走方视角的分数（正值有利）。
    private func rootSearch(for board: Board, depth: Int, useTT: Bool, useMoveOrder: Bool,
                            timeManager: TimeManager? = nil) -> Move? {
        let side = board.currentTurn
        let moves = MoveValidator.allLegalMoves(for: side, on: board)
        guard !moves.isEmpty else { return nil }

        // 走法排序
        let orderedMoves: [Move]
        if useMoveOrder {
            let hash = ZobristHash.hash(board: board)
            let ttBest = useTT ? Self.transpositionTable.probeBestMove(hash: hash) : nil
            orderedMoves = MoveOrderer.order(moves, on: board, ttBestMove: ttBest, checkLegal: depth >= 3)
        } else {
            orderedMoves = orderMovesSimple(moves)
        }

        let hash = ZobristHash.hash(board: board)
        let origAlpha = -100_000_000
        var bestMove: Move? = nil
        var bestScore = origAlpha
        var alpha = origAlpha
        let beta = 100_000_000

        for move in orderedMoves {
            // 超时检查（通过 TimeManager）
            if let tm = timeManager, tm.shouldStop { break }

            board.execute(move)
            // Negamax：对手视角取负
            let score = -negamax(board: board, depth: depth - 1, alpha: -beta, beta: -alpha,
                                 useTT: useTT, useMoveOrder: useMoveOrder)
            _ = board.undoLastMove()

            if score > bestScore {
                bestScore = score
                bestMove = move
            }
            alpha = max(alpha, bestScore)
        }

        // 存入置换表（使用搜索开始时的原始 alpha 值判定 flag）
        if useTT {
            let flag: TranspositionTable.TTFlag = (bestScore <= origAlpha) ? .upper : (bestScore >= beta) ? .lower : .exact
            Self.transpositionTable.store(hash: hash, depth: depth, score: bestScore, flag: flag, bestMove: bestMove)
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

        // 未命中开局库，走 negamax depth=4
        return rootSearch(for: board, depth: 4, useTT: true, useMoveOrder: true)
    }

    // MARK: - 高级：IDS + 杀法搜索 + 棋型识别

    private func hardSearch(for board: Board) -> Move? {
        let side = board.currentTurn

        // 杀法搜索（高优先级）
        if let killMoves = CheckmateSearch.search(board: board, for: side, maxDepth: 10, timeLimitMs: 500) {
            return killMoves.first
        }

        // 迭代加深（接入 TimeManager）
        let tm = TimeManager.forDifficulty(.hard)!
        return iterativeDeepeningSearch(for: board, maxDepth: 4, timeManager: tm)
    }

    // MARK: - 大师：深层 IDS + 杀法搜索 + 残局估值 + 时间管理

    private func masterSearch(for board: Board) -> Move? {
        let side = board.currentTurn

        // 杀法搜索（深度更深）
        if let killMoves = CheckmateSearch.search(board: board, for: side, maxDepth: 12, timeLimitMs: 800) {
            return killMoves.first
        }

        // 残局阶段搜索深度提升
        let baseDepth: Int
        if board.pieces.count <= 10 {
            baseDepth = (board.pieces.count <= 6) ? 8 : 7
        } else {
            baseDepth = 6
        }

        // 迭代加深（接入 TimeManager）
        let tm = TimeManager.forDifficulty(.master)!
        return iterativeDeepeningSearch(for: board, maxDepth: baseDepth, timeManager: tm)
    }

    // MARK: - 迭代加深 Negamax

    private func iterativeDeepeningSearch(for board: Board, maxDepth: Int, timeManager: TimeManager) -> Move? {
        var bestMoveSoFar: Move?

        for depth in 2...maxDepth {
            if timeManager.shouldStop { break }
            if let move = rootSearch(for: board, depth: depth, useTT: true, useMoveOrder: true,
                                      timeManager: timeManager) {
                bestMoveSoFar = move
            }
        }
        return bestMoveSoFar
    }

    // MARK: - Negamax + Alpha-Beta 核心

    /// Negamax 搜索：评估函数始终返回当前行走方视角的分数。
    /// 递归时传递 -beta, -alpha 实现对手视角的窗口翻转。
    private func negamax(board: Board, depth: Int, alpha: Int, beta: Int,
                         useTT: Bool, useMoveOrder: Bool) -> Int {
        let side = board.currentTurn
        let hash = ZobristHash.hash(board: board)

        // 置换表查找
        if useTT {
            if let result = Self.transpositionTable.lookup(hash: hash, depth: depth, alpha: alpha, beta: beta) {
                return result.score
            }
        }

        // 叶节点或终止
        if depth == 0 || isTerminal(board) {
            return evaluate(board)
        }

        var moves = MoveValidator.allLegalMoves(for: side, on: board)

        if moves.isEmpty {
            // 被将军 = 输，未被判和
            let score = MoveValidator.isInCheck(side, on: board) ? (-100000 - depth) : 0
            if useTT {
                Self.transpositionTable.store(hash: hash, depth: depth, score: score, flag: .exact, bestMove: nil)
            }
            return score
        }

        // 走法排序
        if useMoveOrder {
            let ttBest = useTT ? Self.transpositionTable.probeBestMove(hash: hash) : nil
            moves = MoveOrderer.order(moves, on: board, ttBestMove: ttBest, checkLegal: depth >= 3)
        } else if depth >= 2 {
            moves = orderMovesSimple(moves)
        }

        let origAlpha = alpha
        var bestScore = -100_000_000
        var bestMove: Move? = nil
        var a = alpha

        for move in moves {
            board.execute(move)
            let score = -negamax(board: board, depth: depth - 1, alpha: -beta, beta: -a,
                                 useTT: useTT, useMoveOrder: useMoveOrder)
            _ = board.undoLastMove()

            if score > bestScore {
                bestScore = score
                bestMove = move
            }
            a = max(a, bestScore)
            if a >= beta { break }  // beta cutoff
        }

        // 存入置换表（使用搜索开始时的 origAlpha 判定 flag）
        if useTT {
            let flag: TranspositionTable.TTFlag = (bestScore <= origAlpha) ? .upper : (bestScore >= beta) ? .lower : .exact
            Self.transpositionTable.store(hash: hash, depth: depth, score: bestScore, flag: flag, bestMove: bestMove)
        }

        return bestScore
    }

    // MARK: - 终止判定

    private func isTerminal(_ board: Board) -> Bool {
        if board.generalPosition(of: .red) == nil { return true }
        if board.generalPosition(of: .black) == nil { return true }
        return false
    }

    // MARK: - 评估函数（当前行走方视角，正值有利于当前行）

    /// 返回当前行走方视角的评估分数（正值 = 当前行有利）。
    ///
    /// 在 negamax 框架中，evaluate 在 depth=0 时被调用，此时 `board.currentTurn`
    /// 是最后一步走棋后的对手方。外层 negamax 会对此值取负，正确切换视角。
    /// 例如：黑方走棋后 currentTurn 变为红方，evaluate 返回红方视角的负值（黑优），
    /// 外层取负后变为正值（黑优），语义正确。
    private func evaluate(_ board: Board) -> Int {
        let side = board.currentTurn

        // 残局精确估值（≤6 子）
        if let endgameScore = EndgameEvaluator.evaluate(board: board, for: side) {
            return endgameScore
        }

        let sign: Int = (side == .black) ? 1 : -1

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

        // 棋型识别加分：两方都识别，取差值（黑方加分 - 红方加分）
        // sign 会将差值翻转到当前行走方视角
        let blackPatternBonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        let redPatternBonus = PatternRecognizer.bonusPatterns(on: board, for: .red)
        let patternBonus = blackPatternBonus - redPatternBonus

        return sign * (materialScore + positionScore + patternBonus)
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
