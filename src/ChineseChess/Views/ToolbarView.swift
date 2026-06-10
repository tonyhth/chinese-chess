import SwiftUI

struct ToolbarView: View {
    let viewModel: GameViewModel

    var body: some View {
        HStack(spacing: 12) {
            // 棋局控制组
            HStack(spacing: 8) {
                Button(action: { viewModel.newGame() }) {
                    Label(String(localized: "new.game"), systemImage: "arrow.counterclockwise")
                }
                #if os(macOS)
                .keyboardShortcut("n", modifiers: .command)
                #endif
                .disabled(viewModel.isThinking)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint(String(localized: "new.game.hint"))

                Button(action: { viewModel.undoMove() }) {
                    Label(String(localized: "undo"), systemImage: "arrow.uturn.backward")
                }
                #if os(macOS)
                .keyboardShortcut("z", modifiers: .command)
                #endif
                .disabled(viewModel.isThinking || viewModel.board.moveHistory.isEmpty)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint(String(localized: "undo.hint"))

                Button(action: { viewModel.requestHint() }) {
                    Label(String(localized: "hint"), systemImage: "lightbulb")
                }
                #if os(macOS)
                .keyboardShortcut("h", modifiers: [.command, .shift])
                #endif
                .disabled(viewModel.isThinking || viewModel.gameState != .playing)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint(String(localized: "hint.hint"))
            }

            #if os(macOS)
            Divider()
                .frame(height: 24)
            #else
            Spacer()
            #endif

            // 设置组
            Picker(String(localized: "ai.difficulty"), selection: Binding(
                get: { viewModel.difficulty },
                set: { viewModel.setDifficulty($0) }
            )) {
                Text(String(localized: "difficulty.beginner")).tag(AIDifficulty.beginner)
                Text(String(localized: "difficulty.easy")).tag(AIDifficulty.easy)
                Text(String(localized: "difficulty.medium")).tag(AIDifficulty.medium)
                Text(String(localized: "difficulty.hard")).tag(AIDifficulty.hard)
                Text(String(localized: "difficulty.master")).tag(AIDifficulty.master)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
