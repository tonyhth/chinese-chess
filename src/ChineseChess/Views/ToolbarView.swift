import SwiftUI

struct ToolbarView: View {
    let viewModel: GameViewModel

    var body: some View {
        HStack(spacing: 12) {
            // 新局
            Button(action: { viewModel.newGame() }) {
                Label("新局", systemImage: "arrow.counterclockwise")
            }
            #if os(macOS)
            .keyboardShortcut("n", modifiers: .command)
            #endif
            .disabled(viewModel.isThinking)
            .buttonStyle(.bordered)
            .tint(.brown)

            // 悔棋
            Button(action: { viewModel.undoMove() }) {
                Label("悔棋", systemImage: "arrow.uturn.backward")
            }
            #if os(macOS)
            .keyboardShortcut("z", modifiers: .command)
            #endif
            .disabled(viewModel.isThinking || viewModel.board.moveHistory.isEmpty)
            .buttonStyle(.bordered)
            .tint(.brown)

            // 提示
            Button(action: { viewModel.requestHint() }) {
                Label("提示", systemImage: "lightbulb")
            }
            #if os(macOS)
            .keyboardShortcut("h", modifiers: [.command, .shift])
            #endif
            .disabled(viewModel.isThinking || viewModel.gameState != .playing)
            .buttonStyle(.bordered)
            .tint(.brown)

            Spacer()

            // 难度选择
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
