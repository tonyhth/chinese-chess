import Foundation

// MARK: - 棋型识别

/// 识别已知的胜势棋型，给评估函数加分。
/// 加分范围 +500 到 +2000，在子力评估基础上产生明显引导效果。
struct PatternRecognizer {

    enum Pattern: String, CaseIterable {
        case singleChariotWin      // 单车胜（车 vs 无防守子）
        case doubleChariotCrush    // 双车错
        case horseCannon           // 马后炮
        case fishingHorse          // 钓鱼马
        case ironGate              // 铁门栓
        case seaBottomMoon         // 海底捞月
    }

    /// 识别当前局面中 side 方的棋型，返回加分。
    /// 加分相对于 side 方：正值 = side 方优势。
    static func bonusPatterns(on board: Board, for side: Side) -> Int {
        let myPieces = board.pieces(for: side)
        let opSide: Side = (side == .red) ? .black : .red
        let opPieces = board.pieces(for: opSide)

        // 按种类分组计数
        let myKinds = Dictionary(grouping: myPieces, by: { $0.kind }).mapValues { $0.count }
        let opKinds = Dictionary(grouping: opPieces, by: { $0.kind }).mapValues { $0.count }

        var bonus = 0

        // 单车胜：车 vs 对方无防守子（无士象）
        if myKinds[.chariot, default: 0] >= 1
            && opKinds[.advisor, default: 0] == 0
            && opKinds[.elephant, default: 0] == 0 {
            bonus += 800
        }

        // 双车错
        if myKinds[.chariot, default: 0] >= 2 {
            bonus += 600
            // 双车 vs 单车
            if opKinds[.chariot, default: 0] <= 1 {
                bonus += 400
            }
        }

        // 马后炮：马+炮在同一纵线，炮在马后方，对方将在炮后
        if myKinds[.horse, default: 0] >= 1 && myKinds[.cannon, default: 0] >= 1 {
            if let opGeneral = board.generalPosition(of: opSide) {
                let horses = myPieces.filter { $0.kind == .horse }
                let cannons = myPieces.filter { $0.kind == .cannon }
                for horse in horses {
                    for cannon in cannons {
                        if isHorseCannonPattern(horse: horse, cannon: cannon,
                                                general: opGeneral, on: board) {
                            bonus += 2000
                        }
                    }
                }
            }
        }

        // 钓鱼马：马在对方底线附近，控制对方将的出路
        if myKinds[.horse, default: 0] >= 1 {
            if let opGeneral = board.generalPosition(of: opSide) {
                let horses = myPieces.filter { $0.kind == .horse }
                for horse in horses {
                    if isFishingHorse(horse: horse, general: opGeneral, side: side) {
                        bonus += 1000
                    }
                }
            }
        }

        // 铁门栓：车在对方将的正前方，中间无阻挡
        if myKinds[.chariot, default: 0] >= 1 {
            if let opGeneral = board.generalPosition(of: opSide) {
                let chariots = myPieces.filter { $0.kind == .chariot }
                for chariot in chariots {
                    if isIronGate(chariot: chariot, general: opGeneral, on: board) {
                        bonus += 1500
                    }
                }
            }
        }

        // 海底捞月：车/炮在对方底线，对方将在同列
        if myKinds[.chariot, default: 0] >= 1 || myKinds[.cannon, default: 0] >= 1 {
            if let opGeneral = board.generalPosition(of: opSide) {
                let bottomRow = (side == .red) ? 0 : 9
                let attackers = myPieces.filter {
                    ($0.kind == .chariot || $0.kind == .cannon) && $0.position.row == bottomRow
                }
                for attacker in attackers {
                    if attacker.position.col == opGeneral.col {
                        bonus += 1200
                    }
                }
            }
        }

        return bonus
    }

    // MARK: - 棋型判定辅助

    /// 马后炮判定：马和炮在同一列或相关位置，炮在马后方，将/帅在炮后方
    private static func isHorseCannonPattern(horse: Piece, cannon: Piece,
                                              general: Position, on board: Board) -> Bool {
        // 简化判定：炮在将的正前方或正侧方，马控制将的逃跑路线
        // 严格版：马和炮在同列，炮在马和将之间
        let hCol = horse.position.col
        let cCol = cannon.position.col
        let gCol = general.col

        // 同列模式：马-炮-将 或 炮-马-将
        if hCol == cCol && cCol == gCol {
            let hRow = horse.position.row
            let cRow = cannon.position.row
            let gRow = general.row
            // 炮在马和将之间
            return (hRow < cRow && cRow < gRow) || (hRow > cRow && cRow > gRow)
        }

        // 横向模式：炮和将在同行，马在相关位置
        if cannon.position.row == general.row {
            let colDist = abs(cannon.position.col - general.col)
            // 炮和将距离 1-2 格，中间有马作为炮架
            if colDist >= 2 {
                let minC = min(cannon.position.col, general.col)
                let maxC = max(cannon.position.col, general.col)
                // 检查马是否在炮和将之间
                if horse.position.row == cannon.position.row
                    && horse.position.col > minC && horse.position.col < maxC {
                    return true
                }
            }
        }

        return false
    }

    /// 钓鱼马判定：马在对方将的周围（日字位），控制将的出路
    private static func isFishingHorse(horse: Piece, general: Position, side: Side) -> Bool {
        let hRow = horse.position.row
        let hCol = horse.position.col
        let gRow = general.row
        let gCol = general.col

        // 马在将的日字攻击范围内（一步可达）
        let rowDiff = abs(hRow - gRow)
        let colDiff = abs(hCol - gCol)
        return (rowDiff == 1 && colDiff == 2) || (rowDiff == 2 && colDiff == 1)
    }

    /// 铁门栓判定：车在对方将的正前方，同列且中间无阻挡
    private static func isIronGate(chariot: Piece, general: Position, on board: Board) -> Bool {
        guard chariot.position.col == general.col else { return false }
        let cRow = chariot.position.row
        let gRow = general.row
        // 车在将的一侧
        let minRow = min(cRow, gRow) + 1
        let maxRow = max(cRow, gRow)
        // 检查中间无棋子
        for row in minRow..<maxRow {
            if board.piece(at: Position(row: row, col: general.col)) != nil {
                return false
            }
        }
        return true
    }
}
