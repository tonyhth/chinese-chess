import Foundation

// MARK: - AI 引擎协议

protocol AIEngineProtocol {
    /// 计算最佳走法。内部会复制棋盘，不会修改传入的 board。
    func bestMove(for board: Board, difficulty: AIDifficulty, isIOS: Bool) async -> Move?
}

// MARK: - AI 引擎实现

actor AIEngine: AIEngineProtocol {

    /// 开局库引用（VE-1: 使用共享单例，避免双重加载 3.7MB JSON）
    private let openingBook = OpeningBook.shared
    /// 置换表（实例级，避免多 ViewModel 并发访问）
    private let transpositionTable = TranspositionTable()
    /// 历史启发表（实例级，避免并发竞争）
    private var moveOrderer = MoveOrderer()
    /// 评估器（依赖注入）
    private let evaluator: AIEvaluator

    /// v3.1 权重配置（实例级，持有权重副本）
    private let weights: EvalWeights

    /// v4.0: 节点计数器，用于 negamax 内部周期性时间检查
    private var nodeCount: Int = 0
    /// v4.0: 搜索中的 TimeManager 引用（negamax 内部检查用）
    private var activeTimeManager: TimeManager? = nil
    /// 每 4096 个节点检查一次时间
    private let timeCheckInterval = 4096

    /// 原有初始化器（兼容现有代码）
    init() {
        self.weights = EvalConfigManager.shared.weights
        self.evaluator = AIEvaluator(weights: self.weights)
    }

    /// CMA-ES 并行评估专用初始化器（注入权重副本）
    init(weights: EvalWeights) {
        self.weights = weights
        self.evaluator = AIEvaluator(weights: weights)
    }

    /// 开局库已通过 shared 单例加载，无需额外初始化

    /// 清空历史启发表（新对局时调用）
    func clearHistory() {
        moveOrderer.clearHistory()
    }

    func bestMove(for board: Board, difficulty: AIDifficulty, isIOS: Bool = false) async -> Move? {
        // ⚠️ 唯一的 Board → SearchBoard 转换点
        var workBoard = SearchBoard(from: board)

        switch difficulty {
        case .novice:
            return beginnerMove(for: &workBoard)
        case .beginner:
            // v2.1: depth 3→2 + movetime 3000ms 修复超时
            let tm = TimeManager(timeLimitMs: 3000, startTime: Date())
            return rootSearch(for: &workBoard, depth: 2, useTT: true, useMoveOrder: true,
                              evalConfig: .basic, timeManager: tm)
        case .amateurLow:
            return mediumSearch(for: &workBoard, isIOS: isIOS)
        case .amateurMid:
            return hardSearch(for: &workBoard, isIOS: isIOS)
        case .amateurHigh:
            return masterSearch(for: &workBoard, isIOS: isIOS)
        case .amateurDan, .proApprentice, .proExpert, .proMaster, .grandmaster:
            // v6.0: 专业级走 EngineRouter → Pikafish，自研引擎不处理
            // Phase 3 EngineRouter 实现后此处永远不会到达
            return masterSearch(for: &workBoard, isIOS: isIOS)
        }
    }

    // MARK: - 新手：depth-1 搜索 + top-3 加权随机（v2.1）

    // v4.0 旧方案：depth-1 + ±150cp 噪声 + top-5 加权随机（三重扰动不可控）
    // v2.1 新方案：depth-1 + top-3 加权随机（去掉噪声，更可预测）
    private func beginnerMove(for board: inout SearchBoard) -> Move? {
        let side = board.currentTurn
        let moves = MoveValidator.allLegalMoves(for: side, on: board)
        guard !moves.isEmpty else { return nil }

        // 对每个走法做 depth-1 评估（无噪声）
        var scoredMoves: [(move: Move, score: Int)] = []
        for move in moves {
            board.execute(move)
            let rawScore = -evaluator.evaluate(board, config: .basic)
            _ = board.undoLastMove()
            scoredMoves.append((move, rawScore))
        }

        // 排序，取前 3 名（v2.1: top-5→top-3）
        scoredMoves.sort { $0.score > $1.score }
        let topN = min(3, scoredMoves.count)
        let candidates = Array(scoredMoves.prefix(topN))

        // 加权随机选择：分数越高被选概率越大
        return weightedRandomPick(from: candidates)
    }

    /// 加权随机选择：分数越高被选概率越大
    private func weightedRandomPick(from candidates: [(move: Move, score: Int)]) -> Move {
        // 用指数加权确保高分走法有更高概率
        let weights = candidates.map { entry in
            // 偏移确保所有权重为正，然后取平方增强高分偏好
            let offset = entry.score - (candidates.last?.score ?? 0) + 1
            return max(1, offset * offset)
        }
        let totalWeight = weights.reduce(0, +)
        var r = Int.random(in: 0..<totalWeight)
        for (i, w) in weights.enumerated() {
            r -= w
            if r < 0 { return candidates[i].move }
        }
        return candidates.last!.move
    }

    // MARK: - Negamax 根搜索（统一接口）

    private func rootSearch(for board: inout SearchBoard, depth: Int, useTT: Bool, useMoveOrder: Bool,
                            evalConfig: AIEvalConfig = .basic,
                            searchConfig: AISearchConfig? = nil,
                            timeManager: TimeManager? = nil) -> Move? {
        // v4.0: 重置节点计数器和时间管理器
        nodeCount = 0
        activeTimeManager = timeManager

        let side = board.currentTurn
        // #7: 入口处计算初始哈希（全量，只算一次）
        let hash = ZobristHash.hash(board: board)

        let moves = MoveValidator.allLegalMoves(for: side, on: board)
        guard !moves.isEmpty else { return nil }

        let orderedMoves: [Move]
        if useMoveOrder {
            let ttBest = useTT ? transpositionTable.probeBestMove(hash: hash) : nil
            orderedMoves = moveOrderer.order(moves, on: board, ttBestMove: ttBest, checkLegal: depth >= 3, depth: depth)
        } else {
            orderedMoves = orderMovesSimple(moves)
        }

        // #7: hash 已在入口计算，不再重复
        let origAlpha = -100_000_000
        var bestMove: Move? = nil
        var bestScore = origAlpha
        var alpha = origAlpha
        let beta = 100_000_000
        let usePVS = searchConfig?.enablePVS ?? false

        for (moveIndex, move) in orderedMoves.enumerated() {
            if let tm = timeManager, tm.shouldStop { break }

            // #7: 走法执行前增量计算子局面哈希
            let childHash = ZobristHash.update(hash: hash, piece: move.piece,
                                              from: move.from, to: move.to,
                                              captured: move.captured)

            board.execute(move)

            let score: Int
            if usePVS && moveIndex > 0 {
                let nullWindowScore: Int
                if let sc = searchConfig {
                    nullWindowScore = -negamax(board: &board, depth: depth - 1,
                                               alpha: -alpha - 1, beta: -alpha, hash: childHash,
                                               useTT: useTT, useMoveOrder: useMoveOrder,
                                               searchConfig: sc)
                } else {
                    nullWindowScore = -negamax(board: &board, depth: depth - 1,
                                               alpha: -alpha - 1, beta: -alpha, hash: childHash,
                                               useTT: useTT, useMoveOrder: useMoveOrder, evalConfig: evalConfig)
                }

                if nullWindowScore > alpha && nullWindowScore < beta {
                    if let sc = searchConfig {
                        score = -negamax(board: &board, depth: depth - 1,
                                         alpha: -beta, beta: -alpha, hash: childHash,
                                         useTT: useTT, useMoveOrder: useMoveOrder,
                                         searchConfig: sc)
                    } else {
                        score = -negamax(board: &board, depth: depth - 1,
                                         alpha: -beta, beta: -alpha, hash: childHash,
                                         useTT: useTT, useMoveOrder: useMoveOrder, evalConfig: evalConfig)
                    }
                } else {
                    score = nullWindowScore
                }
            } else {
                if let sc = searchConfig {
                    score = -negamax(board: &board, depth: depth - 1,
                                     alpha: -beta, beta: -alpha, hash: childHash,
                                     useTT: useTT, useMoveOrder: useMoveOrder,
                                     searchConfig: sc)
                } else {
                    score = -negamax(board: &board, depth: depth - 1,
                                     alpha: -beta, beta: -alpha, hash: childHash,
                                     useTT: useTT, useMoveOrder: useMoveOrder, evalConfig: evalConfig)
                }
            }
            _ = board.undoLastMove()

            if score > bestScore {
                bestScore = score
                bestMove = move
            }
            alpha = max(alpha, bestScore)
        }

        if useTT {
            let flag: TranspositionTable.TTFlag = (bestScore <= origAlpha) ? .upper : (bestScore >= beta) ? .lower : .exact
            transpositionTable.store(hash: hash, depth: depth, score: bestScore, flag: flag, bestMove: bestMove)
        }

        return bestMove
    }

    // MARK: - 中级

    private func mediumSearch(for board: inout SearchBoard, isIOS: Bool) -> Move? {
        let hash = ZobristHash.hash(board: board)
        if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
           let move = openingBook.parseICCSMove(iccsMove, on: board) {
            return move
        }

        guard let tm = TimeManager.forDifficulty(.amateurLow, isIOS: isIOS, board: board) else {
            let maxDepth = board.pieces.count <= 10 ? 7 : 6
            return rootSearch(for: &board, depth: maxDepth, useTT: true, useMoveOrder: true,
                              searchConfig: .medium)
        }

        let maxDepth = board.pieces.count <= 10 ? 7 : 6
        return iterativeDeepeningSearch(for: &board, maxDepth: maxDepth, timeManager: tm, searchConfig: .medium)
    }

    // MARK: - 高级

    private func hardSearch(for board: inout SearchBoard, isIOS: Bool) -> Move? {
        let side = board.currentTurn

        if board.moveHistory.count < 6 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return move
            }
        }

        let killTimeLimit = isIOS ? 800 : 1200
        if let killMoves = CheckmateSearch.search(board: board, for: side, maxDepth: 12, timeLimitMs: killTimeLimit) {
            return killMoves.first
        }

        let baseDepth: Int
        if board.pieces.count <= 6 { baseDepth = 7 }
        else if board.pieces.count <= 10 { baseDepth = 6 }
        else { baseDepth = 6 }

        guard let tm = TimeManager.forDifficulty(.amateurMid, isIOS: isIOS, board: board) else {
            return rootSearch(for: &board, depth: baseDepth, useTT: true, useMoveOrder: true,
                              searchConfig: .hard)
        }
        return iterativeDeepeningSearch(for: &board, maxDepth: baseDepth, timeManager: tm, searchConfig: .hard)
    }

    // MARK: - 大师

    private func masterSearch(for board: inout SearchBoard, isIOS: Bool) -> Move? {
        let side = board.currentTurn

        if board.moveHistory.count < 6 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookup(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return move
            }
        }

        let killTimeLimit = isIOS ? 1500 : 2500
        if let killMoves = CheckmateSearch.search(board: board, for: side, maxDepth: 16, timeLimitMs: killTimeLimit) {
            return killMoves.first
        }

        let baseDepth: Int
        if board.pieces.count <= 6 { baseDepth = 10 }
        else if board.pieces.count <= 10 { baseDepth = 8 }
        else { baseDepth = 7 }

        guard let tm = TimeManager.forDifficulty(.amateurHigh, isIOS: isIOS, board: board) else {
            return rootSearch(for: &board, depth: baseDepth, useTT: true, useMoveOrder: true,
                              searchConfig: .master)
        }
        return iterativeDeepeningSearch(for: &board, maxDepth: baseDepth, timeManager: tm, searchConfig: .master)
    }

    // MARK: - 迭代加深 Negamax

    private func iterativeDeepeningSearch(for board: inout SearchBoard, maxDepth: Int,
                                            timeManager: TimeManager,
                                            searchConfig: AISearchConfig) -> Move? {
        var bestMoveSoFar: Move?
        var tm = timeManager

        for depth in 2...maxDepth {
            if searchConfig.enableSmartTime {
                if depth > 2 && !tm.shouldStartNextIteration { break }
            }
            if tm.shouldStop { break }

            if let move = rootSearch(for: &board, depth: depth, useTT: true, useMoveOrder: true,
                                      searchConfig: searchConfig,
                                      timeManager: tm) {
                bestMoveSoFar = move
            }

            tm.recordIterationComplete()
        }
        return bestMoveSoFar
    }

    // MARK: - Negamax + Alpha-Beta 核心

    private func negamax(board: inout SearchBoard, depth: Int, alpha: Int, beta: Int,
                         hash: UInt64,  // #7: 增量哈希参数
                         useTT: Bool, useMoveOrder: Bool, evalConfig: AIEvalConfig = .basic,
                         extensions: Int = 0, searchConfig: AISearchConfig = .default) -> Int {
        // v4.0: 周期性时间检查，防止超时
        nodeCount += 1
        if nodeCount & (timeCheckInterval - 1) == 0, // 每 4096 节点
           let tm = activeTimeManager, tm.shouldStop {
            return evaluator.evaluate(board, config: searchConfig.evalConfig)
        }

        let side = board.currentTurn
        let evalCfg = searchConfig.evalConfig

        if useTT {
            if let result = transpositionTable.lookup(hash: hash, depth: depth, alpha: alpha, beta: beta) {
                return result.score
            }
        }

        // Razoring
        if searchConfig.enableRazoring && depth <= 2 && !MoveValidator.isInCheck(side, on: board) {
            let razorMargin = depth == 1 ? 300 : 500
            let staticEval = evaluator.evaluate(board, config: evalCfg)
            if staticEval + razorMargin <= alpha {
                let qsScore: Int
                if searchConfig.enableQuiescence {
                    qsScore = quiescenceSearch(board: &board, hash: hash,
                                                alpha: alpha, beta: beta,
                                                qDepth: searchConfig.maxQSDepth,
                                                searchConfig: searchConfig)
                } else {
                    qsScore = staticEval
                }
                if qsScore <= alpha { return qsScore }
            }
        }

        if isTerminal(board) {
            return evaluator.evaluate(board, config: evalCfg)
        }

        if depth <= 0 {
            if searchConfig.enableQuiescence {
                return quiescenceSearch(board: &board, hash: hash,
                                         alpha: alpha, beta: beta,
                                         qDepth: searchConfig.maxQSDepth,
                                         searchConfig: searchConfig)
            } else {
                return evaluator.evaluate(board, config: evalCfg)
            }
        }

        // Null Move Pruning
        let nullMoveEnabled = evalCfg.mobility && depth >= 3
            && !MoveValidator.isInCheck(board.currentTurn, on: board)
        if nullMoveEnabled {
            let allowNullMove: Bool
            if searchConfig.enableNullMoveFix {
                allowNullMove = !shouldDisableNullMove(on: board, config: searchConfig)
            } else {
                allowNullMove = true
            }

            if allowNullMove {
                let R: Int
                if searchConfig.enableNullMoveFix { R = depth >= 6 ? 3 : 2 }
                else { R = 3 }

                board.toggleTurn()
                // #7: toggleTurn 改变哈希，翻转 sideHash
                let nullHash = hash ^ ZobristHash.sideHash
                let nullScore = -negamax(board: &board, depth: depth - 1 - R,
                                          alpha: -beta, beta: -beta + 1, hash: nullHash,
                                          useTT: false, useMoveOrder: useMoveOrder,
                                          evalConfig: evalCfg, extensions: 0,
                                          searchConfig: searchConfig)
                board.toggleTurn()
                if nullScore >= beta { return beta }
            }
        }

        var moves = MoveValidator.allLegalMoves(for: side, on: board)

        if moves.isEmpty {
            let score = MoveValidator.isInCheck(side, on: board) ? (-100000 - depth) : 0
            if useTT {
                transpositionTable.store(hash: hash, depth: depth, score: score, flag: .exact, bestMove: nil)
            }
            return score
        }

        // IID
        if searchConfig.enableIID && useMoveOrder && depth >= 4 {
            let ttBestProbe = useTT ? transpositionTable.probeBestMove(hash: hash) : nil
            if ttBestProbe == nil {
                _ = negamax(board: &board, depth: depth - 2,
                            alpha: alpha, beta: beta, hash: hash,
                            useTT: useTT, useMoveOrder: useMoveOrder,
                            evalConfig: evalCfg, extensions: extensions,
                            searchConfig: searchConfig)
            }
        }

        // 走法排序
        if useMoveOrder {
            let ttBest = useTT ? transpositionTable.probeBestMove(hash: hash) : nil
            let cmMove: Move? = searchConfig.enableCountermove ? moveOrderer.getCountermove(for: board.moveHistory.last) : nil
            moves = moveOrderer.order(moves, on: board, ttBestMove: ttBest, checkLegal: depth >= 3, depth: depth, countermove: cmMove)
        } else if depth >= 2 {
            moves = orderMovesSimple(moves)
        }

        let origAlpha = alpha
        var bestScore = -100_000_000
        var bestMove: Move? = nil
        var a = alpha

        let selfInCheck = MoveValidator.isInCheck(board.currentTurn, on: board)

        // Futility Pruning 预计算
        let futilityEnabled = searchConfig.enableFutility
            && depth <= 3 && depth >= 1 && !selfInCheck
        let futilityMargin = futilityEnabled ? (depth == 1 ? 300 : depth == 2 ? 500 : 900) : 0
        let staticEvalForFutility: Int? = futilityEnabled ? evaluator.evaluate(board, config: evalCfg) : nil

        for (moveIndex, move) in moves.enumerated() {
            // Futility Pruning
            if futilityEnabled
                && move.captured == nil
                && staticEvalForFutility! + futilityMargin <= alpha {
                continue
            }

            let isCapture = move.captured != nil
            let isKiller = moveOrderer.isKillerMove(move, depth: depth)
            let canReduce = searchConfig.enableLMR
                && !isCapture && !selfInCheck && !isKiller
                && moveIndex >= 3 && depth >= 4

            // #7: 走法执行前增量计算子局面哈希
            let childHash = ZobristHash.update(hash: hash, piece: move.piece,
                                              from: move.from, to: move.to,
                                              captured: move.captured)

            board.execute(move)

            let givesCheck = MoveValidator.isInCheck(board.currentTurn, on: board)
            let ext: Int
            if searchConfig.enableCheckExtension && givesCheck && extensions < searchConfig.maxCheckExtensions {
                ext = 1
            } else {
                ext = 0
            }
            let newDepth = depth - 1 + ext
            let newExtensions = extensions + ext
            let shouldReduce = canReduce && !givesCheck

            let score: Int
            if shouldReduce {
                let reduction = lmrReduction(depth: depth, moveIndex: moveIndex)
                let reducedScore = -negamax(board: &board, depth: newDepth - reduction,
                                              alpha: -beta, beta: -alpha, hash: childHash,
                                              useTT: false, useMoveOrder: useMoveOrder,
                                              evalConfig: evalCfg, extensions: newExtensions,
                                              searchConfig: searchConfig)
                if reducedScore > alpha {
                    score = -negamax(board: &board, depth: newDepth,
                                      alpha: -beta, beta: -a, hash: childHash,
                                      useTT: useTT, useMoveOrder: useMoveOrder,
                                      evalConfig: evalCfg, extensions: newExtensions,
                                      searchConfig: searchConfig)
                } else {
                    score = reducedScore
                }
            } else if searchConfig.enablePVS && moveIndex > 0 {
                let nullWindowScore = -negamax(board: &board, depth: newDepth,
                                                alpha: -a - 1, beta: -a, hash: childHash,
                                                useTT: useTT, useMoveOrder: useMoveOrder,
                                                evalConfig: evalCfg, extensions: newExtensions,
                                                searchConfig: searchConfig)
                if nullWindowScore > a && nullWindowScore < beta {
                    score = -negamax(board: &board, depth: newDepth,
                                      alpha: -beta, beta: -a, hash: childHash,
                                      useTT: useTT, useMoveOrder: useMoveOrder,
                                      evalConfig: evalCfg, extensions: newExtensions,
                                      searchConfig: searchConfig)
                } else {
                    score = nullWindowScore
                }
            } else {
                score = -negamax(board: &board, depth: newDepth,
                                  alpha: -beta, beta: -a, hash: childHash,
                                  useTT: useTT, useMoveOrder: useMoveOrder,
                                  evalConfig: evalCfg, extensions: newExtensions,
                                  searchConfig: searchConfig)
            }
            _ = board.undoLastMove()

            if score > bestScore {
                bestScore = score
                bestMove = move
            }
            a = max(a, bestScore)
            if a >= beta {
                moveOrderer.recordCutoff(move: move, depth: depth)
                if searchConfig.enableKillerMove {
                    moveOrderer.recordKiller(move: move, depth: depth)
                }
                if searchConfig.enableCountermove {
                    let histCount = board.moveHistory.count
                    let opponentMove = histCount >= 2 ? board.moveHistory[histCount - 2] : nil
                    moveOrderer.recordCountermove(move: move, opponentMove: opponentMove)
                }
                break
            }
        }

        if useTT {
            let flag: TranspositionTable.TTFlag = (bestScore <= origAlpha) ? .upper : (bestScore >= beta) ? .lower : .exact
            transpositionTable.store(hash: hash, depth: depth, score: bestScore, flag: flag, bestMove: bestMove)
        }

        return bestScore
    }

    // MARK: - 静态搜索（Quiescence Search）

    private func quiescenceSearch(
        board: inout SearchBoard,
        hash: UInt64,  // #7: 增量哈希参数
        alpha: Int, beta: Int,
        qDepth: Int,
        searchConfig: AISearchConfig
    ) -> Int {
        // v3.9.1: QS 内部时间检查（防止 master maxQSDepth=6 超时）
        nodeCount += 1
        if nodeCount & (timeCheckInterval - 1) == 0, let tm = activeTimeManager, tm.shouldStop {
            return evaluator.evaluate(board, config: searchConfig.evalConfig)
        }

        let standPat = evaluator.evaluate(board, config: searchConfig.evalConfig)

        if standPat >= beta { return beta }
        var alpha = alpha
        if alpha < standPat { alpha = standPat }
        if qDepth <= 0 { return standPat }

        let side = board.currentTurn
        let qMoves = MoveValidator.captureMoves(for: side, on: board)
        let orderedQMoves = orderCapturesMVV_LVA(qMoves)

        for move in orderedQMoves {
            if let captured = move.captured {
                if standPat + captured.baseValue + 200 < alpha { continue }
            }

            // #7: 增量计算子局面哈希
            let childHash = ZobristHash.update(hash: hash, piece: move.piece,
                                              from: move.from, to: move.to,
                                              captured: move.captured)

            board.execute(move)
            let score = -quiescenceSearch(board: &board, hash: childHash,
                                           alpha: -beta, beta: -alpha,
                                           qDepth: qDepth - 1, searchConfig: searchConfig)
            board.undoLastMove()

            if score >= beta { return beta }
            if score > alpha { alpha = score }
        }

        return alpha
    }

    private func orderCapturesMVV_LVA(_ captures: [Move]) -> [Move] {
        captures.map { move -> (Move, Int) in
            var score = 0
            if let captured = move.captured {
                score += 10000 + captured.baseValue * 10 - move.piece.baseValue
            }
            return (move, score)
        }.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    // MARK: - LMR 辅助

    private func lmrReduction(depth: Int, moveIndex: Int) -> Int {
        if depth >= 6 && moveIndex >= 8 { return 3 }
        if depth >= 4 && moveIndex >= 6 { return 2 }
        if moveIndex >= 4 { return 1 }
        return 0
    }

    // MARK: - Null Move 辅助

    private func shouldDisableNullMove(on board: SearchBoard, config: AISearchConfig) -> Bool {
        let side = board.currentTurn
        var materialSum = 0
        for piece in board.pieces(for: side) {
            if piece.kind != .general && piece.kind != .advisor && piece.kind != .elephant {
                materialSum += piece.baseValue
            }
        }
        if materialSum < config.nullMoveMaterialThreshold { return true }

        let kingPos = board.generalPosition(of: side)
        if let kp = kingPos {
            let opSide: Side = (side == .red) ? .black : .red
            for op in board.pieces(for: opSide) where op.kind == .horse {
                if KingSafetyEvaluator.horseJumpTargets(from: op.position, for: opSide, on: board).contains(where: { $0.row == kp.row && $0.col == kp.col }) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - 终止判定

    private func isTerminal(_ board: SearchBoard) -> Bool {
        let side = board.currentTurn
        return MoveValidator.allLegalMoves(for: side, on: board).isEmpty
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

// MARK: - ChessEngine 协议实现

extension AIEngine: ChessEngine {
    nonisolated var displayName: String { "内置引擎" }
    nonisolated var engineType: EngineType { .native }
    var isReady: Bool { true }

    func bestMove(
        fen: String,
        moveHistory: [String],
        difficulty: AIDifficulty,
        timeLimitMs: Int
    ) async -> String? {
        guard let board = UCIMoveConverter.board(from: fen, moves: moveHistory) else {
            return nil
        }
        let move = await self.bestMove(for: board, difficulty: difficulty, isIOS: false)
        return move.map { UCIMoveConverter.uciString(from: $0) }
    }

    func stopSearch() {
        // 自研引擎不支持中止，时间管理由内部处理
    }

    func newGame() {
        clearHistory()
    }

    func shutdown() {
        // 自研引擎无需 shutdown
    }
}
