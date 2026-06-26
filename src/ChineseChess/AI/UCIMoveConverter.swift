import Foundation

// MARK: - UCI 走法转换工具

/// UCI 走法格式：4 字符，如 "h2e2" = 从 col=7,row=2 到 col=4,row=2
///
/// 列映射：a-i → col 0-8
/// 行映射（UCI 协议约定）：
///   - UCI 数字 0 = 红方底线（游戏内 row 9）
///   - UCI 数字 9 = 黑方底线（游戏内 row 0）
/// 因此需要翻转：gameRow = 9 - uciRow
///
/// 修复历史：v2.2.x 初期实现未翻转行坐标，导致 external engine 返回的走法
///           被错误解析（棋子位置偏移），现已修复。
///
/// FEN 生成/解析复用现有 FENParser.generate(board:) / FENParser.parse(fen:)。
enum UCIMoveConverter {

    // MARK: - Move → UCI

    /// Move → UCI 走法字符串（如 "h2e2"）
    static func uciString(from move: Move) -> String {
        // 游戏内 row → UCI row：翻转
        return "\(colToChar(move.from.col))\(9 - move.from.row)\(colToChar(move.to.col))\(9 - move.to.row)"
    }

    // MARK: - UCI → Position pair

    /// UCI 走法字符串 → (from, to) 坐标对
    static func positions(from uci: String) -> (Position, Position)? {
        guard uci.count == 4 else { return nil }
        let chars = Array(uci)
        guard let fromCol = charToCol(chars[0]),
              let toCol = charToCol(chars[2]),
              let fromRow = chars[1].wholeNumberValue,
              let toRow = chars[3].wholeNumberValue,
              fromRow >= 0, fromRow <= 9,
              toRow >= 0, toRow <= 9 else { return nil }
        // UCI row → 游戏内 row：翻转
        return (Position(row: 9 - fromRow, col: fromCol), Position(row: 9 - toRow, col: toCol))
    }

    // MARK: - UCI → Move

    /// UCI 走法字符串 → 完整 Move 对象（在 board 上查找棋子和被吃棋子）
    static func move(from uci: String, on board: Board) -> Move? {
        guard let (from, to) = positions(from: uci) else { return nil }
        guard let piece = board.piece(at: from) else { return nil }
        let captured = board.piece(at: to)
        return Move(piece: piece, from: from, to: to, captured: captured)
    }

    // MARK: - FEN + UCI moves → Board

    /// FEN + UCI moves → Board（解析 FEN 后依次执行走法）
    static func board(from fen: String, moves: [String] = []) -> Board? {
        guard let board = FENParser.parse(fen: fen) else { return nil }
        for uci in moves {
            guard let move = self.move(from: uci, on: board) else { return nil }
            board.execute(move)
        }
        return board
    }

    // MARK: - Private

    private static func colToChar(_ col: Int) -> Character {
        let a = Int(("a" as Character).asciiValue!)
        return Character(UnicodeScalar(a + col)!)
    }

    private static func charToCol(_ char: Character) -> Int? {
        guard let ascii = char.asciiValue, ascii >= 0x61, ascii <= 0x69 else { return nil }
        return Int(ascii) - 0x61
    }
}
