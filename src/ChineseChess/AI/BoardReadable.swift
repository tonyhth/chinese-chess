// BoardReadable.swift — 棋盘只读查询协议

/// 棋盘只读查询协议。Board 和 LegacySearchBoard 均实现。
/// 用于 MoveValidator、评估器等模块的泛型参数，消除搜索路径上的 Board 类型依赖。
protocol BoardReadable {
    var pieces: [Piece] { get }
    var currentTurn: Side { get }
    var moveHistory: [Move] { get }

    func piece(at pos: Position) -> Piece?
    func pieces(for side: Side) -> [Piece]
    func generalPosition(of side: Side) -> Position?
    func hasPiece(at pos: Position) -> Bool

    /// 创建可修改的副本（用于 wouldBeInCheck 等需要执行/撤销走法的场景）
    func makeSearchBoard() -> LegacySearchBoard
}
