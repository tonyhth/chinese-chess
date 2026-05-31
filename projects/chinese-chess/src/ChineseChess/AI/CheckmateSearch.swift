import Foundation

// MARK: - 连将杀搜索

/// 搜索"连续将军"的走法序列。
/// 只扩展将军走法，搜索空间远小于全搜索，可深入 6-8 层。
struct CheckmateSearch {

    /// 搜索连将杀。返回杀法走法序列（如果找到），否则 nil。
    /// - Parameters:
    ///   - board: 当前局面（不会被修改）
    ///   - side: 进攻方（执行将军的一方）
    ///   - maxDepth: 最大搜索深度（半步数）
    ///   - timeLimitMs: 超时毫秒数，nil 表示不限制
    /// - Returns: 杀法走法序列，从进攻方的第一步将军开始
    static func search(board: Board, for side: Side, maxDepth: Int, timeLimitMs: Int? = nil) -> [Move]? {
        let startTime = Date()
        var path: [Move] = []
        if dfs(board: board, side: side, depth: 0, maxDepth: maxDepth, path: &path, startTime: startTime, timeLimitMs: timeLimitMs) {
            return path
        }
        return nil
    }

    /// 内部递归：只扩展将军走法（基础版）
    /// 逻辑：对 side 的每个将军走法，执行后检查对方是否被将死。
    /// 如果对方无合法走法 → 将死，返回成功。
    /// 如果对方有合法走法 → 对每个应将走法，递归继续搜 side 的将军走法。
    /// 基础版中只要找到"存在一条将军链导致将死"即返回，不验证所有应将分支。
    private static func dfs(
        board: Board, side: Side, depth: Int, maxDepth: Int,
        path: inout [Move], startTime: Date, timeLimitMs: Int?
    ) -> Bool {
        // 超时检查
        if let limit = timeLimitMs {
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
            if elapsed > limit { return false }
        }

        // 深度限制
        guard depth < maxDepth else { return false }

        let opponent: Side = (side == .red) ? .black : .red
        let moves = MoveValidator.allLegalMoves(for: side, on: board)

        // 只考虑将军走法
        let checkMoves = moves.filter { move in
            board.execute(move)
            let inCheck = MoveValidator.isInCheck(opponent, on: board)
            _ = board.undoLastMove()
            return inCheck
        }

        for move in checkMoves {
            path.append(move)
            board.execute(move)

            // 检查对方是否被将死
            let opponentMoves = MoveValidator.allLegalMoves(for: opponent, on: board)
            if opponentMoves.isEmpty {
                // 对方无合法走法 = 将死（因为对方正在被将军）
                _ = board.undoLastMove()
                return true
            }

            // 对方有应将走法：尝试所有应将，找到任意一条我方成功的路径
            // 基础版：只找存在一条成功线，不要求所有应将都成功
            var foundWin = false
            for response in opponentMoves {
                board.execute(response)
                if dfs(board: board, side: side, depth: depth + 2, maxDepth: maxDepth,
                       path: &path, startTime: startTime, timeLimitMs: timeLimitMs) {
                    foundWin = true
                    _ = board.undoLastMove()
                    break
                }
                _ = board.undoLastMove()
            }

            if foundWin {
                _ = board.undoLastMove()
                return true
            }

            _ = board.undoLastMove()
            path.removeLast()
        }

        return false
    }
}
