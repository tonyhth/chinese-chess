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
    /// Phase 1 NPS 遥测（D2 P0）：跨迭代累加（nodeCount 每次根搜索清零，收尾只读末迭代的 bug 修正）
    private var totalNodes: Int = 0
    /// Phase 1 NPS 遥测：QS 节点单独计数（NPS 口径声明用，v1.2 §6.3-3）
    private var qsNodes: Int = 0
    /// Phase 1 NPS 遥测（D2 P0）：末次根搜索是否搜完全部走法（部分迭代不计入 completedDepth）
    private var lastIterationFullySearched: Bool = true
    /// Phase 1 NPS 遥测：末次 IDS 完成深度（--nps-bench 回传用）
    private(set) var lastCompletedDepth: Int = 0
    private var npsLogEnabled: Bool { ProcessInfo.processInfo.environment["NPS_LOG"] == "1" }
    /// v4.0: 搜索中的 TimeManager 引用（negamax 内部检查用）
    private var activeTimeManager: TimeManager? = nil
    /// 每 4096 个节点检查一次时间
    private let timeCheckInterval = 4096

    /// Contempt factor（校准专用）：均势局面下给当前走方的正向偏置
    /// 默认 0（人机对弈不受影响），校准时由 bestMove/bestMoves 根据 difficulty 设置
    private var calibrationContempt: Int = 0

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

    func bestMove(for board: Board, difficulty: AIDifficulty, isIOS: Bool = false) async -> Move? {
        // ⚠️ 唯一的 Board → 后端棋盘转换点（P2c-② 接 USE_SEARCHBOARD_V2 开关）
        calibrationContempt = Self.contemptFor(difficulty)
        var workBoard = resolvedSearchBoard(from: board)
        return bestMoveOn(for: &workBoard, difficulty: difficulty, isIOS: isIOS)
    }

    /// P2c-②：后端选择（m1-hotpath-redesign v1.2 §7.4 回滚开关窗口）。
    /// 优先级：USE_SEARCHBOARD_V2 编译条件 > boardPathOverride 实例注入（P5 双引擎 A/B 用） > Legacy。
    /// 开发期默认 Legacy；P5 验收才切 V2 跑全量对比。一行切回 = 翻编译条件（跑法见 DEVTEAM.md a12f9c0 命令块）。
    #if USE_SEARCHBOARD_V2
    static let useSearchBoardV2 = true
    #else
    static let useSearchBoardV2 = false
    #endif

    /// 实例级后端覆盖（SelfPlayRunner 双引擎实例可各自指定；nil = 跟随编译条件）
    var boardPathOverride: Bool?

    /// actor 隔离 setter（外部/测试注入；直接属性写跨 actor 不合法）
    func setBoardPathOverride(_ value: Bool?) {
        boardPathOverride = value
    }

    /// P4-③ C 项：QS_STANDPAT_FULL 实例级注入（校准配对用，照 boardPathOverride 同款模式）。
    /// M1 回退适配（m1-rollback §2 适配条款）：P4-①② 已随 5817cf9 revert 退场，
    /// qsStandPatFullEval 配置位/三改点分流不存在 → 本注入点保留编译、行为 no-op
    /// （--paired-qs-full 参数链保留，置位无引擎效果）；resolveQSStandPatFull 随面删除。
    var qsStandPatFullOverride: Bool?

    /// actor 隔离 setter（外部/测试注入）
    func setQSStandPatFullOverride(_ value: Bool?) {
        qsStandPatFullOverride = value
    }

    private func resolveBackend() -> Bool {
        boardPathOverride ?? Self.useSearchBoardV2
    }

    /// 后端构造统一口（三个 Board 入口的唯一分派点）
    func resolvedSearchBoard(from board: Board) -> any SearchBoardProtocol {
        // P3 崩溃修复（2026-08-16 夜，两份崩溃报告后）：V2 槽位契约 id∈0..31 比产品
        // Board 实际域窄（存量测试/PGN 加载存在越界 id，36 文件实测）。
        // 入口预检：越界域局面回退 Legacy（与 off 态行为一致），V2 断言保留给
        // 内部构造者（交叉对比/引擎自身生成的局面域必然合法）。
        // Debug 一次性告警防静默；存量数据清偿另单（不 masking：日志可定位）
        if resolveBackend() {
            if Self.v2Eligible(board.pieces) {
                return SearchBoardV2(from: board)
            }
            #if DEBUG
            Self.warnIneligiblePiecesOnce(board.pieces)
            #endif
        }
        return LegacySearchBoard(from: board)
    }

    /// V2 槽位契约预检：id ∈ 0..31 且唯一、位置不双占（与 init 断言同口径）
    private static func v2Eligible(_ pieces: [Piece]) -> Bool {
        var seenIds = Set<Int>()
        var seenSquares = Set<Int>()
        for p in pieces {
            guard (0..<32).contains(p.id), seenIds.insert(p.id).inserted else { return false }
            let sq = p.position.row * 9 + p.position.col
            guard (0..<90).contains(sq), seenSquares.insert(sq).inserted else { return false }
        }
        return true
    }

    #if DEBUG
    private static var ineligibleWarned = false
    private static func warnIneligiblePiecesOnce(_ pieces: [Piece]) {
        guard !ineligibleWarned else { return }
        ineligibleWarned = true
        let bad = pieces.filter { !(0..<32).contains($0.id) }.map { "\($0.id)@\($0.position.row),\($0.position.col)" }
        print("[M1] V2 入口回退 Legacy：局面含越界/冲突 id（首 \(min(bad.count, 5)) 项：\(bad.prefix(5))）——存量数据域宽于 V2 槽位契约，回退非错误")
    }
    #endif

    private func bestMoveOn<B: SearchBoardProtocol>(for board: inout B, difficulty: AIDifficulty, isIOS: Bool) -> Move? {
        switch difficulty {
        case .novice:
            return beginnerMove(for: &board)
        case .beginner:
            // v4: depth=2, 1000ms
            let tm = TimeManager(timeLimitMs: 1000, startTime: Date())
            var evalCfg = AIEvalConfig.basic
            evalCfg.contempt = calibrationContempt
            return rootSearch(for: &board, depth: 2, useTT: true, useMoveOrder: true,
                              evalConfig: evalCfg, timeManager: tm)
        case .amateurLow:
            return mediumSearch(for: &board, isIOS: isIOS)
        case .amateurMid:
            return hardSearch(for: &board, isIOS: isIOS)
        case .amateurHigh:
            return masterSearch(for: &board, isIOS: isIOS)
        case .amateurDan, .proApprentice, .proExpert, .proMaster, .grandmaster:
            // v6.0: 专业级走 EngineRouter → Pikafish，自研引擎不处理
            // Phase 3 EngineRouter 实现后此处永远不会到达
            return masterSearch(for: &board, isIOS: isIOS)
        }
    }

    // MARK: - C1: 返回 top-k 候选走法（用于 anti-repetition 走法选择）

    /// 返回 top-k 候选走法，带评分。用于自对弈时回避重复局面。
    /// 仅支持自研引擎级别（novice 走 beginnerMove 逻辑，也返回 top-k）。
    func bestMoves(for board: Board, difficulty: AIDifficulty, isIOS: Bool = false, topK: Int = 3) async -> [(move: Move, score: Int)] {
        // ⚠️ 唯一的 Board → 后端棋盘转换点（P2c-② 同 bestMove）
        calibrationContempt = Self.contemptFor(difficulty)
        var workBoard = resolvedSearchBoard(from: board)
        return bestMovesOn(for: &workBoard, difficulty: difficulty, isIOS: isIOS, topK: topK)
    }

    private func bestMovesOn<B: SearchBoardProtocol>(for board: inout B, difficulty: AIDifficulty, isIOS: Bool, topK: Int) -> [(move: Move, score: Int)] {
        switch difficulty {
        case .novice:
            // novice 已有 top-3 评分逻辑，直接复用
            let side = board.currentTurn
            let moves = board.legalMoves(for: side)
            guard !moves.isEmpty else { return [] }
            var scoredMoves: [(move: Move, score: Int)] = []
            for move in moves {
                let undo = board.make(move)
                let rawScore = -evaluator.evaluate(board, config: .basic)
                board.unmake(undo)
                scoredMoves.append((move, rawScore))
            }
            scoredMoves.sort { $0.score > $1.score }
            return Array(scoredMoves.prefix(topK))

        case .beginner:
            let tm = TimeManager(timeLimitMs: 1000, startTime: Date())
            var evalCfg = AIEvalConfig.basic
            evalCfg.contempt = calibrationContempt
            return rootSearchScored(for: &board, depth: 2, useTT: true, useMoveOrder: true,
                                    evalConfig: evalCfg, timeManager: tm, topK: topK) ?? []

        case .amateurLow:
            return mediumSearchScored(for: &board, isIOS: isIOS, topK: topK) ?? []

        case .amateurMid:
            return hardSearchScored(for: &board, isIOS: isIOS, topK: topK) ?? []

        case .amateurHigh, .amateurDan, .proApprentice, .proExpert, .proMaster, .grandmaster:
            return masterSearchScored(for: &board, isIOS: isIOS, topK: topK) ?? []
        }
    }

    // MARK: - C1 辅助: 带评分的 rootSearch（返回 top-k 候选）

    /// 与 rootSearch 相同逻辑，但返回 top-k 候选走法及评分
    private func rootSearchScored<B: SearchBoardProtocol>(for board: inout B, depth: Int, useTT: Bool, useMoveOrder: Bool,
                                  evalConfig: AIEvalConfig = .basic,
                                  searchConfig: AISearchConfig? = nil,
                                  timeManager: TimeManager? = nil,
                                  topK: Int = 3) -> [(move: Move, score: Int)]? {
        nodeCount = 0
        qsNodes = 0
        lastIterationFullySearched = true
        activeTimeManager = timeManager
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

        let moves = board.legalMoves(for: side)
        guard !moves.isEmpty else { return nil }

        let orderedMoves: [Move]
        if useMoveOrder {
            let ttBest = useTT ? transpositionTable.probeBestMove(hash: hash) : nil
            orderedMoves = moveOrderer.order(moves, on: board, ttBestMove: ttBest, checkLegal: depth >= 3 && board.supportsCheckLegalOrder, depth: depth)
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

            let undo = board.make(move)

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
            board.unmake(undo)

            scoredMoves.append((move, score))

            if score > alpha {
                alpha = score
            }
        }

        // 排序并返回 top-k
        scoredMoves.sort { $0.score > $1.score }
        if scoredMoves.isEmpty { return nil }

        // 存 TT（用最佳走法）
        if useTT {
            let bestScore = scoredMoves[0].score
            let bestMove = scoredMoves[0].move
            let flag: TranspositionTable.TTFlag = (bestScore <= origAlpha) ? .upper : (bestScore >= beta) ? .lower : .exact
            transpositionTable.store(hash: hash, depth: depth, score: bestScore, flag: flag, bestMove: bestMove)
        }

        return Array(scoredMoves.prefix(topK))
    }

    // MARK: - C1 辅助: 各级别的 scored 变体

    /// v4.3: lvl3 scored — IDS maxDepth=3, 2000ms, .mediumNoQS
    private func mediumSearchScored<B: SearchBoardProtocol>(for board: inout B, isIOS: Bool, topK: Int) -> [(move: Move, score: Int)]? {
        let hash = ZobristHash.hash(board: board)
        if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
           let move = openingBook.parseICCSMove(iccsMove, on: board) {
            return [(move, 0)]
        }

        var config = AISearchConfig.mediumNoQS
        config.evalConfig.contempt = calibrationContempt

        let tm = TimeManager(timeLimitMs: 2000, startTime: Date())
        return iterativeDeepeningSearchScored(for: &board, maxDepth: 3, timeManager: tm,
                                               searchConfig: config, topK: topK, depthLogLabel: "lvl3")
    }

    /// v4.3 v1.2: lvl4 scored — IDS maxDepth=6, 5000ms, .hard, CheckmateSearch(12, 800ms)
    private func hardSearchScored<B: SearchBoardProtocol>(for board: inout B, isIOS: Bool, topK: Int) -> [(move: Move, score: Int)]? {
        let side = board.currentTurn

        if board.moveHistory.count < 6 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return [(move, 0)]
            }
        }

        let killTimeLimit = isIOS ? 600 : 800
        if let killMoves = CheckmateSearch.search(board: board.asLegacyForCheckmate(), for: side, maxDepth: 12, timeLimitMs: killTimeLimit) {
            // A3r2 根治 A（docs/bugs/A3r2-first-cause-root-cause.md）：只返回杀法序列第一步。
            // 旧实现 prefix(topK) 返回 m2/m3 未来着法，softmaxSelect 过滤循环对它们
            // execute/undo → 棋子 id 盲搬漂移 → 棋盘腐败（A3-r2 OVERLAP 7 条现场）。
            // 连将杀每步重新命中 CheckmateSearch，行为等价、语义正确。
// 边界声明（Ruby 快审 P2a）：dfs 的 maxResponses=8 截断下，多应着局面可能
            // 假杀——此时走 m1 后对方实际应着解杀 → 下轮不再命中 → 正常搜索 fallback。
            // 即"每步重新命中"严格说是"命中或正常搜索"的良性退化，非完备杀保证。
                        return [killMoves[0]].map { ($0, 0) }
        }

        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let tm = TimeManager(timeLimitMs: 5000, startTime: Date())
        return iterativeDeepeningSearchScored(for: &board, maxDepth: 6, timeManager: tm,
                                               searchConfig: config, topK: topK, depthLogLabel: "lvl4")
    }

    /// v4.3 v1.2: lvl5 scored — IDS maxDepth=7, 8000ms, .hard, CheckmateSearch(maxDepth=12, 1200ms)
    /// ZD-A' 定案（Luke 08-21 批）：预算可注入——detBudgetMs() 读 env
    /// SELFPLAY_DET_BUDGET_MS，缺省 8000（产品零变化）；killTimeLimit 同源缩放。
    /// 门/校准跑超大预算即消墙钟抖动（CheckmateSearch 与 IDS 两截断点同治）。
    private static func detBudgetMs() -> Int {
        if let raw = ProcessInfo.processInfo.environment["SELFPLAY_DET_BUDGET_MS"], let v = Int(raw), v > 0 {
            return v
        }
        return 8000
    }

    private func masterSearchScored<B: SearchBoardProtocol>(for board: inout B, isIOS: Bool, topK: Int) -> [(move: Move, score: Int)]? {
        let side = board.currentTurn

        if board.moveHistory.count < 6 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookup(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return [(move, 0)]
            }
        }

        let budget = Self.detBudgetMs()
        let killTimeLimit = isIOS ? budget / 10 : budget * 3 / 20   // 缺省 8000 → 800 / 1200（原值不变）
        if let killMoves = CheckmateSearch.search(board: board.asLegacyForCheckmate(), for: side, maxDepth: 12, timeLimitMs: killTimeLimit) {
            // A3r2 根治 A（同 lvl4 注释，memo 见 docs/bugs/A3r2-first-cause-root-cause.md）
            return [killMoves[0]].map { ($0, 0) }
        }

        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let tm = TimeManager(timeLimitMs: budget, startTime: Date())
        return iterativeDeepeningSearchScored(for: &board, maxDepth: 7, timeManager: tm,
                                               searchConfig: config, topK: topK, depthLogLabel: "lvl5")
    }

    /// IDS 的 scored 变体：返回最后一轮迭代的 top-k 候选
    /// - Parameter depthLogLabel: 级别标签（如 "lvl4"），用于 IDS_DEPTH_LOG=1 时的完成深度日志
    private func iterativeDeepeningSearchScored<B: SearchBoardProtocol>(for board: inout B, maxDepth: Int,
                                                  timeManager: TimeManager,
                                                  searchConfig: AISearchConfig,
                                                  topK: Int,
                                                  depthLogLabel: String) -> [(move: Move, score: Int)]? {
        var bestResult: [(move: Move, score: Int)]? = nil
        var tm = timeManager
        var completedDepth = 0
        totalNodes = 0
        let npsStart = ProcessInfo.processInfo.systemUptime

        for depth in 2...maxDepth {
            if searchConfig.enableSmartTime {
                if depth > 2 && !tm.shouldStartNextIteration { break }
            }
            if tm.shouldStop { break }

            let iterStart = ProcessInfo.processInfo.systemUptime
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
            totalNodes += nodeCount  // D2 P0：跨迭代累加
            if npsLogEnabled {
                let iterElapsed = Int((ProcessInfo.processInfo.systemUptime - iterStart) * 1000)
                let iterNps = iterElapsed > 0 ? nodeCount * 1000 / iterElapsed : 0
                print("[NPS] lvl=\(depthLogLabel) depth=\(depth) iterNodes=\(nodeCount) qsNodes=\(qsNodes) iterMs=\(iterElapsed) iterNps=\(iterNps) fullySearched=\(lastIterationFullySearched)")
            }

            tm.recordIterationComplete()
        }
        lastCompletedDepth = completedDepth
        logCompletedDepth(label: depthLogLabel, completedDepth: completedDepth,
                          budgetDepth: maxDepth, elapsedMs: tm.elapsedMs)
        if npsLogEnabled {
            let totalElapsed = Int((ProcessInfo.processInfo.systemUptime - npsStart) * 1000)
            let avgNps = totalElapsed > 0 ? totalNodes * 1000 / totalElapsed : 0
            print("[NPS] lvl=\(depthLogLabel) totalNodes=\(totalNodes) totalMs=\(totalElapsed) avgNps=\(avgNps)")
        }
        return bestResult
    }

    // MARK: - Phase 1: NPS 基线测量入口（--nps-bench 专用）

    /// 直连 IDS，绕过开局库/CheckmateSearch（v1.2 §6 + D2 P1-2：窗口 = TimeManager elapsedMs）。
    /// 返回 (totalNodes, elapsedMs, completedDepth)；单局面 120s 熔断（v1.2 P2-6）。
    /// 温度随机关闭（固定取 top-1），纯搜索压力测量。
    func npsBench(board: Board, maxDepth: Int) -> (totalNodes: Int, elapsedMs: Int, completedDepth: Int)? {
        calibrationContempt = 0
        var workBoard = resolvedSearchBoard(from: board)
        return npsBenchOn(for: &workBoard, maxDepth: maxDepth)
    }

    private func npsBenchOn<B: SearchBoardProtocol>(for board: inout B, maxDepth: Int) -> (totalNodes: Int, elapsedMs: Int, completedDepth: Int)? {
        var config = AISearchConfig.hard
        config.evalConfig.contempt = 0
        let tm = TimeManager(timeLimitMs: 120_000, startTime: Date())
        guard iterativeDeepeningSearchScored(for: &board, maxDepth: maxDepth, timeManager: tm,
                                             searchConfig: config, topK: 1,
                                             depthLogLabel: "nps-bench") != nil else { return nil }
        return (totalNodes, tm.elapsedMs, lastCompletedDepth)
    }

    // MARK: - 新手：depth-1 搜索 + top-3 加权随机（v2.1）

    // v4.0 旧方案：depth-1 + ±150cp 噪声 + top-5 加权随机（三重扰动不可控）
    // v2.1 新方案：depth-1 + top-3 加权随机（去掉噪声，更可预测）
    private func beginnerMove<B: SearchBoardProtocol>(for board: inout B) -> Move? {
        let side = board.currentTurn
        let moves = board.legalMoves(for: side)
        guard !moves.isEmpty else { return nil }

        // 对每个走法做 depth-1 评估（无噪声）
        var scoredMoves: [(move: Move, score: Int)] = []
        for move in moves {
            let undo = board.make(move)
            let rawScore = -evaluator.evaluate(board, config: .basic)
            board.unmake(undo)
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
        var r = SeededRandom.int(in: 0..<totalWeight)  // Phase 1 seed 注入点③
        for (i, w) in weights.enumerated() {
            r -= w
            if r < 0 { return candidates[i].move }
        }
        return candidates.last!.move
    }

    // MARK: - Negamax 根搜索（统一接口）

    private func rootSearch<B: SearchBoardProtocol>(for board: inout B, depth: Int, useTT: Bool, useMoveOrder: Bool,
                            evalConfig: AIEvalConfig = .basic,
                            searchConfig: AISearchConfig? = nil,
                            timeManager: TimeManager? = nil) -> Move? {
        // v4.0: 重置节点计数器和时间管理器
        nodeCount = 0
        qsNodes = 0
        lastIterationFullySearched = true
        activeTimeManager = timeManager

        // P1 fix: 统一 resolve searchConfig，确保 evalConfig（含 contempt）传播到 negamax
        let resolvedConfig = searchConfig ?? {
            var sc = AISearchConfig.default
            sc.evalConfig = evalConfig
            return sc
        }()

        let side = board.currentTurn
        // #7: 入口处计算初始哈希（全量，只算一次）
        let hash = ZobristHash.hash(board: board)

        let moves = board.legalMoves(for: side)
        guard !moves.isEmpty else { return nil }

        let orderedMoves: [Move]
        if useMoveOrder {
            let ttBest = useTT ? transpositionTable.probeBestMove(hash: hash) : nil
            orderedMoves = moveOrderer.order(moves, on: board, ttBestMove: ttBest, checkLegal: depth >= 3 && board.supportsCheckLegalOrder, depth: depth)
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

            let undo = board.make(move)

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
            board.unmake(undo)

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

    /// v4.3: lvl3 — IDS maxDepth=3, 2000ms, .mediumNoQS config
    private func mediumSearch<B: SearchBoardProtocol>(for board: inout B, isIOS: Bool) -> Move? {
        let hash = ZobristHash.hash(board: board)
        if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
           let move = openingBook.parseICCSMove(iccsMove, on: board) {
            return move
        }

        var config = AISearchConfig.mediumNoQS
        config.evalConfig.contempt = calibrationContempt

        let tm = TimeManager(timeLimitMs: 2000, startTime: Date())
        return iterativeDeepeningSearch(for: &board, maxDepth: 3, timeManager: tm, searchConfig: config,
                                        depthLogLabel: "lvl3")
    }

    // MARK: - 高级

    /// v4.3 v1.2: lvl4 — IDS maxDepth=6, 5000ms, .hard config, CheckmateSearch(12, 800ms)
    private func hardSearch<B: SearchBoardProtocol>(for board: inout B, isIOS: Bool) -> Move? {
        let side = board.currentTurn

        if board.moveHistory.count < 6 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookupWeightedRandom(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return move
            }
        }

        let killTimeLimit = isIOS ? 600 : 800
        if let killMoves = CheckmateSearch.search(board: board.asLegacyForCheckmate(), for: side, maxDepth: 12, timeLimitMs: killTimeLimit) {
            return killMoves.first
        }

        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let tm = TimeManager(timeLimitMs: 5000, startTime: Date())
        return iterativeDeepeningSearch(for: &board, maxDepth: 6, timeManager: tm, searchConfig: config,
                                        depthLogLabel: "lvl4")
    }

    // MARK: - 大师

    /// v4.3 v1.2: lvl5 — IDS maxDepth=7, 8000ms, .hard config, CheckmateSearch(maxDepth=12, 1200ms)
    private func masterSearch<B: SearchBoardProtocol>(for board: inout B, isIOS: Bool) -> Move? {
        let side = board.currentTurn

        if board.moveHistory.count < 6 {
            let hash = ZobristHash.hash(board: board)
            if let iccsMove = openingBook.lookup(zobristHash: hash),
               let move = openingBook.parseICCSMove(iccsMove, on: board) {
                return move
            }
        }

        let killTimeLimit = isIOS ? 800 : 1200
        if let killMoves = CheckmateSearch.search(board: board.asLegacyForCheckmate(), for: side, maxDepth: 12, timeLimitMs: killTimeLimit) {
            return killMoves.first
        }

        var config = AISearchConfig.hard
        config.evalConfig.contempt = calibrationContempt

        let tm = TimeManager(timeLimitMs: 8000, startTime: Date())
        return iterativeDeepeningSearch(for: &board, maxDepth: 7, timeManager: tm, searchConfig: config,
                                        depthLogLabel: "lvl5")
    }

    // MARK: - 迭代加深 Negamax

    private func iterativeDeepeningSearch<B: SearchBoardProtocol>(for board: inout B, maxDepth: Int,
                                            timeManager: TimeManager,
                                            searchConfig: AISearchConfig,
                                            depthLogLabel: String) -> Move? {
        var bestMoveSoFar: Move?
        var tm = timeManager
        var completedDepth = 0
        totalNodes = 0
        let npsStart = ProcessInfo.processInfo.systemUptime

        for depth in 2...maxDepth {
            if searchConfig.enableSmartTime {
                if depth > 2 && !tm.shouldStartNextIteration { break }
            }
            if tm.shouldStop { break }

            let iterStart = ProcessInfo.processInfo.systemUptime
            if let move = rootSearch(for: &board, depth: depth, useTT: true, useMoveOrder: true,
                                      searchConfig: searchConfig,
                                      timeManager: tm) {
                bestMoveSoFar = move
                if lastIterationFullySearched {
                    completedDepth = depth  // D2 P0：部分迭代不进入 completedDepth
                }
            }
            totalNodes += nodeCount  // D2 P0：跨迭代累加
            if npsLogEnabled {
                let iterElapsed = Int((ProcessInfo.processInfo.systemUptime - iterStart) * 1000)
                let iterNps = iterElapsed > 0 ? nodeCount * 1000 / iterElapsed : 0
                print("[NPS] lvl=\(depthLogLabel) depth=\(depth) iterNodes=\(nodeCount) qsNodes=\(qsNodes) iterMs=\(iterElapsed) iterNps=\(iterNps) fullySearched=\(lastIterationFullySearched)")
            }

            tm.recordIterationComplete()
        }
        lastCompletedDepth = completedDepth
        logCompletedDepth(label: depthLogLabel, completedDepth: completedDepth,
                          budgetDepth: maxDepth, elapsedMs: tm.elapsedMs)
        if npsLogEnabled {
            let totalElapsed = Int((ProcessInfo.processInfo.systemUptime - npsStart) * 1000)
            let avgNps = totalElapsed > 0 ? totalNodes * 1000 / totalElapsed : 0
            print("[NPS] lvl=\(depthLogLabel) totalNodes=\(totalNodes) totalMs=\(totalElapsed) avgNps=\(avgNps)")
        }
        return bestMoveSoFar
    }

    /// v4.3 §9.5.4: IDS 完成深度日志（校准报告用直方图数据）
    /// 仅在环境变量 IDS_DEPTH_LOG=1 时输出，人机对弈不受影响
    private func logCompletedDepth(label: String, completedDepth: Int, budgetDepth: Int, elapsedMs: Int) {
        guard ProcessInfo.processInfo.environment["IDS_DEPTH_LOG"] == "1" else { return }
        print("[IDS] lvl=\(label) completedDepth=\(completedDepth) budgetDepth=\(budgetDepth) elapsedMs=\(elapsedMs)")
    }

    // MARK: - Negamax + Alpha-Beta 核心

    private func negamax<B: SearchBoardProtocol>(board: inout B, depth: Int, alpha: Int, beta: Int,
                         hash: UInt64,  // #7: 增量哈希参数
                         useTT: Bool, useMoveOrder: Bool, evalConfig: AIEvalConfig = .basic,
                         extensions: Int = 0, searchConfig: AISearchConfig = .default) -> Int {
        // P0 归因探针：make/unmake 平衡断言（Debug）
        let histAtEntry = board.moveHistory.count
        defer { assert(board.moveHistory.count == histAtEntry,
                       "negamax make/unmake 不平衡: depth=\(depth) 入口\(histAtEntry) 出口\(board.moveHistory.count)") }
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
        if searchConfig.enableRazoring && depth <= 2 && !board.inCheck(side) {
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

        // P3-②（phase3.md v1.2 甲定案）：isTerminal 预检删除，终局判定并入循环 legalCount==0
        // （消 legalMoves 双跑：预检一遍 + 循环前一遍）。
        // 已知差异三条（§3 定稿块，设计接受）：depth≤0 终局走 QS / depth≥3 困毙节点
        // NMP 可能 fail-high / mate 分永不产生（维持 v6.1.0 起 live 事实）。

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
            && !board.inCheck(board.currentTurn)
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

        // P3-②（phase3.md §3.2）：伪合法单遍化——每候选 make 一次同时供
        // 送将检测+子搜索（Legacy preFiltered 集免检，行为不变）。
        // legalCount==0 → 甲定案：static eval（live 语义维持，零 TT 写；
        // 与被删的 :760 isTerminal 预检返回等价——Vera §3 死分支考古：
        // 原 :804-811 mate+TT 分支 v6.1.0 起不可达，本改造行为不变声明）。
        var moves = board.pseudoMoves(for: side)
        var legalCount = 0

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
            let cmKey: Int? = searchConfig.enableCountermove ? moveOrderer.getCountermoveKey(for: board.moveHistory.last) : nil
            moves = moveOrderer.order(moves, on: board, ttBestMove: ttBest, checkLegal: depth >= 3 && board.supportsCheckLegalOrder, depth: depth, countermoveKey: cmKey)
        } else if depth >= 2 {
            moves = orderMovesSimple(moves)
        }

        let origAlpha = alpha
        var bestScore = -100_000_000
        var bestMove: Move? = nil
        var a = alpha

        let selfInCheck = board.inCheck(board.currentTurn)

        // Futility Pruning 预计算
        let futilityEnabled = searchConfig.enableFutility
            && depth <= 3 && depth >= 1 && !selfInCheck
        let futilityMargin = futilityEnabled ? (depth == 1 ? 300 : depth == 2 ? 500 : 900) : 0
        let staticEvalForFutility: Int? = futilityEnabled ? evaluator.evaluate(board, config: evalCfg) : nil

        for (moveIndex, move) in moves.enumerated() {
            // Futility Pruning（P3-② 首着保护：legalCount==0 时不 prune——
            // 杀棋局面首着必试，legalCount 语义保真；现状全跳时返 -1e8 哨兵，
            // 新版首着必试是更保守方向，正常路径行为不变）
            if futilityEnabled
                && legalCount > 0
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

            let undo = board.make(move)

            // P3-②：单遍送将过滤（仅未预滤集）：make 后自将 → unmake 跳过。
            // 与搜索 make 同一次（A-1 收益核心：消过滤与搜索的重复 make）。
            if !board.moveSetPreFiltered && board.inCheck(side) {
                board.unmake(undo)
                continue
            }
            legalCount += 1

            let givesCheck = board.inCheck(board.currentTurn)
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
            board.unmake(undo)

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

        // P3-② 甲定案（phase3.md v1.2 §3）：legalCount==0 = 杀棋/困毙 →
        // static eval 维持 live 语义（零 TT 写，与被删 isTerminal 预检返回等价；
        // 原 mate+TT 分支 v6.1.0 起不可达——Vera 死分支考古，行为不变声明）
        if legalCount == 0 {
            return evaluator.evaluate(board, config: evalCfg)
        }

        if useTT {
            let flag: TranspositionTable.TTFlag = (bestScore <= origAlpha) ? .upper : (bestScore >= beta) ? .lower : .exact
            transpositionTable.store(hash: hash, depth: depth, score: bestScore, flag: flag, bestMove: bestMove)
        }

        return bestScore
    }

    // MARK: - 静态搜索（Quiescence Search）

    private func quiescenceSearch<B: SearchBoardProtocol>(
        board: inout B,
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
        nodeCount += 1
        qsNodes += 1  // Phase 1 NPS 口径：QS 节点单独计数（v1.2 §6.3-3）
        if nodeCount & (timeCheckInterval - 1) == 0, let tm = activeTimeManager, tm.shouldStop {
            return evaluator.evaluate(board, config: searchConfig.evalConfig)
        }

        let standPat = evaluator.evaluate(board, config: searchConfig.evalConfig)

        if standPat >= beta { return beta }
        var alpha = alpha
        if alpha < standPat { alpha = standPat }
        if qDepth <= 0 { return standPat }

        let side = board.currentTurn
        let qMoves = board.captureCandidates(for: side)
        let orderedQMoves = orderCapturesMVV_LVA(qMoves)

        for move in orderedQMoves {
            if let captured = move.captured {
                if standPat + captured.baseValue + 200 < alpha { continue }
            }

            // #7: 增量计算子局面哈希
            let childHash = ZobristHash.update(hash: hash, piece: move.piece,
                                              from: move.from, to: move.to,
                                              captured: move.captured)

            let undo = board.make(move)
            // P3-③（phase3.md §3.3 QS 行，两态同改 ungated）：吃子送将跳过。
            // v1.2 §3.4 定调：QS 本就不该走送将着法，属修正非回退。
            if board.inCheck(side) {
                board.unmake(undo)
                continue
            }
            let score = -quiescenceSearch(board: &board, hash: childHash,
                                           alpha: -beta, beta: -alpha,
                                           qDepth: qDepth - 1, searchConfig: searchConfig)
            board.unmake(undo)

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

    private func shouldDisableNullMove<B: SearchBoardProtocol>(on board: B, config: AISearchConfig) -> Bool {
        let side = board.currentTurn
        // P3-0（v1.2 §2.4 三层防线②）：NMP 守门子力和走后端快路径
        // （V2 = 槽位扫描 nonGuardMaterial :290；Legacy = pieces(for:) 循环同语义，零行为变化）
        let materialSum = board.nonGuardMaterial(side)
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
