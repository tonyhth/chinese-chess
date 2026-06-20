import Foundation

// MARK: - AI 引擎协议

protocol AIEngineProtocol {
    /// 计算最佳走法。内部会复制棋盘，不会修改传入的 board。
    func bestMove(for board: Board, difficulty: AIDifficulty, isIOS: Bool) -> Move?
}

// MARK: - AI 引擎实现

final class AIEngine: AIEngineProtocol {

    /// 开局库（实例级，避免多 ViewModel 并发访问）
    private let openingBook = OpeningBook()
    /// 置换表（实例级，避免多 ViewModel 并发访问）
    private let transpositionTable = TranspositionTable()
    /// 历史启发表（实例级，避免并发竞争）
    private var moveOrderer = MoveOrderer()

    /// 清空历史启发表（新对局时调用）
    func clearHistory() {
        moveOrderer.clearHistory()
    }

    func bestMove(for board: Board, difficulty: AIDifficulty, isIOS: Bool = false) -> Move? {
        // 入口处统一做深拷贝，确保不修改调用者的 board
        let workBoard = board.snapshot()
        // 不在每次 bestMove 清空 TT，保留 IDS 跨深度缓存。
        // TT 内部用 hash 做完整性校验，不同局面不会误命中。

        switch difficulty {
        case .beginner:
            return beginnerMove(for: workBoard)
        case .easy:
            return rootSearch(for: workBoard, depth: 3, useTT: true, useMoveOrder: true,
                              evalConfig: EvalConfig(mobility: false, safety: true))
        case .medium:
            return mediumSearch(for: workBoard, isIOS: isIOS)
        case .hard:
            return hardSearch(for: workBoard, isIOS: isIOS)
        case .master:
            return masterSearch(for: workBoard, isIOS: isIOS)
        }
    }

    // MARK: - 新手：平滑过渡

    /// 新手级 depth=1 搜索概率（0-100）
    private static let beginnerSearchProbability = 30

