import SwiftUI

@main
struct ChineseChessApp: App {
    @State private var viewModel = GameViewModel()
    @State private var showStats = false
    @State private var showRecord = false

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

                    // 底部操作栏
                    HStack(spacing: 12) {
                        Button(action: { showRecord.toggle() }) {
                            Label("棋谱", systemImage: "doc.text")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)

                        Button(action: { showStats.toggle() }) {
                            Label("统计", systemImage: "chart.bar")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                // 游戏结束弹窗
                if viewModel.gameState != .playing {
                    GameOverOverlay(gameState: viewModel.gameState) {
                        viewModel.newGame()
                    }
                }

                // 棋谱面板
                if showRecord {
                    VStack {
                        Spacer()
                        RecordPanelView(gameMoves: viewModel.gameMoves)
                            .frame(maxWidth: 300, maxHeight: 300)
                            .padding()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // 统计面板
                if showStats {
                    VStack {
                        Spacer()
                        StatsPanelView()
                            .frame(maxWidth: 300)
                            .padding()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
