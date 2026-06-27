import Foundation

// MARK: - AI 引擎协议

protocol AIEngineProtocol {
    /// 计算最佳走法。内部会复制棋盘，不会修改传入的 board。
    func bestMove(for board: Board, difficulty: AIDifficulty, isIOS: Bool) async -> Move?
}

// MARK: - AI 引擎实现

actor AIEngine: AIEngineProtocol {

    /// 开局库（实例级，避免多 ViewModel 并发访问）
    private let openingBook = OpeningBook()
    /// 置换表（实例级，避免多 ViewModel 并发访问）
    private let transpositionTable = TranspositionTable()
    /// 历史启发表（实例级，避免并发竞争）
    private var moveOrderer = MoveOrderer()
    /// 评估器（依赖注入）
    private let evaluator: AIEvaluator

    /// v3.1 权重配置（实例级，持有权重副本）
    private let weights: EvalWeights

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

    /// 清空历史启发表（新对局时调用）
    func clearHistory() {
        moveOrderer.clearHistory()
    }

    func bestMove(for board: Board, difficulty: AIDifficulty, isIOS: Bool = false) async -> Move? {
        let workBoard = board.snapshot()

        switch difficulty {
        case .beginner:
            return beginnerMove(for: workBoard)
        case .easy:
            return rootSearch(for: workBoard, depth: 3, useTT: true, useMoveOrder: true,
                              evalConfig: .basic)
        case .medium:
            return mediumSearch(for: workBoard, isIOS: isIOS)
        case .hard:
            return hardSearch(for: workBoard, isIOS: isIOS)
        case .master:
            return masterSearch(for: workBoard, isIOS: isIOS)
        }
    }

    // MARK: - 新手：平滑过渡

    private static let beginnerSearchProbability = 30

    private func beginnerMove(for board: Board) -> Move? {
        if Int.random(in: 0..<100) < Self.beginnerSearchProbability {
            return rootSearch(for: board, depth: 1, useTT: false, useMoveOrder: false,
                              evalConfig: .basic)
        } else {
            return safeRandomMove(for: board)
        }
    }

    // MARK: - 新手：随机走法 + 安全过滤

    private func safeRandomMove(for board: Board) -> Move? {
        let side = board.currentTurn
        let moves = MoveValidator.allLegalMoves(for: side, on: board)
        guard !moves.isEmpty else { return nil }

        let opponentSide: Side = (side == .red) ? .black : .red

        let safeMoves = moves.filter { move in
            if move.piece.baseValue < 400 && move.captured == nil { return true }

            board.execute(move)
            let targetPos = move.to
            let threatened = board.pieces(for: opponentSide).contains { op in
                MoveValidator.canAttack(piece: op, target: targetPos, on: board)
            }
            _ = board.undoLastMove()

            if move.piece.baseValue >= 400 && threatened && move.captured == nil {
                return false
            }
            return true
        }

        return (safeMoves.isEmpty ? moves : safeMoves).randomElement()
    }

    // MARK: - Negamax 根搜索（统一接口）

    private func rootSearch(for board: Board, depth: Int, useTT: Bool, useMoveOrder: Bool,
                            evalConfig: AIEvalConfig = .basic,
                            searchConfig: AISearchConfig? = nil,
                            timeManager: TimeManager? = nil) -> Move? {
        let side = board.currentTurn
        let moves = MoveValidator.allLegalMoves(for: side, on: board)
        guard !moves.isEmpty else { return nil }

        let orderedMoves: [Move]
        if useMoveOrder {
            let hash = ZobristHash.hash(board: board)
            let ttBest = useTT ? transpositionTable.probeBestMove(hash: hash) : nil
            orderedMoves = moveOrderer.order(moves, on: board, ttBestMove: ttBest, checkLegal: depth >= 3, depth: depth)
        } else {
            orderedMoves = orderMovesSimple(moves)
        }

        let hash = ZobristHash.hash(board: board)
        let origAlpha = -100_000_000
        var bestMove: Move? = nil
        var bestScore = origAlpha
        var alpha = origAlpha
        let beta = 100_000_000
        let usePVS = searchConfig?.enablePVS ?? false

        for (moveIndex, move) in orderedMoves.enumerated() {
            if let tm = timeManager, tm.shouldStop { break }

            board.execute(move)

            let score: Int
            if usePVS && moveIndex > 0 {
                let nullWindowScore: Int
                if let sc = searchConfig {
                    nullWindowScore = -negamax(board: board, depth: depth - 1, alpha: -alpha - 1, beta: -alpha,
                                               useTT: useTT, useMoveOrder: useMoveOrder,
                                               searchConfig: sc)
                } else {
                    nullWindowScore = -negamax(board: board, depth: depth - 1, alpha: -alpha - 1, beta: -alpha,
                                               useTT: useTT, useMoveOrder: useMoveOrder, evalConfig: evalConfig)
                }

                if nullWindowScore > alpha && nullWindowScore < beta {
                    if let sc = searchConfig {
                        score = -negamax(board: board, depth: depth - 1, alpha: -beta, beta: -alpha,
                                         useTT: useTT, useMoveOrder: useMoveOrder,
                                         searchConfig: sc)
                    } else {
                        score = -negamax(board: board, depth: depth - 1, alpha: -beta, beta: -alpha,
                                         useTT: useTT, useMoveOrder: useMoveOrder, evalConfig: evalConfig)
                    }
                } else {
                    score = nullWindowScore
                }
            } else {
                if let sc = searchConfig {
                    score = -negamax(board: board, depth: depth - 1, alpha: -beta, beta: -alpha,
                                     useTT: useTT, useMoveOrder: useMoveOrder,
                                     searchConfig: sc)
                } else {
                    score = -negamax(board: board, depth: depth - 1, alpha: -beta, beta: -alpha,
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

    private func mediumSearch(for board: Board, isIOS: Bool) -> Move? {
        let hash = ZobristHash.hash(board: board)
        if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
           let move = openingBook.parseICCSMove(iccsMove, on: board) {
            return move
        }

        guard let tm = TimeManager.forDifficulty(.medium, isIOS: isIOS, board: board) else {
            let maxDepth = board.pieces.count <= 10 ? 7 : 6
            return rootSearch(for: board, depth: maxDepth, useTT: true, useMoveOrder: true,
                              searchConfig: .medium)
        }

        let maxDepth = board.pieces.count <= 10 ? 7 : 6
        return iterativeDeepeningSearch(for: board, maxDepth: maxDepth, timeManager: tm, searchConfig: .medium)
    }

    // MARK: - 高级

    private func hardSearch(for board: Board, isIOS: Bool) -> Move? {
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

        guard let tm = TimeManager.forDifficulty(.hard, isIOS: isIOS, board: board) else {
            return rootSearch(for: board, depth: baseDepth, useTT: true, useMoveOrder: true,
                              searchConfig: .hard)
        }
        return iterativeDeepeningSearch(for: board, maxDepth: baseDepth, timeManager: tm, searchConfig: .hard)
    }

    // MARK: - 大师

    private func masterSearch(for board: Board, isIOS: Bool) -> Move? {
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

        guard let tm = TimeManager.forDifficulty(.master, isIOS: isIOS, board: board) else {
            return rootSearch(for: board, depth: baseDepth, useTT: true, useMoveOrder: true,
                              searchConfig: .master)
        }
        return iterativeDeepeningSearch(for: board, maxDepth: baseDepth, timeManager: tm, searchConfig: .master)
    }

    // MARK: - 迭代加深 Negamax

    private func iterativeDeepeningSearch(for board: Board, maxDepth: Int,
                                            timeManager: TimeManager,
                                            searchConfig: AISearchConfig) -> Move? {
        var bestMoveSoFar: Move?
        var tm = timeManager

        for depth in 2...maxDepth {
            if searchConfig.enableSmartTime {
                if depth > 2 && !tm.shouldStartNextIteration { break }
            }
            if tm.shouldStop { break }

            if let move = rootSearch(for: board, depth: depth, useTT: true, useMoveOrder: true,
                                      searchConfig: searchConfig,
                                      timeManager: tm) {
                bestMoveSoFar = move
            }

            tm.recordIterationComplete()
        }
        return bestMoveSoFar
    }

    // MARK: - Negamax + Alpha-Beta 核心

    private func negamax(board: Board, depth: Int, alpha: Int, beta: Int,
                         useTT: Bool, useMoveOrder: Bool, evalConfig: AIEvalConfig = .basic,
                         extensions: Int = 0, searchConfig: AISearchConfig = .default) -> Int {
        let side = board.currentTurn
        let hash = ZobristHash.hash(board: board)
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
                    qsScore = quiescenceSearch(board: board, alpha: alpha, beta: beta,
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
                return quiescenceSearch(board: board, alpha: alpha, beta: beta,
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
                let nullScore = -negamax(board: board, depth: depth - 1 - R,
                                          alpha: -beta, beta: -beta + 1,
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
                _ = negamax(board: board, depth: depth - 2,
                            alpha: alpha, beta: beta,
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
                let reducedScore = -negamax(board: board, depth: newDepth - reduction,
                                              alpha: -beta, beta: -alpha,
                                              useTT: false, useMoveOrder: useMoveOrder,
                                              evalConfig: evalCfg, extensions: newExtensions,
                                              searchConfig: searchConfig)
                if reducedScore > alpha {
                    score = -negamax(board: board, depth: newDepth,
                                      alpha: -beta, beta: -a,
                                      useTT: useTT, useMoveOrder: useMoveOrder,
                                      evalConfig: evalCfg, extensions: newExtensions,
                                      searchConfig: searchConfig)
                } else {
                    score = reducedScore
                }
            } else if searchConfig.enablePVS && moveIndex > 0 {
                let nullWindowScore = -negamax(board: board, depth: newDepth,
                                                alpha: -a - 1, beta: -a,
                                                useTT: useTT, useMoveOrder: useMoveOrder,
                                                evalConfig: evalCfg, extensions: newExtensions,
                                                searchConfig: searchConfig)
                if nullWindowScore > a && nullWindowScore < beta {
                    score = -negamax(board: board, depth: newDepth,
                                      alpha: -beta, beta: -a,
                                      useTT: useTT, useMoveOrder: useMoveOrder,
                                      evalConfig: evalCfg, extensions: newExtensions,
                                      searchConfig: searchConfig)
                } else {
                    score = nullWindowScore
                }
            } else {
                score = -negamax(board: board, depth: newDepth,
                                  alpha: -beta, beta: -a,
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
        board: Board,
        alpha: Int, beta: Int,
        qDepth: Int,
        searchConfig: AISearchConfig
    ) -> Int {
        let standPat = evaluator.evaluate(board, config: searchConfig.evalConfig)

        if standPat >= beta { return beta }
        var alpha = alpha
        if alpha < standPat { alpha = standPat }
        if qDepth <= 0 { return standPat }

        let side = board.currentTurn
        let allMoves = MoveValidator.allLegalMoves(for: side, on: board)
        let captureMoves = allMoves.filter { $0.captured != nil }

        let checkMoves = allMoves.filter { move in
            board.execute(move)
            let givesCheck = MoveValidator.isInCheck(board.currentTurn, on: board)
            _ = board.undoLastMove()
            return givesCheck
        }

        let qMoves = captureMoves + checkMoves
        let orderedQMoves = orderCapturesMVV_LVA(qMoves)

        for move in orderedQMoves {
            if let captured = move.captured {
                if standPat + captured.baseValue + 200 < alpha { continue }
            }

            board.execute(move)
            let score = -quiescenceSearch(board: board, alpha: -beta, beta: -alpha,
                                           qDepth: qDepth - 1, searchConfig: searchConfig)
            _ = board.undoLastMove()

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

    private func shouldDisableNullMove(on board: Board, config: AISearchConfig) -> Bool {
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

    private func isTerminal(_ board: Board) -> Bool {
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

    // Note: These are synchronous implementations that satisfy the async ChessEngine
    // protocol requirement. For actor AIEngine, callers still undergo an actor hop
    // when using `await`, so the async semantics are preserved at the call site.

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
