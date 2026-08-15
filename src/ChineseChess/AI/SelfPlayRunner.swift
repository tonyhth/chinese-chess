import Foundation

// MARK: - 自对弈结果

struct SelfPlayGameResult {
    let gameIndex: Int
    let redDifficulty: AIDifficulty
    let blackDifficulty: AIDifficulty
    let result: GameState
    let totalMoves: Int
    let reason: GameEndReason
    let moveHistory: [String]  // ICCS 格式走法列表
}

enum GameEndReason: String {
    case normal         // 正常结束（将死/困毙）
    case moveLimit      // 达到步数上限
    case repetition     // 重复局面
    case stalemate      // 无棋可走（困毙）
}

// MARK: - 耗时统计（排除休眠）

/// 双时钟计时器：墙钟（wall clock，含休眠）+ 纯计算时钟（systemUptime，macOS 休眠期间暂停计时）
struct ElapsedClock {
    let wallStart = Date()
    let uptimeStart = ProcessInfo.processInfo.systemUptime

    /// 纯计算耗时（秒，不含休眠）
    var computeSeconds: Double { ProcessInfo.processInfo.systemUptime - uptimeStart }
    /// 墙钟耗时（秒，含休眠）
    var wallSeconds: Double { Date().timeIntervalSince(wallStart) }
}

struct SelfPlaySessionResult {
    let config: SelfPlayConfig
    let games: [SelfPlayGameResult]
    let redWins: Int
    let blackWins: Int
    let draws: Int
    let avgMoves: Double
    let durationSeconds: Double
    /// 墙钟耗时（含休眠）；durationSeconds 为纯计算耗时（systemUptime，排除休眠）
    var wallDurationSeconds: Double = 0

    var summary: String {
        let total = games.count
        return """
        自对弈结果：\(config.redDifficulty.rawValue) vs \(config.blackDifficulty.rawValue)（\(total) 局）
        红胜：\(redWins)（\(String(format: "%.1f%%", Double(redWins) / Double(total) * 100))）
        黑胜：\(blackWins)（\(String(format: "%.1f%%", Double(blackWins) / Double(total) * 100))）
        和棋：\(draws)（\(String(format: "%.1f%%", Double(draws) / Double(total) * 100))）
        平均步数：\(String(format: "%.1f", avgMoves))
        纯计算耗时：\(String(format: "%.1f", durationSeconds))s（排除休眠）
        墙钟耗时：\(String(format: "%.1f", wallDurationSeconds))s
        """
    }
}

// MARK: - 自对弈配置

struct SelfPlayConfig {
    var redDifficulty: AIDifficulty
    var blackDifficulty: AIDifficulty
    var totalGames: Int
    var maxMovesPerGame: Int = 200
    var repetitionThreshold: Int = 6  // T1: 3→6，减少虚假和棋
    var swapSides: Bool = true        // 交换先后手

    init(red: AIDifficulty, black: AIDifficulty, games: Int,
         maxMoves: Int = 200, swapSides: Bool = true) {
        self.redDifficulty = red
        self.blackDifficulty = black
        self.totalGames = games
        self.maxMovesPerGame = maxMoves
        self.swapSides = swapSides
    }
}

// MARK: - 自对弈运行器

/// 引擎 vs 引擎自动对弈框架
/// 用于 Elo 基线测量和评估函数校准
/// v3.1 Phase 1b: 支持权重注入（CMA-ES 并行评估）
final class SelfPlayRunner {

    private let engine: AIEngine

    /// 原有初始化器（兼容现有代码）
    init() {
        self.engine = AIEngine()
    }

    /// CMA-ES 并行评估专用初始化器（注入权重）
    init(weights: EvalWeights) {
        self.engine = AIEngine(weights: weights)
    }

    // 统计
    private var redWins = 0
    private var blackWins = 0
    private var draws = 0
    private var totalMoves = 0
    private var gameResults: [SelfPlayGameResult] = []

    func run(config: SelfPlayConfig, progressCallback: ((Int, SelfPlayGameResult) -> Void)? = nil) async -> SelfPlaySessionResult {
        let clock = ElapsedClock()

        for gameIndex in 0..<config.totalGames {
            // 交换先后手：偶数局红=redDifficulty，奇数局交换
            let actualRed: AIDifficulty
            let actualBlack: AIDifficulty
            if config.swapSides && gameIndex % 2 == 1 {
                actualRed = config.blackDifficulty
                actualBlack = config.redDifficulty
            } else {
                actualRed = config.redDifficulty
                actualBlack = config.blackDifficulty
            }

            let result = await playGame(
                gameIndex: gameIndex,
                redDifficulty: actualRed,
                blackDifficulty: actualBlack,
                maxMoves: config.maxMovesPerGame,
                repetitionThreshold: config.repetitionThreshold
            )

            gameResults.append(result)
            totalMoves += result.totalMoves

            switch result.result {
            case .redWon: redWins += 1
            case .blackWon: blackWins += 1
            case .draw: draws += 1
            default: break
            }

            progressCallback?(gameIndex + 1, result)

            // 每局之间清空引擎状态
            await engine.clearHistory()
        }

        let elapsed = clock.computeSeconds
        let avg = Double(totalMoves) / Double(config.totalGames)

        return SelfPlaySessionResult(
            config: config,
            games: gameResults,
            redWins: redWins,
            blackWins: blackWins,
            draws: draws,
            avgMoves: avg,
            durationSeconds: elapsed,
            wallDurationSeconds: clock.wallSeconds
        )
    }

    // MARK: - 单局对弈

    /// 生成走法的 ICCS 表示（列字母 + 行数字）
    private static func iccsNotation(for move: Move) -> String {
        let cols = ["a","b","c","d","e","f","g","h","i"]
        let fromCol = cols[move.from.col]
        let toCol = cols[move.to.col]
        return "\(fromCol)\(move.from.row)\(toCol)\(move.to.row)"
    }

    /// v4.3 v1.2: 按难度级别返回 Softmax temperature（cp）
    /// lvl2=30, lvl3=40, lvl4=35, lvl5=25（lvl3 随机峰值，lvl3→lvl5 递减：强方更确定）
    private static func softmaxTemperature(for difficulty: AIDifficulty) -> Double {
        switch difficulty {
        case .beginner:      return 30  // lvl2
        case .amateurLow:    return 40  // lvl3：回退到 v4.2 值，削弱只靠 maxDepth
        case .amateurMid:    return 35  // lvl4：更确定 → 更强
        case .amateurHigh:   return 25  // lvl5：最确定 → 最强（v1.2 恢复递减段，9.7.3）
        default:             return 40  // fallback
        }
    }

    /// C1+Softmax: 先过滤重复候选，再对剩余候选做 Softmax 加权随机选择
    /// - Parameters:
    ///   - candidates: top-k 候选走法（带评分）
    ///   - board: 当前棋盘（方法内部会 execute/undoLastMove 来检查 FEN）
    ///   - fenCounts: FEN 出现次数字典
    ///   - temperature: Softmax 温度（cp），默认 40
    /// - Returns: 选中的走法
    private static func softmaxSelect(
        candidates: [(move: Move, score: Int)],
        on board: Board,
        fenCounts: [String: Int],
        temperature: Double = 40.0
    ) -> Move {
        guard !candidates.isEmpty else {
            fatalError("softmaxSelect called with empty candidates")
        }

        // 1. 过滤掉导致重复的候选（C1 回避逻辑）
        // A3r2 根治 B（docs/bugs/A3r2-first-cause-root-cause.md）：前置一致性校验——
        // 陈旧候选（from/captured 与棋盘实际不符，如杀法序列未来着法）不 execute，
        // 从根切断 id 盲搬漂移；防一切未来来源的陈旧候选，与 A（治本）双保险。
        let nonRepeating = candidates.filter { candidate in
            guard candidate.move.piece.position == candidate.move.from,
                  board.piece(at: candidate.move.from)?.id == candidate.move.piece.id,
                  candidate.move.captured?.id == board.piece(at: candidate.move.to)?.id
            else { return false }  // 陈旧候选：跳过，不 execute（不漂移）
            board.execute(candidate.move)
            let fen = FENParser.generate(board: board)
            _ = board.undoLastMove()
            return fenCounts[fen, default: 0] == 0
        }

        // 2. 对剩余候选做 Softmax 加权随机
        let pool = nonRepeating.isEmpty ? candidates : nonRepeating

        if pool.count == 1 { return pool[0].move }

        let maxScore = pool[0].score  // bestMoves 已按分降序
        let expScores = pool.map { exp(Double($0.score - maxScore) / temperature) }
        let totalExp = expScores.reduce(0, +)

        let r = Double.random(in: 0..<totalExp)
        var cumulative = 0.0
        for (i, e) in expScores.enumerated() {
            cumulative += e
            if r < cumulative {
                return pool[i].move
            }
        }
        return pool[0].move  // fallback
    }

