import Foundation

struct MoveValidator {

    // MARK: - 主入口

    /// 判断走法是否合法
    static func isLegal(_ move: Move, on board: Board) -> Bool {
        let piece = move.piece
        guard Position.isValid(move.to) else { return false }
        if let target = board.piece(at: move.to), target.side == piece.side { return false }
        guard isMovePatternValid(for: piece, from: move.from, to: move.to, on: board) else { return false }
        guard !wouldBeInCheck(move, on: board) else { return false }
        return true
    }

    /// 某棋子所有合法走法（按棋子类型生成候选位置，避免 90 格全遍历）
    static func legalMoves(for piece: Piece, on board: Board) -> [Move] {
        let candidates = candidateMoves(for: piece, on: board)
        return candidates.filter { isLegal($0, on: board) }
    }

    /// 某方所有合法走法
    static func allLegalMoves(for side: Side, on board: Board) -> [Move] {
        board.pieces(for: side).flatMap { legalMoves(for: $0, on: board) }
    }

    // MARK: - 候选走法生成（Y4: 按棋子类型只生成可能的目标位置）

    private static func candidateMoves(for piece: Piece, on board: Board) -> [Move] {
        let from = piece.position
        var targets: [Position] = []

        switch piece.kind {
        case .general:
            for (dr, dc) in [(1,0),(-1,0),(0,1),(0,-1)] {
                let t = Position(row: from.row + dr, col: from.col + dc)
                if Position.isValid(t) { targets.append(t) }
            }

        case .advisor:
            for (dr, dc) in [(1,1),(1,-1),(-1,1),(-1,-1)] {
                let t = Position(row: from.row + dr, col: from.col + dc)
                if Position.isValid(t) { targets.append(t) }
            }

        case .elephant:
            for (dr, dc) in [(2,2),(2,-2),(-2,2),(-2,-2)] {
                let t = Position(row: from.row + dr, col: from.col + dc)
                if Position.isValid(t) { targets.append(t) }
            }

        case .horse:
            for (dr, dc) in [(2,1),(2,-1),(-2,1),(-2,-1),(1,2),(1,-2),(-1,2),(-1,-2)] {
                let t = Position(row: from.row + dr, col: from.col + dc)
                if Position.isValid(t) { targets.append(t) }
            }

        case .chariot:
            // 四个方向直线
            for (dr, dc) in [(1,0),(-1,0),(0,1),(0,-1)] {
                var r = from.row + dr
                var c = from.col + dc
                while r >= 0 && r <= 9 && c >= 0 && c <= 8 {
                    let t = Position(row: r, col: c)
                    targets.append(t)
                    if board.hasPiece(at: t) { break }  // 遇到子停止（吃子或己方子）
                    r += dr
                    c += dc
                }
            }

        case .cannon:
            // 四个方向直线（移动 + 吃子）
            for (dr, dc) in [(1,0),(-1,0),(0,1),(0,-1)] {
                var r = from.row + dr
                var c = from.col + dc
                var mounted = false
                while r >= 0 && r <= 9 && c >= 0 && c <= 8 {
                    let t = Position(row: r, col: c)
                    if !mounted {
                        if board.hasPiece(at: t) {
                            mounted = true  // 找到炮架
                        } else {
                            targets.append(t)  // 移动位置
                        }
                    } else {
                        // 炮架之后，第一个遇到的子是吃子目标
                        if board.hasPiece(at: t) {
                            targets.append(t)
                            break
                        }
                    }
                    r += dr
                    c += dc
                }
            }

        case .soldier:
            let forward = (piece.side == .red) ? -1 : 1
            let hasCrossed = (piece.side == .red) ? from.row <= 4 : from.row >= 5
            // 前进
            let fwd = Position(row: from.row + forward, col: from.col)
            if Position.isValid(fwd) { targets.append(fwd) }
            // 过河后可左右
            if hasCrossed {
                let left = Position(row: from.row, col: from.col - 1)
                let right = Position(row: from.row, col: from.col + 1)
                if Position.isValid(left) { targets.append(left) }
                if Position.isValid(right) { targets.append(right) }
            }
        }

        return targets.map { to in
            let captured = board.piece(at: to)
            return Move(piece: piece, from: from, to: to, captured: captured)
        }
    }

