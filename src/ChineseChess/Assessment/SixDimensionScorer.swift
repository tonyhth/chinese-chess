import Foundation

// MARK: - v6.0 Phase 4: 六维评分算法

/// 评估用的逐手分析结果
struct AssessedMove {
    let index: Int
    let fenBefore: String
    let playerMove: String       // UCI
    let analysis: MoveAnalysis
    let phase: GamePhase
    let isBookMove: Bool
    let hasCheckmateOpportunity: Bool
    let missedCheckmate: Bool
}

/// 六维评分器
enum SixDimensionScorer {

    // MARK: - mate delta 归一化（v6.3.2 热修链，Ruby P1-1）

    /// mate 分数（|s|≥90000，与 EvalChartScale.mateThreshold 同口径）的 evalDelta≈99000
    /// 直接进均值/方差/连续失误检测会把六维整体砸塌。归一为固定重损惩罚值（700cp）
    /// ——语义：将死一步重于普通失误，但不至于单步摧毁整维。
    static let mateDeltaPenalty = 700

    static func normalizedDelta(_ delta: Int) -> Int {
        abs(delta) >= EvalChartScale.mateThreshold ? mateDeltaPenalty : delta
    }


    // MARK: - 维度 1：开局水平（权重 15%）

    static func evaluateOpening(moves: [AssessedMove]) -> SixDimensionScores.ScoreBreakdown {
        let openingMoves = moves.filter { $0.phase == .opening }
        guard !openingMoves.isEmpty else {
            return SixDimensionScores.ScoreBreakdown(
                score: 50, label: "数据不足",
                detail: "无开局阶段数据", metrics: [:]
            )
        }

        // 指标 1：开局库匹配率
        let bookMatches = openingMoves.filter { $0.isBookMove }.count
        let bookMatchRate = Double(bookMatches) / Double(openingMoves.count)

        // 指标 2：开局阶段平均 delta（mate 分数归一，v6.3.2 P1-1）
        let avgDelta = openingMoves.map { Double(normalizedDelta($0.analysis.evalDelta)) }.reduce(0, +) / Double(openingMoves.count)

        // delta 为主（70%），匹配率为辅（30%）
        let deltaScore = max(0, 70 - Int(avgDelta / 3))
        let bookScore = min(100, Int(bookMatchRate / 0.8 * 30))
        let totalScore = min(100, deltaScore + bookScore)

        return SixDimensionScores.ScoreBreakdown(
            score: totalScore,
            label: SixDimensionScores.ScoreBreakdown.scoreLabel(totalScore),
            detail: "开局匹配率 \(Int(bookMatchRate * 100))%，平均偏差 \(Int(avgDelta))cp",
            metrics: ["bookMatchRate": bookMatchRate, "avgDelta": avgDelta]
        )
    }

    // MARK: - 维度 2：中盘战术（权重 25%）

    static func evaluateTactics(moves: [AssessedMove]) -> SixDimensionScores.ScoreBreakdown {
        let midgameMoves = moves.filter { $0.phase == .middle }
        guard !midgameMoves.isEmpty else {
            return SixDimensionScores.ScoreBreakdown(
                score: 50, label: "数据不足",
                detail: "无中盘阶段数据", metrics: [:]
            )
        }

        let total = Double(midgameMoves.count)
        let positiveCount = midgameMoves.filter {
            $0.analysis.quality == .brilliant || $0.analysis.quality == .good
        }.count
        let negativeCount = midgameMoves.filter {
            $0.analysis.quality == .blunder || $0.analysis.quality == .losing
        }.count

        let positiveRate = Double(positiveCount) / total
        let negativeRate = Double(negativeCount) / total

        // 精妙率 ×60 + (1-失误率) ×40
        let tacticsScore = positiveRate * 60.0 + (1.0 - negativeRate) * 40.0
        let score = min(100, Int(tacticsScore))

        let posPct = Int(positiveRate * 100)
        let negPct = Int(negativeRate * 100)
        let detail = "精妙率 \(posPct)%，失误率 \(negPct)%"

        return SixDimensionScores.ScoreBreakdown(
            score: score,
            label: SixDimensionScores.ScoreBreakdown.scoreLabel(score),
            detail: detail,
            metrics: ["positiveRate": positiveRate, "negativeRate": negativeRate]
        )
    }

