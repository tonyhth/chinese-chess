import Foundation

/// ICCS 坐标解析共享工具
/// ICCS 格式：[a-i][0-9][a-i][0-9]，如 "h2e2"
/// 列 a-i 对应 col 0-8，行 0-9（0=黑方底线=row 9）
struct ICCSParser {

    /// 将 ICCS 格式字符串解析为 Move
    /// - Parameters:
    ///   - iccs: ICCS 格式走法（如 "h2e2"）
    ///   - board: 当前棋盘状态
    /// - Returns: 合法的 Move，或 nil
    static func parse(_ iccs: String, on board: Board) -> Move? {
        guard iccs.count == 4 else { return nil }
        let chars = Array(iccs)

        guard let fromCol = colFromChar(chars[0]),
              let fromRow = rowFromChar(chars[1]),
              let toCol = colFromChar(chars[2]),
              let toRow = rowFromChar(chars[3]) else { return nil }

        let from = Position(row: fromRow, col: fromCol)
        let to = Position(row: toRow, col: toCol)

        guard let piece = board.piece(at: from) else { return nil }
        let captured = board.piece(at: to)
        let move = Move(piece: piece, from: from, to: to, captured: captured)

        guard MoveValidator.isLegal(move, on: board) else { return nil }
        return move
    }

    /// 将 Position 转为 ICCS 字符串
    static func iccsString(from: Position, to: Position) -> String {
        let files = "abcdefghi"
        let fromStr = "\(files[files.index(files.startIndex, offsetBy: from.col)])\(9 - from.row)"
        let toStr = "\(files[files.index(files.startIndex, offsetBy: to.col)])\(9 - to.row)"
        return "\(fromStr)\(toStr)"
    }

    // MARK: - Private

    private static func colFromChar(_ c: Character) -> Int? {
        guard let ascii = c.asciiValue, ascii >= UInt8(ascii: "a"), ascii <= UInt8(ascii: "i") else { return nil }
        return Int(ascii - UInt8(ascii: "a"))
    }

    private static func rowFromChar(_ c: Character) -> Int? {
        guard let ascii = c.asciiValue, ascii >= UInt8(ascii: "0"), ascii <= UInt8(ascii: "9") else { return nil }
        return 9 - Int(ascii - UInt8(ascii: "0"))
    }
}
