import Foundation

// MARK: - 局面阶段判断

/// 棋局阶段
enum GamePhase: String {
    case opening   // 开局
    case middle    // 中局
    case endgame   // 残局
    case all       // 跨阶段（棋谚用）
}

/// 局面阶段检测器
enum PhaseDetector {

    /// 判断当前局面阶段
    /// - Parameters:
    ///   - moveNumber: 当前步数（从 0 开始）
    ///   - board: 当前棋盘
    /// - Returns: 阶段
    static func detect(moveNumber: Int, board: Board) -> GamePhase {
        let majorPieceCount = countMajorPieces(on: board)

        // 残局：35+ 步或剩余大子 ≤4
        if moveNumber >= 35 || majorPieceCount <= 4 {
            return .endgame
        }

        // 开局：1-15 步且双方子力完整
        if moveNumber < 15 && majorPieceCount >= 10 {
            return .opening
        }

        // 中局：其他
        return .middle
    }

    /// 大子数量（车马炮，双方合计）
    static func countMajorPieces(on board: Board) -> Int {
        board.pieces.filter {
            $0.kind == .chariot || $0.kind == .horse || $0.kind == .cannon
        }.count
    }
}