    // MARK: - 维度 3：残局功底（权重 20%）

    static func evaluateEndgame(moves: [AssessedMove]) -> SixDimensionScores.ScoreBreakdown {
        let endgameMoves = moves.filter { $0.phase == .endgame }

        guard !endgameMoves.isEmpty else {
            return SixDimensionScores.ScoreBreakdown(
                score: 50, label: "数据不足",
                detail: "无残局阶段数据", metrics: [:]
            )
        }

        let avgDelta = endgameMoves.map { Double(normalizedDelta($0.analysis.evalDelta)) }.reduce(0, +) / Double(endgameMoves.count)
        let blunders = endgameMoves.filter {
            $0.analysis.quality == .blunder || $0.analysis.quality == .losing
        }.count
        let blunderRate = Double(blunders) / Double(endgameMoves.count)

        let deltaScore = max(0, 60 - Int(avgDelta / 3))
        let blunderScore = Int((1.0 - blunderRate) * 40)
        let score = min(100, deltaScore + blunderScore)

        return SixDimensionScores.ScoreBreakdown(
            score: score,
            label: SixDimensionScores.ScoreBreakdown.scoreLabel(score),
            detail: "残局平均偏差 \(Int(avgDelta))cp，失误率 \(Int(blunderRate * 100))%",
            metrics: ["avgDelta": avgDelta, "blunderRate": blunderRate]
        )
    }

    // MARK: - 维度 4：稳定性（权重 20%）

    static func evaluateConsistency(moves: [AssessedMove]) -> SixDimensionScores.ScoreBreakdown {
        let deltas = moves.map { Double(normalizedDelta($0.analysis.evalDelta)) }
        guard deltas.count >= 10 else {
            return SixDimensionScores.ScoreBreakdown(
                score: 50, label: "数据不足",
                detail: "步数不足", metrics: [:]
            )
        }

        let mean = deltas.reduce(0, +) / Double(deltas.count)
        let variance = deltas.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(deltas.count)
        let stddev = sqrt(variance)

        // 连续失误检测：连续 ≥3 步 delta > 100
        let consecutiveBlunders = detectConsecutiveHigh(deltas, threshold: 100, minConsecutive: 3)

        // stddev ≤ 30 = 满分；stddev ≥ 200 = 零分
        let consistencyScore = max(0, min(100, Int(100 - (stddev - 30) / 2)))
        let penalty = consecutiveBlunders * 5
        let score = max(0, consistencyScore - penalty)

        return SixDimensionScores.ScoreBreakdown(
            score: score,
            label: SixDimensionScores.ScoreBreakdown.scoreLabel(score),
            detail: "走法标准差 \(Int(stddev))cp，连续失误 \(consecutiveBlunders) 次",
            metrics: ["stddev": stddev, "consecutiveBlunders": Double(consecutiveBlunders)]
        )
    }

    // MARK: - 维度 5：杀棋敏感度（权重 20%）

    static func evaluateCheckmate(moves: [AssessedMove]) -> SixDimensionScores.ScoreBreakdown {
        let opportunities = moves.filter { $0.hasCheckmateOpportunity }

        guard !opportunities.isEmpty else {
            return SixDimensionScores.ScoreBreakdown(
                score: 50, label: "数据不足",
                detail: "本局无杀棋机会", metrics: [:]
            )
        }

        let found = opportunities.filter { !$0.missedCheckmate }.count
        let discoveryRate = Double(found) / Double(opportunities.count)
        let score = Int(discoveryRate * 100)

        return SixDimensionScores.ScoreBreakdown(
            score: score,
            label: SixDimensionScores.ScoreBreakdown.scoreLabel(score),
            detail: "发现 \(found)/\(opportunities.count) 次杀棋机会",
            metrics: ["discoveryRate": discoveryRate]
        )
    }

    // MARK: - 综合评分

    static func evaluateAll(moves: [AssessedMove]) -> SixDimensionScores {
        return SixDimensionScores(
            opening: evaluateOpening(moves: moves),
            tactics: evaluateTactics(moves: moves),
            endgame: evaluateEndgame(moves: moves),
            consistency: evaluateConsistency(moves: moves),
            checkmate: evaluateCheckmate(moves: moves)
        )
    }

