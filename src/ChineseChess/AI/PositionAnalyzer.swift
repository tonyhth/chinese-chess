import Foundation

// MARK: - v3.6.0 Phase 1: 走法质量分级

/// 走法质量等级
enum MoveQuality: Int, CaseIterable, Codable {
    case brilliant = 5  // 精妙：≤10cp 差距
    case good = 4        // 好棋：≤50cp
    case normal = 3      // 普通：≤100cp
    case doubtful = 2    // 疑问：≤300cp
    case blunder = 1     // 失误：≤700cp
    case losing = 0      // 败着：>700cp

    /// 显示标签的 i18n key
    var l10nKey: String {
        switch self {
        case .brilliant: return "move.quality.brilliant"
        case .good:      return "move.quality.good"
        case .normal:    return "move.quality.normal"
        case .doubtful:  return "move.quality.doubtful"
        case .blunder:   return "move.quality.blunder"
        case .losing:    return "move.quality.losing"
        }
    }

    /// SF Symbol 名称
    var symbolName: String {
        switch self {
        case .brilliant: return "star.fill"
        case .good:      return "checkmark.circle.fill"
        case .normal:    return "circle"
        case .doubtful:  return "questionmark.circle"
        case .blunder:   return "exclamationmark.triangle"
        case .losing:    return "xmark.octagon"
        }
    }

    /// 颜色（用于 UI 标注）
    var color: String {
        switch self {
        case .brilliant: return "green"
        case .good:      return "blue"
        case .normal:    return "gray"
        case .doubtful:  return "yellow"
        case .blunder:   return "orange"
        case .losing:    return "red"
        }
    }
}

/// 单条 PV 线分析结果
struct AnalysisLine: Codable {
    let scoreCp: Int       // 厘兵值（正=红方优势）
    let depth: Int          // 搜索深度
    let bestMove: String    // 最佳走法（UCI）
    let pv: String          // 主变（空格分隔 UCI 走法）
}

/// 单步走法的完整分析结果
struct MoveAnalysis: Codable {
    let playerMove: String       // 玩家实际走的（UCI）
    let quality: MoveQuality     // 质量分级
    let bestMove: String         // 引擎推荐最佳走法（UCI）
    let bestEval: Int            // 最佳走法的评估值（cp）
    let playerEval: Int          // 玩家走法后的评估值（cp）
    let evalDelta: Int           // 评估损失（bestEval - playerEval，正数=损失）
    let alternatives: [AnalysisLine]  // 候选走法（multiPV）
    let isQuickResult: Bool      // v4.0 Phase 3 #8: true=预筛快速分析(单PV精度), false=完整 multiPV

    // Codable 兼容：旧存档无 isQuickResult 字段时默认 false
    enum CodingKeys: String, CodingKey {
        case playerMove, quality, bestMove, bestEval, playerEval, evalDelta
        case alternatives, isQuickResult
    }

    init(playerMove: String, quality: MoveQuality, bestMove: String,
         bestEval: Int, playerEval: Int, evalDelta: Int,
         alternatives: [AnalysisLine], isQuickResult: Bool = false) {
        self.playerMove = playerMove
        self.quality = quality
        self.bestMove = bestMove
        self.bestEval = bestEval
        self.playerEval = playerEval
        self.evalDelta = evalDelta
        self.alternatives = alternatives
        self.isQuickResult = isQuickResult
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        playerMove = try c.decode(String.self, forKey: .playerMove)
        quality = try c.decode(MoveQuality.self, forKey: .quality)
        bestMove = try c.decode(String.self, forKey: .bestMove)
        bestEval = try c.decode(Int.self, forKey: .bestEval)
        playerEval = try c.decode(Int.self, forKey: .playerEval)
        evalDelta = try c.decode(Int.self, forKey: .evalDelta)
        alternatives = try c.decodeIfPresent([AnalysisLine].self, forKey: .alternatives) ?? []
        isQuickResult = try c.decodeIfPresent(Bool.self, forKey: .isQuickResult) ?? false
    }
}

// MARK: - PositionAnalyzer

