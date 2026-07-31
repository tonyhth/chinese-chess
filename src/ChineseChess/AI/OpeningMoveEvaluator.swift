import Foundation

// MARK: - Phase B3 Step 1: 开局走法评估器

/// 开局走法评估器
///
/// 评估分两步，UI 分两阶段反馈：
/// 1. 同步阶段：书谱匹配（O(1) hash 查表）→ 即时反馈
/// 2. async 阶段：引擎 MultiPV 分析 → 补充/修正反馈
actor OpeningMoveEvaluator {

    private let engine: EmbeddedPikafishEngine

    // 评估参数（与复盘分析一致）
    private let evalDepth = 14
    private let evalTimeMs = 1000
    private let multiPVCount = 5

    init(engine: EmbeddedPikafishEngine) {
        self.engine = engine
    }

    // MARK: - 第一步：同步书谱检查

    /// 非隔离书谱检查（零延迟，可从任何线程同步调用）
    ///
    /// 标记 nonisolated 因为书谱查表不涉及 actor 的 mutable state，
    /// 从外部调用时不需要 await hop，保证真正的同步零延迟。
    nonisolated func evaluateBook(
        userMove: String,
        bookMoves: [String]
    ) -> CoachedMove? {
        if bookMoves.contains(userMove) {
            return CoachedMove(
                move: userMove,
                quality: .book,
                bookMove: nil,
                evalDelta: 0,
                explanation: L10n.shared.t("coach.explain.bookMove")
            )
        }
        return nil
    }

    // MARK: - 第二步：async 引擎评估

    /// 引擎评估（~1 秒，在后台调用）
    ///
    /// - Parameters:
    ///   - userMove: 用户走法，**必须为 ICCS 格式**（与 OpeningBook/引擎输出一致）
    ///   - fen: 当前局面 FEN
    ///   - moveHistory: 走法历史（ICCS 格式）
    /// - Returns: 带评估的走法记录
    ///
    /// 算法：
    /// 1. 调用 multiPV(fen, count=N) 获取当前局面前 N 候选走法及评估
    /// 2. 如果用户走法在候选中 → 直接取 eval，与 bestEval 计算 delta
    /// 3. 如果用户走法不在候选中 → 走完用户走法后在新 FEN 上评估：
    ///    a. 执行用户走法，得到 newHistory
    ///    b. 在 newHistory 上 evaluate()，取 bestEval（对手最佳应手的评估）
    ///    c. userEval = -bestEval（视角翻转：对手最佳 = 我方最差）
    ///    d. delta = bestEval_of_current_pos - userEval
    /// 4. 按 PositionAnalyzer 的阈值分级（与复盘一致）
    func evaluateEngine(
        userMove: String,
        fen: String,
        moveHistory: [String]
    ) async -> CoachedMove {
        // Step 1: MultiPV 分析当前局面
        let lines = await engine.multiPV(
            fen: fen,
            moveHistory: moveHistory,
            count: multiPVCount,
            depth: evalDepth,
            timeMs: evalTimeMs
        )

        guard let bestLine = lines.first else {
            return CoachedMove(
                move: userMove,
                quality: .normal,
                bookMove: nil,
                evalDelta: nil,
                explanation: nil
            )
        }
        let bestEval = bestLine.scoreCp
        let bestMove = bestLine.bestMove

        // Step 2: 在候选中找用户走法
        if let userLine = lines.first(where: { $0.bestMove == userMove }) {
            let userEval = userLine.scoreCp
            let delta = abs(bestEval - userEval)
            let quality = qualityFromDelta(delta)
            return CoachedMove(
                move: userMove,
                quality: quality,
                bookMove: bestMove,
                evalDelta: delta,
                explanation: explanationFor(quality: quality, bestMove: bestMove, delta: delta)
            )
        }

        // Step 3: 用户走法不在候选中 — 需要额外评估
        let newHistory = moveHistory + [userMove]
        if let responseLine = await engine.evaluate(
            fen: fen,
            moveHistory: newHistory,
            depth: evalDepth,
            timeMs: evalTimeMs
        ) {
            // 对手视角的最佳评估 = 我方的最差评估
            let userEval = -responseLine.scoreCp
            let delta = abs(bestEval - userEval)
            let quality = qualityFromDelta(delta)
            return CoachedMove(
                move: userMove,
                quality: quality,
                bookMove: bestMove,
                evalDelta: delta,
                explanation: explanationFor(quality: quality, bestMove: bestMove, delta: delta)
            )
        }

        // fallback
        return CoachedMove(
            move: userMove,
            quality: .normal,
            bookMove: bestMove,
            evalDelta: nil,
            explanation: nil
        )
    }

    // MARK: - 阈值分级

    /// 与 PositionAnalyzer 完全一致的阈值分级
    private func qualityFromDelta(_ delta: Int) -> OpeningMoveQuality {
        switch delta {
        case 0...10:    return .brilliant
        case 11...50:   return .good
        case 51...100:  return .normal
        case 101...300: return .doubtful
        case 301...700: return .blunder
        default:        return .losing
        }
    }

    // MARK: - 说明文本

    private func explanationFor(quality: OpeningMoveQuality, bestMove: String?, delta: Int) -> String? {
        switch quality {
        case .book:
            return L10n.shared.t("coach.explain.bookMove")
        case .brilliant:
            return L10n.shared.t("coach.explain.brilliant")
        case .good:
            return L10n.shared.t("coach.explain.good")
        case .normal:
            return nil  // 普通走法无需说明
        case .doubtful:
            if let best = bestMove {
                return L10n.shared.t("coach.explain.doubtful", best)
            }
            return L10n.shared.t("coach.explain.doubtful.noAlt")
        case .blunder:
            if let best = bestMove {
                return L10n.shared.t("coach.explain.blunder", best, String(delta))
            }
            return L10n.shared.t("coach.explain.blunder.noAlt", String(delta))
        case .losing:
            if let best = bestMove {
                return L10n.shared.t("coach.explain.losing", best, String(delta))
            }
            return L10n.shared.t("coach.explain.losing.noAlt", String(delta))
        }
    }
}