    // MARK: - P0 遥测：playGame 边界检查点（A3 EXIT:132 根治）

    /// 执行前检查：move 快照 vs 棋盘实际状态（Release 生效，检出 dump 后继续）
    /// - C1: move.piece 是否仍在 from 且 id/类型/方一致（过期快照检查）
    /// - C2: move.captured 与棋盘 to 位实际棋子一致性（captured 生成缺陷检查）
    /// - C3: 执行前棋盘完整性（重叠/重复 ID 检查）
    private static func preExecuteCheckpoint(_ board: Board, move: Move, gameIndex: Int, ply: Int) {
        var problems: [String] = []

        // C0: 外部突变探针——board 历史长度/走子方/boardId（与 playGame 本地状态交叉验证）
        let boardTurn = board.currentTurn == .red ? "red" : "black"
        let moverTurn = move.piece.side == .red ? "red" : "black"
        if boardTurn != moverTurn {
            problems.append("C0 board.currentTurn=\(boardTurn) 但行棋方=\(moverTurn)")
        }

        // C1: 过期快照检查
        if let actual = board.piece(at: move.from) {
            if actual.id != move.piece.id {
                problems.append("C1 move.piece(id=\(move.piece.id) \(move.piece.kind)) 在 from(\(move.from.row),\(move.from.col)) 实际是 id=\(actual.id) \(actual.kind) —— 过期快照")
            }
        } else {
            problems.append("C1 from(\(move.from.row),\(move.from.col)) 无棋子，但 move.piece=id\(move.piece.id) \(move.piece.kind)")
        }

        // C2: captured 快照一致性
        let target = board.piece(at: move.to)
        if move.captured?.id != target?.id {
            problems.append("C2 move.captured=\(move.captured.map { "id=\($0.id) \($0.kind)" } ?? "nil") != 棋盘 to 位=\(target.map { "id=\($0.id) \($0.kind)" } ?? "nil")")
        }

        // C3: 执行前完整性
        problems.append(contentsOf: Board.integrityProblems(in: board.pieces).map { "C3 \($0)" })

        guard !problems.isEmpty else { return }
        let extra = " [probe histCount=\(board.moveHistory.count) localPlyLabel=\(ply + 1) boardId=\(ObjectIdentifier(board).hashValue)]"
        BoardIntegrityLogger.dumpOverlap(
            reason: "playGame_preExecute game#\(gameIndex + 1) ply#\(ply + 1)",
            pieces: board.pieces,
            recentMoves: Array(board.moveHistory.suffix(10)),
            detail: problems.joined(separator: " | ") + extra)
    }

    /// 执行后检查：棋盘完整性 + 历史长度同步（Release 生效，检出 dump 后继续）
    private static func postExecuteCheckpoint(_ board: Board, move: Move, gameIndex: Int, ply: Int) {
        var problems = Board.integrityProblems(in: board.pieces)
        // C0-post：board 历史长度应等于 ply+1（playGame 与 board 同步追加）
        if board.moveHistory.count != ply + 1 {
            problems.append("C0-post board.moveHistory.count=\(board.moveHistory.count) ≠ 预期 \(ply + 1)——外部 make/unmake 篡改历史")
        }
        guard !problems.isEmpty else { return }
        BoardIntegrityLogger.dumpOverlap(
            reason: "playGame_postExecute game#\(gameIndex + 1) ply#\(ply + 1)",
            pieces: board.pieces,
            recentMoves: Array(board.moveHistory.suffix(10)),
            detail: "执行 move=id\(move.piece.id) \(move.piece.kind) (\(move.from.row),\(move.from.col))→(\(move.to.row),\(move.to.col)) 后: \(problems.joined(separator: " | "))")
    }

    private func playGame(
        gameIndex: Int,
        redDifficulty: AIDifficulty,
        blackDifficulty: AIDifficulty,
        maxMoves: Int,
        repetitionThreshold: Int
    ) async -> SelfPlayGameResult {
        let board = Board()  // 标准初始局面
        var moveHistory: [String] = []
        var fenCounts: [String: Int] = [:]
        var endReason: GameEndReason = .normal

        let isIOS = false  // 自对弈在 macOS 运行

        while moveHistory.count < maxMoves {
            let currentSide = board.currentTurn
            let difficulty = (currentSide == .red) ? redDifficulty : blackDifficulty

            // P0 遥测：更新运行上下文（防御点 dump 需要知道当前 lvl/局号/ply）
            BoardIntegrityLogger.currentContext = "selfplay red=\(redDifficulty.rawValue) black=\(blackDifficulty.rawValue) game#\(gameIndex + 1) ply#\(moveHistory.count + 1) turn=\(difficulty.rawValue)"

            // C1: 取 top-3 候选走法，回避重复局面
            let candidates = await engine.bestMoves(for: board, difficulty: difficulty, isIOS: isIOS, topK: 3)
            guard !candidates.isEmpty else {
                // 无合法走法：区分将死和困毙
                let isCheckmate = MoveValidator.isInCheck(board.currentTurn, on: board)
                endReason = isCheckmate ? .normal : .stalemate
                let winner: GameState = (currentSide == .red) ? .blackWon : .redWon
                return SelfPlayGameResult(
                    gameIndex: gameIndex,
                    redDifficulty: redDifficulty,
                    blackDifficulty: blackDifficulty,
                    result: winner,
                    totalMoves: moveHistory.count,
                    reason: endReason,
                    moveHistory: moveHistory
                )
            }

            // C1+Softmax: 先过滤重复候选，再 Softmax 加权随机选择
            let temp = Self.softmaxTemperature(for: difficulty)
            let move = Self.softmaxSelect(candidates: candidates, on: board, fenCounts: fenCounts, temperature: temp)

            // P0 遥测：边界检查点（检出异常 dump 后继续，不阻塞对弈）
            Self.preExecuteCheckpoint(board, move: move, gameIndex: gameIndex, ply: moveHistory.count)
            board.execute(move)
            Self.postExecuteCheckpoint(board, move: move, gameIndex: gameIndex, ply: moveHistory.count)
            let iccs = Self.iccsNotation(for: move)
            moveHistory.append(iccs)

            // 记录 FEN 出现次数（不含走子方信息，用完整 FEN）
            let fen = FENParser.generate(board: board)
            fenCounts[fen, default: 0] += 1

            // 重复局面检测
            if fenCounts[fen]! >= repetitionThreshold {
                endReason = .repetition
                return SelfPlayGameResult(
                    gameIndex: gameIndex,
                    redDifficulty: redDifficulty,
                    blackDifficulty: blackDifficulty,
                    result: .draw,
                    totalMoves: moveHistory.count,
                    reason: endReason,
                    moveHistory: moveHistory
                )
            }

            // 检查终局
            if board.generalPosition(of: .red) == nil {
                return SelfPlayGameResult(
                    gameIndex: gameIndex,
                    redDifficulty: redDifficulty,
                    blackDifficulty: blackDifficulty,
                    result: .blackWon,
                    totalMoves: moveHistory.count,
                    reason: .normal,
                    moveHistory: moveHistory
                )
            }
            if board.generalPosition(of: .black) == nil {
                return SelfPlayGameResult(
                    gameIndex: gameIndex,
                    redDifficulty: redDifficulty,
                    blackDifficulty: blackDifficulty,
                    result: .redWon,
                    totalMoves: moveHistory.count,
                    reason: .normal,
                    moveHistory: moveHistory
                )
            }
        }

        // 达到步数上限，判和
        endReason = .moveLimit
        return SelfPlayGameResult(
            gameIndex: gameIndex,
            redDifficulty: redDifficulty,
            blackDifficulty: blackDifficulty,
            result: .draw,
            totalMoves: moveHistory.count,
            reason: endReason,
            moveHistory: moveHistory
        )
    }
}

