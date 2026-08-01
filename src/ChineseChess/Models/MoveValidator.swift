import Foundation

struct MoveValidator {

    // MARK: - 主入口

    /// 判断走法是否合法
    static func isLegal<T: BoardReadable>(_ move: Move, on board: T) -> Bool {
        let piece = move.piece
        guard Position.isValid(move.to) else { return false }
        if let target = board.piece(at: move.to), target.side == piece.side { return false }
        guard isMovePatternValid(for: piece, from: move.from, to: move.to, on: board) else { return false }
        guard !wouldBeInCheck(move, on: board) else { return false }
        return true
    }

    /// 某棋子所有合法走法（按棋子类型生成候选位置，避免 90 格全遍历）
    static func legalMoves<T: BoardReadable>(for piece: Piece, on board: T) -> [Move] {
        let candidates = candidateMoves(for: piece, on: board)
        return candidates.filter { isLegal($0, on: board) }
    }

    /// 某方所有合法走法
    static func allLegalMoves<T: BoardReadable>(for side: Side, on board: T) -> [Move] {
        board.pieces(for: side).flatMap { legalMoves(for: $0, on: board) }
    }

    // MARK: - 吃子走法生成（v3.9: 为静态搜索优化，跳过 wouldBeInCheck）

    /// 某方所有吃子候选走法（仅走法模式校验 + 己方棋子过滤，不做将帅暴露检查）
    /// 用于静态搜索（QS），在 QS 内部通过实际执行验证合法性
    static func captureMoves<T: BoardReadable>(for side: Side, on board: T) -> [Move] {
        var result: [Move] = []
        for piece in board.pieces(for: side) {
            let candidates = candidateMoves(for: piece, on: board)
            for move in candidates {
                // 只保留吃子走法（目标位置有对方棋子）
                guard move.captured != nil else { continue }
                // 己方棋子过滤已在 candidateMoves 中处理，只需走法模式校验
                guard isMovePatternValid(for: move.piece, from: move.from, to: move.to, on: board) else { continue }
                result.append(move)
            }
        }
        return result
    }

    // MARK: - 候选走法生成（Y4: 按棋子类型只生成可能的目标位置）

    private static func candidateMoves<T: BoardReadable>(for piece: Piece, on board: T) -> [Move] {
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
    static func isInCheck<T: BoardReadable>(_ side: Side, on board: T) -> Bool {
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

    static func isCheckmate<T: BoardReadable>(_ side: Side, on board: T) -> Bool {
        isInCheck(side, on: board) && allLegalMoves(for: side, on: board).isEmpty
    }

    static func isStalemate<T: BoardReadable>(_ side: Side, on board: T) -> Bool {
        !isInCheck(side, on: board) && allLegalMoves(for: side, on: board).isEmpty
    }

    // MARK: - 移动模式校验

    private static func isMovePatternValid<T: BoardReadable>(for piece: Piece, from: Position, to: Position, on board: T) -> Bool {
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
    private static func isValidElephantMove<T: BoardReadable>(_ piece: Piece, from: Position, to: Position, on board: T) -> Bool {
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
    private static func isValidHorseMove<T: BoardReadable>(_ piece: Piece, from: Position, to: Position, on board: T) -> Bool {
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
    private static func isValidChariotMove<T: BoardReadable>(from: Position, to: Position, on board: T) -> Bool {
        guard from.row == to.row || from.col == to.col else { return false }
        return countPiecesBetween(from: from, to: to, on: board) == 0
    }

    // MARK: 炮
    private static func isValidCannonMove<T: BoardReadable>(_ piece: Piece, from: Position, to: Position, on board: T) -> Bool {
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

    private static func countPiecesBetween<T: BoardReadable>(from: Position, to: Position, on board: T) -> Int {
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

    // v3.9: canAttack 复用 isMovePatternValid，消除与 isValidXxxMove 的逻辑不一致
    // 审计发现三处偏差：象半场检查用 from（应为 target）、士宫殿检查属性错、将分支为死代码
    static func canAttack<T: BoardReadable>(piece: Piece, target: Position, on board: T) -> Bool {
        // 攻击目标必须是对方棋子或空位（canAttack 只判断攻击范围，不检查目标归属）
        // isMovePatternValid 已包含宫殿/半场/蹩腿等约束
        return isMovePatternValid(for: piece, from: piece.position, to: target, on: board)
    }

    private static func wouldBeInCheck<T: BoardReadable>(_ move: Move, on board: T) -> Bool {
        var workBoard = board.makeSearchBoard()
        workBoard.execute(move)
        return isInCheck(move.piece.side, on: workBoard)
    }
}
