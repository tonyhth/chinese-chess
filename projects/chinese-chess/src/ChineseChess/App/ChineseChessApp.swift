import SwiftUI

@main
struct ChineseChessApp: App {
    @State private var viewModel = GameViewModel()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 窗口背景
                Color(red: 44/255, green: 24/255, blue: 16/255)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ToolbarView(viewModel: viewModel)

                    BoardView(viewModel: viewModel)
                        .padding()

                    StatusBarView(viewModel: viewModel)
                }

                // 游戏结束弹窗
                if viewModel.gameState != .playing {
                    GameOverOverlay(gameState: viewModel.gameState) {
                        viewModel.newGame()
                    }
                }
            }
            .frame(minWidth: 600, minHeight: 720)
            .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 660, height: 780)
    }
}
