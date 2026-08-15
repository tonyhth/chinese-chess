// BoardReadable.swift — 棋盘只读查询协议

/// 棋盘只读查询协议。Board、LegacySearchBoard、SearchBoardV2 均实现。
/// 用于评估器、ZobristHash、MoveValidator 纯读判定等泛型模块，消除搜索路径的 Board 类型依赖。
///
/// **M1 Phase 2b（m1-hotpath-redesign v1.2 §2.4，v1.1/P0-1）**：
/// makeSearchBoard 已移出本协议（返回 Legacy 具体类型的转换操作不属于纯读面），
/// 收敛至窄协议 SearchBoardConvertible——SearchBoardV2 明确不实现，
/// 拷贝式合法化路径在类型层面进不了 V2。
protocol BoardReadable {
    var pieces: [Piece] { get }
    var currentTurn: Side { get }
    var moveHistory: [Move] { get }

    func piece(at pos: Position) -> Piece?
    func pieces(for side: Side) -> [Piece]
    func generalPosition(of side: Side) -> Position?
    func hasPiece(at pos: Position) -> Bool
}

/// 拷贝式合法化路径专用转换协议（v1.2 §2.4）。
/// Board 与 LegacySearchBoard 实现；**SearchBoardV2 明确不实现**——
/// MoveValidator.wouldBeInCheck / MoveOrderer.givesCheck 依赖此协议，
/// V2 的走法来源是 MoveGenerator 伪合法生成（§2.6），不走拷贝式合法化。
protocol SearchBoardConvertible: BoardReadable {
    func makeSearchBoard() -> LegacySearchBoard
}
