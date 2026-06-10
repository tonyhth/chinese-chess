import SwiftUI

struct ToolbarView: View {
    let viewModel: GameViewModel

    var body: some View {
        HStack(spacing: 12) {
            // 棋局控制组
            HStack(spacing: 8) {
                Button(action: { viewModel.newGame() }) {
                    Label("新局", systemImage: "arrow.counterclockwise")
                }
                #if os(macOS)
                .keyboardShortcut("n", modifiers: .command)
                #endif
                .disabled(viewModel.isThinking)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint("双击开始新对局")

                Button(action: { viewModel.undoMove() }) {
                    Label("悔棋", systemImage: "arrow.uturn.backward")
                }
                #if os(macOS)
                .keyboardShortcut("z", modifiers: .command)
                #endif
                .disabled(viewModel.isThinking || viewModel.board.moveHistory.isEmpty)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint("双击撤销上一步")

                Button(action: { viewModel.requestHint() }) {
                    Label("提示", systemImage: "lightbulb")
                }
                #if os(macOS)
                .keyboardShortcut("h", modifiers: [.command, .shift])
                #endif
                .disabled(viewModel.isThinking || viewModel.gameState != .playing)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint("双击获取走法提示")
            }

            #if os(macOS)
            Divider()
                .frame(height: 24)
            #else
            Spacer()
            #endif

            // 设置组
            Picker("AI 难度", selection: Binding(
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
