import SwiftUI

/// 回放专用棋盘视图
///
/// 独立于 ChessBoardView / BoardMode enum，避免 enum 持有 @Observable associated value
/// 导致 AG LayoutDescriptor 在 sheet 中递归崩溃。
///
/// 只读模式：渲染棋盘 + 棋子 + 上一步高亮，无交互层。
/// 薄壳：渲染委托给 BoardCanvasView，自身仅负责数据适配 + 翻转动画。
struct ReplayBoardView: View {
    let viewModel: ReplayViewModel
    var theme: ThemeColors = ThemeManager.shared.colors
    var isFlipped: Bool = false

    var body: some View {
        BoardCanvasView(
            board: viewModel.board,
            lastMove: viewModel.lastMove,
            isFlipped: isFlipped,
            theme: theme
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFlipped)
    }
}
