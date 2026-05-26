import SwiftUI

struct ToolbarView: View {
    let viewModel: GameViewModel

    var body: some View {
        HStack(spacing: 16) {
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
            .disabled(viewModel.isThinking || viewModel.board.moveHistory.count < 2)
            .buttonStyle(.bordered)
            .tint(.brown)

            Spacer()

            // 难度选择
            Picker("难度", selection: Binding(
                get: { viewModel.difficulty },
                set: { viewModel.setDifficulty($0) }
            )) {
                Text("初级").tag(AIDifficulty.easy)
                Text("中级").tag(AIDifficulty.medium)
                Text("高级").tag(AIDifficulty.hard)
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
