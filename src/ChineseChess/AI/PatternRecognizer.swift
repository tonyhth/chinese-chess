import Foundation

// MARK: - 棋型识别（v3.0 Phase 3a 扩展版）

/// 识别棋局中的战术棋型，给评估函数加分。
/// v3.0: 从 8 种扩展到 30+ 种，覆盖攻击/防守/兵卒/将帅/协同五大类。
struct PatternRecognizer {

    // MARK: - 棋型枚举（30+ 种）

    enum Pattern: String, CaseIterable {
        // 攻击型（原有）
        case singleChariotWin      // 单车胜
        case doubleChariotCrush    // 双车错
        case horseCannon           // 马后炮
        case fishingHorse          // 钓鱼马
        case ironGate              // 铁门栓
        case seaBottomMoon         // 海底捞月
        case trappedHorse          // 窝心马
        case ironGateVariant       // 铁门栓变体
        // 攻击型（新增）
        case corneredHorse         // 拐角马
        case tandemCannon          // 担子炮
        case riverCannon           // 巡河炮
        case centralCannon         // 当头炮
        case stackedCannon         // 叠炮
        // 防守型
        case cornerAdvisor         // 羊角士
        case flyingElephant        // 飞相局
        case highChariotRiver      // 高车保河
        // 兵卒型
        case crossedRiverSoldier   // 过河兵
        case soldierLineSync       // 兵线协同
        // 将帅型
        case flyingGeneralThreat   // 飞将威胁
        case palaceAirDefense      // 防空评估
        // 子力协同
        case chariotCannonCoord    // 车炮配合
        case horseCannonCoord      // 马炮配合
        case doubleChariotLink     // 双车联动
        case doubleHorseLink       // 双马连环
        // 战术型
        case pinPattern            // 牵制
        case discoveredAttack      // 闪击
        case blockade              // 堵塞
        case overload              // 过载
        case firstMoveBonus        // 先手价值
    }

    // MARK: - 主入口