// MARK: - v6.0 Phase 6: 混合引擎对弈结果

struct MixedEngineGameResult {
    let gameIndex: Int
    let result: GameState
    let totalMoves: Int
    let reason: GameEndReason
    let moveHistory: [String]  // UCI 格式
    let redEngineName: String
    let blackEngineName: String
}

struct MixedEngineSessionResult {
    let games: [MixedEngineGameResult]
    let redWins: Int
    let blackWins: Int
    let draws: Int
    let avgMoves: Double
    let durationSeconds: Double
    /// 墙钟耗时（含休眠）；durationSeconds 为纯计算耗时（systemUptime，排除休眠）
    var wallDurationSeconds: Double = 0
    let bayesEloDelta: Int
    // 校准 v3.0: 终局分类统计
    let checkmateCount: Int      // .normal reason（将死/将帅被吃）
    let stalemateCount: Int      // 困毙 (.stalemate)
    let repetitionCount: Int     // 重复和棋 (.repetition)
    let moveLimitCount: Int      // 步数上限 (.moveLimit)
    let redWinRate: Double       // 先手胜率

    var summary: String {
        let total = games.count
        guard total > 0 else {
            return "混合引擎对弈结果（0 局）\n无数据"
        }
        let pct: (Int) -> String = { count in
            String(format: "%.1f%%", Double(count) / Double(total) * 100)
        }
        return """
        混合引擎对弈结果（\(total) 局）
        红胜：\(redWins)（\(pct(redWins))）
        黑胜：\(blackWins)（\(pct(blackWins))）
        和棋：\(draws)（\(pct(draws))）
        平均步数：\(String(format: "%.1f", avgMoves))
        BayesElo 差值：\(bayesEloDelta >= 0 ? "+" : "")\(bayesEloDelta)
        纯计算耗时：\(String(format: "%.1f", durationSeconds))s（排除休眠）
        墙钟耗时：\(String(format: "%.1f", wallDurationSeconds))s

        终局分布：
          将死(normal)：\(checkmateCount) 局（\(pct(checkmateCount))）
          困毙(stalemate)：\(stalemateCount) 局（\(pct(stalemateCount))）
          重复(repetition)：\(repetitionCount) 局（\(pct(repetitionCount))）
          步数上限(moveLimit)：\(moveLimitCount) 局（\(pct(moveLimitCount))）
        先手优势：红方胜率 \(String(format: "%.1f%%", redWinRate * 100))（Elo ±\(abs(bayesEloDelta))）
        """
    }
}

// MARK: - v6.0 Phase 6: 混合引擎对弈配置

struct MixedEngineConfig {
    var totalGames: Int
    var maxMovesPerGame: Int = 200
    var moveTimeMs: Int = 500       // 每步固定时限（确保公平）
    var repetitionThreshold: Int = 6  // T1: 3→6，减少虚假和棋
    var swapSides: Bool = true

    init(games: Int, maxMoves: Int = 200, moveTimeMs: Int = 500, swapSides: Bool = true) {
        self.totalGames = games
        self.maxMovesPerGame = maxMoves
        self.moveTimeMs = moveTimeMs
        self.swapSides = swapSides
    }
}

// MARK: - 命令行报告生成

extension SelfPlayRunner {
    /// 从难度 rawValue 提取级别号（"lvl3" → "3"；旧值如 "beginner" → nil）
    static func levelNumber(_ rawValue: String) -> String? {
        guard rawValue.hasPrefix("lvl") else { return nil }
        let suffix = String(rawValue.dropFirst(3))
        return Int(suffix).map { _ in suffix }
    }

    /// 逐局即时落盘走法序列（--save-moves / --calibrate-native 共用）
    /// 崩溃时已完成的局不丢失（旧版 --calibrate-native 跑完全部后统一写，
    /// 第 11 局崩溃 = 前 10 局全部丢失，A3 重跑 15 局零落盘的根因）
    static func writeMoveHistory(_ game: SelfPlayGameResult, to dir: String, groupLabel: String) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let filename = "\(groupLabel)_game\(game.gameIndex + 1)_\(game.redDifficulty.rawValue)vs\(game.blackDifficulty.rawValue)_\(game.totalMoves).txt"
        let content = game.moveHistory.joined(separator: "\n")
        try? content.write(toFile: "\(dir)/\(filename)", atomically: true, encoding: .utf8)
    }

    /// 运行自对弈并生成报告字符串
    func runAndReport(config: SelfPlayConfig, label: String, progressCallback: ((Int, SelfPlayGameResult) -> Void)? = nil) async -> String {
        let result = await run(config: config, progressCallback: progressCallback)

        let eloDelta = BayesElo.estimateDelta(
            wins: result.redWins,
            losses: result.blackWins,
            draws: result.draws
        )

        var report = result.summary + "\n\n"
        report += "BayesElo 估值：\(eloDelta >= 0 ? "+" : "")\(eloDelta)\n"
        report += "\n逐局结果：\n"
        for game in result.games {
            let winnerStr: String
            switch game.result {
            case .redWon: winnerStr = "红胜"
            case .blackWon: winnerStr = "黑胜"
            case .draw: winnerStr = "和棋"
            default: winnerStr = "未知"
            }
            report += "  第\(game.gameIndex + 1)局：\(winnerStr)（\(game.totalMoves)步, \(game.reason.rawValue)）\n"
        }

        return report
    }
}

// MARK: - v6.0 Phase 6: 混合引擎对弈扩展

extension SelfPlayRunner {

