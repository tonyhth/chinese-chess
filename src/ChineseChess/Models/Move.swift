import Foundation

struct Move: Equatable {
    let piece: Piece          // 移动的棋子（移动前快照）
    let from: Position        // 起点
    let to: Position          // 终点
    let captured: Piece?      // 被吃棋子（无则 nil）
}
