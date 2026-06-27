import Foundation

// MARK: - 将帅安全评估

/// 从 AIEngine 拆分出来的将帅安全 + 机动性评估模块
struct KingSafetyEvaluator {

    /// 将帅安全：周围防护（士/象覆盖）加分，对方攻击线经过九宫减分
    /// 开销极小（约 8 次检查），所有难度启用
    /// v3.0 Phase 3b: 将帅安全评估增强
    /// 开局侧重防守子力完整性，残局侧重将的机动性
    static func kingSafetyScore(for side: Side, on board: Board, weights: EvalWeights) -> Int {
        guard let kingPos = board.generalPosition(of: side) else { return -50000 }
        let w = weights
        var score = 0
        let totalPieces = board.pieces.count
        let isEndgame = totalPieces <= 16

        let advisors = board.pieces(for: side).filter { $0.kind == .advisor }
        let elephants = board.pieces(for: side).filter { $0.kind == .elephant }

        // 士象覆盖加分（开局权重更高）
        let guardWeight = isEndgame ? w.guardWeightEndgame : w.guardWeightOpening
        score += advisors.count * guardWeight + elephants.count * (guardWeight + w.elephantWeightModifier)

        // 将帅暴露扣分（开局更严重）
        let exposurePenalty = isEndgame ? w.exposurePenaltyEndgame : w.exposurePenaltyOpening
        if advisors.count < 2 || elephants.count < 2 {
            let missingGuards = (2 - advisors.count) + (2 - elephants.count)
            score -= missingGuards * exposurePenalty
        }

        // v3.0 Phase 3b: 防空检测
        let defenseRowOffset = (side == .black) ? -1 : 1
        let airDefPos = Position(row: kingPos.row + defenseRowOffset, col: kingPos.col)
        if airDefPos.row >= 0 && airDefPos.row <= 9 {
            if let defender = board.piece(at: airDefPos), defender.side == side {
                score += w.airDefenseBonus
            } else if !isEndgame {
                score -= w.airDefensePenaltyOpening
            }
        }

        // 对方车/炮攻击线经过九宫减分
        let opSide: Side = (side == .red) ? .black : .red
        for op in board.pieces(for: opSide) {
            if op.kind == .chariot || op.kind == .cannon {
                if isAttackingPosition(op, target: kingPos, on: board) {
                    score -= isEndgame ? w.attackPenaltyEndgame : w.attackPenaltyOpening
                }
            }
        }

        // 对方马对九宫的威胁
        for op in board.pieces(for: opSide) where op.kind == .horse {
            score -= horsePalaceThreat(op, kingPos: kingPos, on: board, weights: w)
        }

        return score
    }

    /// v3.0 Phase 3a: 机动性评估重写
    static func simplifiedMobilityScore(for side: Side, on board: Board, weights: EvalWeights) -> Int {
        let w = weights
        var score = 0
        let totalPieces = board.pieces.count
        let isEndgame = totalPieces <= 16

        for piece in board.pieces(for: side) {
            switch piece.kind {
            case .chariot:
                let rowEmpty = countEmptyInRow(piece.position.row, on: board)
                let colEmpty = countEmptyInCol(piece.position.col, on: board)
                let baseMobility = (rowEmpty + colEmpty) * w.chariotRowColEmptyMultiplier
                let positionalBonus: Int
                if piece.position.col == 4 { positionalBonus = w.chariotCenterBonus }
                else if piece.position.col == 3 || piece.position.col == 5 { positionalBonus = w.chariotNearCenterBonus }
                else { positionalBonus = 0 }
                let endgameMult = isEndgame ? w.chariotEndgameMultiplier : w.chariotOpeningMultiplier
                score += baseMobility * endgameMult / w.chariotOpeningMultiplier + positionalBonus

            case .cannon:
                let targets = countCannonTargets(piece, on: board)
                score += targets * w.cannonTargetBonus
                if piece.position.col == 4 { score += w.cannonCenterBonus }
                if isEndgame { score = score * w.cannonEndgameFactor / 10 }

            case .horse:
                let jumpCount = horseJumpTargets(from: piece.position, for: side, on: board).count
                score += jumpCount * w.horseJumpBonus
                if isEndgame { score += jumpCount * w.horseEndgameJumpBonus }
                let localRow = (side == .black) ? piece.position.row : (9 - piece.position.row)
                if localRow == 1 && piece.position.col == 4 { score -= w.horseBadPositionPenalty }

            case .soldier:
                let crossed = (side == .black) ? piece.position.row >= 5 : piece.position.row <= 4
                if crossed {
                    let forwardDir = (side == .black) ? 1 : -1
                    let fr = piece.position.row + forwardDir
                    if fr >= 0 && fr <= 9 && board.piece(at: Position(row: fr, col: piece.position.col)) == nil {
                        score += w.soldierForwardBonus
                    }
                    for dc in [-1, 1] {
                        let nc = piece.position.col + dc
                        if nc >= 0 && nc <= 8 && board.piece(at: Position(row: piece.position.row, col: nc)) == nil {
                            score += w.soldierSideBonus
                        }
                    }
                }

            default:
                break
            }
        }
        return score
    }

