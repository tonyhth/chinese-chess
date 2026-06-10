import Foundation

// MARK: - ICCS 中文坐标法棋谱生成
// TODO: localize — 中文传统棋谱格式与 locale 双维度，需根据 notationFormat + locale 决定输出

struct NotationGenerator {

    // 红方纵线：col 0→九, 1→八, ..., 8→一
    private static let redFileNames = ["九", "八", "七", "六", "五", "四", "三", "二", "一"]
    // 黑方纵线：col 0→9, 1→8, ..., 8→1
    private static let blackFileNames = ["9", "8", "7", "6", "5", "4", "3", "2", "1"]

    // 中文数字 1-9
    private static let chineseNumbers = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]

    /// 生成一步棋的中文坐标法描述
    /// - Parameters:
    ///   - move: 走法
    ///   - board: 走之前的棋盘状态
    static func notation(for move: Move, on board: Board) -> String {
        let piece = move.piece
        let from = move.from
        let to = move.to
        let isRed = piece.side == .red

        // 1. 消歧义前缀（前/后）
        let disambig = disambiguationPrefix(piece: piece, at: from, allPieces: board.pieces)

        // 2. 棋子名
        let name = pieceName(piece)

        // 3. 纵线编号（消歧义前缀与纵线号并存：前車九进一）
        let fileStr = fileNumber(for: piece, at: from)

        // 4. 动作 + 目标
        let actionTarget = actionAndTarget(piece: piece, from: from, to: to, isRed: isRed)

        return disambig + name + fileStr + actionTarget
    }

    // MARK: - 棋子名

    private static func pieceName(_ piece: Piece) -> String {
        switch piece.side {
        case .red:
            switch piece.kind {
            case .general:  return "帅"
            case .advisor:  return "仕"
            case .elephant: return "相"
            case .horse:    return "馬"
            case .chariot:  return "車"
            case .cannon:   return "炮"
            case .soldier:  return "兵"
            }
        case .black:
            switch piece.kind {
            case .general:  return "将"
            case .advisor:  return "士"
            case .elephant: return "象"
            case .horse:    return "馬"
            case .chariot:  return "車"
            case .cannon:   return "砲"
            case .soldier:  return "卒"
            }
        }
    }

    // MARK: - 纵线编号

    private static func fileNumber(for piece: Piece, at pos: Position) -> String {
        if piece.side == .red {
            return redFileNames[pos.col]
        } else {
            return blackFileNames[pos.col]
        }
    }

    // MARK: - 消歧义（前/后）

    private static func disambiguationPrefix(piece: Piece, at pos: Position, allPieces: [Piece]) -> String {
        let sameKindSameFile = allPieces.filter {
            $0.kind == piece.kind
            && $0.side == piece.side
            && $0.position.col == pos.col
            && $0.id != piece.id
        }

        guard !sameKindSameFile.isEmpty else { return "" }

        // 红方：行号小的在前（靠近黑方 = 前进方向）
        // 黑方：行号大的在前（靠近红方 = 前进方向）
        let isRed = piece.side == .red
        let myRow = pos.row
        let otherRow = sameKindSameFile[0].position.row

        if isRed {
            return myRow < otherRow ? "前" : "后"
        } else {
            return myRow > otherRow ? "前" : "后"
        }
    }

    // MARK: - 动作与目标

    private static func actionAndTarget(piece: Piece, from: Position, to: Position, isRed: Bool) -> String {
        let isDiagonal: Bool
        switch piece.kind {
        case .horse, .advisor, .elephant:
            isDiagonal = true
        default:
            isDiagonal = false
        }

        // 横走
        if from.row == to.row && from.col != to.col {
            let targetFile = fileNumber(for: piece, at: to)
            // 如果有消歧义，纵线号放在目标里
            return "平" + targetFile
        }

        // 纵向移动
        let forward = isRed ? (to.row < from.row) : (to.row > from.row)
        let action = forward ? "进" : "退"

        if isDiagonal {
            // 斜走子：目标 = 目标纵线号
            let targetFile = fileNumber(for: piece, at: to)
            return action + targetFile
        } else {
            // 直线走子（车/炮/兵/将）：目标 = 格数
            let steps = abs(to.row - from.row)
            if isRed {
                return action + chineseNumbers[steps - 1]
            } else {
                return action + String(steps)
            }
        }
    }
}
