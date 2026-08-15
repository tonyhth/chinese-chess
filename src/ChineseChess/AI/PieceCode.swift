// PieceCode.swift — 90 格信箱编码辅助（m1-hotpath-redesign v1.2 §2.1）
//
// 纯函数无状态：code 编码（正=红/负=黑，abs=棋种）与 Position ↔ sq 互转。
// 热路径直查（switch 映射，无字典哈希、无数组分配）。

import Foundation

enum PieceCode {
    /// 空格编码
    static let empty: Int8 = 0

    /// 棋种 → 编码：general=1, advisor=2, elephant=3, horse=4, chariot=5, cannon=6, soldier=7；黑方取负
    static func code(kind: PieceKind, side: Side) -> Int8 {
        let base: Int8
        switch kind {
        case .general:  base = 1
        case .advisor:  base = 2
        case .elephant: base = 3
        case .horse:    base = 4
        case .chariot:  base = 5
        case .cannon:   base = 6
        case .soldier:  base = 7
        }
        return side == .red ? base : -base
    }

    /// abs 解码：棋子编码 → 棋种
    static func kind(of code: Int8) -> PieceKind {
        switch code < 0 ? -code : code {
        case 1:  return .general
        case 2:  return .advisor
        case 3:  return .elephant
        case 4:  return .horse
        case 5:  return .chariot
        case 6:  return .cannon
        default: return .soldier
        }
    }

    /// sign 解码：棋子编码 → 阵营（0 = 空格，约定返回 .red——调用方应先判 empty）
    static func side(of code: Int8) -> Side {
        code >= 0 ? .red : .black
    }

    /// Position → 90 格索引：sq = row * 9 + col（row 0..9, col 0..8，sq ∈ 0..89）
    static func square(_ pos: Position) -> Int8 {
        Int8(pos.row * 9 + pos.col)
    }

    /// 90 格索引 → Position（逆变换）
    static func position(_ sq: Int8) -> Position {
        Position(row: Int(sq) / 9, col: Int(sq) % 9)
    }
}
