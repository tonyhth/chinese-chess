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
final class SelfPlayRunner {

    private let engine = AIEngine()

    // 统计
    private var redWins = 0
    private var blackWins = 0
    private var draws = 0
    private var totalMoves = 0
    private var gameResults: [SelfPlayGameResult] = []

    func run(config: SelfPlayConfig, progressCallback: ((Int, SelfPlayGameResult) -> Void)? = nil) -> SelfPlaySessionResult {
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

            let result = playGame(
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
            engine.clearHistory()
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
    ) -> SelfPlayGameResult {
        let board = Board()  // 标准初始局面
        var moveHistory: [String] = []
        var fenCounts: [String: Int] = [:]
        var endReason: GameEndReason = .normal

        let isIOS = false  // 自对弈在 macOS 运行

        while moveHistory.count < maxMoves {
            let currentSide = board.currentTurn
            let difficulty = (currentSide == .red) ? redDifficulty : blackDifficulty

            // 清空 TT 避免跨局污染（但局内保留 TT 加速搜索）
            guard let move = engine.bestMove(for: board, difficulty: difficulty, isIOS: isIOS) else {
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
