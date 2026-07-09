import Foundation

// MARK: - v5.0 轻量局面快照

/// 轻量局面快照（脱离 @Observable，纯数据）
/// 用于 OpeningExplorerNode 存储 Board 状态，避免 @Observable 观察链开销。
/// 不含 moveHistory——开局探索不需要走法历史。
struct PositionSnapshot {
    let pieces: [Piece]       // 32 个 Piece 结构体
    let currentTurn: Side     // 当前走棋方

    /// 从 Board 创建快照
    init(board: Board) {
        self.pieces = board.pieces.map {
            Piece(kind: $0.kind, side: $0.side, position: $0.position, id: $0.id)
        }
        self.currentTurn = board.currentTurn
    }

    /// 直接构造
    init(pieces: [Piece], currentTurn: Side) {
        self.pieces = pieces
        self.currentTurn = currentTurn
    }
}
