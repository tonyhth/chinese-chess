import Foundation
import Pikafish

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

    /// 显示标签（通过 L10n）
    func localizedLabel() -> String {
        L10n.shared.t(l10nKey)
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
}

// MARK: - PositionAnalyzer

/// 局面分析器（actor，线程安全）
///
/// 引擎实例策略：直接调用 C API（pikafish_eval / pikafish_multi_pv），
/// 复用 EmbeddedPikafishEngine 已初始化的全局引擎状态。
/// 分析请求通过 actor 串行化，避免与对弈的 bestMove 并发冲突。
actor PositionAnalyzer {

    static let shared = PositionAnalyzer()

    /// 通过 EngineRouter 确保嵌入式引擎已启动（含 NNUE 加载）
    /// 避免直接调 pikafish_init() 绕过 EmbeddedPikafishEngine
    private func ensureEngineReady() async {
        _ = await EngineRouter.shared.switchEngineIfNeeded()
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
        await ensureEngineReady()
        let movesStr = moveHistory.joined(separator: " ")
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = UnsafeMutablePointer<PikafishEvalResult>.allocate(capacity: 1)
                memset(result, 0, MemoryLayout<PikafishEvalResult>.size)
                defer { result.deallocate() }
                let ok = fen.withCString { fenCStr in
                    movesStr.withCString { movesCStr in
                        pikafish_eval(fenCStr, movesCStr, 0, 0, result)
                    }
                }
                if ok == 0 {
                    let bestMove = String(cString: UnsafeRawPointer(result).advanced(by: 8).assumingMemoryBound(to: CChar.self))
                    let pv = String(cString: UnsafeRawPointer(result).advanced(by: 24).assumingMemoryBound(to: CChar.self))
                    continuation.resume(returning: AnalysisLine(
                        scoreCp: Int(result.pointee.score_cp),
                        depth: Int(result.pointee.depth),
                        bestMove: bestMove,
                        pv: pv
                    ))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// 获取多条候选走法（MultiPV）
    func topMoves(fen: String, moveHistory: [String] = [], count: Int = 3) async -> [AnalysisLine] {
        await ensureEngineReady()
        let movesStr = moveHistory.joined(separator: " ")
        let n = min(count, multiPVCount)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let results = UnsafeMutablePointer<PikafishEvalResult>.allocate(capacity: n)
                // Zero-initialize via memset
                memset(results, 0, MemoryLayout<PikafishEvalResult>.size * n)
                defer { results.deallocate() }
                let actualCount = fen.withCString { fenCStr in
                    movesStr.withCString { movesCStr in
                        pikafish_multi_pv(fenCStr, movesCStr, Int32(n), 0, 0, results, Int32(n))
                    }
                }
                var lines: [AnalysisLine] = []
                let safeCount = max(0, Int(actualCount))
                for i in 0..<safeCount {
                    let basePtr = UnsafeRawPointer(results).advanced(by: MemoryLayout<PikafishEvalResult>.stride * i)
                    let bestMove = String(cString: basePtr.advanced(by: 8).assumingMemoryBound(to: CChar.self))
                    let pv = String(cString: basePtr.advanced(by: 24).assumingMemoryBound(to: CChar.self))
                    lines.append(AnalysisLine(
                        scoreCp: Int(results[i].score_cp),
                        depth: Int(results[i].depth),
                        bestMove: bestMove,
                        pv: pv
                    ))
                }
                continuation.resume(returning: lines)
            }
        }
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

    // MARK: - 完整单步分析

    /// 分析单步走法：局面 → 玩家走 → 结果
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
        // 1. 分析走棋前的局面（获取最佳走法 + multiPV）
        let lines = await topMoves(fen: fenBefore, moveHistory: moveHistory, count: multiPVCount)
        guard let bestLine = lines.first else { return nil }

        let bestMove = bestLine.bestMove
        let bestEval = bestLine.scoreCp

        // 2. 分析玩家走法后的局面
        let afterHistory = moveHistory + [playerMove]
        // 走棋后的 FEN 需要引擎计算（我们通过 eval 获取）
        let playerLine = await evaluate(fen: fenBefore, moveHistory: afterHistory)
        // playerEval：走棋后对方视角的评估（需要取反，因为 FEN 评估是当前行棋方）
        // 但实际上，pikafish_eval 返回的是走完后的局面评估，已自动切换视角
        // 这里用 before + afterHistory 的评估来推算
        let playerEval = playerLine?.scoreCp ?? bestEval

        // P0: playerEval 是走完后的局面评估，视角已翻转到对手，需要取反
        let adjustedPlayerEval = -playerEval

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
            alternatives: lines
        )
    }
}