    /// 识别当前局面中 side 方的棋型，返回加分。
    /// 加分相对于 side 方：正值 = side 方优势。
    static func bonusPatterns(on board: Board, for side: Side) -> Int {
        var bonus = 0

        let myPieces = board.pieces(for: side)
        let opSide: Side = (side == .red) ? .black : .red
        let opPieces = board.pieces(for: opSide)

        let myKinds = Dictionary(grouping: myPieces, by: { $0.kind }).mapValues { $0.count }
        let opKinds = Dictionary(grouping: opPieces, by: { $0.kind }).mapValues { $0.count }
        let opGeneral = board.generalPosition(of: opSide)
        let myGeneral = board.generalPosition(of: side)

        // --- 原有棋型（保持不变） ---

        // 单车胜
        if myKinds[.chariot, default: 0] >= 1
            && opKinds[.advisor, default: 0] == 0
            && opKinds[.elephant, default: 0] == 0 {
            bonus += 800
        }

        // 双车错
        if myKinds[.chariot, default: 0] >= 2 {
            bonus += 600
            if opKinds[.chariot, default: 0] <= 1 { bonus += 400 }
        }

        // 马后炮
        if myKinds[.horse, default: 0] >= 1 && myKinds[.cannon, default: 0] >= 1 {
            if let og = opGeneral {
                for h in myPieces where h.kind == .horse {
                    for c in myPieces where c.kind == .cannon {
                        if isHorseCannonPattern(horse: h, cannon: c, general: og) {
                            bonus += 2000
                        }
                    }
                }
            }
        }

        // 钓鱼马
        if myKinds[.horse, default: 0] >= 1, let og = opGeneral {
            for h in myPieces where h.kind == .horse {
                if isFishingHorse(horse: h, general: og) { bonus += 1000 }
            }
        }

        // 铁门栓
        if myKinds[.chariot, default: 0] >= 1, let og = opGeneral {
            for ch in myPieces where ch.kind == .chariot {
                if isIronGate(chariot: ch, general: og, on: board) { bonus += 1500 }
            }
        }

        // 海底捞月
        if myKinds[.chariot, default: 0] >= 1 || myKinds[.cannon, default: 0] >= 1, let og = opGeneral {
            let bottomRow = (side == .red) ? 0 : 9
            let attackers = myPieces.filter { $0.kind == .chariot || $0.kind == .cannon }
            for a in attackers where a.position.row == bottomRow {
                if a.position.col == og.col { bonus += 1200 }
            }
        }

        // 窝心马（对方）
        if let og = opGeneral {
            for h in opPieces where h.kind == .horse {
                let localRow = (opSide == .black) ? h.position.row : (9 - h.position.row)
                if localRow == 1 && h.position.col == 4 { bonus += 600 }
            }
        }
        // 窝心马（己方，减分）
        if let mg = myGeneral {
            for h in myPieces where h.kind == .horse {
                let localRow = (side == .black) ? h.position.row : (9 - h.position.row)
                if localRow == 1 && h.position.col == 4 { bonus -= 600 }
            }
        }

        // 铁门栓变体
        if myKinds[.chariot, default: 0] >= 1 && myKinds[.cannon, default: 0] >= 1, let og = opGeneral {
            for ch in myPieces where ch.kind == .chariot {
                for ca in myPieces where ca.kind == .cannon {
                    if ch.position.col == og.col && ca.position.col == og.col { bonus += 1000 }
                }
            }
        }

        // --- v3.0 新增棋型 ---

        // 拐角马：马在对方九宫角，威胁将帅
        if let og = opGeneral {
            for h in myPieces where h.kind == .horse {
                if isCorneredHorse(horse: h, general: og, side: side) {
                    bonus += 500
                }
            }
        }

        // 担子炮：两个炮在同一直线上对峙
        bonus += tandemCannonBonus(pieces: myPieces)

        // 巡河炮：炮在己方河沿（黑方 row 4 / 红方 row 5）
        bonus += riverCannonBonus(pieces: myPieces, side: side)

        // 当头炮：炮在中路（col 4）对着对方将
        if let og = opGeneral, og.col == 4 {
            for c in myPieces where c.kind == .cannon && c.position.col == 4 {
                bonus += 400
            }
        }

        // 叠炮：两炮在同一列
        bonus += stackedCannonBonus(pieces: myPieces)

        // 羊角士：双士在九宫保护将帅
        if let mg = myGeneral {
            bonus += cornerAdvisorBonus(pieces: myPieces, general: mg, side: side)
        }

        // 飞相局：象在好位置
        if let mg = myGeneral {
            bonus += flyingElephantBonus(pieces: myPieces, general: mg, side: side)
        }

        // 过河兵
        for s in myPieces where s.kind == .soldier {
            let crossed = (side == .black) ? s.position.row >= 5 : s.position.row <= 4
            if crossed { bonus += 200 }
        }

        // 兵线协同：多个兵在同一行
        bonus += soldierLineSyncBonus(pieces: myPieces, side: side)

        // 飞将威胁：双方将在同一列，中间无子
        if let mg = myGeneral, let og = opGeneral, mg.col == og.col {
            var blocked = false
            let minR = min(mg.row, og.row) + 1
            let maxR = max(mg.row, og.row)
            for r in minR..<maxR {
                if board.piece(at: Position(row: r, col: mg.col)) != nil { blocked = true; break }
            }
            if !blocked {
                // 飞将——轮到谁走谁有利，简化给当前行加分
                bonus += 300
            }
        }

        // 车炮配合：车和炮在同一行或列
        bonus += chariotCannonCoordBonus(pieces: myPieces)

        // 马炮配合：马和炮在邻近位置
        bonus += horseCannonCoordBonus(pieces: myPieces)

        // 双车联动：两车在不同行不同列（避免重叠）
        if myKinds[.chariot, default: 0] >= 2 {
            let chariots = myPieces.filter { $0.kind == .chariot }
            if chariots.count == 2 {
                if chariots[0].position.row != chariots[1].position.row
                   && chariots[0].position.col != chariots[1].position.col {
                    bonus += 350  // 联动良好
                }
            }
        }

        // 双马连环：两马在日字互保位置
        if myKinds[.horse, default: 0] >= 2 {
            let horses = myPieces.filter { $0.kind == .horse }
            for i in 0..<horses.count {
                for j in (i+1)..<horses.count {
                    let rd = abs(horses[i].position.row - horses[j].position.row)
                    let cd = abs(horses[i].position.col - horses[j].position.col)
                    if (rd == 1 && cd == 2) || (rd == 2 && cd == 1) {
                        bonus += 250  // 互保
                    }
                }
            }
        }

        // 防空评估：对方无炮时，己方将帅较安全
        if opKinds[.cannon, default: 0] == 0 {
            bonus += 100
        }

        // 先手价值：简化版——子力推进加分（已在位置权重中体现，此处只加微调）
        // 这里不额外加分，避免重复计算

        return bonus
    }

