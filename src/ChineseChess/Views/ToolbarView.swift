import SwiftUI

struct ToolbarView: View {
    let viewModel: GameViewModel

    private let l10n = L10n.shared

    var body: some View {
        #if os(iOS)
        HStack {
            // 左侧：悔棋 + 提示（对局辅助操作）
            HStack(spacing: 8) {
                Button(action: { viewModel.undoMove() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(viewModel.isThinking || viewModel.board.moveHistory.isEmpty)
                .tint(.brown)
                .accessibilityLabel(l10n.t("game.undoMove"))
                .accessibilityHint(l10n.t("accessibility.undoHint"))

                Button(action: { viewModel.requestHint() }) {
                    Image(systemName: "lightbulb")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(viewModel.isThinking || viewModel.gameState != .playing)
                .tint(.brown)
                .accessibilityLabel(l10n.t("game.hint"))
                .accessibilityHint(l10n.t("accessibility.hintActionHint"))
            }

            Spacer()

            // 右侧：新开一局（高风险操作，远离悔棋）
            Button(action: { viewModel.newGame() }) {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.isThinking)
            .tint(.brown)
            .accessibilityLabel(l10n.t("game.newGame"))
            .accessibilityHint(l10n.t("accessibility.newGameHint"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        #else
        HStack(spacing: 12) {
            // 棋局控制组
            HStack(spacing: 8) {
                Button(action: { viewModel.newGame() }) {
                    Label(l10n.t("game.newGame"), systemImage: "arrow.counterclockwise")
                }
                #if os(macOS)
                .keyboardShortcut("n", modifiers: .command)
                #endif
                .disabled(viewModel.isThinking)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint(l10n.t("accessibility.newGameHint"))

                Button(action: { viewModel.undoMove() }) {
                    Label(l10n.t("game.undoMove"), systemImage: "arrow.uturn.backward")
                }
                #if os(macOS)
                .keyboardShortcut("z", modifiers: .command)
                #endif
                .disabled(viewModel.isThinking || viewModel.board.moveHistory.isEmpty)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint(l10n.t("accessibility.undoHint"))

                Button(action: { viewModel.requestHint() }) {
                    Label(l10n.t("game.hint"), systemImage: "lightbulb")
                }
                #if os(macOS)
                .keyboardShortcut("h", modifiers: [.command, .shift])
                #endif
                .disabled(viewModel.isThinking || viewModel.gameState != .playing)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint(l10n.t("accessibility.hintActionHint"))
            }

            #if os(macOS)
            Divider()
                .frame(height: 24)
            #else
            Spacer()
            #endif

            // 设置组
            HStack(spacing: 8) {
                // P2 #10: 执边选择
                Picker("执方", selection: Binding(
                    get: { viewModel.humanSide },
                    set: { viewModel.setHumanSide($0); viewModel.newGame() }
                )) {
                    Text("红").tag(Side.red)
                    Text("黑").tag(Side.black)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
                .help("选择执方")

                Picker(l10n.t("difficulty.label"), selection: Binding(
                    get: { viewModel.difficulty },
                    set: { viewModel.setDifficulty($0) }
                )) {
                    Text(l10n.t("difficulty.beginner")).tag(AIDifficulty.beginner)
                    Text(l10n.t("difficulty.easy")).tag(AIDifficulty.easy)
                    Text(l10n.t("difficulty.medium")).tag(AIDifficulty.medium)
                    Text(l10n.t("difficulty.hard")).tag(AIDifficulty.hard)
                    Text(l10n.t("difficulty.master")).tag(AIDifficulty.master)
                }
                .pickerStyle(.menu)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        #endif
    }
}
