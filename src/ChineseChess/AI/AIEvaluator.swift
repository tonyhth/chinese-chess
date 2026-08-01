import Foundation

// MARK: - AI 评估函数

/// 从 AIEngine 拆分出来的评估模块
/// 包含：棋盘评估 + 棋子动态价值计算
struct AIEvaluator {

    let weights: EvalWeights

    init(weights: EvalWeights = EvalConfigManager.shared.weights) {
        self.weights = weights
    }

    /// 返回当前行走方视角的评估分数（正值 = 当前行有利）。
    func evaluate<T: BoardReadable>(_ board: T, config: AIEvalConfig = .basic) -> Int {
        let side = board.currentTurn

        // 残局精确估值（≤6 子）
        if let endgameScore = EndgameEvaluator.evaluate(board: board, for: side) {
            return endgameScore
        }

        let w = weights
        let sign: Int = (side == .black) ? 1 : -1

        var materialScore = 0
        var positionScore = 0
        let totalPieces = board.pieces.count

        for piece in board.pieces {
            let value = dynamicValue(for: piece, totalPieces: totalPieces)
            let posWeight = PositionTables.positionWeight(for: piece, totalPieces: totalPieces)
            if piece.side == .black {
                materialScore += value
                positionScore += posWeight
            } else {
                materialScore -= value
                positionScore -= posWeight
            }
        }

        // 棋型识别加分
        let blackPatternBonus = PatternRecognizer.bonusPatterns(on: board, for: .black, weights: w)
        let redPatternBonus = PatternRecognizer.bonusPatterns(on: board, for: .red, weights: w)
        let patternBonus = blackPatternBonus - redPatternBonus

        // 将帅安全评估
        let safetyBonus: Int
        if config.safety {
            safetyBonus = KingSafetyEvaluator.kingSafetyScore(for: .black, on: board, weights: w)
                - KingSafetyEvaluator.kingSafetyScore(for: .red, on: board, weights: w)
        } else {
            safetyBonus = 0
        }

        // 简化机动性评估
        let mobilityBonus: Int
        if config.mobility {
            mobilityBonus = KingSafetyEvaluator.simplifiedMobilityScore(for: .black, on: board, weights: w)
                - KingSafetyEvaluator.simplifiedMobilityScore(for: .red, on: board, weights: w)
        } else {
            mobilityBonus = 0
        }

        return sign * (Int(Double(materialScore) * w.materialWeight)
            + Int(Double(positionScore) * w.positionWeight)
            + Int(Double(patternBonus) * w.patternWeight)
            + Int(Double(mobilityBonus) * w.mobilityWeight)
            + Int(Double(safetyBonus) * w.safetyWeight))
    }

    // MARK: - 棋子动态价值

    /// 棋子动态价值：基础分 + 残局调整
    /// v3.0 Phase 3a: 残局兵/象/士价值调整
    func dynamicValue(for piece: Piece, totalPieces: Int) -> Int {
        let base = piece.baseValue
        let isEndgame = totalPieces <= 16

        // 残局调整：兵卒过河价值翻倍，象/士贬值（残局防守价值下降）
        if isEndgame {
            switch piece.kind {
            case .soldier:
                let crossed = (piece.side == .black) ? piece.position.row >= 5 : piece.position.row <= 4
                return crossed ? base * 2 : base
            case .elephant:
                return base / 2  // 残局象贬值
            case .advisor:
                return base * 3 / 4  // 残局势贬值
            default:
                return base
            }
        }
        return base
    }
}