/// 局面分析器（actor，线程安全）
///
/// 引擎实例策略（v4.1 Phase 7.3）：持有独立的 EmbeddedPikafishEngine 实例，
/// 不再通过 EngineRouter.shared 获取共享实例。
/// 原因：避免测试间 quit/init 循环导致全局 C 引擎搜索线程挂死。
/// 内存代价：测试期间两份引擎实例（pikafish + NNUE 约 50MB+），
/// 仅测试环境影响，打包 App 只有一个引擎实例。
actor PositionAnalyzer {

    static let shared = PositionAnalyzer()

    /// 引擎实例引用——复用 EngineRouter 的引擎，不创建独立实例
    /// C 层 g_engine 是全局单例，两个 EmbeddedPikafishEngine 实例共享同一个 C 引擎
    /// PositionAnalyzer 通过 EngineRouter 获取已初始化的引擎，不管理生命周期
    private func getEngine() async -> EmbeddedPikafishEngine? {
        // 先检查配置：未启用嵌入式引擎时不分析
        let useEmbedded = await MainActor.run {
            EngineConfigStore.shared.useEmbeddedEngine
        }
        guard useEmbedded else {
            NSLog("[PositionAnalyzer] Embedded engine disabled in config")
            return nil
        }

        // 通过 EngineRouter 确保引擎已启动
        let engine = await EngineRouter.shared.switchEngineIfNeeded()

        if let embedded = engine as? EmbeddedPikafishEngine, embedded.isReady {
            return embedded
        }

        NSLog("[PositionAnalyzer] Active engine is not EmbeddedPikafishEngine or not ready")
        return nil
    }

    // MARK: - 分析参数

    /// 分析搜索深度（比实战浅，快速返回）
    private let analysisDepth = 18
    /// 分析时间限制（毫秒）
    private let analysisTimeMs = 2000
    /// MultiPV 数量
    private let multiPVCount = 3

    // MARK: - 单局面分析

    /// 评估当前局面（单 PV）
    func evaluate(fen: String, moveHistory: [String] = []) async -> AnalysisLine? {
        guard let engine = await getEngine() else { return nil }
        return await engine.evaluate(
            fen: fen, moveHistory: moveHistory,
            depth: analysisDepth, timeMs: analysisTimeMs
        )
    }

    /// 获取多条候选走法（MultiPV）
    func topMoves(fen: String, moveHistory: [String] = [], count: Int = 3) async -> [AnalysisLine] {
        guard let engine = await getEngine() else { return [] }
        let n = min(count, multiPVCount)
        return await engine.multiPV(
            fen: fen, moveHistory: moveHistory,
            count: n, depth: analysisDepth, timeMs: analysisTimeMs
        )
    }

    // MARK: - 走法分类

    /// 根据评估差距分类走法质量
    ///
    /// - Parameters:
    ///   - playerMove: 玩家实际走法（UCI）
    ///   - bestMove: 引擎推荐最佳走法（UCI）
    ///   - bestEval: 最佳走法的评估值（cp）
    ///   - playerEval: 玩家走法后的评估值（cp）
    /// - Returns: 走法质量等级
    nonisolated func classifyMove(
        playerMove: String,
        bestMove: String,
        bestEval: Int,
        playerEval: Int
    ) -> MoveQuality {
        // 如果玩家走的就是最佳走法，直接精妙
        if playerMove == bestMove { return .brilliant }

        let delta = abs(bestEval - playerEval)
        switch delta {
        case 0...10:   return .brilliant
        case 11...50:  return .good
        case 51...100: return .normal
        case 101...300: return .doubtful
        case 301...700: return .blunder
        default:        return .losing
        }
    }

    // MARK: - v4.0 Phase 3 #8: 快速预筛

    /// 预筛结果（携带中间值，避免重复引擎调用）
    /// 注意：evalDelta/bestEval 基于单 PV 评估，精度低于完整 multiPV 分析。
    /// 预筛命中（isQuickResult=true）的 evalDelta 可能在 UI 上与完整分析结果有细微差异。
    struct QuickClassifyResult {
        let quality: MoveQuality
        let bestMove: String
        let bestEval: Int
        let adjustedPlayerEval: Int
        let evalDelta: Int
        let needFullAnalysis: Bool
    }

    /// 快速评估走法质量（单 PV，用于预筛）
    /// 返回: QuickClassifyResult（通过 needFullAnalysis 区分是否需要补 multiPV）
    func quickClassify(
        fenBefore: String,
        playerMove: String,
        moveHistory: [String] = []
    ) async -> QuickClassifyResult? {
        // 1. 评估走棋前局面
        guard let beforeLine = await evaluate(
            fen: fenBefore, moveHistory: moveHistory
        ) else { return nil }

        let bestMove = beforeLine.bestMove
        let bestEval = beforeLine.scoreCp

        // 2. 评估玩家走法后局面
        let afterHistory = moveHistory + [playerMove]
        guard let afterLine = await evaluate(
            fen: fenBefore, moveHistory: afterHistory
        ) else { return nil }

        let adjustedPlayerEval = -afterLine.scoreCp
        let delta = abs(bestEval - adjustedPlayerEval)

        // 3. 分类（与 classifyMove 阈值对齐）
        if playerMove == bestMove || delta <= 10 {
            // brilliant：预筛命中
            return QuickClassifyResult(
                quality: .brilliant, bestMove: bestMove, bestEval: bestEval,
                adjustedPlayerEval: adjustedPlayerEval, evalDelta: delta,
                needFullAnalysis: false
            )
        } else if delta < 30 {
            // good：预筛命中
            return QuickClassifyResult(
                quality: .good, bestMove: bestMove, bestEval: bestEval,
                adjustedPlayerEval: adjustedPlayerEval, evalDelta: delta,
                needFullAnalysis: false
            )
        }

        // delta >= 30cp：需要完整 multiPV
        return QuickClassifyResult(
            quality: .normal,  // 临时值，完整分析会覆盖
            bestMove: bestMove, bestEval: bestEval,
            adjustedPlayerEval: adjustedPlayerEval, evalDelta: delta,
            needFullAnalysis: true
        )
    }

    // MARK: - 完整单步分析

    /// 分析单步走法：局面 → 玩家走 → 结果
    ///
    /// v4.0 Phase 3 #8: 先快速预筛，好棋直接返回；需完整分析才补 multiPV
    ///
    /// - Parameters:
    ///   - fenBefore: 走棋前的局面 FEN
    ///   - playerMove: 玩家走法（UCI）
    ///   - moveHistory: 走法历史
    /// - Returns: 完整分析结果（包含质量、最佳走法、候选）
    func analyzeMove(
        fenBefore: String,
        playerMove: String,
        moveHistory: [String] = []
    ) async -> MoveAnalysis? {
        // === 第一步：快速预筛（2 次 evaluate）===
        guard let pre = await quickClassify(
            fenBefore: fenBefore,
            playerMove: playerMove,
            moveHistory: moveHistory
        ) else { return nil }

        // 预筛命中：直接返回（不再调引擎）
        if !pre.needFullAnalysis {
            return MoveAnalysis(
                playerMove: playerMove,
                quality: pre.quality,
                bestMove: pre.bestMove,
                bestEval: pre.bestEval,
                playerEval: pre.adjustedPlayerEval,
                evalDelta: pre.evalDelta,
                alternatives: [],
                isQuickResult: true
            )
        }

        // === 第二步：需要完整分析，补一次 multiPV（复用预筛的 adjustedPlayerEval）===
        let lines = await topMoves(fen: fenBefore, moveHistory: moveHistory, count: multiPVCount)

        // V-B7: multiPV 返回空时降级为预筛结果
        guard let bestLine = lines.first else {
            return MoveAnalysis(
                playerMove: playerMove,
                quality: pre.quality,
                bestMove: pre.bestMove,
                bestEval: pre.bestEval,
                playerEval: pre.adjustedPlayerEval,
                evalDelta: pre.evalDelta,
                alternatives: [],
                isQuickResult: true
            )
        }

        // multiPV 成功：用更深搜索的 bestEval，复用预筛的 playerEval
        let bestMove = bestLine.bestMove
        let bestEval = bestLine.scoreCp
        let adjustedPlayerEval = pre.adjustedPlayerEval

        let quality = classifyMove(
            playerMove: playerMove,
            bestMove: bestMove,
            bestEval: bestEval,
            playerEval: adjustedPlayerEval
        )

        return MoveAnalysis(
            playerMove: playerMove,
            quality: quality,
            bestMove: bestMove,
            bestEval: bestEval,
            playerEval: adjustedPlayerEval,
            evalDelta: abs(bestEval - adjustedPlayerEval),
            alternatives: lines,
            isQuickResult: false
        )
    }

    // MARK: - 轻量分析（MasterGameCommentator 专用）

    /// 轻量分析——用自定义参数（低于默认的 depth=18）
    /// 与 analyzeMove 共享同一引擎实例，通过 actor 串行化保证安全
    func analyzeMoveLite(
        fenBefore: String,
        playerMove: String,
        moveHistory: [String] = [],
        depth: Int,
        timeMs: Int,
        multiPVCount: Int
    ) async -> MoveAnalysis? {
        guard let engine = await getEngine() else { return nil }

        // 1. 评估走棋前局面
        guard let beforeLine = await engine.evaluate(
            fen: fenBefore, moveHistory: moveHistory,
            depth: depth, timeMs: timeMs
        ) else { return nil }

        let bestMove = beforeLine.bestMove
        let bestEval = beforeLine.scoreCp

        // 2. 评估玩家走法后局面
        let afterHistory = moveHistory + [playerMove]
        guard let afterLine = await engine.evaluate(
            fen: fenBefore, moveHistory: afterHistory,
            depth: depth, timeMs: timeMs
        ) else { return nil }

        let adjustedPlayerEval = -afterLine.scoreCp
        let delta = abs(bestEval - adjustedPlayerEval)

        // 3. 质量分级
        let quality: MoveQuality
        if playerMove == bestMove || delta <= 10 { quality = .brilliant }
        else if delta <= 50 { quality = .good }
        else if delta <= 100 { quality = .normal }
        else if delta <= 300 { quality = .doubtful }
        else if delta <= 700 { quality = .blunder }
        else { quality = .losing }

        // 4. 失误走法获取候选
        var alternatives: [AnalysisLine] = []
        if quality == .doubtful || quality == .blunder || quality == .losing {
            let n = min(multiPVCount, self.multiPVCount)
            alternatives = await engine.multiPV(
                fen: fenBefore, moveHistory: moveHistory,
                count: n, depth: depth, timeMs: timeMs
            )
        }

        return MoveAnalysis(
            playerMove: playerMove, quality: quality,
            bestMove: bestMove, bestEval: bestEval,
            playerEval: adjustedPlayerEval, evalDelta: delta,
            alternatives: alternatives, isQuickResult: true
        )
    }
}
