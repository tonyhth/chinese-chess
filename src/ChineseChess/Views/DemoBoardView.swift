import SwiftUI

/// 只读演示棋盘视图
///
/// 用于 PuzzleDemoView 的只读棋盘渲染。
/// 不依赖 GameViewModel/PuzzleViewModel，直接从 Board + lastMove 渲染。
/// 薄壳：渲染委托给 BoardCanvasView，无翻转动画。
struct DemoBoardView: View {
    let board: Board
    let lastMove: (from: Position, to: Position)?
    let isFlipped: Bool
    var theme: ThemeColors = ThemeManager.shared.colors

    var body: some View {
        BoardCanvasView(
            board: board,
            lastMove: lastMove,
            isFlipped: isFlipped,
            theme: theme
        )
    }
}