    // MARK: - 辅助方法

    static func isAttackingPosition(_ piece: Piece, target: Position, on board: Board) -> Bool {
        let pr = piece.position.row, pc = piece.position.col
        let tr = target.row, tc = target.col

        if piece.kind == .chariot {
            if pr == tr {
                let minC = min(pc, tc) + 1, maxC = max(pc, tc)
                for c in minC..<maxC {
                    if board.piece(at: Position(row: pr, col: c)) != nil { return false }
                }
                return true
            }
            if pc == tc {
                let minR = min(pr, tr) + 1, maxR = max(pr, tr)
                for r in minR..<maxR {
                    if board.piece(at: Position(row: r, col: pc)) != nil { return false }
                }
                return true
            }
        }

        if piece.kind == .cannon {
            if pr == tr {
                let minC = min(pc, tc) + 1, maxC = max(pc, tc)
                var count = 0
                for c in minC..<maxC {
                    if board.piece(at: Position(row: pr, col: c)) != nil { count += 1 }
                }
                return count == 1
            }
            if pc == tc {
                let minR = min(pr, tr) + 1, maxR = max(pr, tr)
                var count = 0
                for r in minR..<maxR {
                    if board.piece(at: Position(row: r, col: pc)) != nil { count += 1 }
                }
                return count == 1
            }
        }

        return false
    }

    /// 马从指定位置可跳的日字目标（含蹩脚检测和己方占位检查）
    static func horseJumpTargets(from pos: Position, for side: Side, on board: Board) -> [Position] {
        let r = pos.row, c = pos.col
        let targets = [(r+2,c+1),(r+2,c-1),(r-2,c+1),(r-2,c-1),
                       (r+1,c+2),(r+1,c-2),(r-1,c+2),(r-1,c-2)]
        let legs = [(r+1,c),(r+1,c),(r-1,c),(r-1,c),
                   (r,c+1),(r,c-1),(r,c+1),(r,c-1)]
        var result: [Position] = []
        for (i, (tr, tc)) in targets.enumerated() {
            guard tr >= 0, tr <= 9, tc >= 0, tc <= 8 else { continue }
            let (lr, lc) = legs[i]
            if board.piece(at: Position(row: lr, col: lc)) != nil { continue }
            if let target = board.piece(at: Position(row: tr, col: tc)), target.side == side { continue }
            result.append(Position(row: tr, col: tc))
        }
        return result
    }

    /// 评估对方马对己方九宫的威胁程度
    static func horsePalaceThreat(_ horse: Piece, kingPos: Position, on board: Board, weights: EvalWeights) -> Int {
        let jumps = horseJumpTargets(from: horse.position, for: horse.side, on: board)
        for jump in jumps {
            if jump.row == kingPos.row && jump.col == kingPos.col {
                return weights.horsePalaceThreatDirect
            }
        }
        for jump in jumps {
            if abs(jump.row - kingPos.row) <= 1 && abs(jump.col - kingPos.col) <= 1 {
                return weights.horsePalaceThreatNear
            }
        }
        return 0
    }

    static func countEmptyInRow(_ row: Int, on board: Board) -> Int {
        var count = 0
        for col in 0...8 {
            if board.piece(at: Position(row: row, col: col)) == nil { count += 1 }
        }
        return count
    }

    static func countEmptyInCol(_ col: Int, on board: Board) -> Int {
        var count = 0
        for row in 0...9 {
            if board.piece(at: Position(row: row, col: col)) == nil { count += 1 }
        }
        return count
    }

    static func countCannonTargets(_ piece: Piece, on board: Board) -> Int {
        var targets = 0
        let pr = piece.position.row, pc = piece.position.col
        let directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        for (dr, dc) in directions {
            var r = pr + dr, c = pc + dc
            var foundScreen = false
            while r >= 0 && r <= 9 && c >= 0 && c <= 8 {
                if board.piece(at: Position(row: r, col: c)) != nil {
                    if !foundScreen {
                        foundScreen = true
                    } else {
                        targets += 1
                        break
                    }
                }
                r += dr
                c += dc
            }
        }
        return targets
    }
}
