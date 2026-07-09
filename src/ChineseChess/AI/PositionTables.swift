import Foundation

// MARK: - 位置权重表

/// 棋子位置权重评估（纯数据 + 查询方法）
/// 从 AIEngine 拆分出来，便于独立维护和测试
struct PositionTables {

    // MARK: - 兵/卒

    // 开局（黑卒视角）
    // v3.9: row 8 从 1/18 row7 调整为 ~1/3 row7，平滑过河后衰减
    private static let blackSoldierWeightsOpening: [[Int]] = [
        [  30,  30,  30,  30,  30,  30,  30,  30,  30],
        [  30,  30,  30,  30,  30,  30,  30,  30,  30],
        [  30,  30,  30,  30,  30,  30,  30,  30,  30],
        [  60,  30,  90,  30, 150,  30,  90,  30,  60],
        [ 120, 210, 300, 300, 360, 300, 300, 210, 120],
        [ 210, 360, 540, 630, 720, 630, 540, 360, 210],
        [ 300, 510, 810,1080,1440,1080, 810, 510, 300],
        [ 360, 660,1020,1440,2160,1440,1020, 660, 360],
        [ 120, 210, 330, 480, 720, 480, 330, 210, 120],
        [  30,  30,  30,  30,  30,  30,  30,  30,  30]
    ]

    // 残局（更强调推进）
    // v3.9: row 8 从 ~1/14 row7 调整为 ~1/3 row7，平滑过河后衰减
    private static let blackSoldierWeightsEndgame: [[Int]] = [
        [  30,  30,  30,  30,  30,  30,  30,  30,  30],
        [  30,  30,  30,  30,  30,  30,  30,  30,  30],
        [  30,  30,  30,  30,  30,  30,  30,  30,  30],
        [  90,  60, 120,  60, 210,  60, 120,  60,  90],
        [ 180, 270, 360, 420, 480, 420, 360, 270, 180],
        [ 300, 480, 690, 810, 960, 810, 690, 480, 300],
        [ 420, 660,1080,1440,1920,1440,1080, 660, 420],
        [ 540, 960,1500,2160,2880,2160,1500, 960, 540],
        [ 180, 330, 510, 720, 960, 720, 510, 330, 180],
        [  30,  30,  30,  30,  30,  30,  30,  30,  30]
    ]

    static func soldierPositionWeight(row: Int, col: Int, side: Side, isEndgame: Bool) -> Int {
        let r = (side == .black) ? row : (9 - row)
        return isEndgame ? blackSoldierWeightsEndgame[r][col] : blackSoldierWeightsOpening[r][col]
    }

    // MARK: - 马

    // v3.0 放大 15x + 零值清理
    private static let blackHorseWeights: [[Int]] = [
        [ 30,  60,  90,  90,  30,  90,  90,  60,  30],
        [ 60, 150, 210, 210, 210, 210, 210, 150,  60],
        [ 90, 210, 270, 300, 300, 300, 270, 210,  90],
        [120, 270, 360, 390, 420, 390, 360, 270, 120],
        [150, 300, 420, 480, 510, 480, 420, 300, 150],
        [150, 300, 420, 480, 510, 480, 420, 300, 150],
        [120, 270, 360, 390, 420, 390, 360, 270, 120],
        [ 90, 210, 270, 300, 300, 300, 270, 210,  90],
        [ 60, 150, 210, 210, 210, 210, 210, 150,  60],
        [ 30,  60,  90,  90,  30,  90,  90,  60,  30]
    ]

    static func horsePositionWeight(row: Int, col: Int, side: Side, isEndgame: Bool) -> Int {
        let r = (side == .black) ? row : (9 - row)
        return blackHorseWeights[r][col]
    }

    // MARK: - 车

    // v3.0 放大 15x
    private static let chariotEdgeRow: [Int] = [90, 120, 120, 180, 210, 180, 120, 120, 90]
    private static let chariotMidRow: [Int]  = [90, 150, 180, 240, 270, 240, 180, 150, 90]

    static func chariotPositionWeight(row: Int, col: Int, side: Side, isEndgame: Bool) -> Int {
        let r = (side == .black) ? row : (9 - row)
        return (r == 0 || r == 9) ? chariotEdgeRow[col] : chariotMidRow[col]
    }

    // MARK: - 炮

    // v3.0 放大 15x + 零值清理
    private static let blackCannonWeights: [[Int]] = [
        [ 30,  60,  90, 120, 150, 120,  90,  60,  30],
        [ 60,  90, 150, 210, 240, 210, 150,  90,  60],
        [ 90, 150, 210, 270, 300, 270, 210, 150,  90],
        [ 90, 180, 270, 330, 360, 330, 270, 180,  90],
        [120, 210, 300, 390, 420, 390, 300, 210, 120],
        [120, 210, 300, 390, 420, 390, 300, 210, 120],
        [ 90, 180, 270, 330, 360, 330, 270, 180,  90],
        [ 90, 150, 210, 270, 300, 270, 210, 150,  90],
        [ 60,  90, 150, 210, 240, 210, 150,  90,  60],
        [ 30,  60,  90, 120, 150, 120,  90,  60,  30]
    ]

    static func cannonPositionWeight(row: Int, col: Int, side: Side, isEndgame: Bool) -> Int {
        let r = (side == .black) ? row : (9 - row)
        return blackCannonWeights[r][col]
    }

    // MARK: - 将/帅

    static func generalPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let weights: [[Int]] = [
            [0, 0, 0, 2, 4, 2, 0, 0, 0],
            [0, 0, 0, 4, 8, 4, 0, 0, 0],
            [0, 0, 0, 2, 4, 2, 0, 0, 0]
        ]
        let localRowIdx = (side == .black) ? row : (9 - row)
        if localRowIdx >= 0 && localRowIdx <= 2 && col >= 3 && col <= 5 {
            return weights[localRowIdx][col]
        }
        return 0
    }

    // MARK: - 士

    static func advisorPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let localRow = (side == .black) ? row : (9 - row)
        if localRow == 1 && col == 4 { return 6 }
        if localRow >= 0 && localRow <= 2 && col >= 3 && col <= 5 { return 2 }
        return 0
    }

    // MARK: - 象

    static func elephantPositionWeight(row: Int, col: Int, side: Side) -> Int {
        let localRow = (side == .black) ? row : (9 - row)
        if localRow == 2 && (col == 2 || col == 6) { return 4 }
        if localRow == 0 && (col == 2 || col == 6) { return 2 }
        if localRow == 2 && col == 4 { return 2 }
        return 0
    }

    // MARK: - 统一查询接口

    /// 查询棋子在当前位置的权重加成
    static func positionWeight(for piece: Piece, totalPieces: Int) -> Int {
        let row = piece.position.row
        let col = piece.position.col
        let isEndgame = totalPieces <= 16

        switch piece.kind {
        case .general:  return generalPositionWeight(row: row, col: col, side: piece.side)
        case .advisor:  return advisorPositionWeight(row: row, col: col, side: piece.side)
        case .elephant: return elephantPositionWeight(row: row, col: col, side: piece.side)
        case .horse:    return horsePositionWeight(row: row, col: col, side: piece.side, isEndgame: isEndgame)
        case .chariot:  return chariotPositionWeight(row: row, col: col, side: piece.side, isEndgame: isEndgame)
        case .cannon:   return cannonPositionWeight(row: row, col: col, side: piece.side, isEndgame: isEndgame)
        case .soldier:  return soldierPositionWeight(row: row, col: col, side: piece.side, isEndgame: isEndgame)
        }
    }
}