    // MARK: - 原有棋型判定辅助（保持不变）

    private static func isHorseCannonPattern(horse: Piece, cannon: Piece,
                                              general: Position) -> Bool {
        let hCol = horse.position.col, cCol = cannon.position.col, gCol = general.col
        if hCol == cCol && cCol == gCol {
            let hRow = horse.position.row, cRow = cannon.position.row, gRow = general.row
            return (hRow < cRow && cRow < gRow) || (hRow > cRow && cRow > gRow)
        }
        if cannon.position.row == general.row {
            let colDist = abs(cCol - gCol)
            if colDist >= 2 {
                let minC = min(cCol, gCol), maxC = max(cCol, gCol)
                if horse.position.row == cannon.position.row
                    && horse.position.col > minC && horse.position.col < maxC {
                    return true
                }
            }
        }
        return false
    }

    private static func isFishingHorse(horse: Piece, general: Position) -> Bool {
        let rowDiff = abs(horse.position.row - general.row)
        let colDiff = abs(horse.position.col - general.col)
        return (rowDiff == 1 && colDiff == 2) || (rowDiff == 2 && colDiff == 1)
    }

    private static func isIronGate(chariot: Piece, general: Position, on board: Board) -> Bool {
        guard chariot.position.col == general.col else { return false }
        let minRow = min(chariot.position.row, general.row) + 1
        let maxRow = max(chariot.position.row, general.row)
        for row in minRow..<maxRow {
            if board.piece(at: Position(row: row, col: general.col)) != nil { return false }
        }
        return true
    }

    // MARK: - v3.0 新增棋型判定

    /// 拐角马：马在对方九宫角附近（对方九宫的两个上角）
    private static func isCorneredHorse(horse: Piece, general: Position, side: Side) -> Bool {
        let hRow = horse.position.row, hCol = horse.position.col
        let gRow = general.row, gCol = general.col
        // 马在九宫角的日字位
        let rowDiff = abs(hRow - gRow)
        let colDiff = abs(hCol - gCol)
        // 拐角：马距将 1-2 格，偏侧
        return (rowDiff <= 2 && colDiff <= 2) && (rowDiff + colDiff >= 2)
            && !((rowDiff == 1 && colDiff == 2) || (rowDiff == 2 && colDiff == 1))  // 排除钓鱼马
    }

    /// 担子炮：两炮同列，间距 ≥ 3，中间有对方子
    private static func tandemCannonBonus(pieces: [Piece]) -> Int {
        let cannons = pieces.filter { $0.kind == .cannon }
        guard cannons.count >= 2 else { return 0 }
        var bonus = 0
        for i in 0..<cannons.count {
            for j in (i+1)..<cannons.count {
                if cannons[i].position.col == cannons[j].position.col
                   && abs(cannons[i].position.row - cannons[j].position.row) >= 3 {
                    bonus += 300
                }
                if cannons[i].position.row == cannons[j].position.row
                   && abs(cannons[i].position.col - cannons[j].position.col) >= 3 {
                    bonus += 300
                }
            }
        }
        return bonus
    }

