import Foundation

// MARK: - DemoMoveConverter

/// 将 Puzzle.solution（ICCS 坐标格式）转换为 Board 可执行的 Move 序列
/// 解析失败时 continue 跳过该步，不 break 整个序列
struct DemoMoveConverter {

    /// 将 solution ICCS 字符串转换为 Move 列表
    /// - Parameters:
    ///   - solution: ICCS 格式走法数组（如 ["h2e2", "e9e8"]）
    ///   - initialBoard: 初始棋盘（用于逐步执行）
    /// - Returns: 合法的 Move 列表（跳过解析失败的步）
    static func convert(solution: [String], on initialBoard: Board) -> [Move] {
        var result: [Move] = []
        let board = initialBoard.snapshot()

        for (index, iccs) in solution.enumerated() {
            guard let move = ICCSParser.parse(iccs, on: board) else {
                #if DEBUG
                AppLog.puzzleStore.warning("DemoMoveConverter: 解析失败 step \(index + 1) '\(iccs)'，跳过")
                #endif
                continue
            }
            result.append(move)
            board.execute(move)
        }

        return result
    }

    // MARK: - 大师棋谱走法转换

    /// 转换结果（包含失败步数和完整性标记）
    struct ConvertResult {
        let moves: [Move]
        let failedSteps: Int      // 转换失败的步数
        let isComplete: Bool      // 是否全部转换成功
    }

    /// 将 GameRecord.moves (GameMove) 转换为 Board 可执行的 Move 序列
    /// 使用 ICCSParser 走和残局相同的解析路径，保证可靠性
    ///
    /// - Parameters:
    ///   - gameMoves: GameRecord 中的走法列表
    ///   - initialFEN: 初始 FEN
    /// - Returns: ConvertResult（成功转换的 Move 列表 + 是否有失败步）
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