    /// 混合引擎交叉对弈：自研引擎（amateurHigh）vs Pikafish（指定 Skill Level）
    /// 引擎 A（自研）执红，引擎 B（Pikafish）执黑，交换先后手
    func runMixedEngineMatch(
        config: MixedEngineConfig,
        nativeDifficulty: AIDifficulty = .amateurHigh,
        pikafishDifficulty: AIDifficulty = .amateurDan,
        pikafishSkillOverride: Int? = nil,
        progressCallback: ((Int, MixedEngineGameResult) -> Void)? = nil
    ) async -> MixedEngineSessionResult {
        let clock = ElapsedClock()
        var games: [MixedEngineGameResult] = []
        var redWins = 0
        var blackWins = 0
        var draws = 0
        var nativeWins = 0     // v6.0 P1 fix: 按引擎维度统计
        var pikafishWins = 0
        var totalMoves = 0

        // 确保 Pikafish 引擎可用
        let pikafishEngine = EmbeddedPikafishEngine()
        do {
            try await pikafishEngine.start()
        } catch {
            NSLog("[MixedEngine] Pikafish failed to start: \(error)")
            return MixedEngineSessionResult(
                games: [], redWins: 0, blackWins: 0, draws: 0,
                avgMoves: 0, durationSeconds: 0, bayesEloDelta: 0,
                checkmateCount: 0, stalemateCount: 0, repetitionCount: 0,
                moveLimitCount: 0, redWinRate: 0
            )
        }

        // 应用 Skill override
        if let skill = pikafishSkillOverride {
            await pikafishEngine.setSkillLevel(skill)
        }

        let nativeName = "Native(\(nativeDifficulty.rawValue))"
        let pfSkillDesc = pikafishSkillOverride.map { "s\($0)" } ?? pikafishDifficulty.rawValue
        let pikafishName = "Pikafish(\(pfSkillDesc))"

        for gameIndex in 0..<config.totalGames {
            // 交换先后手
            let nativeIsRed: Bool
            if config.swapSides && gameIndex % 2 == 1 {
                nativeIsRed = false
            } else {
                nativeIsRed = true
            }

            let result = await playMixedGame(
                gameIndex: gameIndex,
                nativeDifficulty: nativeDifficulty,
                pikafishDifficulty: pikafishDifficulty,
                nativeIsRed: nativeIsRed,
                maxMoves: config.maxMovesPerGame,
                moveTimeMs: config.moveTimeMs,
                repetitionThreshold: config.repetitionThreshold,
                pikafishEngine: pikafishEngine,
                pikafishSkillOverride: pikafishSkillOverride
            )

            games.append(MixedEngineGameResult(
                gameIndex: gameIndex,
                result: result.result,
                totalMoves: result.totalMoves,
                reason: result.reason,
                moveHistory: result.moveHistory,
                redEngineName: nativeIsRed ? nativeName : pikafishName,
                blackEngineName: nativeIsRed ? pikafishName : nativeName
            ))

            totalMoves += result.totalMoves
            switch result.result {
            case .redWon:
                redWins += 1
                if nativeIsRed { nativeWins += 1 } else { pikafishWins += 1 }
            case .blackWon:
                blackWins += 1
                if nativeIsRed { pikafishWins += 1 } else { nativeWins += 1 }
            case .draw:
                draws += 1
            default: break
            }

            progressCallback?(gameIndex + 1, games.last!)

            // 每局之间清空状态
            await engine.clearHistory()
            await pikafishEngine.newGame()
        }

        await pikafishEngine.shutdown()

        let elapsed = clock.computeSeconds
        let avg = config.totalGames > 0 ? Double(totalMoves) / Double(config.totalGames) : 0
        // v6.0 P1 fix: 按引擎维度（native vs pikafish）算 Elo，不是红黑维度
        let eloDelta = BayesElo.estimateDelta(wins: nativeWins, losses: pikafishWins, draws: draws)

        // 校准 v3.0: 终局分类统计
        let checkmateCount = games.filter { $0.reason == .normal }.count
        let stalemateCount = games.filter { $0.reason == .stalemate }.count
        let repetitionCount = games.filter { $0.reason == .repetition }.count
        let moveLimitCount = games.filter { $0.reason == .moveLimit }.count
        let redWinRate = games.count > 0 ? Double(redWins) / Double(games.count) : 0

        return MixedEngineSessionResult(
            games: games,
            redWins: redWins,
            blackWins: blackWins,
            draws: draws,
            avgMoves: avg,
            durationSeconds: elapsed,
            wallDurationSeconds: clock.wallSeconds,
            bayesEloDelta: eloDelta,
            checkmateCount: checkmateCount,
            stalemateCount: stalemateCount,
            repetitionCount: repetitionCount,
            moveLimitCount: moveLimitCount,
            redWinRate: redWinRate
        )
    }

    // MARK: - 混合引擎单局

    private func playMixedGame(
        gameIndex: Int,
        nativeDifficulty: AIDifficulty,
        pikafishDifficulty: AIDifficulty,
        nativeIsRed: Bool,
        maxMoves: Int,
        moveTimeMs: Int,
        repetitionThreshold: Int,
        pikafishEngine: EmbeddedPikafishEngine,
        pikafishSkillOverride: Int? = nil
    ) async -> (result: GameState, totalMoves: Int, reason: GameEndReason, moveHistory: [String]) {
        let board = Board()
        var moveHistory: [String] = []
        var fenCounts: [String: Int] = [:]
        var endReason: GameEndReason = .normal

        while moveHistory.count < maxMoves {
            let currentSide = board.currentTurn
            let isNativeTurn = (currentSide == .red) == nativeIsRed

            if isNativeTurn {
                // C1: 取 top-3 候选走法，回避重复局面
                let candidates = await engine.bestMoves(for: board, difficulty: nativeDifficulty, isIOS: false, topK: 3)
                guard !candidates.isEmpty else {
                    let isCheckmate = MoveValidator.isInCheck(board.currentTurn, on: board)
                    endReason = isCheckmate ? .normal : .stalemate
                    let winner: GameState = (board.currentTurn == .red) ? .blackWon : .redWon
                    return (winner, moveHistory.count, endReason, moveHistory)
                }

                // C1+Softmax: 先过滤重复候选，再 Softmax 加权随机选择
                let temp = Self.softmaxTemperature(for: nativeDifficulty)
                let move = Self.softmaxSelect(candidates: candidates, on: board, fenCounts: fenCounts, temperature: temp)

                let iccs = SelfPlayRunner.iccsNotation(for: move)
                moveHistory.append(iccs)
                board.execute(move)
            } else {
                // Pikafish 走棋
                // v2.1: 使用 .amateurLow（skillLevel 返回 nil），避免 bestMove 内部覆盖外部 override
                // 同时 depth=10（比 .amateurHigh depth=24 快很多），校准变量更干净
                if let skillOverride = pikafishSkillOverride {
                    await pikafishEngine.setSkillLevel(skillOverride)
                }
                let fen = FENParser.generate(board: board)
                // 构造 UCI move history（ICCS 格式兼容）
                let pfDifficulty: AIDifficulty = pikafishSkillOverride != nil ? .amateurLow : pikafishDifficulty
                let result = await pikafishEngine.bestMove(
                    fen: fen,
                    moveHistory: [],
                    difficulty: pfDifficulty,
                    timeLimitMs: moveTimeMs
                )
                guard let move = result,
                      let parsed = UCIMoveConverter.move(from: move, on: board) else {
                    let isCheckmate = MoveValidator.isInCheck(board.currentTurn, on: board)
                    endReason = isCheckmate ? .normal : .stalemate
                    let winner: GameState = (board.currentTurn == .red) ? .blackWon : .redWon
                    return (winner, moveHistory.count, endReason, moveHistory)
                }
                let iccs = ICCSParser.iccsString(from: parsed.from, to: parsed.to)
                moveHistory.append(iccs)
                board.execute(parsed)
            }

            // 重复局面检测
            let fen = FENParser.generate(board: board)
            fenCounts[fen, default: 0] += 1
            if fenCounts[fen]! >= repetitionThreshold {
                endReason = .repetition
                return (.draw, moveHistory.count, endReason, moveHistory)
            }

            // 检查终局
            if board.generalPosition(of: .red) == nil {
                return (.blackWon, moveHistory.count, .normal, moveHistory)
            }
            if board.generalPosition(of: .black) == nil {
                return (.redWon, moveHistory.count, .normal, moveHistory)
            }
        }

        endReason = .moveLimit
        return (.draw, moveHistory.count, endReason, moveHistory)
    }

    // MARK: - 校准报告

    /// 运行交叉对弈并生成校准报告
    func runCalibration(
        nativeDifficulty: AIDifficulty = .amateurHigh,
        pikafishDifficulty: AIDifficulty = .amateurDan,
        pikafishSkillOverride: Int? = nil,
        games: Int = 10,
        moveTimeMs: Int = 1000,
        maxMoves: Int = 500
    ) async -> String {
        let config = MixedEngineConfig(games: games, maxMoves: maxMoves, moveTimeMs: moveTimeMs)

        let pfSkillDesc = pikafishSkillOverride.map { " (Skill \($0) override)" } ?? ""
        print("═══════════════════════════════════════════")
        print("  交叉对弈校准")
        print("  \(nativeDifficulty.rawValue) vs \(pikafishDifficulty.rawValue)\(pfSkillDesc)（\(games) 局）")
        print("═══════════════════════════════════════════")
        print("")

        let result = await runMixedEngineMatch(
            config: config,
            nativeDifficulty: nativeDifficulty,
            pikafishDifficulty: pikafishDifficulty,
            pikafishSkillOverride: pikafishSkillOverride
        ) { completed, gameResult in
            let winnerStr: String
            switch gameResult.result {
            case .redWon: winnerStr = "红胜"
            case .blackWon: winnerStr = "黑胜"
            case .draw: winnerStr = "和棋"
            default: winnerStr = "未知"
            }
            print("  [\(completed)/\(games)] \(winnerStr) (\(gameResult.totalMoves)步, \(gameResult.reason.rawValue)) [红:\(gameResult.redEngineName) 黑:\(gameResult.blackEngineName)]")
        }

        var report = result.summary + "\n\n"

        // 校准结论
        let eloDelta = result.bayesEloDelta
        report += "── 校准结论 ──\n"
        let absDelta = abs(eloDelta)
        if absDelta < 100 {
            report += "Elo 差 |\(eloDelta)| < 100 → 梯度过小，建议 6 级上调到 Skill 7\n"
        } else if absDelta >= 200 && absDelta <= 400 {
            report += "Elo 差 |\(eloDelta)| 在 200-400 → ✅ 合理过渡，确认当前 Skill Level\n"
        } else if absDelta > 500 {
            report += "Elo 差 |\(eloDelta)| > 500 → 跨度过大，建议 6 级下调到 Skill 3\n"
        } else {
            report += "Elo 差 |\(eloDelta)| 在 100-200 → 过渡合理（接近边界）\n"
        }

        report += "\n逐局结果：\n"
        for game in result.games {
            let winnerStr: String
            switch game.result {
            case .redWon: winnerStr = "红胜"
            case .blackWon: winnerStr = "黑胜"
            case .draw: winnerStr = "和棋"
            default: winnerStr = "未知"
            }
            report += "  第\(game.gameIndex + 1)局：\(winnerStr)（\(game.totalMoves)步, \(game.reason.rawValue)）[红:\(game.redEngineName) 黑:\(game.blackEngineName)]\n"
        }

        print("")
        print(report)

        // 保存报告
        let fm = FileManager.default
        let outputDir = "calibration-results"
        try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let outputPath = "\(outputDir)/calibration_\(nativeDifficulty.rawValue)_vs_\(pikafishDifficulty.rawValue)_\(timestamp).txt"
        try? report.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("报告已保存：\(outputPath)")

        return report
    }

