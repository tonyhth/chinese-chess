import Foundation

/// ICCS 坐标解析共享工具
/// ICCS 格式：[a-i][0-9][a-i][0-9]，如 "h2e2"
/// 列 a-i 对应 col 0-8，行 0-9（0=黑方底线=row 9）
struct ICCSParser {

    /// 将 ICCS 格式字符串解析为 Move
    /// - Parameters:
    ///   - iccs: ICCS 格式走法，支持两种格式：
    ///     - 字母格式："h2e2"（列a-i + 行0-9）
    ///     - 数字格式："5450"（row + col + row + col）
    ///   - board: 当前棋盘状态
    /// - Returns: 合法的 Move，或 nil
    static func parse<T: SearchBoardConvertible>(_ iccs: String, on board: T) -> Move? {
        guard iccs.count == 4 else { return nil }
        let chars = Array(iccs)

        let isNumeric = chars.allSatisfy { $0.isNumber }
        let fromCol: Int, fromRow: Int, toCol: Int, toRow: Int

        if isNumeric {
            // 数字格式："5450" → from(row=5, col=4) to(row=5, col=0)
            guard let fR = Int(String(chars[0])), let fC = Int(String(chars[1])),
                  let tR = Int(String(chars[2])), let tC = Int(String(chars[3])) else { return nil }
            fromRow = fR; fromCol = fC; toRow = tR; toCol = tC
        } else {
            // 字母格式："h2e2" → colFromChar + rowFromChar
            guard let fC = colFromChar(chars[0]), let fR = rowFromChar(chars[1]),
                  let tC = colFromChar(chars[2]), let tR = rowFromChar(chars[3]) else { return nil }
            fromRow = fR; fromCol = fC; toRow = tR; toCol = tC
        }

        let from = Position(row: fromRow, col: fromCol)
        let to = Position(row: toRow, col: toCol)

        guard let piece = board.piece(at: from) else { return nil }
        let captured = board.piece(at: to)
        let move = Move(piece: piece, from: from, to: to, captured: captured)

        guard MoveValidator.isLegal(move, on: board) else { return nil }
        return move
    }

    /// 将 Position 转为 ICCS 字符串（字母格式，向后兼容）
    static func iccsString(from: Position, to: Position) -> String {
        let files = "abcdefghi"
        let fromStr = "\(files[files.index(files.startIndex, offsetBy: from.col)])\(9 - from.row)"
        let toStr = "\(files[files.index(files.startIndex, offsetBy: to.col)])\(9 - to.row)"
        return "\(fromStr)\(toStr)"
    }

    /// 将 Position 转为数字 ICCS 字符串（"5450" 格式）
    static func numericIccsString(from: Position, to: Position) -> String {
        return "\(from.row)\(from.col)\(to.row)\(to.col)"
    }

    /// 检测 ICCS 字符串是否为数字格式
    static func isNumeric(_ iccs: String) -> Bool {
        return iccs.count == 4 && iccs.allSatisfy { $0.isNumber }
    }

    // MARK: - Private

    static func colFromChar(_ c: Character) -> Int? {
        guard let ascii = c.asciiValue, ascii >= UInt8(ascii: "a"), ascii <= UInt8(ascii: "i") else { return nil }
        return Int(ascii - UInt8(ascii: "a"))
    }

    static func rowFromChar(_ c: Character) -> Int? {
        guard let ascii = c.asciiValue, ascii >= UInt8(ascii: "0"), ascii <= UInt8(ascii: "9") else { return nil }
        return 9 - Int(ascii - UInt8(ascii: "0"))
    }
}
