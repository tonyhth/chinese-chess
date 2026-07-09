import Foundation

struct Piece: Equatable, Identifiable, Codable {
    let id: Int              // P0-1 修正：稳定唯一 ID（0-31），开局分配
    let kind: PieceKind
    let side: Side
    var position: Position

    init(kind: PieceKind, side: Side, position: Position, id: Int) {
        self.id = id
        self.kind = kind
        self.side = side
        self.position = position
    }

    // MARK: - 显示名称

    var displayName: String {
        switch side {
        case .red:
            switch kind {
            case .general:  return "帅"
            case .advisor:  return "仕"
            case .elephant: return "相"
            case .horse:    return "馬"
            case .chariot:  return "車"
            case .cannon:   return "炮"
            case .soldier:  return "兵"
            }
        case .black:
            switch kind {
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

    // MARK: - 子力基础价值

    var baseValue: Int {
        switch kind {
        case .general:  return 10000
        case .chariot:  return 900
        case .cannon:   return 450
        case .horse:    return 400
        case .advisor:  return 200
        case .elephant: return 200
        case .soldier:
            // 过河兵/卒价值翻倍
            let hasCrossedRiver = (side == .red) ? position.row <= 4 : position.row >= 5
            return hasCrossedRiver ? 200 : 100
        }
    }

    // MARK: - P0-1 修正：fallback ID 推算（旧存档兼容）

    /// 根据棋子类型、方、位置推算 ID（用于旧存档兼容）
    /// 仅在开局初始位置时有效，其他位置返回 -1 表示无法推算
    /// ID 方案与 Board.initialPieces() 完全一致
    static func fallbackId(kind: PieceKind, side: Side, position: Position) -> Int {
        // 开局布局：
        // 黑方（row 0-3）:
        //   row 0: 车(0,0) 马(0,1) 象(0,2) 士(0,3) 将(0,4) 士(0,5) 象(0,6) 马(0,7) 车(0,8)
        //   row 2: 炮(2,1) 炮(2,7)
        //   row 3: 卒(3,0) 卒(3,2) 卒(3,4) 卒(3,6) 卒(3,8)
        // 红方（row 6-9）:
        //   row 9: 车(9,0) 马(9,1) 相(9,2) 仕(9,3) 帅(9,4) 仕(9,5) 相(9,6) 马(9,7) 车(9,8)
        //   row 7: 炮(7,1) 炮(7,7)
        //   row 6: 兵(6,0) 兵(6,2) 兵(6,4) 兵(6,6) 兵(6,8)

        let baseId = side == .red ? 0 : 16

        switch kind {
        case .general:
            let generalRow = side == .red ? 9 : 0
            guard position.row == generalRow else { return -1 }
            return baseId + 8
        case .chariot:
            let chariotRow = side == .red ? 9 : 0
            guard position.row == chariotRow else { return -1 }
            return baseId + (position.col == 0 ? 0 : (position.col == 8 ? 1 : -1))
        case .horse:
            let horseRow = side == .red ? 9 : 0
            guard position.row == horseRow else { return -1 }
            return baseId + (position.col == 1 ? 2 : (position.col == 7 ? 3 : -1))
        case .cannon:
            let cannonRow = side == .red ? 7 : 2
            guard position.row == cannonRow else { return -1 }
            return baseId + 9 + (position.col == 1 ? 0 : (position.col == 7 ? 1 : -1))
        case .advisor:
            let advisorRow = side == .red ? 9 : 0
            guard position.row == advisorRow else { return -1 }
            return baseId + (position.col == 3 ? 6 : (position.col == 5 ? 7 : -1))
        case .elephant:
            let elephantRow = side == .red ? 9 : 0
            guard position.row == elephantRow else { return -1 }
            return baseId + (position.col == 2 ? 4 : (position.col == 6 ? 5 : -1))
        case .soldier:
            let soldierRow = side == .red ? 6 : 3
            guard position.row == soldierRow else { return -1 }
            switch position.col {
            case 0: return baseId + 11
            case 2: return baseId + 12
            case 4: return baseId + 13
            case 6: return baseId + 14
            case 8: return baseId + 15
            default: return -1
            }
        }
    }

    // MARK: - Codable 兼容（处理旧存档）

    enum CodingKeys: String, CodingKey {
        case id, kind, side, position
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(PieceKind.self, forKey: .kind)
        side = try c.decode(Side.self, forKey: .side)
        position = try c.decode(Position.self, forKey: .position)

        // 兼容旧存档：id 可能是 Int、UUID String、或不存在
        if let idInt = try c.decodeIfPresent(Int.self, forKey: .id) {
            self.id = idInt
        } else if let idString = try c.decodeIfPresent(String.self, forKey: .id) {
            // 旧存档可能用 UUID String，降级用 fallbackId
            self.id = Self.fallbackId(kind: kind, side: side, position: position)
        } else {
            // id 字段不存在，用 fallbackId
            self.id = Self.fallbackId(kind: kind, side: side, position: position)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(side, forKey: .side)
        try c.encode(position, forKey: .position)
    }
}
