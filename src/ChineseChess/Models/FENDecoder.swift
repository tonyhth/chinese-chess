import Foundation

// MARK: - FENDecoder（纯解析，无 Service 依赖）

/// FEN 格式：rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1
///
/// 棋子编码：
/// 红方: K=帅, A=仕, B=相, N=馬, R=車, C=炮, P=兵（大写）
/// 黑方: k=将, a=士, b=象, n=馬, r=車, c=砲, p=卒（小写）
/// 数字: 连续空格数
/// 行分隔: /
/// 行走方: w=红方, b=黑方

/// FEN 解析结果（解耦 Board 初始化）
struct FENParseResult {
    let pieces: [Piece]
    let currentTurn: Side
}

/// 纯 FEN 解析器，属于 Models 层，不依赖 Services
enum FENDecoder {

    /// 标准开局 FEN
    static let standardInitial = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

    // MARK: - 解析

    /// 从 FEN 字符串解析棋子和行走方
    static func parse(fen: String) -> FENParseResult? {
        let parts = fen.split(separator: " ", omittingEmptySubsequences: false)

        // 至少需要局面部分和行走方
        guard parts.count >= 2 else { return nil }

        let positionPart = String(parts[0])
        let turnPart = String(parts[1])

        // 解析行走方
        let currentTurn: Side
        switch turnPart {
        case "w": currentTurn = .red
        case "b": currentTurn = .black
        default: return nil
        }

        // 按行分割（10 行）
        let rows = positionPart.split(separator: "/", omittingEmptySubsequences: false)
        guard rows.count == 10 else { return nil }

        var pieces: [Piece] = []

        for (rowIndex, rowStr) in rows.enumerated() {
            var col = 0
            for char in rowStr {
                if let num = char.wholeNumberValue {
                    guard num > 0 else { return nil }  // FEN 中 0 不合法，1-9 有效
                    col += num
                } else if let piece = fenCharToPiece(char, row: rowIndex, col: col) {
                    pieces.append(piece)
                    col += 1
                } else {
                    return nil  // 非法字符
                }
                guard col <= 9 else { return nil }  // 列溢出
            }
            guard col == 9 else { return nil }  // 每行必须 9 列
        }

        return FENParseResult(pieces: pieces, currentTurn: currentTurn)
    }

    // MARK: - 序列化

    /// 从棋子数组生成 FEN 字符串
    static func generate(pieces: [Piece], currentTurn: Side) -> String {
        var rows: [String] = []

        for row in 0...9 {
            var rowStr = ""
            var emptyCount = 0

            for col in 0...8 {
                if let piece = pieces.first(where: { $0.position == Position(row: row, col: col) }) {
                    if emptyCount > 0 {
                        rowStr += "\(emptyCount)"
                        emptyCount = 0
                    }
                    rowStr += pieceToFENChar(piece)
                } else {
                    emptyCount += 1
                }
            }
            if emptyCount > 0 {
                rowStr += "\(emptyCount)"
            }
            rows.append(rowStr)
        }

        let turnStr = currentTurn == .red ? "w" : "b"
        return "\(rows.joined(separator: "/")) \(turnStr) - - 0 1"
    }

    // MARK: - 标准开局判断

    /// 判断 FEN 是否代表标准开局（归一化后比较）
    static func isStandardInitial(_ fen: String) -> Bool {
        guard let result = parse(fen: fen) else { return false }
        let normalized = generate(pieces: result.pieces, currentTurn: result.currentTurn)
        return normalized == standardInitial
    }

    // MARK: - 辅助

    private static func fenCharToPiece(_ char: Character, row: Int, col: Int) -> Piece? {
        switch char {
        // 红方（大写）
        case "K": return Piece(kind: .general,  side: .red, position: Position(row: row, col: col))
        case "A": return Piece(kind: .advisor,  side: .red, position: Position(row: row, col: col))
        case "B": return Piece(kind: .elephant, side: .red, position: Position(row: row, col: col))
        case "N": return Piece(kind: .horse,    side: .red, position: Position(row: row, col: col))
        case "R": return Piece(kind: .chariot,  side: .red, position: Position(row: row, col: col))
        case "C": return Piece(kind: .cannon,   side: .red, position: Position(row: row, col: col))
        case "P": return Piece(kind: .soldier,  side: .red, position: Position(row: row, col: col))
        // 黑方（小写）
        case "k": return Piece(kind: .general,  side: .black, position: Position(row: row, col: col))
        case "a": return Piece(kind: .advisor,  side: .black, position: Position(row: row, col: col))
        case "b": return Piece(kind: .elephant, side: .black, position: Position(row: row, col: col))
        case "n": return Piece(kind: .horse,    side: .black, position: Position(row: row, col: col))
        case "r": return Piece(kind: .chariot,  side: .black, position: Position(row: row, col: col))
        case "c": return Piece(kind: .cannon,   side: .black, position: Position(row: row, col: col))
        case "p": return Piece(kind: .soldier,  side: .black, position: Position(row: row, col: col))
        default:  return nil
        }
    }

    private static func pieceToFENChar(_ piece: Piece) -> String {
        let map: [Side: [PieceKind: String]] = [
            .red: [
                .general: "K", .advisor: "A", .elephant: "B",
                .horse: "N", .chariot: "R", .cannon: "C", .soldier: "P"
            ],
            .black: [
                .general: "k", .advisor: "a", .elephant: "b",
                .horse: "n", .chariot: "r", .cannon: "c", .soldier: "p"
            ]
        ]
        return map[piece.side]?[piece.kind] ?? "?"
    }
}