    /// 新手级：70% 随机（safeRandomMove），30% depth=1 搜索
    /// depth=1 只看一步，偶尔走出好棋，但整体仍然很弱
    private func beginnerMove(for board: Board) -> Move? {
        if Int.random(in: 0..<100) < Self.beginnerSearchProbability {
            // 30% 概率：depth=1 搜索，只看一步
            return rootSearch(for: board, depth: 1, useTT: false, useMoveOrder: false,
                              evalConfig: EvalConfig(mobility: false, safety: false))
        } else {
            // 70% 概率：随机走法（过滤送大子）
            return safeRandomMove(for: board)
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

    // MARK: - 评估配置

    /// 控制评估函数中哪些高级维度被启用
    struct EvalConfig {
        var mobility: Bool  // 简化机动性评估
        var safety: Bool    // 将帅安全评估

        static let basic = EvalConfig(mobility: false, safety: true)       // 初级/中级
        static let advanced = EvalConfig(mobility: true, safety: true)     // 高级/大师
    }

    // MARK: - 搜索配置

    /// 搜索优化配置（运行时，非编译常量）
    /// 集中管理所有搜索参数，支持热修复和难度差异化
    struct SearchConfig {
        var enableQuiescence: Bool = false
        var enableKillerMove: Bool = false
        var enableCheckExtension: Bool = false
        var enableNullMoveFix: Bool = false
        var enableLMR: Bool = false
        var enableSmartTime: Bool = false
        var enablePVS: Bool = false
        var enableCountermove: Bool = false

        var evalConfig: EvalConfig = .advanced
        var maxQSDepth: Int = 4
        var maxCheckExtensions: Int = 8
        var nullMoveMaterialThreshold: Int = 2000

        /// 默认配置：所有优化关闭（中级及以下安全）
        static let `default` = SearchConfig()

        /// 完整优化配置（高级/大师）
        static let fullOptimization = SearchConfig(
            enableQuiescence: true,
            enableKillerMove: true,
            enableCheckExtension: true,
            enableNullMoveFix: true,
            enableLMR: true,
            enableSmartTime: false,
            enablePVS: true,
            enableCountermove: true,
            evalConfig: .advanced,
            maxQSDepth: 4,
            maxCheckExtensions: 8
        )

        /// 中级配置
        static let medium = SearchConfig(
            enableQuiescence: false,
            enableKillerMove: true,
            enableCheckExtension: false,
            enableNullMoveFix: false,
            enableLMR: false,
            enableSmartTime: false,
            evalConfig: .basic,
            maxQSDepth: 4,
            maxCheckExtensions: 8
        )

        /// 高级配置
        static let hard = SearchConfig(
            enableQuiescence: true,
            enableKillerMove: true,
            enableCheckExtension: true,
            enableNullMoveFix: true,
            enableLMR: true,
            enableSmartTime: false,
            enablePVS: true,
            enableCountermove: true,
            evalConfig: .advanced,
            maxQSDepth: 4,
            maxCheckExtensions: 6
        )

        /// 大师配置
        static let master = SearchConfig(
            enableQuiescence: true,
            enableKillerMove: true,
            enableCheckExtension: true,
            enableNullMoveFix: true,
            enableLMR: true,
            enableSmartTime: true,
            enablePVS: true,
            enableCountermove: true,
            evalConfig: .advanced,
            maxQSDepth: 6,
            maxCheckExtensions: 8
        )
    }

    // MARK: - Negamax 根搜索（统一接口）

    /// Negamax + Alpha-Beta 根节点搜索。
    /// 评估函数始终返回当前行走方视角的分数（正值有利）。
    private func rootSearch(for board: Board, depth: Int, useTT: Bool, useMoveOrder: Bool,
                            evalConfig: EvalConfig = .basic,
                            searchConfig: SearchConfig? = nil,
                            timeManager: TimeManager? = nil) -> Move? {
        let side = board.currentTurn
        let moves = MoveValidator.allLegalMoves(for: side, on: board)
        guard !moves.isEmpty else { return nil }

        // 走法排序
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
            // 超时检查（通过 TimeManager）
            if let tm = timeManager, tm.shouldStop { break }

            board.execute(move)

            let score: Int
            if usePVS && moveIndex > 0 {
                // PVS: 零窗口试探
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
                    // 零窗口失败，重新全窗口搜索
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
                // 第一个走法或未启用 PVS：正常全窗口搜索
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

        // 存入置换表（使用搜索开始时的原始 alpha 值判定 flag）
        if useTT {
            let flag: TranspositionTable.TTFlag = (bestScore <= origAlpha) ? .upper : (bestScore >= beta) ? .lower : .exact
            transpositionTable.store(hash: hash, depth: depth, score: bestScore, flag: flag, bestMove: bestMove)
        }

        return bestMove
    }

    // MARK: - 中级：IDS depth=5-6 + Alpha-Beta + 开局库 + 将帅安全评估

    private func mediumSearch(for board: Board, isIOS: Bool) -> Move? {
        // medium 开局库：用 weighted random 增加多样性，不限制步数（medium 对局体验 > 最优性）
        let hash = ZobristHash.hash(board: board)
        if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
           let move = openingBook.parseICCSMove(iccsMove, on: board) {
            return move
        }

        // IDS + 时间管理：通过 TimeManager.forDifficulty 统一获取时间配置
        guard let tm = TimeManager.forDifficulty(.medium, isIOS: isIOS, board: board) else {
            // fallback：理论上不会到达（.medium 已配置返回非 nil）
            let maxDepth = board.pieces.count <= 10 ? 7 : 6
            return rootSearch(for: board, depth: maxDepth, useTT: true, useMoveOrder: true,
                              searchConfig: .medium)
        }

        // 最大深度上限：残局 7，中局 6
        let maxDepth = board.pieces.count <= 10 ? 7 : 6

        return iterativeDeepeningSearch(for: board, maxDepth: maxDepth, timeManager: tm, searchConfig: .medium)
    }

    // MARK: - 高级：IDS depth=6-7 + 杀法搜索 + 机动性评估

    private func hardSearch(for board: Board, isIOS: Bool) -> Move? {
        let side = board.currentTurn

        // 开局库（前 6 步以内，优先于搜索——开局阶段信任开局库 > 搜索）
        // 开局库（前 6 步以内，加权随机选——高权重走法概率更大，同时增加多样性）
        if board.moveHistory.count < 6 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return move
            }
        }

        // 杀法搜索（深度 12，iOS 800ms / macOS 1200ms）
        let killTimeLimit = isIOS ? 800 : 1200
        if let killMoves = CheckmateSearch.search(board: board, for: side, maxDepth: 12, timeLimitMs: killTimeLimit) {
            return killMoves.first
        }

        // 残局阶段加深
        let baseDepth: Int
        if board.pieces.count <= 6 {
            baseDepth = 7
        } else if board.pieces.count <= 10 {
            baseDepth = 6
        } else {
            baseDepth = 6
        }

        guard let tm = TimeManager.forDifficulty(.hard, isIOS: isIOS, board: board) else {
            return rootSearch(for: board, depth: baseDepth, useTT: true, useMoveOrder: true,
                              searchConfig: .hard)
        }
        return iterativeDeepeningSearch(for: board, maxDepth: baseDepth, timeManager: tm, searchConfig: .hard)
    }

    // MARK: - 大师：IDS depth=8-10 + 杀法搜索 + 残局估值 + 时间管理

    private func masterSearch(for board: Board, isIOS: Bool) -> Move? {
        let side = board.currentTurn

        // v3.0: 开局库（前 6 步以内，确定性最优——取权重最高走法）
        if board.moveHistory.count < 6 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookup(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return move
            }
        }

        // 杀法搜索（深度 16，iOS 1500ms / macOS 2500ms）
        let killTimeLimit = isIOS ? 1500 : 2500
        if let killMoves = CheckmateSearch.search(board: board, for: side, maxDepth: 16, timeLimitMs: killTimeLimit) {
            return killMoves.first
        }

        // 残局阶段大幅加深
        let baseDepth: Int
        if board.pieces.count <= 6 {
            baseDepth = 10
        } else if board.pieces.count <= 10 {
            baseDepth = 8
        } else {
            baseDepth = 7
        }

        guard let tm = TimeManager.forDifficulty(.master, isIOS: isIOS, board: board) else {
            return rootSearch(for: board, depth: baseDepth, useTT: true, useMoveOrder: true,
                              searchConfig: .master)
        }
        return iterativeDeepeningSearch(for: board, maxDepth: baseDepth, timeManager: tm, searchConfig: .master)
    }

