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
        var fallbackCounter = 100  // P1-1: 非开局位置的棋子用 100+ 后备 ID

        for (rowIndex, rowStr) in rows.enumerated() {
            var col = 0
            for char in rowStr {
                if let num = char.wholeNumberValue {
                    guard num > 0 else { return nil }
                    col += num
                } else if let piece = fenCharToPiece(char, row: rowIndex, col: col, fallbackCounter: &fallbackCounter) {
                    pieces.append(piece)
                    col += 1
                } else {
                    return nil
                }
                guard col <= 9 else { return nil }
            }
            guard col == 9 else { return nil }
        }

        // v4.0: 棋子数量校验
        guard validatePieceCounts(pieces) else { return nil }

        return FENParseResult(pieces: pieces, currentTurn: currentTurn)
    }

    // MARK: - 棋子数量校验

    /// 校验棋子数量是否合法
    private static func validatePieceCounts(_ pieces: [Piece]) -> Bool {
        // 总数不超过 32
        guard pieces.count <= 32 else { return false }

        var redCounts: [PieceKind: Int] = [:]
        var blackCounts: [PieceKind: Int] = [:]

        for piece in pieces {
            if piece.side == .red {
                redCounts[piece.kind, default: 0] += 1
            } else {
                blackCounts[piece.kind, default: 0] += 1
            }
        }

        // 每方将/帅恰好 1 个
        guard redCounts[.general, default: 0] == 1 else { return false }
        guard blackCounts[.general, default: 0] == 1 else { return false }

        // 各兵种上限
        let limits: [PieceKind: Int] = [
            .advisor: 2, .elephant: 2, .horse: 2,
            .chariot: 2, .cannon: 2, .soldier: 5
        ]
        for (kind, limit) in limits {
            guard redCounts[kind, default: 0] <= limit else { return false }
            guard blackCounts[kind, default: 0] <= limit else { return false }
        }

        // 兵/卒不在底线（row 0 = 黑方底线，row 9 = 红方底线）
        for piece in pieces {
            if piece.kind == .soldier {
                if piece.side == .black && piece.position.row == 0 { return false }
                if piece.side == .red && piece.position.row == 9 { return false }
            }
        }

        // 将/帅必须在九宫内
        for piece in pieces {
            if piece.kind == .general {
                let row = piece.position.row
                let col = piece.position.col
                if piece.side == .black {
                    guard row >= 0 && row <= 2 && col >= 3 && col <= 5 else { return false }
                } else {
                    guard row >= 7 && row <= 9 && col >= 3 && col <= 5 else { return false }
                }
            }
        }

        return true
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

    private static func fenCharToPiece(_ char: Character, row: Int, col: Int, fallbackCounter: inout Int) -> Piece? {
        let kind: PieceKind
        let side: Side

        switch char {
        // 红方（大写）
        case "K": kind = .general;  side = .red
        case "A": kind = .advisor;  side = .red
        case "B": kind = .elephant; side = .red
        case "N": kind = .horse;    side = .red
        case "R": kind = .chariot;  side = .red
        case "C": kind = .cannon;   side = .red
        case "P": kind = .soldier;  side = .red
        // 黑方（小写）
        case "k": kind = .general;  side = .black
        case "a": kind = .advisor;  side = .black
        case "b": kind = .elephant; side = .black
        case "n": kind = .horse;    side = .black
        case "r": kind = .chariot;  side = .black
        case "c": kind = .cannon;   side = .black
        case "p": kind = .soldier;  side = .black
        default:  return nil
        }

        let pos = Position(row: row, col: col)
        // P1-1: 用确定性 ID（与 initialPieces 一致），非开局位置用后备 ID
        var id = Piece.fallbackId(kind: kind, side: side, position: pos)
        if id < 0 {
            id = fallbackCounter
            fallbackCounter += 1
        }
        return Piece(kind: kind, side: side, position: pos, id: id)
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
