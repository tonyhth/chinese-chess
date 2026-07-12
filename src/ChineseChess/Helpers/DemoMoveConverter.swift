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
}