    // MARK: - 将军 / 将死 / 困毙

    /// 某方是否被将军（含将帅对面）
    static func isInCheck(_ side: Side, on board: Board) -> Bool {
        guard let generalPos = board.generalPosition(of: side) else { return true }

        let opponent: Side = (side == .red) ? .black : .red

        for piece in board.pieces(for: opponent) {
            if canAttack(piece: piece, target: generalPos, on: board) {
                return true
            }
        }

        // 将帅对面检查
        if let otherGeneralPos = board.generalPosition(of: opponent),
           generalPos.col == otherGeneralPos.col {
            let minRow = min(generalPos.row, otherGeneralPos.row)
            let maxRow = max(generalPos.row, otherGeneralPos.row)
            var blocked = false
            for r in (minRow + 1)..<maxRow {
                if board.hasPiece(at: Position(row: r, col: generalPos.col)) {
                    blocked = true
                    break
                }
            }
            if !blocked { return true }
        }

        return false
    }

    static func isCheckmate(_ side: Side, on board: Board) -> Bool {
        isInCheck(side, on: board) && allLegalMoves(for: side, on: board).isEmpty
    }

    static func isStalemate(_ side: Side, on board: Board) -> Bool {
        !isInCheck(side, on: board) && allLegalMoves(for: side, on: board).isEmpty
    }

    // MARK: - 移动模式校验

    private static func isMovePatternValid(for piece: Piece, from: Position, to: Position, on board: Board) -> Bool {
        switch piece.kind {
        case .general:  return isValidGeneralMove(piece, from: from, to: to)
        case .advisor:  return isValidAdvisorMove(piece, from: from, to: to)
        case .elephant: return isValidElephantMove(piece, from: from, to: to, on: board)
        case .horse:    return isValidHorseMove(piece, from: from, to: to, on: board)
        case .chariot:  return isValidChariotMove(from: from, to: to, on: board)
        case .cannon:   return isValidCannonMove(piece, from: from, to: to, on: board)
        case .soldier:  return isValidSoldierMove(piece, from: from, to: to)
        }
    }

    // MARK: 将/帅
    private static func isValidGeneralMove(_ piece: Piece, from: Position, to: Position) -> Bool {
        let palace: Bool = (piece.side == .red) ? to.isInRedPalace : to.isInBlackPalace
        guard palace else { return false }
        let dr = abs(to.row - from.row)
        let dc = abs(to.col - from.col)
        return (dr == 1 && dc == 0) || (dr == 0 && dc == 1)
    }

    // MARK: 士/仕
    private static func isValidAdvisorMove(_ piece: Piece, from: Position, to: Position) -> Bool {
        let palace: Bool = (piece.side == .red) ? to.isInRedPalace : to.isInBlackPalace
        guard palace else { return false }
        let dr = abs(to.row - from.row)
        let dc = abs(to.col - from.col)
        return dr == 1 && dc == 1
    }

    // MARK: 象/相
    private static func isValidElephantMove(_ piece: Piece, from: Position, to: Position, on board: Board) -> Bool {
        let inHalf: Bool = (piece.side == .red) ? to.isInRedHalf : to.isInBlackHalf
        guard inHalf else { return false }
        let dr = abs(to.row - from.row)
        let dc = abs(to.col - from.col)
        guard dr == 2 && dc == 2 else { return false }
        let eyeRow = (from.row + to.row) / 2
        let eyeCol = (from.col + to.col) / 2
        return !board.hasPiece(at: Position(row: eyeRow, col: eyeCol))
    }

