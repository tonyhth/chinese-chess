import Foundation

// MARK: - 走法排序

/// 对候选走法排序，提升 Alpha-Beta 剪枝效率。
/// 优先级：置换表最佳走法 > 将军 > 吃子(MVV-LVA) > 其他
struct MoveOrderer {

    /// 排序走法列表
    /// - Parameters:
    ///   - moves: 候选走法
    ///   - board: 当前棋盘
    ///   - ttBestMove: 置换表中的最佳走法（如有）
    ///   - checkLegal: 是否启用将军排序（depth >= 3 时启用，低深度开销大）
    static func order(_ moves: [Move], on board: Board, ttBestMove: Move? = nil, checkLegal: Bool = false) -> [Move] {
        let ttMove = ttBestMove

        return moves.map { move in
            var score = 0

            // 0. 置换表最佳走法（最高优先级）
            if let ttMove = ttMove, move.piece.id == ttMove.piece.id && move.from == ttMove.from && move.to == ttMove.to {
                score += 100000
            }

            // 1. 将军走法（仅 depth >= 3 时启用，避免低深度的 execute 开销）
            if checkLegal && givesCheck(move, on: board) {
                score += 50000
            }

            // 2. 吃子 MVV-LVA (Most Valuable Victim - Least Valuable Attacker)
            if let captured = move.captured {
                score += 10000 + captured.baseValue * 10 - move.piece.baseValue
            }

            // 3. 威胁子力（走到目标位置后能威胁对方高价值棋子）
            score += threatBonus(for: move, on: board)

            return (move, score)
        }
        .sorted { $0.1 > $1.1 }
        .map { $0.0 }
    }

    // MARK: - 将军检测

    /// 判断走法是否会导致将军
    private static func givesCheck(_ move: Move, on board: Board) -> Bool {
        let snapshot = board.snapshot()
        snapshot.execute(move)
        let opponentSide: Side = (move.piece.side == .red) ? .black : .red
        return MoveValidator.isInCheck(opponentSide, on: snapshot)
    }

    // MARK: - 威胁子力加分

    /// 走到目标位置后能威胁对方高价值棋子的加分
    private static func threatBonus(for move: Move, on board: Board) -> Int {
        let opponentSide: Side = (move.piece.side == .red) ? .black : .red
        let opponentPieces = board.pieces.filter { $0.side == opponentSide && $0.kind != .general }

        // 简化版：只看车、炮、马的潜在威胁，不做完整走法生成
        var bonus = 0
        switch move.piece.kind {
        case .chariot:
            // 车威胁同行/同列的高价值子
            for target in opponentPieces where target.baseValue >= 300 {
                if target.position.row == move.to.row || target.position.col == move.to.col {
                    bonus += target.baseValue / 5
                }
            }
        case .cannon:
            // 炮威胁同列高价值子（简化：不计算翻山）
            for target in opponentPieces where target.baseValue >= 300 {
                if target.position.col == move.to.col || target.position.row == move.to.row {
                    bonus += target.baseValue / 10
                }
            }
        case .horse:
            // 马威胁日字形位置的高价值子
            let horseMoves = [(2,1),(2,-1),(-2,1),(-2,-1),(1,2),(1,-2),(-1,2),(-1,-2)]
            for (dr, dc) in horseMoves {
                let tr = move.to.row + dr, tc = move.to.col + dc
                if let target = opponentPieces.first(where: { $0.position.row == tr && $0.position.col == tc }) {
                    bonus += target.baseValue / 5
                }
            }
        default:
            break
        }
        return min(bonus, 5000)  // 上限
    }
}
