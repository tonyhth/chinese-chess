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

struct SelfPlaySessionResult {
    let config: SelfPlayConfig
    let games: [SelfPlayGameResult]
    let redWins: Int
    let blackWins: Int
    let draws: Int
    let avgMoves: Double
    let durationSeconds: Double

    var summary: String {
        let total = games.count
        return """
        自对弈结果：\(config.redDifficulty.rawValue) vs \(config.blackDifficulty.rawValue)（\(total) 局）
        红胜：\(redWins)（\(String(format: "%.1f%%", Double(redWins) / Double(total) * 100))）
        黑胜：\(blackWins)（\(String(format: "%.1f%%", Double(blackWins) / Double(total) * 100))）
        和棋：\(draws)（\(String(format: "%.1f%%", Double(draws) / Double(total) * 100))）
        平均步数：\(String(format: "%.1f", avgMoves))
        耗时：\(String(format: "%.1f", durationSeconds))s
        """
    }
}

// MARK: - 自对弈配置

struct SelfPlayConfig {
    var redDifficulty: AIDifficulty
    var blackDifficulty: AIDifficulty
    var totalGames: Int
    var maxMovesPerGame: Int = 200
    var repetitionThreshold: Int = 3  // 同一 FEN 出现 ≥3 次判和
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
        let startTime = Date()

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

        let elapsed = Date().timeIntervalSince(startTime)
        let avg = Double(totalMoves) / Double(config.totalGames)

