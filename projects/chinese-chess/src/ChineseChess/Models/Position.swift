import Foundation

struct Position: Equatable, Hashable {
    let row: Int   // 0..9, 0 = 黑方底线, 9 = 红方底线
    let col: Int   // 0..8, 0 = 最左列

    static func isValid(_ pos: Position) -> Bool {
        pos.row >= 0 && pos.row <= 9 && pos.col >= 0 && pos.col <= 8
    }

    var isInRedPalace: Bool {
        row >= 7 && row <= 9 && col >= 3 && col <= 5
    }

    var isInBlackPalace: Bool {
        row >= 0 && row <= 2 && col >= 3 && col <= 5
    }

    var isInRedHalf: Bool {
        row >= 5 && row <= 9
    }

    var isInBlackHalf: Bool {
        row >= 0 && row <= 4
    }
}