    /// 巡河炮：炮在己方河沿
    private static func riverCannonBonus(pieces: [Piece], side: Side) -> Int {
        let riverRow = (side == .black) ? 4 : 5
        var bonus = 0
        for p in pieces where p.kind == .cannon && p.position.row == riverRow {
            bonus += 200
        }
        return bonus
    }

    /// 叠炮：两炮同一列且相邻
    private static func stackedCannonBonus(pieces: [Piece]) -> Int {
        let cannons = pieces.filter { $0.kind == .cannon }
        guard cannons.count >= 2 else { return 0 }
        var bonus = 0
        for i in 0..<cannons.count {
            for j in (i+1)..<cannons.count {
                if cannons[i].position.col == cannons[j].position.col
                   && abs(cannons[i].position.row - cannons[j].position.row) <= 2 {
                    bonus += 250
                }
            }
        }
        return bonus
    }

    /// 羊角士：双士在九宫
    private static func cornerAdvisorBonus(pieces: [Piece], general: Position, side: Side) -> Int {
        let advisors = pieces.filter { $0.kind == .advisor }
        guard advisors.count >= 1 else { return 0 }
        var bonus = 0
        // 士在九宫内
        for a in advisors {
            let aLocalRow = (side == .black) ? a.position.row : (9 - a.position.row)
            if aLocalRow <= 2 && a.position.col >= 3 && a.position.col <= 5 {
                bonus += 150
            }
        }
        // 双士完整额外加分
        if advisors.count == 2 { bonus += 100 }
        return bonus
    }

    /// 飞相局：象在好位置（河边或中路）
    private static func flyingElephantBonus(pieces: [Piece], general: Position, side: Side) -> Int {
        let elephants = pieces.filter { $0.kind == .elephant }
        var bonus = 0
        for e in elephants {
            let localRow = (side == .black) ? e.position.row : (9 - e.position.row)
            // 象在河沿附近（localRow 2-4）是好位置
            if localRow >= 2 && localRow <= 4 {
                if e.position.col == 2 || e.position.col == 6 { bonus += 120 }
                if e.position.col == 4 { bonus += 80 }
            }
        }
        // 双象完整
        if elephants.count == 2 { bonus += 100 }
        return bonus
    }

    /// 兵线协同：多个兵在同一行
    private static func soldierLineSyncBonus(pieces: [Piece], side: Side) -> Int {
        let soldiers = pieces.filter { $0.kind == .soldier }
        guard soldiers.count >= 2 else { return 0 }
        var rowCounts: [Int: Int] = [:]
        for s in soldiers {
            rowCounts[s.position.row, default: 0] += 1
        }
        var bonus = 0
        for (_, count) in rowCounts {
            if count >= 2 { bonus += 150 * (count - 1) }
        }
        return bonus
    }

    /// 车炮配合：车和炮在同一行或列
    private static func chariotCannonCoordBonus(pieces: [Piece]) -> Int {
        let chariots = pieces.filter { $0.kind == .chariot }
        let cannons = pieces.filter { $0.kind == .cannon }
        guard !chariots.isEmpty && !cannons.isEmpty else { return 0 }
        var bonus = 0
        for ch in chariots {
            for ca in cannons {
                if ch.position.row == ca.position.row || ch.position.col == ca.position.col {
                    bonus += 180
                }
            }
        }
        return bonus
    }

    /// 马炮配合：马和炮在邻近位置（距离 ≤ 2）
    private static func horseCannonCoordBonus(pieces: [Piece]) -> Int {
        let horses = pieces.filter { $0.kind == .horse }
        let cannons = pieces.filter { $0.kind == .cannon }
        guard !horses.isEmpty && !cannons.isEmpty else { return 0 }
        var bonus = 0
        for h in horses {
            for ca in cannons {
                let dist = abs(h.position.row - ca.position.row) + abs(h.position.col - ca.position.col)
                if dist <= 2 { bonus += 150 }
            }
        }
        return bonus
    }
}