    // MARK: - v6.0: 纯 Pikafish 自对弈（Skill Level 梯度验证）

    /// Skill Level → AIDifficulty 映射辅助
    /// 将任意 Skill 值 (0-20) 映射到最近的 AIDifficulty 枚举占位
    /// 实际 Skill 由 skillOverride 控制
    static func skillToDifficulty(_ skill: Int) -> AIDifficulty {
        // 专业级枚举有 skillLevel，选最近的
        let mapping: [(AIDifficulty, Int)] = [
            (.amateurDan, 0),
            (.proApprentice, 4),
            (.proExpert, 7),
            (.proMaster, 10),
            (.grandmaster, 20),
        ]
        return mapping.min(by: { abs($0.1 - skill) < abs($1.1 - skill) })?.0 ?? .amateurDan
    }

    /// 纯 Pikafish 自对弈：红方 Skill A vs 黑方 Skill B
    /// 单实例 Pikafish，每步前通过 difficulty 设置当前方的 Skill Level
    func runPikafishSelfPlay(
        redDifficulty: AIDifficulty,
        blackDifficulty: AIDifficulty,
        games: Int,
        maxMoves: Int = 80,
        moveTimeMs: Int = 500,
        redSkillOverride: Int? = nil,
        blackSkillOverride: Int? = nil,
        progressCallback: ((Int, MixedEngineGameResult) -> Void)? = nil
    ) async -> MixedEngineSessionResult {
        let clock = ElapsedClock()
        var gameResults: [MixedEngineGameResult] = []
        var redWins = 0, blackWins = 0, draws = 0, totalMoves = 0
        var redSkillWins = 0, blackSkillWins = 0

        let engine = EmbeddedPikafishEngine()
        do {
            try await engine.start()
        } catch {
            print("❌ Pikafish failed to start: \(error)")
            return MixedEngineSessionResult(
                games: [], redWins: 0, blackWins: 0, draws: 0,
                avgMoves: 0, durationSeconds: 0, bayesEloDelta: 0,
                checkmateCount: 0, stalemateCount: 0, repetitionCount: 0,
                moveLimitCount: 0, redWinRate: 0
            )
        }

        let redSkill = redSkillOverride ?? redDifficulty.skillLevel ?? 0
        let blackSkill = blackSkillOverride ?? blackDifficulty.skillLevel ?? 0
        let redName = "Skill\(redSkill)"
        let blackName = "Skill\(blackSkill)"

        for gameIndex in 0..<games {
            let actualRed: AIDifficulty
            let actualBlack: AIDifficulty
            // 交换先后手
            if gameIndex % 2 == 1 {
                actualRed = blackDifficulty
                actualBlack = redDifficulty
            } else {
                actualRed = redDifficulty
                actualBlack = blackDifficulty
            }

            let result = await playPikafishSelfPlayGame(
                gameIndex: gameIndex,
                redDifficulty: actualRed,
                blackDifficulty: actualBlack,
                maxMoves: maxMoves,
                moveTimeMs: moveTimeMs,
                engine: engine,
                redSkillOverride: redSkillOverride,
                blackSkillOverride: blackSkillOverride
            )

            let redIsRedSkill = (gameIndex % 2 == 0)
            gameResults.append(MixedEngineGameResult(
                gameIndex: gameIndex,
                result: result.result,
                totalMoves: result.totalMoves,
                reason: result.reason,
                moveHistory: result.moveHistory,
                redEngineName: redIsRedSkill ? redName : blackName,
                blackEngineName: redIsRedSkill ? blackName : redName
            ))

            totalMoves += result.totalMoves
            switch result.result {
            case .redWon:
                redWins += 1
                if redIsRedSkill { redSkillWins += 1 } else { blackSkillWins += 1 }
            case .blackWon:
                blackWins += 1
                if !redIsRedSkill { redSkillWins += 1 } else { blackSkillWins += 1 }
            case .draw:
                draws += 1
            default: break
            }

            progressCallback?(gameIndex + 1, gameResults.last!)
            await engine.newGame()
        }

        await engine.shutdown()

        let elapsed = clock.computeSeconds
        let wallElapsed = clock.wallSeconds
        let avg = games > 0 ? Double(totalMoves) / Double(games) : 0
        let eloDelta = BayesElo.estimateDelta(wins: redSkillWins, losses: blackSkillWins, draws: draws)

        print("")
        print("═══ 纯 Pikafish 自对弈结果 ═══")
        print("  \(redName) vs \(blackName)（\(games) 局）")
        print("  \(redName) 胜：\(redSkillWins)")
        print("  \(blackName) 胜：\(blackSkillWins)")
        print("  和棋：\(draws)")
        print("  BayesElo 差值：\(eloDelta >= 0 ? "+" : "")\(eloDelta)")
        print("  平均步数：\(String(format: "%.1f", avg))")
        print("  纯计算耗时：\(String(format: "%.1f", elapsed))s（排除休眠）")
        print("  墙钟耗时：\(String(format: "%.1f", wallElapsed))s")

        // 校准 v3.0: 终局分类统计
        let checkmateCount = gameResults.filter { $0.reason == .normal }.count
        let stalemateCount = gameResults.filter { $0.reason == .stalemate }.count
        let repetitionCount = gameResults.filter { $0.reason == .repetition }.count
        let moveLimitCount = gameResults.filter { $0.reason == .moveLimit }.count
        let redWinRate = gameResults.count > 0 ? Double(redWins) / Double(gameResults.count) : 0

        return MixedEngineSessionResult(
            games: gameResults, redWins: redWins, blackWins: blackWins,
            draws: draws, avgMoves: avg, durationSeconds: elapsed,
            wallDurationSeconds: wallElapsed, bayesEloDelta: eloDelta,
            checkmateCount: checkmateCount, stalemateCount: stalemateCount,
            repetitionCount: repetitionCount, moveLimitCount: moveLimitCount,
            redWinRate: redWinRate
        )
    }

