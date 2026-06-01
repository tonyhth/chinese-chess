import SwiftUI

struct ToolbarView: View {
    let viewModel: GameViewModel

    var body: some View {
        HStack(spacing: 12) {
            // 新局
            Button(action: { viewModel.newGame() }) {
                Label("新局", systemImage: "arrow.counterclockwise")
            }
            .disabled(viewModel.isThinking)
            .buttonStyle(.bordered)
            .tint(.brown)

            // 悔棋
            Button(action: { viewModel.undoMove() }) {
                Label("悔棋", systemImage: "arrow.uturn.backward")
            }
            .disabled(viewModel.isThinking || viewModel.board.moveHistory.isEmpty)
            .buttonStyle(.bordered)
            .tint(.brown)

            Spacer()

            // 对战模式
            Picker("模式", selection: Binding(
                get: { viewModel.gameMode },
                set: { viewModel.setGameMode($0) }
            )) {
                Text("人机").tag(GameMode.singlePlayer)
                Text("人人").tag(GameMode.localPVP)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)

            // 难度选择（仅人机模式）
            if viewModel.gameMode == .singlePlayer {
                Picker("难度", selection: Binding(
                    get: { viewModel.difficulty },
                    set: { viewModel.setDifficulty($0) }
                )) {
                    Text("新手").tag(AIDifficulty.beginner)
                    Text("初级").tag(AIDifficulty.easy)
                    Text("中级").tag(AIDifficulty.medium)
                    Text("高级").tag(AIDifficulty.hard)
                    Text("大师").tag(AIDifficulty.master)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
