import Foundation

// MARK: - UCI 走法转换工具

/// UCI 走法格式：4 字符，如 "h2e2" = 从 col=7,row=2 到 col=4,row=2
///
/// 列映射：a-i → col 0-8
/// 行映射：'0'-'9' → row 0-9（0 = 黑方底线，9 = 红方底线）
///
/// FEN 生成/解析复用现有 FENParser.generate(board:) / FENParser.parse(fen:)。
enum UCIMoveConverter {

    // MARK: - Move → UCI

    /// Move → UCI 走法字符串（如 "h2e2"）
    static func uciString(from move: Move) -> String {
        return "\(colToChar(move.from.col))\(move.from.row)\(colToChar(move.to.col))\(move.to.row)"
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
        return (Position(row: fromRow, col: fromCol), Position(row: toRow, col: toCol))
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
