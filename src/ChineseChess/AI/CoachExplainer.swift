import Foundation

// MARK: - v3.6.0 Phase 3.1: AI 教练讲解器

/// 教练讲解场景类型
enum CoachScenario: String, CaseIterable {
    case blunder            // 送子/失误
    case missedMate         // 错失杀机
    case missedCheck        // 将军机会
    case missedCapture      // 吃子机会
    case developPiece       // 兵力展开
    case defensiveMove      // 防守优先
    case centerControl      // 控制中线
    case generic            // 通用 fallback
}

/// 教练讲解结果
struct CoachExplanation {
    let scenario: CoachScenario
    let title: String        // 简短标题
    let detail: String       // 详细讲解
    let betterMove: String   // 推荐走法（UCI）
    let evalDelta: Int       // 评估差距（cp）
}

// MARK: - CoachExplainer

/// AI 教练讲解器
///
/// 基于 PositionAnalyzer 的分析结果，生成自然语言讲解。
/// 8 类场景模板 + fallback。
actor CoachExplainer {

    static let shared = CoachExplainer()

    private let l10n = L10n.shared

    // MARK: - 核心方法

    /// 生成单步走法的教练讲解
    ///
    /// - Parameters:
    ///   - analysis: 走法分析结果
    ///   - boardBefore: 走棋前的棋盘（用于判断场景）
    ///   - playerMove: 玩家走法（UCI）
    ///   - bestMove: 最佳走法（UCI）
    func explain(
        analysis: MoveAnalysis,
        fenBefore: String,
        playerMove: String,
        bestMove: String
    ) -> CoachExplanation {
        let delta = analysis.evalDelta
        let scenario = classifyScenario(
            analysis: analysis,
            fenBefore: fenBefore,
            playerMove: playerMove,
            bestMove: bestMove
        )

        return CoachExplanation(
            scenario: scenario,
            title: titleFor(scenario: scenario, delta: delta),
            detail: detailFor(
                scenario: scenario,
                delta: delta,
                betterMove: bestMove,
                analysis: analysis
            ),
            betterMove: bestMove,
            evalDelta: delta
        )
    }

    // MARK: - 场景分类

    private func classifyScenario(
        analysis: MoveAnalysis,
        fenBefore: String,
        playerMove: String,
        bestMove: String
    ) -> CoachScenario {
        let delta = analysis.evalDelta

        // 评估落差 < 50cp，不需要讲解
        if delta < 50 { return .generic }

        // 大失误（≥300cp）：进一步分类
        if delta >= 300 {
            // 检查是否有杀棋相关
            if isMateScore(analysis.bestEval) && !isMateScore(analysis.playerEval) {
                return .missedMate
            }
            return .blunder
        }

        // 中等落差（50-300cp）
        // 检查最佳走法是否将军
        if isCheckingMove(bestMove, fen: fenBefore) {
            return .missedCheck
        }

        // 检查是否安全吃子
        if isSafeCapture(bestMove, fen: fenBefore) {
            return .missedCapture
        }

        // 检查是否展开子力
        if isDevelopmentMove(bestMove, fen: fenBefore) {
            return .developPiece
        }

        // 检查是否防守
        if isDefensiveMove(bestMove, fen: fenBefore, analysis: analysis) {
            return .defensiveMove
        }

        // 检查中线控制
        if isCenterControlMove(bestMove, fen: fenBefore) {
            return .centerControl
        }

        return .generic
    }

    // MARK: - 模板文案

    private func titleFor(scenario: CoachScenario, delta: Int) -> String {
        switch scenario {
        case .blunder:
            return delta >= 700
                ? l10n.t("coach.blunder.severe")
                : l10n.t("coach.blunder.title")
        case .missedMate:
            return l10n.t("coach.missedMate.title")
        case .missedCheck:
            return l10n.t("coach.missedCheck.title")
        case .missedCapture:
            return l10n.t("coach.missedCapture.title")
        case .developPiece:
            return l10n.t("coach.develop.title")
        case .defensiveMove:
            return l10n.t("coach.defensive.title")
        case .centerControl:
            return l10n.t("coach.center.title")
        case .generic:
            return l10n.t("coach.generic.title")
        }
    }

    private func detailFor(
        scenario: CoachScenario,
        delta: Int,
        betterMove: String,
        analysis: MoveAnalysis
    ) -> String {
        let deltaStr = String(delta)

        switch scenario {
        case .blunder:
            return String(format: l10n.t("coach.blunder.detail"), betterMove, deltaStr)
        case .missedMate:
            return String(format: l10n.t("coach.missedMate.detail"), betterMove)
        case .missedCheck:
            return String(format: l10n.t("coach.missedCheck.detail"), betterMove)
        case .missedCapture:
            return String(format: l10n.t("coach.missedCapture.detail"), betterMove)
        case .developPiece:
            return String(format: l10n.t("coach.develop.detail"), betterMove)
        case .defensiveMove:
            return String(format: l10n.t("coach.defensive.detail"), betterMove)
        case .centerControl:
            return String(format: l10n.t("coach.center.detail"), betterMove)
        case .generic:
            if delta >= 50 {
                return String(format: l10n.t("coach.generic.detail"), betterMove, deltaStr)
            } else {
                return l10n.t("coach.generic.good")
            }
        }
    }

    // MARK: - 局面判断辅助

    /// 是否是杀棋分数
    private func isMateScore(_ cp: Int) -> Bool {
        abs(cp) >= 90000
    }

    /// 是否是将军走法（简化判断：目标位置在九宫格附近）
    private func isCheckingMove(_ move: String, fen: String) -> Bool {
        // P2 fix: 精确推演走法后检查对方是否被将军
        guard let (from, to) = UCIMoveConverter.positions(from: move) else { return false }
        let board = Board(fen: fen)
        guard let piece = board.piece(at: from) else { return false }

        let chessMove = Move(piece: piece, from: from, to: to, captured: board.piece(at: to))
        board.execute(chessMove)

        // 走完后检查对方是否被将军
        let opponent: Side = (piece.side == .red) ? .black : .red
        return MoveValidator.isInCheck(opponent, on: board)
    }

    /// 是否是安全吃子（走法推演：吃子后己方不被将军，且落点不受对方攻击）
    private func isSafeCapture(_ move: String, fen: String) -> Bool {
        guard let (from, to) = UCIMoveConverter.positions(from: move) else { return false }
        let board = Board(fen: fen)
        guard let piece = board.piece(at: from) else { return false }
        guard let captured = board.piece(at: to) else { return false }  // 必须有吃子目标

        let chessMove = Move(piece: piece, from: from, to: to, captured: captured)
        board.execute(chessMove)

        let moverSide: Side = piece.side
        let opponentSide: Side = (moverSide == .red) ? .black : .red

        // 条件 1：走完后己方不能被将军
        if MoveValidator.isInCheck(moverSide, on: board) { return false }

        // 条件 2：落点不受对方攻击（对方无法回吃）
        let opponentMoves = MoveValidator.allLegalMoves(for: opponentSide, on: board)
        let isContested = opponentMoves.contains { $0.to == to }
        return !isContested
    }

    /// 是否是展开子力走法（简化判断：起始行在底线附近）
    private func isDevelopmentMove(_ move: String, fen: String) -> Bool {
        // UCI 格式：colRankColRank（如 "h0e3"）
        // move[1] 是起始行（0-9），0 和 9 是底线
        guard move.count >= 2 else { return false }
        let rankChar = move[move.index(move.startIndex, offsetBy: 1)]
        return rankChar == "0" || rankChar == "9"
    }

    /// 是否是防守走法
    private func isDefensiveMove(_ move: String, fen: String, analysis: MoveAnalysis) -> Bool {
        // 如果之前被将军且最佳走法是应将
        // 简化：如果 bestEval 是负的（己方劣势），推荐走法大概率是防守
        return analysis.bestEval < -50
    }

    /// 是否是中线控制走法
    private func isCenterControlMove(_ move: String, fen: String) -> Bool {
        // P3 fix: 收窄范围 c-g → d-f（九宫格列 + 中线）
        // 中国象棋中线控制核心区域：d(4列)、e(5列/正中)、f(6列)
        guard move.count >= 3 else { return false }
        let toCol = move[move.index(move.startIndex, offsetBy: 2)]
        return toCol == "d" || toCol == "e" || toCol == "f"
    }
}