    // MARK: 马
    private static func isValidHorseMove(_ piece: Piece, from: Position, to: Position, on board: Board) -> Bool {
        let dr = to.row - from.row
        let dc = to.col - from.col
        let adr = abs(dr)
        let adc = abs(dc)
        guard (adr == 2 && adc == 1) || (adr == 1 && adc == 2) else { return false }

        let legRow: Int
        let legCol: Int
        if adr == 2 {
            legRow = from.row + (dr > 0 ? 1 : -1)
            legCol = from.col
        } else {
            legRow = from.row
            legCol = from.col + (dc > 0 ? 1 : -1)
        }
        return !board.hasPiece(at: Position(row: legRow, col: legCol))
    }

    // MARK: 车
    private static func isValidChariotMove(from: Position, to: Position, on board: Board) -> Bool {
        guard from.row == to.row || from.col == to.col else { return false }
        return countPiecesBetween(from: from, to: to, on: board) == 0
    }

    // MARK: 炮
    private static func isValidCannonMove(_ piece: Piece, from: Position, to: Position, on board: Board) -> Bool {
        guard from.row == to.row || from.col == to.col else { return false }
        let between = countPiecesBetween(from: from, to: to, on: board)
        let target = board.piece(at: to)
        if target != nil {
            return between == 1
        } else {
            return between == 0
        }
    }

    // MARK: 兵/卒
    private static func isValidSoldierMove(_ piece: Piece, from: Position, to: Position) -> Bool {
        let dr = to.row - from.row
        let dc = abs(to.col - from.col)
        let hasCrossed = (piece.side == .red) ? from.row <= 4 : from.row >= 5

        if !hasCrossed {
            let forward = (piece.side == .red) ? -1 : 1
            return dr == forward && dc == 0
        } else {
            let forward = (piece.side == .red) ? -1 : 1
            if dr == forward && dc == 0 { return true }
            if dr == 0 && dc == 1 { return true }
            return false
        }
    }

    // MARK: - 辅助方法

    private static func countPiecesBetween(from: Position, to: Position, on board: Board) -> Int {
        var count = 0
        if from.row == to.row {
            let minC = min(from.col, to.col)
            let maxC = max(from.col, to.col)
            for c in (minC + 1)..<maxC {
                if board.hasPiece(at: Position(row: from.row, col: c)) { count += 1 }
            }
        } else {
            let minR = min(from.row, to.row)
            let maxR = max(from.row, to.row)
            for r in (minR + 1)..<maxR {
                if board.hasPiece(at: Position(row: r, col: from.col)) { count += 1 }
            }
        }
        return count
    }

    private static func canAttack(piece: Piece, target: Position, on board: Board) -> Bool {
        let from = piece.position
        switch piece.kind {
        case .general:
            let palace: Bool = (piece.side == .red) ? target.isInRedPalace : target.isInBlackPalace
            guard palace else { return false }
            let dr = abs(target.row - from.row)
            let dc = abs(target.col - from.col)
            return (dr == 1 && dc == 0) || (dr == 0 && dc == 1)

        case .advisor:
            let palace: Bool = (piece.side == .red) ? target.isInRedPalace : target.isInBlackPalace
            guard palace else { return false }
            return abs(target.row - from.row) == 1 && abs(target.col - from.col) == 1

        case .elephant:
            let inHalf: Bool = (piece.side == .red) ? from.isInRedHalf : from.isInBlackHalf
            guard inHalf else { return false }
            let dr = abs(target.row - from.row)
            let dc = abs(target.col - from.col)
            guard dr == 2 && dc == 2 else { return false }
            let eyeRow = (from.row + target.row) / 2
            let eyeCol = (from.col + target.col) / 2
            return !board.hasPiece(at: Position(row: eyeRow, col: eyeCol))

        case .horse:
            return isValidHorseMove(piece, from: from, to: target, on: board)

        case .chariot:
            return isValidChariotMove(from: from, to: target, on: board)

        case .cannon:
            guard from.row == target.row || from.col == target.col else { return false }
            return countPiecesBetween(from: from, to: target, on: board) == 1

        case .soldier:
            return isValidSoldierMove(piece, from: from, to: target)
        }
    }

    private static func wouldBeInCheck(_ move: Move, on board: Board) -> Bool {
        let snapshot = board.snapshot()
        snapshot.execute(move)
        return isInCheck(move.piece.side, on: snapshot)
    }
}
