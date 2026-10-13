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
    /// 末次根搜索是否搜完全部走法（源出 6b1ad26；M1 回退保留——39fd4d9 ZD-A' partial 不覆盖消噪的消费点）
    private var lastIterationFullySearched: Bool = true
    /// v4.0: 搜索中的 TimeManager 引用（negamax 内部检查用）
    private var activeTimeManager: TimeManager? = nil
    /// T-0926-OC-01 Phase 0：deadline 硬中止旗标——首个周期检查点置位后，
    /// 全树节点 O(1) 快退（修复迭代内无 deadline 截断：open-a 5000ms 实跑 13498ms，KI-2026-0829）
    private var searchAborted = false
    /// 每 64 个节点检查一次时间（T-0926-OC-01：4096→64——实测 mediumNoQS 满子力中局
    /// 单节点可达 ~2.2ms（mobility eval+checkLegal 排序），粗粒度检查点=置位前满负荷盲区
    /// 最坏 1023×2.2ms≈2.3s（mid-b 实测 2000→4285）；64 粒度最坏 ≈140ms，shouldStop 开销 <0.1%）
    private let timeCheckInterval = 64

    /// Contempt factor（校准专用）：均势局面下给当前走方的正向偏置
    /// 默认 0（人机对弈不受影响），校准时由 bestMove/bestMoves 根据 difficulty 设置
    private var calibrationContempt: Int = 0

    /// v6.5 v2: 叶节点评估噪声幅度（§3.3 消费侧包装层）
    /// 由 bestMove/bestMoves 按 difficulty.leafNoiseAmplitude 设置；
    /// noisyEvaluate 消费——noise=0 时直接返回 raw（lvl5 等价性锚点）
    private var leafNoise: Int = 0

    /// v6.5 v2 §3.3: 消费侧包装层——不动 evaluator.evaluate 本体（红线）
    /// noise=0 时直接返回 raw（lvl5 等价性锚点）；noise>0 时加有界 ±noise
    /// alpha-beta 不变量保持（附录 A 伪码转正）
    private func noisyEvaluate(_ board: LegacySearchBoard, config: AIEvalConfig) -> Int {
        let raw = evaluator.evaluate(board, config: config)
        guard leafNoise > 0 else { return raw }
        return raw + Int.random(in: -leafNoise...leafNoise)
    }

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
        transpositionTable.clear()
    }

    /// 清空置换表（T2: 防止红黑双方通过 TT 互相偷看搜索结果）
    ///
    /// ⚠️ 性能 trade-off：每次调用后局内 TT 缓存失效，
    /// 搜索性能下降约 30-50%（无 TT 加速，每步从零开始搜索）。
    /// 清空 TT（当前无内部调用方）。
    /// T2 回退后局间清空通过 clearHistory() 中的 transpositionTable.clear() 实现。
    /// 保留此方法作为公共 API，供外部调用方使用。
    func clearTT() {
        transpositionTable.clear()
    }

    /// 单向 Contempt factor 映射（校准专用）
    /// lvl1-3: contempt=0（弱方保持中立）
    /// lvl4: contempt=20（均势局面下主动求变）
    /// lvl5: contempt=30
    /// lvl6+: 不走自研引擎，值不重要
    private static func contemptFor(_ difficulty: AIDifficulty) -> Int {
        return 0  // contempt 实现有缺陷（评估层加常数导致强方走弱），全面禁用
        // 原映射：lvl4=20, lvl5=30。未来在搜索层正确实现后可恢复
        // switch difficulty {
        //     case .novice, .beginner, .amateurLow: return 0
        //     case .amateurMid: return 20   // lvl4
        //     case .amateurHigh: return 30  // lvl5
        //     case .amateurDan, .proApprentice, .proExpert, .proMaster, .grandmaster: return 0
        // }
    }

    /// P4-③ C 项：QS_STANDPAT_FULL 实例级注入（校准配对用）。
    /// M1 回退适配（m1-rollback §2 适配条款）：P4-①② 已随 5817cf9 revert 退场，
    /// qsStandPatFullEval 配置位/三改点分流不存在 → 本注入点保留编译、行为 no-op
    /// （--paired-qs-full 参数链保留，置位无引擎效果）；resolveQSStandPatFull 随面删除。
    var qsStandPatFullOverride: Bool?

    /// actor 隔离 setter（外部/测试注入）
    func setQSStandPatFullOverride(_ value: Bool?) {
        qsStandPatFullOverride = value
    }

    func bestMove(for board: Board, difficulty: AIDifficulty, isIOS: Bool = false) async -> Move? {
        // ⚠️ 唯一的 Board → LegacySearchBoard 转换点
        calibrationContempt = Self.contemptFor(difficulty)
        leafNoise = difficulty.leafNoiseAmplitude  // v6.5 v2: §3.3 叶噪声设置
        var workBoard = LegacySearchBoard(from: board)

        switch difficulty {
        case .novice:
            return noviceSearch(for: &workBoard, isIOS: isIOS)
        case .beginner:
            return beginnerSearch(for: &workBoard, isIOS: isIOS)
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

    // MARK: - C1: 返回 top-k 候选走法（用于 anti-repetition 走法选择）

    /// 返回 top-k 候选走法，带评分。用于自对弈时回避重复局面。
    /// 仅支持自研引擎级别（novice 走 beginnerMove 逻辑，也返回 top-k）。
    func bestMoves(for board: Board, difficulty: AIDifficulty, isIOS: Bool = false, topK: Int = 3) async -> [(move: Move, score: Int)] {
        calibrationContempt = Self.contemptFor(difficulty)
        leafNoise = difficulty.leafNoiseAmplitude  // v6.5 v2: §3.3 叶噪声设置
        var workBoard = LegacySearchBoard(from: board)

        switch difficulty {
        case .novice:
            return noviceSearchScored(for: &workBoard, isIOS: isIOS, topK: topK) ?? []

        case .beginner:
            return beginnerSearchScored(for: &workBoard, isIOS: isIOS, topK: topK) ?? []

        case .amateurLow:
            return mediumSearchScored(for: &workBoard, isIOS: isIOS, topK: topK) ?? []

        case .amateurMid:
            return hardSearchScored(for: &workBoard, isIOS: isIOS, topK: topK) ?? []

        case .amateurHigh, .amateurDan, .proApprentice, .proExpert, .proMaster, .grandmaster:
            return masterSearchScored(for: &workBoard, isIOS: isIOS, topK: topK) ?? []
        }
    }

    // MARK: - C1 辅助: 带评分的 rootSearch（返回 top-k 候选）

    /// 与 rootSearch 相同逻辑，但返回 top-k 候选走法及评分
    private func rootSearchScored(for board: inout LegacySearchBoard, depth: Int, useTT: Bool, useMoveOrder: Bool,
                                  evalConfig: AIEvalConfig = .basic,
                                  searchConfig: AISearchConfig? = nil,
                                  timeManager: TimeManager? = nil,
                                  topK: Int = 3) -> [(move: Move, score: Int)]? {
        nodeCount = 0
        lastIterationFullySearched = true
        activeTimeManager = timeManager
        searchAborted = false  // T-0926-OC-01：迭代入口复位硬中止旗标
        // P0 归因探针：make/unmake 平衡断言（Debug，位置保真版——计数平衡不足以检出 teleport）
        #if DEBUG
        let histAtEntry = board.moveHistory.count
        let piecesAtEntry = board.pieces.map { "\($0.id):\($0.position.row),\($0.position.col)" }.sorted()
        defer {
            assert(board.moveHistory.count == histAtEntry,
                   "rootSearchScored make/unmake 计数不平衡: 入口\(histAtEntry) 出口\(board.moveHistory.count)")
            let piecesAtExit = board.pieces.map { "\($0.id):\($0.position.row),\($0.position.col)" }.sorted()
            assert(piecesAtExit == piecesAtEntry,
                   "rootSearchScored 位置保真失败——引擎内部 teleport（陈旧候选第一因）：\n入口\(piecesAtEntry)\n出口\(piecesAtExit)")
        }
        #endif

        // P1 fix: 统一 resolve searchConfig，确保 evalConfig（含 contempt）传播到 negamax
        let resolvedConfig = searchConfig ?? {
            var sc = AISearchConfig.default
            sc.evalConfig = evalConfig
            return sc
        }()

        let side = board.currentTurn
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

        let origAlpha = -100_000_000
        var alpha = origAlpha
        let beta = 100_000_000
        var scoredMoves: [(move: Move, score: Int)] = []
        let usePVS = resolvedConfig.enablePVS

        for (moveIndex, move) in orderedMoves.enumerated() {
            if let tm = timeManager, tm.shouldStop {
                lastIterationFullySearched = false  // D2 P0：部分迭代不计入 completedDepth
                break
            }

            let childHash = ZobristHash.update(hash: hash, piece: move.piece,
                                              from: move.from, to: move.to,
                                              captured: move.captured)

            board.execute(move)

            let score: Int
            if usePVS && moveIndex > 0 {
                let nullWindowScore = -negamax(board: &board, depth: depth - 1,
                                               alpha: -alpha - 1, beta: -alpha, hash: childHash,
                                               useTT: useTT, useMoveOrder: useMoveOrder,
                                               searchConfig: resolvedConfig)

                if nullWindowScore > alpha && nullWindowScore < beta {
                    score = -negamax(board: &board, depth: depth - 1,
                                     alpha: -beta, beta: -alpha, hash: childHash,
                                     useTT: useTT, useMoveOrder: useMoveOrder,
                                     searchConfig: resolvedConfig)
                } else {
                    score = nullWindowScore
                }
            } else {
                score = -negamax(board: &board, depth: depth - 1,
                                 alpha: -beta, beta: -alpha, hash: childHash,
                                 useTT: useTT, useMoveOrder: useMoveOrder,
                                 searchConfig: resolvedConfig)
            }
            _ = board.undoLastMove()

            scoredMoves.append((move, score))

            if score > alpha {
                alpha = score
            }
        }

        // 排序并返回 top-k
        scoredMoves.sort { $0.score > $1.score }
        if scoredMoves.isEmpty { return nil }

        // 存 TT（用最佳走法）
        // T-0926-OC-01 Ruby P2：中止迭代不写 TT——快退 0 值/部分分驻留会经 lookup/probe 污染后续搜索
        if useTT && !searchAborted {
            let bestScore = scoredMoves[0].score
            let bestMove = scoredMoves[0].move
            let flag: TranspositionTable.TTFlag = (bestScore <= origAlpha) ? .upper : (bestScore >= beta) ? .lower : .exact
            transpositionTable.store(hash: hash, depth: depth, score: bestScore, flag: flag, bestMove: bestMove)
        }

        return Array(scoredMoves.prefix(topK))
    }

    // MARK: - C1 辅助: 各级别的 scored 变体

    // MARK: - v0.4.2 §Y 五档总表 Scored 变体（T-1001-2 对齐）

    /// lvl1 scored — depth=1, 2000ms, .hard, 无库（T-1001-2：v0.4.2 §Y 分支 Y）
    private func noviceSearchScored(for board: inout LegacySearchBoard, isIOS: Bool, topK: Int) -> [(move: Move, score: Int)]? {
        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let budget = AIDifficulty.novice.s2Spec.budgetMs  // T-1013-OC-03 P3-②：lvl1-a 预算单源化（现值 2000 不变；iOS ×0.6 已撤销 v0.4.2 §6）
        let tm = TimeManager(timeLimitMs: budget, startTime: Date())
        return iterativeDeepeningSearchScored(for: &board, maxDepth: 1, timeManager: tm,
                                               searchConfig: config, topK: topK, depthLogLabel: "lvl1")
    }

    /// lvl2 scored — depth=2, 2000ms, .hard, 无库（T-1001-2：v0.4.2 §Y 分支 Y）
    private func beginnerSearchScored(for board: inout LegacySearchBoard, isIOS: Bool, topK: Int) -> [(move: Move, score: Int)]? {
        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let budget = 2000  // iOS ×0.6 已撤销（v0.4.2 §6，Luke 10-01 12:52 裁）：macOS/iOS 同值
        let tm = TimeManager(timeLimitMs: budget, startTime: Date())
        return iterativeDeepeningSearchScored(for: &board, maxDepth: 2, timeManager: tm,
                                               searchConfig: config, topK: topK, depthLogLabel: "lvl2")
    }

    /// lvl3 scored — depth=2, 2000ms, .hard, 有库（T-1001-2：v0.4.2 §Y 已符合，仅注释对齐）
    private func mediumSearchScored(for board: inout LegacySearchBoard, isIOS: Bool, topK: Int) -> [(move: Move, score: Int)]? {
        if board.moveHistory.count < 8 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return [(move, 0)]
            }
        }

        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let budget = 2000  // iOS ×0.6 已撤销（v0.4.2 §6，Luke 10-01 12:52 裁）：macOS/iOS 同值
        let tm = TimeManager(timeLimitMs: budget, startTime: Date())
        return iterativeDeepeningSearchScored(for: &board, maxDepth: 2, timeManager: tm,
                                               searchConfig: config, topK: topK, depthLogLabel: "lvl3")
    }

    /// lvl4 scored — depth=3, 2000ms, .hard, 有库, kill off（T-1001-2：v0.4.2 §Y 分支 Y）
    private func hardSearchScored(for board: inout LegacySearchBoard, isIOS: Bool, topK: Int) -> [(move: Move, score: Int)]? {
        if board.moveHistory.count < 8 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return [(move, 0)]
            }
        }

        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let budget = 2000  // iOS ×0.6 已撤销（v0.4.2 §6，Luke 10-01 12:52 裁）：macOS/iOS 同值
        let tm = TimeManager(timeLimitMs: budget, startTime: Date())
        return iterativeDeepeningSearchScored(for: &board, maxDepth: 3, timeManager: tm,
                                               searchConfig: config, topK: topK, depthLogLabel: "lvl4")
    }

    /// lvl5 scored — depth=3, 2000ms, .hard, 有库, CheckmateSearch(12, 750ms 显式常量)（T-1001-2：v0.4.2 §Y）
    /// ZD-A' 定案（Luke 08-21 批）：预算可注入——detBudgetMs() 读 env
    /// SELFPLAY_DET_BUDGET_MS，缺省 2000（v0.4.2 §Y 全档统一护栏值）；killTimeLimit=750 显式常量（§3.1 v0.3 解耦）。
    private static func detBudgetMs() -> Int {
        if let raw = ProcessInfo.processInfo.environment["SELFPLAY_DET_BUDGET_MS"], let v = Int(raw), v > 0 {
            return v
        }
        return 2000  // T-1001-2：v0.4.2 §Y 全档统一护栏值（8000→5000→2000）
    }

    private func masterSearchScored(for board: inout LegacySearchBoard, isIOS: Bool, topK: Int) -> [(move: Move, score: Int)]? {
        let side = board.currentTurn

        if board.moveHistory.count < 8 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return [(move, 0)]
            }
        }

        let budget = Self.detBudgetMs()
        let killTimeLimit = 750  // §3.1 v0.3 算术订正：与统一预算解耦的显式常量（原 ×3/20 仅缺省 5000 时=750；iOS 两支同值，×0.6 从未生效）
        if let killMoves = CheckmateSearch.search(board: board, for: side, maxDepth: 12, timeLimitMs: killTimeLimit) {
            // A3r2 根治 A（同 lvl4 注释，memo 见 docs/bugs/A3r2-first-cause-root-cause.md）
            return [killMoves[0]].map { ($0, 0) }
        }

        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let tm = TimeManager(timeLimitMs: budget, startTime: Date())
        return iterativeDeepeningSearchScored(for: &board, maxDepth: 3, timeManager: tm,
                                               searchConfig: config, topK: topK, depthLogLabel: "lvl5")
    }

    /// IDS 的 scored 变体：返回最后一轮迭代的 top-k 候选
    /// - Parameter depthLogLabel: 级别标签（如 "lvl4"），用于 IDS_DEPTH_LOG=1 时的完成深度日志
    private func iterativeDeepeningSearchScored(for board: inout LegacySearchBoard, maxDepth: Int,
                                                  timeManager: TimeManager,
                                                  searchConfig: AISearchConfig,
                                                  topK: Int,
                                                  depthLogLabel: String) -> [(move: Move, score: Int)]? {
        var bestResult: [(move: Move, score: Int)]? = nil
        var tm = timeManager
        var completedDepth = 0

        for depth in min(2, maxDepth)...maxDepth {  // T-1001-2：lvl1 depth=1 通道（其余档 min(2,maxDepth)=2 行为不变）
            if searchConfig.enableSmartTime {
                if depth > 2 && !tm.shouldStartNextIteration { break }
            }
            if tm.shouldStop { break }

            if let result = rootSearchScored(for: &board, depth: depth, useTT: true, useMoveOrder: true,
                                              searchConfig: searchConfig,
                                              timeManager: tm, topK: topK) {
                // ZD-A' 消噪（Luke 08-21 批）：partial 迭代不覆盖已完成的完整迭代结果
                // （截断迭代分随时钟抖动进 softmax = 门未过根因之一；首次无结果仍收下防空返）
                if lastIterationFullySearched || bestResult == nil {
                    bestResult = result
                }
                if lastIterationFullySearched {
                    completedDepth = depth  // D2 P0：部分迭代不进入 completedDepth
                }
            }

            tm.recordIterationComplete()
        }
        logCompletedDepth(label: depthLogLabel, completedDepth: completedDepth,
                          budgetDepth: maxDepth, elapsedMs: tm.elapsedMs)
        return bestResult
    }

    // MARK: - 新手：depth-1 搜索 + top-3 加权随机（v2.1）

    // v4.0 旧方案：depth-1 + ±150cp 噪声 + top-5 加权随机（三重扰动不可控）
    // v2.1 新方案：depth-1 + top-3 加权随机（去掉噪声，更可预测）
    // MARK: - v0.4.2 §Y 五档总表（非 Scored 变体，T-1001-2 对齐）

    /// lvl1 — depth=1, 2000ms, .hard, 无库（T-1001-2：v0.4.2 §Y 分支 Y）
    private func noviceSearch(for board: inout LegacySearchBoard, isIOS: Bool) -> Move? {
        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let budget = AIDifficulty.novice.s2Spec.budgetMs  // T-1013-OC-03 P3-②：lvl1-a 预算单源化（现值 2000 不变；iOS ×0.6 已撤销 v0.4.2 §6）
        let tm = TimeManager(timeLimitMs: budget, startTime: Date())
        return iterativeDeepeningSearch(for: &board, maxDepth: 1, timeManager: tm, searchConfig: config,
                                        depthLogLabel: "lvl1")
    }

    /// lvl2 — depth=2, 2000ms, .hard, 无库（T-1001-2：v0.4.2 §Y 分支 Y）
    private func beginnerSearch(for board: inout LegacySearchBoard, isIOS: Bool) -> Move? {
        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let budget = 2000  // iOS ×0.6 已撤销（v0.4.2 §6，Luke 10-01 12:52 裁）：macOS/iOS 同值
        let tm = TimeManager(timeLimitMs: budget, startTime: Date())
        return iterativeDeepeningSearch(for: &board, maxDepth: 2, timeManager: tm, searchConfig: config,
                                        depthLogLabel: "lvl2")
    }

    // MARK: - Negamax 根搜索（统一接口）

    private func rootSearch(for board: inout LegacySearchBoard, depth: Int, useTT: Bool, useMoveOrder: Bool,
                            evalConfig: AIEvalConfig = .basic,
                            searchConfig: AISearchConfig? = nil,
                            timeManager: TimeManager? = nil) -> Move? {
        // v4.0: 重置节点计数器和时间管理器
        nodeCount = 0
        lastIterationFullySearched = true
        activeTimeManager = timeManager
        searchAborted = false  // T-0926-OC-01：迭代入口复位硬中止旗标

        // P1 fix: 统一 resolve searchConfig，确保 evalConfig（含 contempt）传播到 negamax
        let resolvedConfig = searchConfig ?? {
            var sc = AISearchConfig.default
            sc.evalConfig = evalConfig
            return sc
        }()

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
        let usePVS = resolvedConfig.enablePVS

        for (moveIndex, move) in orderedMoves.enumerated() {
            if let tm = timeManager, tm.shouldStop {
                lastIterationFullySearched = false  // D2 P0
                break
            }

            // #7: 走法执行前增量计算子局面哈希
            let childHash = ZobristHash.update(hash: hash, piece: move.piece,
                                              from: move.from, to: move.to,
                                              captured: move.captured)

            board.execute(move)

            let score: Int
            if usePVS && moveIndex > 0 {
                let nullWindowScore = -negamax(board: &board, depth: depth - 1,
                                               alpha: -alpha - 1, beta: -alpha, hash: childHash,
                                               useTT: useTT, useMoveOrder: useMoveOrder,
                                               searchConfig: resolvedConfig)

                if nullWindowScore > alpha && nullWindowScore < beta {
                    score = -negamax(board: &board, depth: depth - 1,
                                     alpha: -beta, beta: -alpha, hash: childHash,
                                     useTT: useTT, useMoveOrder: useMoveOrder,
                                     searchConfig: resolvedConfig)
                } else {
                    score = nullWindowScore
                }
            } else {
                score = -negamax(board: &board, depth: depth - 1,
                                 alpha: -beta, beta: -alpha, hash: childHash,
                                 useTT: useTT, useMoveOrder: useMoveOrder,
                                 searchConfig: resolvedConfig)
            }
            _ = board.undoLastMove()

            if score > bestScore {
                bestScore = score
                bestMove = move
            }
            alpha = max(alpha, bestScore)
        }

        if useTT && !searchAborted {  // T-0926-OC-01 Ruby P2：中止迭代不写 TT
            let flag: TranspositionTable.TTFlag = (bestScore <= origAlpha) ? .upper : (bestScore >= beta) ? .lower : .exact
            transpositionTable.store(hash: hash, depth: depth, score: bestScore, flag: flag, bestMove: bestMove)
        }

        return bestMove
    }

    // MARK: - 中级（v0.4.2 §Y：lvl3 depth=2, 2000ms, .hard）

    /// lvl3 — depth=2, 2000ms, .hard, 有库（T-1001-2：v0.4.2 §Y 已符合，仅注释对齐）
    private func mediumSearch(for board: inout LegacySearchBoard, isIOS: Bool) -> Move? {
        if board.moveHistory.count < 8 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return move
            }
        }

        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let budget = 2000  // iOS ×0.6 已撤销（v0.4.2 §6，Luke 10-01 12:52 裁）：macOS/iOS 同值
        let tm = TimeManager(timeLimitMs: budget, startTime: Date())
        return iterativeDeepeningSearch(for: &board, maxDepth: 2, timeManager: tm, searchConfig: config,
                                        depthLogLabel: "lvl3")
    }

    // MARK: - 高级（v0.4.2 §Y：lvl4 depth=3, 2000ms, .hard, kill off）

    /// lvl4 — depth=3, 2000ms, .hard, 有库, kill off（T-1001-2：v0.4.2 §Y 分支 Y）
    private func hardSearch(for board: inout LegacySearchBoard, isIOS: Bool) -> Move? {
        if board.moveHistory.count < 8 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return move
            }
        }

        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let budget = 2000  // iOS ×0.6 已撤销（v0.4.2 §6，Luke 10-01 12:52 裁）：macOS/iOS 同值
        let tm = TimeManager(timeLimitMs: budget, startTime: Date())
        return iterativeDeepeningSearch(for: &board, maxDepth: 3, timeManager: tm, searchConfig: config,
                                        depthLogLabel: "lvl4")
    }

    // MARK: - 大师（v0.4.2 §Y：lvl5 depth=3, 2000ms, .hard, kill≤12+750ms 显式常量）

    /// lvl5 — depth=3, 2000ms, .hard, 有库, CheckmateSearch(12, 750ms 显式常量)（T-1001-2：v0.4.2 §Y）
    /// ZD-A' 预算可注入：detBudgetMs() 缺省 2000（v6.5 v2 从 8000 下调；T-1001-2 统一护栏值）
    private func masterSearch(for board: inout LegacySearchBoard, isIOS: Bool) -> Move? {
        let side = board.currentTurn

        if board.moveHistory.count < 8 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return move
            }
        }

        let budget = Self.detBudgetMs()
        let killTimeLimit = 750  // §3.1 v0.3 算术订正：与统一预算解耦的显式常量（原 ×3/20 仅缺省 5000 时=750）
        if let killMoves = CheckmateSearch.search(board: board, for: side, maxDepth: 12, timeLimitMs: killTimeLimit) {
            return killMoves.first
        }

        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let tm = TimeManager(timeLimitMs: budget, startTime: Date())
        return iterativeDeepeningSearch(for: &board, maxDepth: 3, timeManager: tm, searchConfig: config,
                                        depthLogLabel: "lvl5")
    }

    // MARK: - 迭代加深 Negamax

    private func iterativeDeepeningSearch(for board: inout LegacySearchBoard, maxDepth: Int,
                                            timeManager: TimeManager,
                                            searchConfig: AISearchConfig,
                                            depthLogLabel: String) -> Move? {
        var bestMoveSoFar: Move?
        var tm = timeManager
        var completedDepth = 0

        for depth in min(2, maxDepth)...maxDepth {  // T-1001-2：lvl1 depth=1 通道（其余档行为不变）
            if searchConfig.enableSmartTime {
                if depth > 2 && !tm.shouldStartNextIteration { break }
            }
            if tm.shouldStop { break }

            if let move = rootSearch(for: &board, depth: depth, useTT: true, useMoveOrder: true,
                                      searchConfig: searchConfig,
                                      timeManager: tm) {
                bestMoveSoFar = move
                if lastIterationFullySearched {
                    completedDepth = depth  // D2 P0：部分迭代不进入 completedDepth
                }
            }

            tm.recordIterationComplete()
        }
        logCompletedDepth(label: depthLogLabel, completedDepth: completedDepth,
                          budgetDepth: maxDepth, elapsedMs: tm.elapsedMs)
        return bestMoveSoFar
    }

    /// v4.3 §9.5.4: IDS 完成深度日志（校准报告用直方图数据）
    /// 仅在环境变量 IDS_DEPTH_LOG=1 时输出，人机对弈不受影响
    private func logCompletedDepth(label: String, completedDepth: Int, budgetDepth: Int, elapsedMs: Int) {
        guard ProcessInfo.processInfo.environment["IDS_DEPTH_LOG"] == "1" else { return }
        print("[IDS] lvl=\(label) completedDepth=\(completedDepth) budgetDepth=\(budgetDepth) elapsedMs=\(elapsedMs)")
    }

    // MARK: - Negamax + Alpha-Beta 核心

    private func negamax(board: inout LegacySearchBoard, depth: Int, alpha: Int, beta: Int,
                         hash: UInt64,  // #7: 增量哈希参数
                         useTT: Bool, useMoveOrder: Bool, evalConfig: AIEvalConfig = .basic,
                         extensions: Int = 0, searchConfig: AISearchConfig = .default) -> Int {
        // P0 归因探针：make/unmake 平衡断言（Debug）
        let histAtEntry = board.moveHistory.count
        defer { assert(board.moveHistory.count == histAtEntry,
                       "negamax make/unmake 不平衡: depth=\(depth) 入口\(histAtEntry) 出口\(board.moveHistory.count)") }
        // v4.0: 周期性时间检查，防止超时
        // T-0926-OC-01 Phase 0：硬中止两段式——旗标置位后全节点 O(1) 快退（值弃用：
        // 部分迭代经 lastIterationFullySearched=false 通道整体废弃，不消费中止值）
        nodeCount += 1
        if searchAborted { return 0 }
        if nodeCount & (timeCheckInterval - 1) == 0, // 每 64 节点（T-0926-OC-01：注释漂移修正，Ruby P3-1）
           let tm = activeTimeManager, tm.shouldStop {
            searchAborted = true
            return noisyEvaluate(board, config: searchConfig.evalConfig)  // v6.5 v2: 超时叶噪声包装
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
            return noisyEvaluate(board, config: evalCfg)  // v6.5 v2: 叶噪声包装
        }

        if depth <= 0 {
            if searchConfig.enableQuiescence {
                return quiescenceSearch(board: &board, hash: hash,
                                         alpha: alpha, beta: beta,
                                         qDepth: searchConfig.maxQSDepth,
                                         searchConfig: searchConfig)
            } else {
                return noisyEvaluate(board, config: evalCfg)  // v6.5 v2: 叶噪声包装
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
            let cm: Move? = searchConfig.enableCountermove ? moveOrderer.getCountermove(for: board.moveHistory.last) : nil
            moves = moveOrderer.order(moves, on: board, ttBestMove: ttBest, checkLegal: depth >= 3, depth: depth, countermove: cm)
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

        if useTT && !searchAborted {  // T-0926-OC-01 Ruby P2：快退退栈路径不写 TT（0 值垃圾类）
            let flag: TranspositionTable.TTFlag = (bestScore <= origAlpha) ? .upper : (bestScore >= beta) ? .lower : .exact
            transpositionTable.store(hash: hash, depth: depth, score: bestScore, flag: flag, bestMove: bestMove)
        }

        return bestScore
    }

    // MARK: - 静态搜索（Quiescence Search）

    private func quiescenceSearch(
        board: inout LegacySearchBoard,
        hash: UInt64,  // #7: 增量哈希参数
        alpha: Int, beta: Int,
        qDepth: Int,
        searchConfig: AISearchConfig
    ) -> Int {
        // P0 归因探针：make/unmake 平衡断言（Debug）
        let histAtEntry = board.moveHistory.count
        defer { assert(board.moveHistory.count == histAtEntry,
                       "quiescenceSearch make/unmake 不平衡: 入口\(histAtEntry) 出口\(board.moveHistory.count)") }
        // v3.9.1: QS 内部时间检查（防止 master maxQSDepth=6 超时）
        // T-0926-OC-01 Phase 0：与 negamax 同款硬中止两段式（旗标快退）
        nodeCount += 1
        if searchAborted { return 0 }
        if nodeCount & (timeCheckInterval - 1) == 0, let tm = activeTimeManager, tm.shouldStop {
            searchAborted = true
            return noisyEvaluate(board, config: searchConfig.evalConfig)  // v6.5 v2: QS 超时叶噪声包装
        }

        let standPat = noisyEvaluate(board, config: searchConfig.evalConfig)  // v6.5 v2: QS standPat 噪声包装

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

    private func shouldDisableNullMove(on board: LegacySearchBoard, config: AISearchConfig) -> Bool {
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

    private func isTerminal(_ board: LegacySearchBoard) -> Bool {
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