// MARK: - v3.6.0 Phase 3.3: 复盘卡片

/// 对局复盘统计
struct GameReviewCard {
    let totalMoves: Int
    let qualityDistribution: [MoveQuality: Int]
    let biggestBlunder: (moveIndex: Int, delta: Int)?
    let rating: Int          // 1-5 星
    let suggestion: String   // 提升建议
}

extension CoachExplainer {
    /// 生成复盘统计卡片
    func generateReviewCard(analyses: [MoveAnalysis?]) -> GameReviewCard {
        var dist: [MoveQuality: Int] = [:]
        var biggestBlunder: (moveIndex: Int, delta: Int)? = nil

        for (i, a) in analyses.enumerated() {
            guard let a = a else { continue }
            dist[a.quality, default: 0] += 1

            if a.evalDelta >= 100 {
                if biggestBlunder == nil || a.evalDelta > biggestBlunder!.delta {
                    biggestBlunder = (i, a.evalDelta)
                }
            }
        }

        let totalAnalyzed = analyses.compactMap { $0 }.count
        let goodCount = (dist[.brilliant] ?? 0) + (dist[.good] ?? 0)
        let doubtfulCount = dist[.doubtful] ?? 0
        let badCount = (dist[.blunder] ?? 0) + (dist[.losing] ?? 0)

        // 棋力评分（1-5星）
        let rating: Int
        if totalAnalyzed == 0 {
            rating = 3
        } else {
            let goodRatio = Double(goodCount) / Double(totalAnalyzed)
            let doubtfulRatio = Double(doubtfulCount) / Double(totalAnalyzed)
            let badRatio = Double(badCount) / Double(totalAnalyzed)
            let score = goodRatio * 5 - doubtfulRatio * 0.5 - badRatio * 2
            rating = max(1, min(5, Int(score.rounded()) + 3))
        }

        // 建议文案
        let suggestion: String
        if badCount > goodCount {
            suggestion = l10n.t("coach.review.morePractice")
        } else if doubtfulCount > goodCount {
            suggestion = l10n.t("coach.review.reduceDoubtful")
        } else if rating >= 4 {
            suggestion = l10n.t("coach.review.wellPlayed")
        } else {
            suggestion = l10n.t("coach.review.keepGoing")
        }

        return GameReviewCard(
            totalMoves: totalAnalyzed,
            qualityDistribution: dist,
            biggestBlunder: biggestBlunder,
            rating: rating,
            suggestion: suggestion
        )
    }
}
