import Foundation

// MARK: - FEN 精确推算

/// 从走法序列精确推算任意步骤的 FEN
/// 使用 `board.piece(at: gm.from) ?? gm.piece` 做 fallback
struct FENRebuilder {

    /// 推算第 index 步走棋前的 FEN
    /// - Parameters:
    ///   - initialFEN: 初始局面 FEN
    ///   - moves: 走法列表
    ///   - before: 走法索引（0 = 第一步走棋前 = 初始局面）
    /// - Returns: 第 index 步走棋前的 FEN
    static func computeFEN(initialFEN: String, moves: [GameMove], before index: Int) -> String {
        guard index >= 0 && index <= moves.count else { return initialFEN }
        if index == 0 { return initialFEN }

        let board = Board(fen: initialFEN)

        // P2-3: 如果 FEN 无效，Board 会静默回退到标准开局，记录警告
        if !FENParser.isStandardInitial(initialFEN) && FENParser.parse(fen: initialFEN) == nil {
            #if DEBUG
            AppLog.history.warning("FENRebuilder: invalid FEN '\(initialFEN)', fallback to standard initial")
            #endif
        }

        for i in 0..<index {
            let gm = moves[i]
            let piece = board.piece(at: gm.from) ?? gm.piece
            let captured = board.piece(at: gm.to)
            let move = Move(piece: piece, from: gm.from, to: gm.to, captured: captured)
            board.execute(move)
        }
        return FENParser.generate(board: board)
    }

    /// 批量推算：生成每步走棋前后的 FEN 列表
    /// - Returns: FEN 数组，[0] = initialFEN, [1] = 第一步走后, ...
    static func computeAllFENs(initialFEN: String, moves: [GameMove]) -> [String] {
        var board = Board(fen: initialFEN)

        // P2-3: 如果 FEN 无效，Board 会静默回退到标准开局，记录警告
        if !FENParser.isStandardInitial(initialFEN) && FENParser.parse(fen: initialFEN) == nil {
            #if DEBUG
            AppLog.history.warning("FENRebuilder: invalid FEN '\(initialFEN)', fallback to standard initial")
            #endif
        }

        var fens = [initialFEN]
        for gm in moves {
            let piece = board.piece(at: gm.from) ?? gm.piece
            let captured = board.piece(at: gm.to)
            let move = Move(piece: piece, from: gm.from, to: gm.to, captured: captured)
            board.execute(move)
            fens.append(FENParser.generate(board: board))
        }
        return fens
    }
}
