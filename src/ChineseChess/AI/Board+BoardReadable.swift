// Board+BoardReadable.swift — Board 扩展实现 BoardReadable 协议

extension Board: BoardReadable {
    // Board 已实现所有协议方法，无需额外代码
    // pieces / currentTurn / piece(at:) / pieces(for:) / generalPosition(of:) / hasPiece(at:)
    // 均已在 Board.swift 中定义，且访问级别匹配

    func makeSearchBoard() -> LegacySearchBoard {
        LegacySearchBoard(from: self)
    }
}