    /// 纯 Pikafish 单局
    private func playPikafishSelfPlayGame(
        gameIndex: Int,
        redDifficulty: AIDifficulty,
        blackDifficulty: AIDifficulty,
        maxMoves: Int,
        moveTimeMs: Int,
        engine: EmbeddedPikafishEngine,
        redSkillOverride: Int? = nil,
        blackSkillOverride: Int? = nil,
        repetitionThreshold: Int = 6  // T1: 默认 6，统一阈值
    ) async -> (result: GameState, totalMoves: Int, reason: GameEndReason, moveHistory: [String]) {
        let board = Board()
        var moveHistory: [String] = []
        var fenCounts: [String: Int] = [:]
        var endReason: GameEndReason = .normal

        while moveHistory.count < maxMoves {
            let currentSide = board.currentTurn
            let baseDifficulty = (currentSide == .red) ? redDifficulty : blackDifficulty
            let skillOverride = (currentSide == .red) ? redSkillOverride : blackSkillOverride

            // 校准 v3.0: 如果有 skillOverride，手动设置 Skill Level
            // bestMove 内部检测 lastSkillOverride != nil 时自动强制 depth=0
            // ⚠️ 必须传 skillLevel=nil 的 difficulty（如 .amateurLow），否则 bestMove 内部
            // 会用 difficulty.skillLevel 覆盖我们手动设的 Skill Level（P0 fix）
            if let skill = skillOverride {
                await engine.setSkillLevel(skill)
            }
            let difficulty: AIDifficulty = skillOverride != nil ? .amateurLow : baseDifficulty

            let fen = FENParser.generate(board: board)
            let result = await engine.bestMove(
                fen: fen,
                moveHistory: [],
                difficulty: difficulty,
                timeLimitMs: moveTimeMs
            )

            guard let uciMove = result,
                  let move = UCIMoveConverter.move(from: uciMove, on: board) else {
                // 区分将死（被将军且无解）和困毙（无棋可走但未被将军）
                let isCheckmate = MoveValidator.isInCheck(board.currentTurn, on: board)
                endReason = isCheckmate ? .normal : .stalemate
                let winner: GameState = (board.currentTurn == .red) ? .blackWon : .redWon
                return (winner, moveHistory.count, endReason, moveHistory)
            }

            let iccs = SelfPlayRunner.iccsNotation(for: move)
            moveHistory.append(iccs)
            board.execute(move)

            let fen2 = FENParser.generate(board: board)
            fenCounts[fen2, default: 0] += 1
            if fenCounts[fen2]! >= repetitionThreshold {
                endReason = .repetition
                return (.draw, moveHistory.count, endReason, moveHistory)
            }

            if board.generalPosition(of: .red) == nil {
                return (.blackWon, moveHistory.count, .normal, moveHistory)
            }
            if board.generalPosition(of: .black) == nil {
                return (.redWon, moveHistory.count, .normal, moveHistory)
            }
        }

        endReason = .moveLimit
        return (.draw, moveHistory.count, endReason, moveHistory)
    }
}

// MARK: - BayesElo 估值

/// 简化版 BayesElo 估值
/// 基于胜率计算 Elo 差值（不涉及完整贝叶斯模型，用于快速估算）
enum BayesElo {
    /// 根据胜率计算 Elo 差值
    /// - Parameter winRate: 胜率（0-1），和棋算 0.5
    /// - Returns: Elo 差值（正值表示领先）
    static func estimateDelta(winRate: Double) -> Int {
        // 标准 Elo 公式：E = 1 / (1 + 10^(-Δ/400))
        // 反推：Δ = -400 * log10(1/E - 1)
        let clamped = max(0.01, min(0.99, winRate))
        let delta = -400.0 * log10(1.0 / clamped - 1.0)
        return Int(delta.rounded())
    }

    /// 根据胜负平统计计算 Elo 差值
    static func estimateDelta(wins: Int, losses: Int, draws: Int) -> Int {
        let total = wins + losses + draws
        guard total > 0 else { return 0 }
        let score = Double(wins) + Double(draws) * 0.5
        let winRate = score / Double(total)
        return estimateDelta(winRate: winRate)
    }
}

// MARK: - v6.0 Phase 6: 交叉对弈校准 CLI 入口

#if os(macOS)
func runCalibrateFromCLI() async {
    // v6.0: 禁用 stdout 缓冲，确保 CLI 模式下 print 立即输出
    setvbuf(stdout, nil, _IONBF, 0)

    let args = CommandLine.arguments
    let games = args.count > 2 ? (Int(args[2]) ?? 10) : 10
    let maxMoves = args.count > 3 ? (Int(args[3]) ?? 500) : 500  // 默认 500 步上限（让对局自然结束）

    // NNUE 路径排查日志
    let bundlePath = Bundle.main.bundlePath
    let execPath = CommandLine.arguments[0]
    let execDir = (execPath as NSString).deletingLastPathComponent
    NSLog("[Calibrate] Bundle.main.bundlePath: \(bundlePath)")
    NSLog("[Calibrate] Executable path: \(execPath)")
    NSLog("[Calibrate] Exec dir: \(execDir)")

    // 尝试在可执行文件目录附近查找 NNUE
    let possiblePaths = [
        "\(execDir)/pikafish.nnue",
        "\(execDir)/Contents/Resources/pikafish.nnue",  // .app bundle
        "\(execDir)/../Resources/pikafish.nnue",
        "\(execDir)/../SharedSupport/pikafish.nnue",
    ]
    var nnueFound = false
    for path in possiblePaths {
        if FileManager.default.fileExists(atPath: path) {
            NSLog("[Calibrate] Found NNUE at: \(path)")
            nnueFound = true
            break
        }
    }

    if !nnueFound {
        // 尝试 Bundle.main 资源
        if let nnueURL = Bundle.main.url(forResource: "pikafish", withExtension: "nnue") {
            NSLog("[Calibrate] Found NNUE via Bundle.main: \(nnueURL.path)")
            nnueFound = true
        } else {
            print("❌ pikafish.nnue not found in any location")
            print("   Searched: \(possiblePaths.joined(separator: ", "))")
            print("   Bundle.main path: \(bundlePath)")
            return
        }
    }

    print("═══════════════════════════════════════════")
    print("  交叉对弈校准（\(games) 局，最多 \(maxMoves) 步/局）")
    print("═══════════════════════════════════════════")
    print("")

    // 支持自定义难度: --calibrate <games> <maxMoves> [nativeLvl] [pikafishLvl]
    // 默认: native=4(lvl4/amateurMid), pikafish=6(lvl6/amateurDan=Skill0)
    // 特殊: pikafishLvl=0 表示 Skill 0（用 novice/lvl1 映射到 Skill 0）
    let nativeLvl = args.count > 4 ? (Int(args[4]) ?? 4) : 4  // 默认 4 级
    let pikafishLvl = args.count > 5 ? (Int(args[5]) ?? 6) : 6  // 默认 6 级
    let nativeDiff = AIDifficulty(rawValue: "lvl\(nativeLvl)") ?? .amateurMid
    // pikafishLvl 直接就是 Skill Level (0-20)
    let skillLevel = pikafishLvl
    // 用 lvl6 作为 enum 占位（EngineRouter 需要 isProfessional=true），实际 Skill 由下面 override
    let pikafishDiff = AIDifficulty.amateurDan  // lvl6 占位
    print("  自研: lvl\(nativeLvl)(\(nativeDiff.displayName)) vs Pikafish: Skill \(skillLevel)")
    print("")

    // 临时覆盖 skillLevel
    let runner = SelfPlayRunner()
    _ = await runner.runCalibration(
        nativeDifficulty: nativeDiff,
        pikafishDifficulty: pikafishDiff,
        pikafishSkillOverride: skillLevel,
        games: games,
        maxMoves: maxMoves
    )
}
#endif

// MARK: - 命令行入口

