import SwiftUI

/// BoardView 保留为薄包装，内部使用 ChessBoardView
struct BoardView: View {
    let viewModel: GameViewModel
    var theme: ThemeColors = ThemeManager.shared.colors

    var body: some View {
        ChessBoardView(mode: .playGame(viewModel), theme: theme)
    }
}
