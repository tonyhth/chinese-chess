import SwiftUI

struct ToolbarView: View {
    let viewModel: GameViewModel

    var body: some View {
        #if os(iOS)
        HStack(spacing: 0) {
            Button(action: { viewModel.newGame() }) {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.isThinking)
            .tint(.brown)
            .accessibilityLabel(String(localized: "game.newGame"))
            .accessibilityHint(String(localized: "accessibility.newGameHint"))

            Button(action: { viewModel.undoMove() }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.isThinking || viewModel.board.moveHistory.isEmpty)
            .tint(.brown)
            .accessibilityLabel(String(localized: "game.undoMove"))
            .accessibilityHint(String(localized: "accessibility.undoHint"))

            Button(action: { viewModel.requestHint() }) {
                Image(systemName: "lightbulb")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.isThinking || viewModel.gameState != .playing)
            .tint(.brown)
            .accessibilityLabel(String(localized: "game.hint"))
            .accessibilityHint(String(localized: "accessibility.hintActionHint"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        #else
        HStack(spacing: 12) {
            // 棋局控制组
            HStack(spacing: 8) {
                Button(action: { viewModel.newGame() }) {
                    Label(String(localized: "game.newGame"), systemImage: "arrow.counterclockwise")
                }
                #if os(macOS)
                .keyboardShortcut("n", modifiers: .command)
                #endif
                .disabled(viewModel.isThinking)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint(String(localized: "accessibility.newGameHint"))

                Button(action: { viewModel.undoMove() }) {
                    Label(String(localized: "game.undoMove"), systemImage: "arrow.uturn.backward")
                }
                #if os(macOS)
                .keyboardShortcut("z", modifiers: .command)
                #endif
                .disabled(viewModel.isThinking || viewModel.board.moveHistory.isEmpty)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint(String(localized: "accessibility.undoHint"))

                Button(action: { viewModel.requestHint() }) {
                    Label(String(localized: "game.hint"), systemImage: "lightbulb")
                }
                #if os(macOS)
                .keyboardShortcut("h", modifiers: [.command, .shift])
                #endif
                .disabled(viewModel.isThinking || viewModel.gameState != .playing)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint(String(localized: "accessibility.hintActionHint"))
            }

            #if os(macOS)
            Divider()
                .frame(height: 24)
            #else
            Spacer()
            #endif

            // 设置组
            Picker(String(localized: "difficulty.label"), selection: Binding(
                get: { viewModel.difficulty },
                set: { viewModel.setDifficulty($0) }
            )) {
                Text(String(localized: "difficulty.beginner")).tag(AIDifficulty.beginner)
                Text(String(localized: "difficulty.easy")).tag(AIDifficulty.easy)
                Text(String(localized: "difficulty.medium")).tag(AIDifficulty.medium)
                Text(String(localized: "difficulty.hard")).tag(AIDifficulty.hard)
                Text(String(localized: "difficulty.master")).tag(AIDifficulty.master)
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        #endif
    }
}