#if os(macOS)
/// 命令行自对弈入口（在 ChineseChessApp.swift 的 main 中通过 --selfplay 参数调用）
func runSelfPlayFromCLI() async {
    // v6.0: 禁用 stdout 缓冲
    setvbuf(stdout, nil, _IONBF, 0)

    let args = CommandLine.arguments

    // v6.0: 交叉对弈校准入口
    if args.count >= 2 && args[1] == "--calibrate" {
        let games = args.count > 2 ? (Int(args[2]) ?? 10) : 10
        let runner = SelfPlayRunner()
        _ = await runner.runCalibration(games: games)
        return
    }

    guard args.count >= 5 else {
        print("""
        用法: ChineseChess --selfplay <红方难度> <黑方难度> <局数> [标签] [--no-save-moves]
        用法: ChineseChess --calibrate [局数]

        难度 (v6.0): lvl1 | lvl2 | lvl3 | lvl4 | lvl5 | lvl6 | lvl7 | lvl8 | lvl9 | lvl10
        （旧值兼容: beginner | easy | medium | hard | master）

        走法序列默认逐局即时落盘到 selfplay-results/move-history/（崩溃不丢已完成局）
        加 --no-save-moves 可关闭（A3 崩溃教训：无落盘 = 无归因数据）

        示例:
          ChineseChess --selfplay lvl5 lvl4 100 5vs4
          ChineseChess --selfplay lvl3 lvl4 15 a3rerun
          ChineseChess --calibrate 10
        """)
        return
    }

    // 走法落盘默认开启（P0-3 细化约束）；--no-save-moves 显式关闭（位置无关）
    let saveMoves = !args.contains("--no-save-moves")
    let positional = args.filter { $0 != "--no-save-moves" }

    guard let red = AIDifficulty(rawValue: positional[2]) else {
        print("❌ 无效的红方难度: \(positional[2])")
        return
    }
    guard let black = AIDifficulty(rawValue: positional[3]) else {
        print("❌ 无效的黑方难度: \(positional[3])")
        return
    }
    guard let games = Int(positional[4]), games > 0 else {
        print("❌ 无效的局数: \(positional[4])")
        return
    }

    let label = positional.count > 5 ? positional[5] : "\(red.rawValue)-vs-\(black.rawValue)"
    // 走法落盘分组名：优先与 --calibrate-native 的 A34 风格对齐，非 lvl 格式用 label
    let groupLabel: String
    if let rn = SelfPlayRunner.levelNumber(red.rawValue), let bn = SelfPlayRunner.levelNumber(black.rawValue) {
        groupLabel = "A\(rn)\(bn)"
    } else {
        groupLabel = label
    }
    let mhDir = "selfplay-results/move-history"
    if saveMoves {
        print("  走法序列落盘：\(mhDir)/ （逐局即时写，崩溃不丢已完成局；--no-save-moves 关闭）")
    }

    print("═══════════════════════════════════════════")
    print("  自对弈：\(red.rawValue) vs \(black.rawValue)（\(games) 局）")
    print("═══════════════════════════════════════════")
    print("")

    let runner = SelfPlayRunner()
    let config = SelfPlayConfig(red: red, black: black, games: games)

    let startUptime = ProcessInfo.processInfo.systemUptime

    let report = await runner.runAndReport(config: config, label: label) { completed, gameResult in
        let elapsed = ProcessInfo.processInfo.systemUptime - startUptime
        let winnerStr: String
        switch gameResult.result {
        case .redWon: winnerStr = "红胜"
        case .blackWon: winnerStr = "黑胜"
        case .draw: winnerStr = "和棋"
        default: winnerStr = "未知"
        }
        print("  [\(completed)/\(games)] \(winnerStr) (\(gameResult.totalMoves)步, \(gameResult.reason.rawValue)) [\(String(format: "%.1f", elapsed))s]")
        // --save-moves：逐局即时落盘（崩溃时已完成的局保留）
        if saveMoves {
            SelfPlayRunner.writeMoveHistory(gameResult, to: mhDir, groupLabel: groupLabel)
        }
    }

    print("")
    print(report)
    print("")

    let fm = FileManager.default
    let outputDir = "selfplay-results"
    try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

    let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let outputPath = "\(outputDir)/\(label)_\(timestamp).txt"

    try? report.write(toFile: outputPath, atomically: true, encoding: String.Encoding.utf8)
    print("报告已保存：\(outputPath)")
}
#endif

// MARK: - 纯 Pikafish 自对弈梯度验证

#if os(macOS)
func runPikafishMatchFromCLI() async {
    setvbuf(stdout, nil, _IONBF, 0)
    
    let args = CommandLine.arguments
    // --pfmatch <games> <maxMoves> <skillA> <skillB>
    let games = args.count > 2 ? (Int(args[2]) ?? 4) : 4
    let maxMoves = args.count > 3 ? (Int(args[3]) ?? 40) : 40
    let skillA = args.count > 4 ? (Int(args[4]) ?? 0) : 0
    let skillB = args.count > 5 ? (Int(args[5]) ?? 4) : 4
    let repetitionThreshold = args.count > 6 ? (Int(args[6]) ?? 6) : 6  // T1: 默认 6，可从 args[6] 覆盖
    
    print("═══════════════════════════════════════════")
    print("  Pikafish 自对弈梯度验证")
    print("  Skill \(skillA) vs Skill \(skillB)（\(games) 局，最多 \(maxMoves) 步/局）")
    print("═══════════════════════════════════════════")
    print("")
    
    let engine = EmbeddedPikafishEngine()
    do {
        try await engine.start()
    } catch {
        print("❌ Pikafish 启动失败: \(error)")
        return
    }
    
    var winsA = 0
    var winsB = 0
    var draws = 0
    
    for gameIdx in 0..<games {
        let aIsRed = gameIdx % 2 == 0
        let board = Board()
        var moveHistory: [String] = []
        var fenCounts: [String: Int] = [:]
        
        print("  第\(gameIdx+1)局开始... Skill\(skillA)(\(aIsRed ? "红" : "黑")) vs Skill\(skillB)(\(aIsRed ? "黑" : "红"))")
        
        while moveHistory.count < maxMoves {
            let currentSide = board.currentTurn
            let isATurn = (currentSide == .red) == aIsRed
            let skill = isATurn ? skillA : skillB
            
            await engine.setSkillLevel(skill)
            
            let fen = FENParser.generate(board: board)
            // 传 .amateurLow（skillLevel=nil）避免 bestMove 内部覆盖手动设的 Skill
            // amateurLow 的 depth=10 + timeLimitMs=1000 控制搜索（v2.1 校准优化）
            guard let bestMove = await engine.bestMove(
                fen: fen, moveHistory: [], difficulty: .amateurLow, timeLimitMs: 1000
            ),
            let parsed = UCIMoveConverter.move(from: bestMove, on: board) else {
                // 困毙/无子可动：当前走子方输棋（中国象棋规则）
                let loserSide = board.currentTurn
                let winnerSkill: String
                let isCurrentA = (loserSide == .red) == aIsRed
                if isCurrentA {
                    // A 方无子可动，B 赢
                    winnerSkill = "Skill\(skillB)"; winsB += 1
                } else {
                    winnerSkill = "Skill\(skillA)"; winsA += 1
                }
                let isCheckmate = MoveValidator.isInCheck(board.currentTurn, on: board)
                let endLabel = isCheckmate ? "将死" : "困毙"
                print("  第\(gameIdx+1)局: \(winnerSkill) 胜（\(endLabel)，\(moveHistory.count)步）")
                break
            }
            
            let iccs = ICCSParser.iccsString(from: parsed.from, to: parsed.to)
            moveHistory.append(iccs)
            board.execute(parsed)
            
            let fenAfter = FENParser.generate(board: board)
            fenCounts[fenAfter, default: 0] += 1
            if fenCounts[fenAfter]! >= repetitionThreshold {
                print("  第\(gameIdx+1)局: 和棋（三次重复）\(moveHistory.count)步")
                draws += 1
                break
            }
            
            if board.generalPosition(of: .red) == nil {
                let winner: String
                if aIsRed { winner = "Skill\(skillB)"; winsB += 1 } else { winner = "Skill\(skillA)"; winsA += 1 }
                print("  第\(gameIdx+1)局: \(winner) 胜（\(moveHistory.count)步）")
                break
            }
            if board.generalPosition(of: .black) == nil {
                let winner: String
                if aIsRed { winner = "Skill\(skillA)"; winsA += 1 } else { winner = "Skill\(skillB)"; winsB += 1 }
                print("  第\(gameIdx+1)局: \(winner) 胜（\(moveHistory.count)步）")
                break
            }
        }
        
        if moveHistory.count >= maxMoves {
            print("  第\(gameIdx+1)局: 和棋（步数上限\(maxMoves)）")
            draws += 1
        }
    }
    
    print("")
    print("═══════════════════════════════════════════")
    print("  结果: Skill\(skillA) \(winsA)胜 / Skill\(skillB) \(winsB)胜 / \(draws)和")
    
    let total = winsA + winsB + draws
    if total > 0 {
        let scoreA = Double(winsA) + 0.5 * Double(draws)
        let scoreRate = scoreA / Double(total)
        print("  Skill\(skillA) 得分率: \(String(format: "%.1f%%", scoreRate * 100))")
        if scoreRate > 0 && scoreRate < 1 {
            let eloDelta = -400 * log10(1.0 / scoreRate - 1.0)
            print("  BayesElo 差: \(String(format: "%.0f", eloDelta))（正数表示 A 强于 B）")
        }
    }
    print("═══════════════════════════════════════════")
}
#endif