    // MARK: - 迭代加深 Negamax

    private func iterativeDeepeningSearch(for board: Board, maxDepth: Int,
                                            timeManager: TimeManager,
                                            searchConfig: SearchConfig) -> Move? {
        var bestMoveSoFar: Move?
        var tm = timeManager  // 可变副本

        for depth in 2...maxDepth {
            // 智能时间控制：剩余时间是否足够搜下一层
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

    /// Negamax 搜索：评估函数始终返回当前行走方视角的分数。
    /// 递归时传递 -beta, -alpha 实现对手视角的窗口翻转。
    /// extensions: 当前路径累计延伸次数（参数传递，不回溯）
    private func negamax(board: Board, depth: Int, alpha: Int, beta: Int,
                         useTT: Bool, useMoveOrder: Bool, evalConfig: EvalConfig = .basic,
                         extensions: Int = 0, searchConfig: SearchConfig = .default) -> Int {
        let side = board.currentTurn
        let hash = ZobristHash.hash(board: board)
        let evalCfg = searchConfig.evalConfig

        // 置换表查找
        if useTT {
            if let result = transpositionTable.lookup(hash: hash, depth: depth, alpha: alpha, beta: beta) {
                return result.score
            }
        }

        // 终止局面
        if isTerminal(board) {
            return evaluate(board, config: evalCfg)
        }

        // 叶节点：进入 QS 或直接评估
        if depth <= 0 {
            if searchConfig.enableQuiescence {
                return quiescenceSearch(board: board, alpha: alpha, beta: beta,
                                         qDepth: searchConfig.maxQSDepth,
                                         searchConfig: searchConfig)
            } else {
                return evaluate(board, config: evalCfg)
            }
        }

        // 空着裁剪（Null Move Pruning）
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
                if searchConfig.enableNullMoveFix {
                    R = depth >= 6 ? 3 : 2  // 动态 R
                } else {
                    R = 3
                }

                board.toggleTurn()
                // Null Move 分支独立计算 extension 预算（extensions: 0）
                // 设计意图：null move 是试探性搜索，不应继承主搜索的延伸深度
                let nullScore = -negamax(board: board, depth: depth - 1 - R,
                                          alpha: -beta, beta: -beta + 1,
                                          useTT: false, useMoveOrder: useMoveOrder,
                                          evalConfig: evalCfg, extensions: 0,
                                          searchConfig: searchConfig)
                board.toggleTurn()
                if nullScore >= beta {
                    return beta
                }
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

        // LMR：selfInCheck 在循环外计算（同 depth 内 execute 前不变）
        let selfInCheck = MoveValidator.isInCheck(board.currentTurn, on: board)

        for (moveIndex, move) in moves.enumerated() {
            // LMR：判断走法是否可削减
            let isCapture = move.captured != nil
            let isKiller = moveOrderer.isKillerMove(move, depth: depth)
            let canReduce = searchConfig.enableLMR
                && !isCapture
                && !selfInCheck
                && !isKiller
                && moveIndex >= 3
                && depth >= 4

            board.execute(move)

            // 将军延伸：走后对手被将军时，不消耗深度
            let givesCheck = MoveValidator.isInCheck(board.currentTurn, on: board)
            let ext: Int
            if searchConfig.enableCheckExtension && givesCheck && extensions < searchConfig.maxCheckExtensions {
                ext = 1
            } else {
                ext = 0
            }
            let newDepth = depth - 1 + ext
            let newExtensions = extensions + ext

            // 走后将军对手的走法不做 LMR 削减
            let shouldReduce = canReduce && !givesCheck

            let score: Int
            if shouldReduce {
                // 先以降低深度搜索（不写 TT，避免浅层结果污染）
                let reduction = lmrReduction(depth: depth, moveIndex: moveIndex)
                let reducedScore = -negamax(board: board, depth: newDepth - reduction,
                                              alpha: -beta, beta: -alpha,
                                              useTT: false,
                                              useMoveOrder: useMoveOrder,
                                              evalConfig: evalCfg,
                                              extensions: newExtensions,
                                              searchConfig: searchConfig)
                if reducedScore > alpha {
                    // 可能被低估，用全深度重新搜索
                    // v3.0 Phase 2a: PVS — re-search 用全窗口
                    score = -negamax(board: board, depth: newDepth,
                                      alpha: -beta, beta: -a,
                                      useTT: useTT,
                                      useMoveOrder: useMoveOrder,
                                      evalConfig: evalCfg,
                                      extensions: newExtensions,
                                      searchConfig: searchConfig)
                } else {
                    score = reducedScore
                }
            } else if searchConfig.enablePVS && moveIndex > 0 {
                // v3.0 Phase 2a: PVS — 先用零窗口试探
                let nullWindowScore = -negamax(board: board, depth: newDepth,
                                                alpha: -a - 1, beta: -a,
                                                useTT: useTT, useMoveOrder: useMoveOrder,
                                                evalConfig: evalCfg,
                                                extensions: newExtensions,
                                                searchConfig: searchConfig)
                if nullWindowScore > a && nullWindowScore < beta {
                    // 零窗口失败，重新全窗口搜索
                    score = -negamax(board: board, depth: newDepth,
                                      alpha: -beta, beta: -a,
                                      useTT: useTT, useMoveOrder: useMoveOrder,
                                      evalConfig: evalCfg,
                                      extensions: newExtensions,
                                      searchConfig: searchConfig)
                } else {
                    score = nullWindowScore
                }
            } else {
                // 正常全深度搜索
                score = -negamax(board: board, depth: newDepth,
                                  alpha: -beta, beta: -a,
                                  useTT: useTT, useMoveOrder: useMoveOrder,
                                  evalConfig: evalCfg,
                                  extensions: newExtensions,
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
                // v3.0 Phase 2a: 记录 countermove
                if searchConfig.enableCountermove {
                    moveOrderer.recordCountermove(move: move, opponentMove: board.moveHistory.last)
                }
                break  // beta cutoff
            }
        }

        // 存入置换表（使用搜索开始时的 origAlpha 判定 flag）
        if useTT {
            let flag: TranspositionTable.TTFlag = (bestScore <= origAlpha) ? .upper : (bestScore >= beta) ? .lower : .exact
            transpositionTable.store(hash: hash, depth: depth, score: bestScore, flag: flag, bestMove: bestMove)
        }

        return bestScore
    }

    // MARK: - 静态搜索（Quiescence Search）

    /// 在主搜索 depth=0 时继续搜索吃子走法，消除地平线效应。
    /// 不读写置换表，分支因子有限（仅吃子走法）。
    private func quiescenceSearch(
        board: Board,
        alpha: Int, beta: Int,
        qDepth: Int,
        searchConfig: SearchConfig
    ) -> Int {
        // 站立评估（stand pat）：不走的分数
        let standPat = evaluate(board, config: searchConfig.evalConfig)

        if standPat >= beta {
            return beta  // 已经足够好，剪枝
        }
        var alpha = alpha
        if alpha < standPat {
            alpha = standPat  // 提升下限
        }

        // 静态搜索深度耗尽
        if qDepth <= 0 {
            return standPat
        }

        let side = board.currentTurn

        // 生成吃子走法
        // TODO: Phase 3c — 扩展 MoveValidator 支持 captureLegalMoves 接口
        let allMoves = MoveValidator.allLegalMoves(for: side, on: board)
        let captureMoves = allMoves.filter { $0.captured != nil }

        // v3.0: QS 增加将军走法搜索
        // 将军走法可能迫使对手应将，暴露战术机会
        let checkMoves = allMoves.filter { move in
            move.captured == nil  // 避免与吃子走法重复
        }.filter { move in
            board.execute(move)
            let givesCheck = MoveValidator.isInCheck(board.currentTurn, on: board)
            _ = board.undoLastMove()
            return givesCheck
        }

        // 按 MVV-LVA 排序吃子走法，将军走法放后面（优先级更低）
        let orderedCaptures = orderCapturesMVV_LVA(captureMoves)

        for move in orderedCaptures {
            board.execute(move)
            let score = -quiescenceSearch(
                board: board,
                alpha: -beta, beta: -alpha,
                qDepth: qDepth - 1,
                searchConfig: searchConfig
            )
            _ = board.undoLastMove()

            if score >= beta {
                return beta  // beta cutoff
            }
            if score > alpha {
                alpha = score
            }
        }

        // v3.0: 搜索将军走法（不吃子的将军，消耗额外 QS 深度）
        for move in checkMoves {
            board.execute(move)
            let score = -quiescenceSearch(
                board: board,
                alpha: -beta, beta: -alpha,
                qDepth: qDepth - 1,
                searchConfig: searchConfig
            )
            _ = board.undoLastMove()

            if score >= beta {
                return beta  // beta cutoff
            }
            if score > alpha {
                alpha = score
            }
        }

        return alpha
    }

    /// 吃子走法 MVV-LVA 排序
    private func orderCapturesMVV_LVA(_ captures: [Move]) -> [Move] {
        captures.sorted { a, b in
            let scoreA = (a.captured?.baseValue ?? 0) * 10 - a.piece.baseValue
            let scoreB = (b.captured?.baseValue ?? 0) * 10 - b.piece.baseValue
            return scoreA > scoreB
        }
    }

    // MARK: - LMR 辅助

    /// 计算 LMR 削减层数
    /// 固定 1-2 层，保守策略，通过 re-search 兜底
    private func lmrReduction(depth: Int, moveIndex: Int) -> Int {
        let reduction: Int
        if moveIndex >= 6 && depth >= 5 {
            reduction = 2
        } else {
            reduction = 1
        }
        // 独立防御：确保削减量不超过 depth-3 且不返回负值
        return max(0, min(reduction, depth - 3))
    }

    // MARK: - Null Move 辅助

    /// 是否应禁用 Null Move Pruning（残局 Zugzwang 风险高）
    /// 使用子力动态价值而非棋子数量，更精确
    /// 注：阈值 2000 基于 baseValue 校准（车900+炮450+马400=1750 < 2000）。
    /// dynamicValue 在残局会调整马/炮/兵价值，可能导致残局误判。
    /// 待自对弈校准后切换为 baseValue 或调整阈值。
    private func shouldDisableNullMove(on board: Board, config: SearchConfig) -> Bool {
        let side = board.currentTurn

        // 条件 1：当前行子力总价值低于阈值
        let materialValue = board.pieces(for: side).reduce(0) { sum, piece in
            sum + dynamicValue(for: piece, totalPieces: board.pieces.count)
        }
        if materialValue > config.nullMoveMaterialThreshold { return false }

        // 条件 2：当前行没有车（有车时 null move 通常安全）
        let hasChariot = board.pieces(for: side).contains { $0.kind == .chariot }
        if hasChariot { return false }

        return true
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
    private func evaluate(_ board: Board, config: EvalConfig = .basic) -> Int {
        let side = board.currentTurn

        // 残局精确估值（≤6 子）
        if let endgameScore = EndgameEvaluator.evaluate(board: board, for: side) {
            return endgameScore
        }

        let sign: Int = (side == .black) ? 1 : -1

        var materialScore = 0
        var positionScore = 0

        let totalPieces = board.pieces.count

        for piece in board.pieces {
            let value = dynamicValue(for: piece, totalPieces: totalPieces)
            let posWeight = positionWeight(for: piece)
            if piece.side == .black {
                materialScore += value
                positionScore += posWeight
            } else {
                materialScore -= value
                positionScore -= posWeight
            }
        }

        // 棋型识别加分
        let blackPatternBonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        let redPatternBonus = PatternRecognizer.bonusPatterns(on: board, for: .red)
        let patternBonus = blackPatternBonus - redPatternBonus

        // 将帅安全评估（所有难度启用，开销极小）
        let safetyBonus: Int
        if config.safety {
            safetyBonus = kingSafetyScore(for: .black, on: board)
                - kingSafetyScore(for: .red, on: board)
        } else {
            safetyBonus = 0
        }

        // 简化机动性评估（仅高级/大师启用）
        let mobilityBonus: Int
        if config.mobility {
            mobilityBonus = simplifiedMobilityScore(for: .black, on: board)
                - simplifiedMobilityScore(for: .red, on: board)
        } else {
            mobilityBonus = 0
        }

        // 权重：子力(1.0) + 位置(1.0) + 棋型(1.0) + 机动性(0.3) + 安全(0.8)
        // 注：权重为经验值，需通过自对弈校准调参
        return sign * (materialScore
            + positionScore
            + patternBonus
            + mobilityBonus / 3
            + safetyBonus * 4 / 5)
    }

    // MARK: - 棋子动态价值

    /// 根据局面阶段计算棋子动态价值
    /// totalPieces: 场上总子力数（含将帅）
    ///
    /// 阈值依据：
    /// - totalPieces <= 10（约 5 对子）：残局阶段，马开间优势显现（无車阻挡），
    ///   炮缺架子价值下降。马 450 > 炮 400 是常见棋理共识。
    /// - totalPieces <= 6（约 2-3 对子）：残末期，兵/卒过河威胁剧增（可逼近将帅），
    ///   价值提升至 300。此阈值待自对弈校准。
    /// 注：阈值来源于象棋棋理经验，具体数值待通过大规模自对弈校准调参。
    private func dynamicValue(for piece: Piece, totalPieces: Int) -> Int {
        switch piece.kind {
        case .general:  return 10000
        case .chariot:  return 900
        case .horse:
            if totalPieces <= 10 { return 450 }  // 残局：马 > 炮
            return 400
        case .cannon:
            if totalPieces <= 10 { return 400 }  // 残局：炮 < 马
            return 450
        case .advisor:  return 200
        case .elephant: return 200
        case .soldier:
            if totalPieces <= 6 { return 300 }  // 残末期
            let hasCrossedRiver = (piece.side == .red) ? piece.position.row <= 4 : piece.position.row >= 5
            return hasCrossedRiver ? 200 : 100
        }
    }

    // MARK: - 将帅安全评估

    /// 将帅安全：周围防护（士/象覆盖）加分，对方攻击线经过九宫减分
    /// 开销极小（约 8 次检查），所有难度启用
    private func kingSafetyScore(for side: Side, on board: Board) -> Int {
        guard let kingPos = board.generalPosition(of: side) else { return -50000 }
        var score = 0

        // 士象覆盖加分
        let advisors = board.pieces(for: side).filter { $0.kind == .advisor }
        let elephants = board.pieces(for: side).filter { $0.kind == .elephant }
        score += advisors.count * 30 + elephants.count * 25

        // 将帅暴露扣分（士象不完整时额外扣分）
        if advisors.count < 2 || elephants.count < 2 {
            let missingGuards = (2 - advisors.count) + (2 - elephants.count)
            score -= missingGuards * 40
        }

        // 对方车/炮攻击线经过九宫减分
        let opSide: Side = (side == .red) ? .black : .red
        for op in board.pieces(for: opSide) {
            if op.kind == .chariot || op.kind == .cannon {
                if isAttackingPosition(op, target: kingPos, on: board) {
                    score -= 200
                }
            }
        }

        // 对方马对九宫的威胁
        for op in board.pieces(for: opSide) where op.kind == .horse {
            score -= horsePalaceThreat(op, kingPos: kingPos, on: board)
        }

        return score
    }

    /// 检查棋子是否攻击目标位置（简化版）
    private func isAttackingPosition(_ piece: Piece, target: Position, on board: Board) -> Bool {
        let pr = piece.position.row, pc = piece.position.col
        let tr = target.row, tc = target.col

        if piece.kind == .chariot {
            // 车攻击：同行或同列，中间无阻挡
            if pr == tr {
                let minC = min(pc, tc) + 1, maxC = max(pc, tc)
                for c in minC..<maxC {
                    if board.piece(at: Position(row: pr, col: c)) != nil { return false }
                }
                return true
            }
            if pc == tc {
                let minR = min(pr, tr) + 1, maxR = max(pr, tr)
                for r in minR..<maxR {
                    if board.piece(at: Position(row: r, col: pc)) != nil { return false }
                }
                return true
            }
        }

        if piece.kind == .cannon {
            // 炮攻击：同行或同列，中间恰好一个子
            if pr == tr {
                let minC = min(pc, tc) + 1, maxC = max(pc, tc)
                var count = 0
                for c in minC..<maxC {
                    if board.piece(at: Position(row: pr, col: c)) != nil { count += 1 }
                }
                return count == 1
            }
            if pc == tc {
                let minR = min(pr, tr) + 1, maxR = max(pr, tr)
                var count = 0
                for r in minR..<maxR {
                    if board.piece(at: Position(row: r, col: pc)) != nil { count += 1 }
                }
                return count == 1
            }
        }

        return false
    }

    // MARK: - 马的跳目标（共享方法）

    /// 马从指定位置可跳的日字目标（含蹩脚检测和己方占位检查）
    /// P2-a（机动性）和 P2-b（将帅安全）共用
    private func horseJumpTargets(from pos: Position, for side: Side, on board: Board) -> [Position] {
        let r = pos.row, c = pos.col
        let targets = [(r+2,c+1),(r+2,c-1),(r-2,c+1),(r-2,c-1),
                       (r+1,c+2),(r+1,c-2),(r-1,c+2),(r-1,c-2)]
        let legs = [(r+1,c),(r+1,c),(r-1,c),(r-1,c),
                   (r,c+1),(r,c-1),(r,c+1),(r,c-1)]
        var result: [Position] = []
        for (i, (tr, tc)) in targets.enumerated() {
            guard tr >= 0, tr <= 9, tc >= 0, tc <= 8 else { continue }
            let (lr, lc) = legs[i]
            if board.piece(at: Position(row: lr, col: lc)) != nil { continue }
            if let target = board.piece(at: Position(row: tr, col: tc)), target.side == side { continue }
            result.append(Position(row: tr, col: tc))
        }
        return result
    }

    // MARK: - 对方马的九宫威胁

    /// 评估对方马对己方九宫的威胁程度
    private func horsePalaceThreat(_ horse: Piece, kingPos: Position, on board: Board) -> Int {
        let jumps = horseJumpTargets(from: horse.position, for: horse.side, on: board)
        for jump in jumps {
            if jump.row == kingPos.row && jump.col == kingPos.col {
                return 150  // 能直接攻击将帅，立即返回
            }
        }
        // 马的实际跳点中有落在九宫范围内的，视为有间接威胁
        // 九宫范围：将帅周围 3×3 区域（row: kingRow±1, col: kingCol±1）
        for jump in jumps {
            if abs(jump.row - kingPos.row) <= 1 && abs(jump.col - kingPos.col) <= 1 {
                return 30
            }
        }
        return 0
    }

    /// 机动性评估：车/炮攻击线覆盖 + 马的可达位置
    /// 注：车空格系数 5、炮目标系数 3、马机动性系数 3 为经验值
    private func simplifiedMobilityScore(for side: Side, on board: Board) -> Int {
        var score = 0
        for piece in board.pieces(for: side) {
            if piece.kind == .chariot {
                let rowEmpty = countEmptyInRow(piece.position.row, on: board)
                let colEmpty = countEmptyInCol(piece.position.col, on: board)
                score += (rowEmpty + colEmpty) * 5
            } else if piece.kind == .cannon {
                let targets = countCannonTargets(piece, on: board)
                score += targets * 3
            } else if piece.kind == .horse {
                score += horseJumpTargets(from: piece.position, for: side, on: board).count * 3
            }
        }
        return score
    }

    /// 计算某行空格数
    private func countEmptyInRow(_ row: Int, on board: Board) -> Int {
        var count = 0
        for col in 0...8 {
            if board.piece(at: Position(row: row, col: col)) == nil { count += 1 }
        }
        return count
    }

    /// 计算某列空格数
    private func countEmptyInCol(_ col: Int, on board: Board) -> Int {
        var count = 0
        for row in 0...9 {
            if board.piece(at: Position(row: row, col: col)) == nil { count += 1 }
        }
        return count
    }

    /// 计算炮可攻击的目标数（翻山吃子）
    private func countCannonTargets(_ piece: Piece, on board: Board) -> Int {
        var targets = 0
        let pr = piece.position.row, pc = piece.position.col

        // 四个方向
        let directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        for (dr, dc) in directions {
            var r = pr + dr, c = pc + dc
            var foundScreen = false
            while r >= 0 && r <= 9 && c >= 0 && c <= 8 {
                if board.piece(at: Position(row: r, col: c)) != nil {
                    if !foundScreen {
                        foundScreen = true
                    } else {
                        targets += 1  // 翻过炮架后的第一个子
                        break
                    }
                }
                r += dr
                c += dc
            }
        }
        return targets
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

    // 兵/卒位置权重（黑卒视角）— v3.0 放大 15x + 零值清理
    private static let blackSoldierWeights: [[Int]] = [
        [  30,  30,  30,  30,  30,  30,  30,  30,  30],
        [  30,  30,  30,  30,  30,  30,  30,  30,  30],
        [  30,  30,  30,  30,  30,  30,  30,  30,  30],
        [  60,  30,  90,  30, 150,  30,  90,  30,  60],
        [ 120, 210, 300, 300, 360, 300, 300, 210, 120],
        [ 210, 360, 540, 630, 720, 630, 540, 360, 210],
        [ 300, 510, 810,1080,1440,1080, 810, 510, 300],
        [ 360, 660,1020,1440,2160,1440,1020, 660, 360],
        [  30,  90, 120, 120, 120, 120, 120,  90,  30],
        [  30,  30,  30,  30,  30,  30,  30,  30,  30]
    ]

    private func soldierPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let r = (side == .black) ? row : (9 - row)
        return Self.blackSoldierWeights[r][col]
    }

    // 马位置权重 — v3.0 放大 15x + 零值清理
    private static let blackHorseWeights: [[Int]] = [
        [ 30,  60,  90,  90,  30,  90,  90,  60,  30],
        [ 60, 150, 210, 210, 210, 210, 210, 150,  60],
        [ 90, 210, 270, 300, 300, 300, 270, 210,  90],
        [120, 270, 360, 390, 420, 390, 360, 270, 120],
        [150, 300, 420, 480, 510, 480, 420, 300, 150],
        [150, 300, 420, 480, 510, 480, 420, 300, 150],
        [120, 270, 360, 390, 420, 390, 360, 270, 120],
        [ 90, 210, 270, 300, 300, 300, 270, 210,  90],
        [ 60, 150, 210, 210, 210, 210, 210, 150,  60],
        [ 30,  60,  90,  90,  30,  90,  90,  60,  30]
    ]

    private func horsePositionWeight(row: Int, col: Int, side: Side) -> Int {
        let r = (side == .black) ? row : (9 - row)
        return Self.blackHorseWeights[r][col]
    }

    // 车位置权重 — v3.0 放大 15x
    private static let chariotEdgeRow: [Int] = [90, 120, 120, 180, 210, 180, 120, 120, 90]
    private static let chariotMidRow: [Int]  = [90, 150, 180, 240, 270, 240, 180, 150, 90]

    private func chariotPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let r = (side == .black) ? row : (9 - row)
        return (r == 0 || r == 9) ? Self.chariotEdgeRow[col] : Self.chariotMidRow[col]
    }

    // 炮位置权重 — v3.0 放大 15x + 零值清理
    private static let blackCannonWeights: [[Int]] = [
        [ 30,  60,  90, 120, 150, 120,  90,  60,  30],
        [ 60,  90, 150, 210, 240, 210, 150,  90,  60],
        [ 90, 150, 210, 270, 300, 270, 210, 150,  90],
        [ 90, 180, 270, 330, 360, 330, 270, 180,  90],
        [120, 210, 300, 390, 420, 390, 300, 210, 120],
        [120, 210, 300, 390, 420, 390, 300, 210, 120],
        [ 90, 180, 270, 330, 360, 330, 270, 180,  90],
        [ 90, 150, 210, 270, 300, 270, 210, 150,  90],
        [ 60,  90, 150, 210, 240, 210, 150,  90,  60],
        [ 30,  60,  90, 120, 150, 120,  90,  60,  30]
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
