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
    static func search(board: LegacySearchBoard, for side: Side, maxDepth: Int, timeLimitMs: Int? = nil) -> [Move]? {
        var mutableBoard = board
        let startTime = Date()
        var path: [Move] = []
        if dfs(board: &mutableBoard, side: side, depth: 0, maxDepth: maxDepth, path: &path, startTime: startTime, timeLimitMs: timeLimitMs) {
            // dfs 使用后序追加（深层先 append），反转后才是从根节点出发的正确顺序
            return path.reversed()
        }
        return nil
    }

    /// 内部递归：只扩展将军走法
    /// 逻辑：对 side 的每个将军走法，执行后检查对方是否被将死。
    /// 如果对方无合法走法 → 将死，返回成功。
    /// 如果对方有合法走法 → 必须所有应将走法后我方都能赢，才算强制将杀。
    ///
    /// ⚠️ 不用 defer：for 循环中 defer 延迟到函数退出，不在迭代结束时触发。
    /// 每个分支必须手动 board.undoLastMove()。
    private static func dfs(
        board: inout LegacySearchBoard, side: Side, depth: Int, maxDepth: Int,
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
            board.undoLastMove()
            return inCheck
        }

        for move in checkMoves {
            board.execute(move)

            // 检查对方是否被将死
            let opponentMoves = MoveValidator.allLegalMoves(for: opponent, on: board)
            if opponentMoves.isEmpty {
                // 对方无合法走法 = 将死（因为对方正在被将军）
                path.append(move)
                board.undoLastMove()
                return true
            }

            // 对方有应将走法：必须验证所有应将后我方都能赢，才是强制将杀
            let maxResponses = 8
            let opponentMovesToCheck: [Move]
            if opponentMoves.count > maxResponses {
                opponentMovesToCheck = Array(opponentMoves.sorted { moveScore($0, on: board) > moveScore($1, on: board) }.prefix(maxResponses))
            } else {
                opponentMovesToCheck = opponentMoves
            }

            var allResponsesWin = true
            for response in opponentMovesToCheck {
                board.execute(response)
                if !dfs(board: &board, side: side, depth: depth + 2, maxDepth: maxDepth,
                         path: &path, startTime: startTime, timeLimitMs: timeLimitMs) {
                    allResponsesWin = false
                    board.undoLastMove()
                    break
                }
                board.undoLastMove()
            }

            if allResponsesWin {
                path.append(move)
                board.undoLastMove()
                return true
            }

            board.undoLastMove()
        }

        return false
    }

    /// 应将走法简单排序评分：吃子优先、走向己方九宫附近优先、阻挡攻击线加分。
    private static func moveScore(_ move: Move, on board: LegacySearchBoard) -> Int {
        var score = 0
        // 吃子加分
        if let captured = move.captured {
            score += captured.baseValue
        }
        // 走向己方将帅附近加分（保护倾向）
        if let gp = board.generalPosition(of: move.piece.side) {
            let dist = abs(move.to.row - gp.row) + abs(move.to.col - gp.col)
            score += max(0, 6 - dist) * 20
        }
        // 阻挡对方攻击己方将帅的攻击线加分
        let attackerSide: Side = (move.piece.side == .red) ? .black : .red
        if let gp = board.generalPosition(of: move.piece.side) {
            let attackerPieces = board.pieces(for: attackerSide)
            for attacker in attackerPieces {
                guard attacker.kind == .chariot || attacker.kind == .cannon else { continue }
                let ap = attacker.position
                // 必须与将帅在同一行或同一列
                guard ap.row == gp.row || ap.col == gp.col else { continue }
                // 走法目标必须在攻击者和将帅之间
                guard isBetween(move.to, attacker: ap, general: gp) else { continue }
                // 统计攻击者与将帅之间的棋子数
                let betweenCount = countPiecesBetween(ap, gp, on: board)
                if attacker.kind == .chariot && betweenCount == 0 {
                    score += 60
                } else if attacker.kind == .cannon && betweenCount == 1 {
                    score += 30
                }
            }
        }
        return score
    }

    /// 检查 point 是否在 attacker 和 general 之间（同一行或同一列，不含两端）
    private static func isBetween(_ point: Position, attacker: Position, general: Position) -> Bool {
        if attacker.row == general.row {
            let minCol = min(attacker.col, general.col)
            let maxCol = max(attacker.col, general.col)
            return point.row == attacker.row && point.col > minCol && point.col < maxCol
        } else if attacker.col == general.col {
            let minRow = min(attacker.row, general.row)
            let maxRow = max(attacker.row, general.row)
            return point.col == attacker.col && point.row > minRow && point.row < maxRow
        }
        return false
    }

    /// 计算两个位置之间（不含两端）的棋子数量（仅限同行或同列）
    private static func countPiecesBetween(_ a: Position, _ b: Position, on board: LegacySearchBoard) -> Int {
        var count = 0
        if a.row == b.row {
            let minCol = min(a.col, b.col) + 1
            let maxCol = max(a.col, b.col)
            for c in minCol..<maxCol {
                if board.piece(at: Position(row: a.row, col: c)) != nil {
                    count += 1
                }
            }
        } else if a.col == b.col {
            let minRow = min(a.row, b.row) + 1
            let maxRow = max(a.row, b.row)
            for r in minRow..<maxRow {
                if board.piece(at: Position(row: r, col: a.col)) != nil {
                    count += 1
                }
            }
        }
        return count
    }
}