    // MARK: - 辅助

    /// 检测连续高 delta 的段数
    private static func detectConsecutiveHigh(_ deltas: [Double], threshold: Double, minConsecutive: Int) -> Int {
        var count = 0
        var streak = 0
        for delta in deltas {
            if delta > threshold {
                streak += 1
            } else {
                if streak >= minConsecutive { count += 1 }
                streak = 0
            }
        }
        if streak >= minConsecutive { count += 1 }
        return count
    }

    // MARK: - 优势/短板分析

    static func generateStrengths(_ dims: SixDimensionScores) -> [String] {
        var result: [String] = []
        if dims.opening.score >= 70 { result.append("开局准备充分（\(dims.opening.score)%）") }
        if dims.tactics.score >= 70 { result.append("中盘战术出色（\(dims.tactics.score)%）") }
        if dims.endgame.score >= 70 { result.append("残局功底扎实（\(dims.endgame.score)%）") }
        if dims.consistency.score >= 70 { result.append("走法稳定（\(dims.consistency.score)%）") }
        if dims.checkmate.score >= 70 { result.append("杀棋敏锐（\(dims.checkmate.score)%）") }
        return result
    }

    static func generateWeaknesses(_ dims: SixDimensionScores) -> [String] {
        var result: [String] = []
        if dims.opening.score < 50 { result.append("开局准备不足（\(dims.opening.score)%）") }
        if dims.tactics.score < 50 { result.append("中盘失误偏多（\(dims.tactics.score)%）") }
        if dims.endgame.score < 50 { result.append("残局功底待提升（\(dims.endgame.score)%）") }
        if dims.consistency.score < 50 { result.append("走法波动大（\(dims.consistency.score)%）") }
        if dims.checkmate.score < 50 { result.append("杀棋敏感度偏低（\(dims.checkmate.score)%）") }
        return result
    }

    // MARK: - 训练建议

    static func generateSuggestions(_ dims: SixDimensionScores, elo: EloEstimate) -> [TrainingSuggestion] {
        var suggestions: [TrainingSuggestion] = []

        if dims.checkmate.score < 60 {
            suggestions.append(TrainingSuggestion(
                dimension: "杀棋敏感度",
                title: "练习残局杀棋题",
                description: "你的杀棋敏感度偏低（\(dims.checkmate.score)%），建议从 2-3 星残局开始练习",
                actionType: .puzzleChapter,
                actionTarget: "endgame_2star"
            ))
        }
        if dims.opening.score < 60 {
            suggestions.append(TrainingSuggestion(
                dimension: "开局水平",
                title: "学习常见开局定式",
                description: "开局匹配率偏低，建议浏览开局树学习主流走法",
                actionType: .openingExplorer,
                actionTarget: "opening_tree"
            ))
        }
        if dims.tactics.score < 60 {
            suggestions.append(TrainingSuggestion(
                dimension: "中盘战术",
                title: "复盘中盘失误",
                description: "中盘失误率偏高，建议使用复盘分析逐手检查",
                actionType: .replayAnalysis,
                actionTarget: "replay"
            ))
        }
        if dims.endgame.score < 60 {
            suggestions.append(TrainingSuggestion(
                dimension: "残局功底",
                title: "练习残局",
                description: "残局阶段失误较多，建议从基础残局开始系统练习",
                actionType: .puzzleChapter,
                actionTarget: "endgame_1star"
            ))
        }

        // 如果都 ≥60，推荐对弈提升
        let allGood = [dims.opening.score, dims.tactics.score, dims.endgame.score,
                       dims.consistency.score, dims.checkmate.score].allSatisfy { $0 >= 60 }
        if allGood {
            let level = EloEstimator.recommendedLevel(from: elo)
            suggestions.append(TrainingSuggestion(
                dimension: "综合",
                title: "挑战更高难度",
                description: "各维度评分均衡，建议挑战 \(level.displayName) 级别提升棋力",
                actionType: .aiMatch,
                actionTarget: level.rawValue
            ))
        }

        return suggestions
    }
}
