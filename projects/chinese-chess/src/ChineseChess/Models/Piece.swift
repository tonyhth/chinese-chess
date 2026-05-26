import Foundation

struct Piece: Equatable, Identifiable {
    let id: UUID
    let kind: PieceKind
    let side: Side
    var position: Position

    init(kind: PieceKind, side: Side, position: Position, id: UUID = UUID()) {
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
}
