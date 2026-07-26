import Foundation

// MARK: - DemoMoveConverter

/// 将 Puzzle.solution（ICCS 坐标格式）转换为 Board 可执行的 Move 序列
/// 解析失败时立即终止，避免 Board 状态偏移导致后续步级联错误
struct DemoMoveConverter {

    /// 转换结果（包含失败步数和完整性标记）
    struct ConvertResult {
        let moves: [Move]
        let failedSteps: Int      // 转换失败的步数
        let isComplete: Bool      // 是否全部转换成功
    }

    /// 将 solution ICCS 字符串转换为 Move 列表
    /// - Parameters:
    ///   - solution: ICCS 格式走法数组（如 ["h2e2", "e9e8"]）
    ///   - initialBoard: 初始棋盘（用于逐步执行）
    /// - Returns: ConvertResult（成功转换的 Move 列表 + 是否有失败步）
    ///
    /// 解析失败时立即终止（不跳过），原因同 convertGameMoves：
    /// 跳过一步会导致 Board 状态偏移，后续所有步级联错误。
    static func convert(solution: [String], on initialBoard: Board) -> ConvertResult {
        var result: [Move] = []
        let board = initialBoard.snapshot()

        for (index, iccs) in solution.enumerated() {
            guard let move = ICCSParser.parse(iccs, on: board) else {
                #if DEBUG
                AppLog.puzzleStore.warning("DemoMoveConverter: 解析失败 step \(index + 1) '\(iccs)'，立即终止")
                #endif
                let failedSteps = solution.count - index
                return ConvertResult(moves: result, failedSteps: failedSteps, isComplete: false)
            }
            result.append(move)
            board.execute(move)
        }

        return ConvertResult(moves: result, failedSteps: 0, isComplete: true)
    }

    /// 便利方法：返回纯 Move 列表（向后兼容，丢弃完整性信息）
    static func convertMoves(solution: [String], on initialBoard: Board) -> [Move] {
        convert(solution: solution, on: initialBoard).moves
    }

    static func convertGameMoves(_ gameMoves: [GameMove], initialFEN: String) -> ConvertResult {
        var result: [Move] = []
        var failedSteps = 0
        let board = Board(fen: initialFEN)

        for (index, gameMove) in gameMoves.enumerated() {
            // 关键：走 ICCSParser 路径，和 Puzzle.solution 完全一致
            let iccs = gameMove.uciNotation  // ICCS 格式如 "h2e2"
            guard let move = ICCSParser.parse(iccs, on: board) else {
                // 转换失败立即终止，不做"跳过继续"
                // 原因：跳过一步会导致 Board 状态偏移，后续所有步级联错误
                failedSteps = gameMoves.count - index
                return ConvertResult(moves: result, failedSteps: failedSteps, isComplete: false)
            }
            result.append(move)
            board.execute(move)
        }

        return ConvertResult(moves: result, failedSteps: 0, isComplete: true)
    }
}