// MARK: - 校准 v3.0: --calibrate-native CLI 入口（自研内部对弈）

#if os(macOS)
func runCalibrateNativeFromCLI() async {
    setvbuf(stdout, nil, _IONBF, 0)

    let args = CommandLine.arguments
    // --calibrate-native <lvlA> <lvlB> <games> [maxMoves]
    guard args.count >= 5 else {
        print("""
        用法: ChineseChess --calibrate-native <lvlA> <lvlB> <games> [maxMoves]
        示例: ChineseChess --calibrate-native 3 4 20 500

        lvlA/lvlB: 自研引擎级别 (1-5)
          lvl1=novice(入门)  lvl2=beginner(初级)  lvl3=amateurLow(中级)
          lvl4=amateurMid(高级)  lvl5=amateurHigh(精通)
        """)
        return
    }

    guard let lvlA = Int(args[2]), let lvlB = Int(args[3]) else {
        print("❌ 无效的级别参数")
        return
    }
    guard let games = Int(args[4]), games > 0 else {
        print("❌ 无效的局数: \(args[4])")
        return
    }
    let maxMoves = args.count > 5 ? (Int(args[5]) ?? 500) : 500

    let diffA = AIDifficulty(rawValue: "lvl\(lvlA)") ?? .amateurMid
    let diffB = AIDifficulty(rawValue: "lvl\(lvlB)") ?? .amateurHigh

    print("═══════════════════════════════════════════")
    print("  自研内部对弈校准")
    print("  \(diffA.rawValue)(\(diffA.displayName)) vs \(diffB.rawValue)(\(diffB.displayName))")
    print("  \(games) 局，最多 \(maxMoves) 步/局")
    print("═══════════════════════════════════════════")
    print("")

    let config = SelfPlayConfig(red: diffA, black: diffB, games: games, maxMoves: maxMoves)
    let runner = SelfPlayRunner()
    let groupLabel = "A\(lvlA)\(lvlB)"  // e.g. A34 for lvl3 vs lvl4
    let mhDir = "calibration-results/move-history"

    let result = await runner.run(config: config) { completed, gameResult in
        let winnerStr: String
        switch gameResult.result {
        case .redWon: winnerStr = "红胜"
        case .blackWon: winnerStr = "黑胜"
        case .draw: winnerStr = "和棋"
        default: winnerStr = "未知"
        }
        print("  [\(completed)/\(games)] \(winnerStr) (\(gameResult.totalMoves)步, \(gameResult.reason.rawValue))")
        // 逐局即时落盘（A3 教训：旧版跑完才统一写，崩溃 = 全丢）
        SelfPlayRunner.writeMoveHistory(gameResult, to: mhDir, groupLabel: groupLabel)
    }

    let eloDelta = BayesElo.estimateDelta(wins: result.redWins, losses: result.blackWins, draws: result.draws)

    var report = result.summary + "\n\n"
    report += "BayesElo 估值：\(eloDelta >= 0 ? "+" : "")\(eloDelta)\n"
    report += "\n逐局结果：\n"
    for game in result.games {
        let winnerStr: String
        switch game.result {
        case .redWon: winnerStr = "红胜"
        case .blackWon: winnerStr = "黑胜"
        case .draw: winnerStr = "和棋"
        default: winnerStr = "未知"
        }
        report += "  第\(game.gameIndex + 1)局：\(winnerStr)（\(game.totalMoves)步, \(game.reason.rawValue)）\n"
    }

    print("")
    print(report)

    // 保存报告
    let fm = FileManager.default
    let outputDir = "calibration-results"
    try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
    let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let outputPath = "\(outputDir)/native_\(diffA.rawValue)_vs_\(diffB.rawValue)_\(timestamp).txt"
    try? report.write(toFile: outputPath, atomically: true, encoding: .utf8)
    print("报告已保存：\(outputPath)")

    // 走法序列已在 progressCallback 中逐局即时保存（崩溃不丢已完成局）
    print("走法序列已保存：\(mhDir)/ （逐局即时写）")
}
#endif

// MARK: - 校准 v3.0: --calibrate-pf CLI 入口（Pikafish 内部对弈）

#if os(macOS)
func runCalibratePfFromCLI() async {
    setvbuf(stdout, nil, _IONBF, 0)

    let args = CommandLine.arguments
    // --calibrate-pf <skillA> <skillB> <games> [maxMoves] [moveTimeMs]
    guard args.count >= 5 else {
        print("""
        用法: ChineseChess --calibrate-pf <skillA> <skillB> <games> [maxMoves] [moveTimeMs]
        示例: ChineseChess --calibrate-pf 0 4 20 500 500

        skillA/skillB: Pikafish Skill Level (0-20)
        """)
        return
    }

    guard let skillA = Int(args[2]), let skillB = Int(args[3]) else {
        print("❌ 无效的 Skill 参数")
        return
    }
    guard let games = Int(args[4]), games > 0 else {
        print("❌ 无效的局数: \(args[4])")
        return
    }
    let maxMoves = args.count > 5 ? (Int(args[5]) ?? 500) : 500
    let moveTimeMs = args.count > 6 ? (Int(args[6]) ?? 500) : 500

    // Skill → AIDifficulty 映射：找最近的枚举值作为占位
    // 实际 Skill 由 skillOverride 参数控制
    let diffA = SelfPlayRunner.skillToDifficulty(skillA)
    let diffB = SelfPlayRunner.skillToDifficulty(skillB)

    print("═══════════════════════════════════════════")
    print("  Pikafish 内部对弈校准")
    print("  Skill\(skillA) vs Skill\(skillB)")
    print("  \(games) 局，最多 \(maxMoves) 步/局，每步 \(moveTimeMs)ms")
    print("═══════════════════════════════════════════")
    print("")

    let runner = SelfPlayRunner()
    let result = await runner.runPikafishSelfPlay(
        redDifficulty: diffA,
        blackDifficulty: diffB,
        games: games,
        maxMoves: maxMoves,
        moveTimeMs: moveTimeMs,
        redSkillOverride: skillA,
        blackSkillOverride: skillB
    ) { completed, gameResult in
        let winnerStr: String
        switch gameResult.result {
        case .redWon: winnerStr = "红胜"
        case .blackWon: winnerStr = "黑胜"
        case .draw: winnerStr = "和棋"
        default: winnerStr = "未知"
        }
        print("  [\(completed)/\(games)] \(winnerStr) (\(gameResult.totalMoves)步, \(gameResult.reason.rawValue)) [红:\(gameResult.redEngineName) 黑:\(gameResult.blackEngineName)]")
    }

    print("")
    print(result.summary)

    // 生成并保存报告
    var report = result.summary + "\n\n"
    report += "逐局结果：\n"
    for game in result.games {
        let winnerStr: String
        switch game.result {
        case .redWon: winnerStr = "红胜"
        case .blackWon: winnerStr = "黑胜"
        case .draw: winnerStr = "和棋"
        default: winnerStr = "未知"
        }
        report += "  第\(game.gameIndex + 1)局：\(winnerStr)（\(game.totalMoves)步, \(game.reason.rawValue)）[红:\(game.redEngineName) 黑:\(game.blackEngineName)]\n"
    }

    let fm = FileManager.default
    let outputDir = "calibration-results"
    try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
    let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let outputPath = "\(outputDir)/pikafish_skill\(skillA)_vs_skill\(skillB)_\(timestamp).txt"
    try? report.write(toFile: outputPath, atomically: true, encoding: .utf8)
    print("报告已保存：\(outputPath)")
}
#endif
