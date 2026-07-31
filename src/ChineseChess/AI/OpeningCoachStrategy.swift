import Foundation

// MARK: - Phase B3 Step 2: AI 开局配合走法策略

/// AI 开局配合走法策略
///
/// 三级策略（P0-3 修正）：
/// 1. 前 N 步（firstMoves 覆盖范围内）：严格按 firstMoves 序列走
/// 2. N 步之后、仍有书谱候选：从 OpeningBook 候选中选招（按权重随机）
/// 3. 无书谱候选：回退正常 AI
///
/// 步数计数器由 nextAIMove() 内部统一管理，调用方无需手动递增：
/// - 每次调用 nextAIMove() 时，自动计入用户的前置走法 + AI 的走法
/// - 唯一例外：AI 先手时（用户执黑），首次调用不计算前置用户走法
final class OpeningCoachStrategy {

    /// 目标开局子分类
    let targetSubcategory: OpeningSubcategory
    /// 开局库
    let book: OpeningBook
    /// 用户执哪方
    let playerSide: Side

    /// 总步数计数器（双方合计），用于跟踪 firstMoves 的进度
    private var totalStepIndex = 0

    /// 最大开局步数（超过则判定开局结束）
    private let maxSteps = 20

    init(targetSubcategory: OpeningSubcategory, book: OpeningBook = .shared, playerSide: Side) {
        self.targetSubcategory = targetSubcategory
        self.book = book
        self.playerSide = playerSide
    }

    // MARK: - AI 走法获取

    /// 获取 AI 应走的走法
    ///
    /// 步数计数器内部统一管理：
    /// - 用户执红时：每次调用先计入用户的前置走法（+1），再计入 AI 走法（+1）
    /// - 用户执黑时：首次调用 AI 先手，无前置用户走法，只计入 AI 走法（+1）
    /// - 后续调用均计入前置用户走法 + AI 走法
    ///
    /// firstMoves 索引映射：
    ///   index 0 = 红第1步, 1 = 黑第1步, 2 = 红第2步, 3 = 黑第2步, ...
    ///
    /// - Parameter currentFEN: 当前局面 FEN
    /// - Returns: AI 应走的走法（ICCS），nil 表示开局结束
    func nextAIMove(currentFEN: String) -> String? {
        // 计入用户的前置走法
        // 唯一例外：用户执黑时首次调用（AI 先手），totalStepIndex==0 且用户还没走
        if !(totalStepIndex == 0 && playerSide == .black) {
            totalStepIndex += 1
        }

        let aiStepIndex = totalStepIndex

        // 超过最大步数，开局结束
        guard aiStepIndex < maxSteps else { return nil }

        // 策略 1：firstMoves 覆盖范围内，严格按序列走
        if aiStepIndex < targetSubcategory.firstMoves.count {
            let move = targetSubcategory.firstMoves[aiStepIndex]
            // 合法性校验：如果 firstMoves 中的走法在当前局面不合法，回退到策略 2
            if isLegalMove(move, in: currentFEN) {
                totalStepIndex += 1
                return move
            }
            // 不合法 → 用户已脱谱，回退到策略 2
        }

        // 策略 2：超出 firstMoves 范围或 firstMoves 走法不合法，查 OpeningBook
        guard let board = FENParser.parse(fen: currentFEN) else { return nil }
        let zobrist = ZobristHash.hash(board: board)
        if let candidates = book.lookupAll(zobristHash: zobrist), !candidates.isEmpty {
            totalStepIndex += 1
            // 按权重随机选招（保证重复练习有变化）
            return weightedRandomPick(candidates)
        }

        // 策略 3：无书谱候选，开局结束
        return nil
    }

    /// 当前是否仍在 firstMoves 覆盖范围内
    var isInFirstMovesRange: Bool {
        totalStepIndex < targetSubcategory.firstMoves.count
    }

    // MARK: - 走法合法性校验

    /// 检查走法在当前 FEN 是否合法
    private func isLegalMove(_ move: String, in fen: String) -> Bool {
        guard let board = FENParser.parse(fen: fen) else { return false }
        guard let parsedMove = ICCSParser.parse(move, on: board) else { return false }
        let legalMoves = MoveValidator.legalMoves(for: parsedMove.piece, on: board)
        return legalMoves.contains(where: { $0.from == parsedMove.from && $0.to == parsedMove.to })
    }

    // MARK: - 权重随机选择

    /// 按权重随机选一个候选走法
    private func weightedRandomPick(_ candidates: [(move: String, weight: Int)]) -> String {
        let totalWeight = candidates.reduce(0) { $0 + $1.weight }
        var r = Int.random(in: 0..<totalWeight)
        for candidate in candidates {
            r -= candidate.weight
            if r < 0 { return candidate.move }
        }
        return candidates[0].move
    }
}