        return SelfPlaySessionResult(
            config: config,
            games: gameResults,
            redWins: redWins,
            blackWins: blackWins,
            draws: draws,
            avgMoves: avg,
            durationSeconds: elapsed
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

            // 清空 TT 避免跨局污染（但局内保留 TT 加速搜索）
            guard let move = await engine.bestMove(for: board, difficulty: difficulty, isIOS: isIOS) else {
                // 无棋可走 = 困毙
                endReason = .stalemate
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

            board.execute(move)
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
    let bayesEloDelta: Int

    var summary: String {
        let total = games.count
        return """
        混合引擎对弈结果（\(total) 局）
        红胜：\(redWins)（\(String(format: "%.1f%%", Double(redWins) / Double(total) * 100))）
        黑胜：\(blackWins)（\(String(format: "%.1f%%", Double(blackWins) / Double(total) * 100))）
        和棋：\(draws)（\(String(format: "%.1f%%", Double(draws) / Double(total) * 100))）
        平均步数：\(String(format: "%.1f", avgMoves))
        BayesElo 差值：\(bayesEloDelta >= 0 ? "+" : "")\(bayesEloDelta)
        耗时：\(String(format: "%.1f", durationSeconds))s
        """
    }
}

// MARK: - v6.0 Phase 6: 混合引擎对弈配置

struct MixedEngineConfig {
    var totalGames: Int
    var maxMovesPerGame: Int = 200
    var moveTimeMs: Int = 500       // 每步固定时限（确保公平）
    var repetitionThreshold: Int = 3
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
        let startTime = Date()
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
                avgMoves: 0, durationSeconds: 0, bayesEloDelta: 0
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

        let elapsed = Date().timeIntervalSince(startTime)
        let avg = config.totalGames > 0 ? Double(totalMoves) / Double(config.totalGames) : 0
        // v6.0 P1 fix: 按引擎维度（native vs pikafish）算 Elo，不是红黑维度
        let eloDelta = BayesElo.estimateDelta(wins: nativeWins, losses: pikafishWins, draws: draws)

        return MixedEngineSessionResult(
            games: games,
            redWins: redWins,
            blackWins: blackWins,
            draws: draws,
            avgMoves: avg,
            durationSeconds: elapsed,
            bayesEloDelta: eloDelta
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
                // 自研引擎走棋
                guard let move = await engine.bestMove(
                    for: board, difficulty: nativeDifficulty, isIOS: false
                ) else {
                    endReason = .stalemate
                    let winner: GameState = (currentSide == .red) ? .blackWon : .redWon
                    return (winner, moveHistory.count, endReason, moveHistory)
                }
                let iccs = SelfPlayRunner.iccsNotation(for: move)
                moveHistory.append(iccs)
                board.execute(move)
            } else {
                // Pikafish 走棋
                if let skillOverride = pikafishSkillOverride {
                    await pikafishEngine.setSkillLevel(skillOverride)
                }
                let fen = FENParser.generate(board: board)
                // 构造 UCI move history（ICCS 格式兼容）
                let result = await pikafishEngine.bestMove(
                    fen: fen,
                    moveHistory: [],
                    difficulty: pikafishDifficulty,
                    timeLimitMs: moveTimeMs
                )
                guard let move = result,
                      let parsed = UCIMoveConverter.move(from: move, on: board) else {
                    endReason = .stalemate
                    let winner: GameState = (currentSide == .red) ? .blackWon : .redWon
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
        moveTimeMs: Int = 500,
        maxMoves: Int = 80
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

    /// 纯 Pikafish 自对弈：红方 Skill A vs 黑方 Skill B
    /// 单实例 Pikafish，每步前通过 difficulty 设置当前方的 Skill Level
    func runPikafishSelfPlay(
        redDifficulty: AIDifficulty,
        blackDifficulty: AIDifficulty,
        games: Int,
        maxMoves: Int = 80,
        moveTimeMs: Int = 500,
        progressCallback: ((Int, MixedEngineGameResult) -> Void)? = nil
    ) async -> MixedEngineSessionResult {
        let startTime = Date()
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
                avgMoves: 0, durationSeconds: 0, bayesEloDelta: 0
            )
        }

        let redName = "Skill\(redDifficulty.skillLevel ?? 0)"
        let blackName = "Skill\(blackDifficulty.skillLevel ?? 0)"

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
                engine: engine
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

        let elapsed = Date().timeIntervalSince(startTime)
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
        print("  耗时：\(String(format: "%.1f", elapsed))s")

        return MixedEngineSessionResult(
            games: gameResults, redWins: redWins, blackWins: blackWins,
            draws: draws, avgMoves: avg, durationSeconds: elapsed,
            bayesEloDelta: eloDelta
        )
    }

    /// 纯 Pikafish 单局
    private func playPikafishSelfPlayGame(
        gameIndex: Int,
        redDifficulty: AIDifficulty,
        blackDifficulty: AIDifficulty,
        maxMoves: Int,
        moveTimeMs: Int,
        engine: EmbeddedPikafishEngine
    ) async -> (result: GameState, totalMoves: Int, reason: GameEndReason, moveHistory: [String]) {
        let board = Board()
        var moveHistory: [String] = []
        var fenCounts: [String: Int] = [:]
        var endReason: GameEndReason = .normal

        while moveHistory.count < maxMoves {
            let currentSide = board.currentTurn
            let difficulty = (currentSide == .red) ? redDifficulty : blackDifficulty

            // bestMove 内部会根据 difficulty.skillLevel 自动设置 Skill Level
            let fen = FENParser.generate(board: board)
            let result = await engine.bestMove(
                fen: fen,
                moveHistory: [],
                difficulty: difficulty,
                timeLimitMs: moveTimeMs
            )

            guard let uciMove = result,
                  let move = UCIMoveConverter.move(from: uciMove, on: board) else {
                endReason = .stalemate
                let winner: GameState = (currentSide == .red) ? .blackWon : .redWon
                return (winner, moveHistory.count, endReason, moveHistory)
            }

            let iccs = SelfPlayRunner.iccsNotation(for: move)
            moveHistory.append(iccs)
            board.execute(move)

            let fen2 = FENParser.generate(board: board)
            fenCounts[fen2, default: 0] += 1
            if fenCounts[fen2]! >= 3 {
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
    let maxMoves = args.count > 3 ? (Int(args[3]) ?? 80) : 80  // 默认 80 步上限（快速校准）

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
    // 默认: native=4(lvl4/amateurMid), pikafish=6(lvl6/amateurDan=Skill5)
    // 特殊: pikafishLvl=0 表示 Skill 0（用 novice/lvl1 映射到 Skill 0）
    let nativeLvl = args.count > 4 ? (Int(args[4]) ?? 4) : 4  // 默认 4 级
    let pikafishLvl = args.count > 5 ? (Int(args[5]) ?? 6) : 6  // 默认 6 级
    let nativeDiff = AIDifficulty(rawValue: "lvl\(nativeLvl)") ?? .amateurMid
    // pikafishLvl 1-5 = Skill 0/4/7/10/13（对应天梯实测点）
    // 直接传 Skill Level 数值
    let skillMap = [0: 0, 1: 4, 2: 7, 3: 10, 4: 13, 5: 20]  // pikafishLvl → Skill Level
    // 如果 pikafishLvl > 5，直接当 Skill Level 用
    let skillLevel = pikafishLvl <= 5 ? (skillMap[pikafishLvl] ?? 0) : pikafishLvl
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
        用法: ChineseChess --selfplay <红方难度> <黑方难度> <局数> [标签]
        用法: ChineseChess --calibrate [局数]

        难度 (v6.0): lvl1 | lvl2 | lvl3 | lvl4 | lvl5 | lvl6 | lvl7 | lvl8 | lvl9 | lvl10
        （旧值兼容: beginner | easy | medium | hard | master）

        示例:
          ChineseChess --selfplay lvl5 lvl4 100 5vs4
          ChineseChess --calibrate 10
        """)
        return
    }

    guard let red = AIDifficulty(rawValue: args[2]) else {
        print("❌ 无效的红方难度: \(args[2])")
        return
    }
    guard let black = AIDifficulty(rawValue: args[3]) else {
        print("❌ 无效的黑方难度: \(args[3])")
        return
    }
    guard let games = Int(args[4]), games > 0 else {
        print("❌ 无效的局数: \(args[4])")
        return
    }

    let label = args.count > 5 ? args[5] : "\(red.rawValue)-vs-\(black.rawValue)"

    print("═══════════════════════════════════════════")
    print("  自对弈：\(red.rawValue) vs \(black.rawValue)（\(games) 局）")
    print("═══════════════════════════════════════════")
    print("")

    let runner = SelfPlayRunner()
    let config = SelfPlayConfig(red: red, black: black, games: games)

    let startTime = Date()

    let report = await runner.runAndReport(config: config, label: label) { completed, gameResult in
        let elapsed = Date().timeIntervalSince(startTime)
        let winnerStr: String
        switch gameResult.result {
        case .redWon: winnerStr = "红胜"
        case .blackWon: winnerStr = "黑胜"
        case .draw: winnerStr = "和棋"
        default: winnerStr = "未知"
        }
        print("  [\(completed)/\(games)] \(winnerStr) (\(gameResult.totalMoves)步, \(gameResult.reason.rawValue)) [\(String(format: "%.1f", elapsed))s]")
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
            guard let bestMove = await engine.bestMove(
                fen: fen, moveHistory: [], difficulty: .amateurDan, timeLimitMs: 500
            ),
            let parsed = UCIMoveConverter.move(from: bestMove, on: board) else {
                print("    无合法走法，结束")
                break
            }
            
            let iccs = ICCSParser.iccsString(from: parsed.from, to: parsed.to)
            moveHistory.append(iccs)
            board.execute(parsed)
            
            let fenAfter = FENParser.generate(board: board)
            fenCounts[fenAfter, default: 0] += 1
            if fenCounts[fenAfter]! >= 3 {
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
