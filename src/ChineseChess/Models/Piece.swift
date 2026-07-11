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
    /// 开局初始位置返回确定性 ID（0-31），其他位置返回基于确定性哈希的唯一 ID（32-999）
    /// ID 方案与 Board.initialPieces() 完全一致
    static func fallbackId(kind: PieceKind, side: Side, position: Position) -> Int {
        let baseId = side == .red ? 0 : 16

        switch kind {
        case .general:
            let generalRow = side == .red ? 9 : 0
            if position.row == generalRow && position.col == 4 {
                return baseId + 8
            }
        case .chariot:
            let chariotRow = side == .red ? 9 : 0
            if position.row == chariotRow && (position.col == 0 || position.col == 8) {
                return baseId + (position.col == 0 ? 0 : 1)
            }
        case .horse:
            let horseRow = side == .red ? 9 : 0
            if position.row == horseRow && (position.col == 1 || position.col == 7) {
                return baseId + (position.col == 1 ? 2 : 3)
            }
        case .cannon:
            let cannonRow = side == .red ? 7 : 2
            if position.row == cannonRow && (position.col == 1 || position.col == 7) {
                return baseId + 9 + (position.col == 1 ? 0 : 1)
            }
        case .advisor:
            let advisorRow = side == .red ? 9 : 0
            if position.row == advisorRow && (position.col == 3 || position.col == 5) {
                return baseId + (position.col == 3 ? 6 : 7)
            }
        case .elephant:
            let elephantRow = side == .red ? 9 : 0
            if position.row == elephantRow && (position.col == 2 || position.col == 6) {
                return baseId + (position.col == 2 ? 4 : 5)
            }
        case .soldier:
            let soldierRow = side == .red ? 6 : 3
            if position.row == soldierRow {
                switch position.col {
                case 0: return baseId + 11
                case 2: return baseId + 12
                case 4: return baseId + 13
                case 6: return baseId + 14
                case 8: return baseId + 15
                default: break
                }
            }
        }

        // 非开局位置：用确定性哈希生成唯一 ID（32-999 范围，避免与开局 ID 0-31 碰撞）
        // 使用乘法+加法链式组合，避免 XOR 碰撞和 hashValue 跨进程不确定问题
        return 32 + deterministicHash(kind: kind, side: side, position: position) % 968
    }

    /// 确定性哈希：基于 kind+side+position 生成跨进程稳定的哈希值
    /// 不使用 Swift hashValue（per-process seed 导致跨进程不确定）
    private static func deterministicHash(kind: PieceKind, side: Side, position: Position) -> Int {
        // PieceKind.allCases 顺序：general, advisor, elephant, horse, chariot, cannon, soldier
        let kindIndex = PieceKind.allCases.firstIndex(of: kind) ?? 0
        let sideBit = side == .red ? 1 : 0
        // 乘法+加法链式哈希，&* 溢出截断保证确定性
        var h = 0
        h = h &* 31 &+ kindIndex
        h = h &* 31 &+ sideBit
        h = h &* 31 &+ position.row
        h = h &* 31 &+ position.col
        return h < 0 ? ~h : h  // 避免负数，不用 abs() 防止 Int.min 溢出
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
