import SwiftUI

struct ToolbarView: View {
    let viewModel: GameViewModel
    var onReplayRequest: (() -> Void)? = nil

    private let l10n = L10n.shared

    // Toast 提示状态
    @State private var showToast = false
    @State private var toastMessage = ""
    // v3.7.1 P2-3: 执边切换确认
    @State private var showSideSwitchConfirm = false
    // AI 思考视觉指示
    @State private var showThinkingIndicator = false
    @State private var thinkingTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            toolbarContent

            // AI 思考指示器
            if showThinkingIndicator {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(l10n.t("game.thinking"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // Toast overlay（allowsHitTesting(false) 不拦截下方按钮）
            if showToast {
                VStack {
                    Text(toastMessage)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .offset(y: 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showToast = false }
                            }
                        }
                    Spacer()
                }
                .padding(.top, 8)
                .allowsHitTesting(false)
            }
        }
        // P1 返工：监听引擎 fallback 通知，显示 Toast
        .onChange(of: viewModel.engineFallbackMessage) {
            if let msg = viewModel.engineFallbackMessage {
                toastMessage = msg
                withAnimation { showToast = true }
                viewModel.engineFallbackMessage = nil
            }
        }
        .onChange(of: viewModel.isThinking) {
            thinkingTask?.cancel()
            if viewModel.isThinking {
                thinkingTask = Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation { showThinkingIndicator = true }
                }
            } else {
                withAnimation { showThinkingIndicator = false }
            }
        }
        .alert(l10n.t("game.resignConfirm"), isPresented: Binding(
            get: { viewModel.showResignConfirm },
            set: { if !$0 { viewModel.cancelResign() } }
        )) {
            Button(l10n.t("common.cancel"), role: .cancel) { viewModel.cancelResign() }
            Button(l10n.t("game.resign"), role: .destructive) { viewModel.confirmResign() }
        } message: {
            Text(l10n.t("game.resignConfirmMessage"))
        }

    }

    @ViewBuilder
    private var toolbarContent: some View {
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

                // 认输按钮
                Button(action: { viewModel.requestResign() }) {
                    Image(systemName: "flag.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(viewModel.isThinking || viewModel.gameState != .playing)
                .tint(.red)
                .accessibilityLabel(l10n.t("game.resign"))

                // FINAL-002: 对局结束后显示复盘按钮
                if viewModel.gameState != .playing, let onReplayRequest = onReplayRequest {
                    Button(action: onReplayRequest) {
                        Image(systemName: "arrow.uturn.forward.circle")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .tint(.brown)
                    .accessibilityLabel(l10n.t("game.replay"))
                }
            }

            Spacer()

            // 右侧：执边 + 新开一局
            HStack(spacing: 8) {
                // v3.7.1 B1: iOS 执边选择按钮（P2-3: 对弈中确认）
                Button(action: {
                    if !viewModel.board.moveHistory.isEmpty && viewModel.gameState == .playing {
                        showSideSwitchConfirm = true
                    } else {
                        let newSide: Side = viewModel.humanSide == .red ? .black : .red
                        viewModel.setHumanSide(newSide)
                        viewModel.newGame()
                    }
                }) {
                    Circle()
                        .fill(viewModel.humanSide == .red ? Color.red : Color.black)
                        .frame(width: 14, height: 14)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(viewModel.isThinking)
                .opacity(viewModel.isThinking ? 0.5 : 1.0)
                .tint(.brown)
                .accessibilityLabel(l10n.t("game.sideLabel"))

                // v6.0: 10 级难度快捷菜单
                Menu {
                    Button(l10n.t("difficulty.lvl1")) { viewModel.setDifficulty(.novice) }
                    Button(l10n.t("difficulty.lvl2")) { viewModel.setDifficulty(.beginner) }
                    Button(l10n.t("difficulty.lvl3")) { viewModel.setDifficulty(.amateurLow) }
                    Button(l10n.t("difficulty.lvl4")) { viewModel.setDifficulty(.amateurMid) }
                    Button(l10n.t("difficulty.lvl5")) { viewModel.setDifficulty(.amateurHigh) }
                    Divider()
                    Button(l10n.t("difficulty.lvl6")) { viewModel.setDifficulty(.amateurDan) }
                    Button(l10n.t("difficulty.lvl7")) { viewModel.setDifficulty(.proApprentice) }
                    Button(l10n.t("difficulty.lvl8")) { viewModel.setDifficulty(.proExpert) }
                    Button(l10n.t("difficulty.lvl9")) { viewModel.setDifficulty(.proMaster) }
                    Button(l10n.t("difficulty.lvl10")) { viewModel.setDifficulty(.grandmaster) }
                } label: {
                    Text(difficultyShortName(viewModel.difficulty))
                        .font(.caption.weight(.bold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(viewModel.isThinking)
                .opacity(viewModel.isThinking ? 0.5 : 1.0)
                .tint(.brown)
                .accessibilityLabel(l10n.t("difficulty.label"))

                Button(action: { viewModel.newGame() }) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(viewModel.isThinking)
                .opacity(viewModel.isThinking ? 0.5 : 1.0)
                .tint(.brown)
                .accessibilityLabel(l10n.t("game.newGame"))
                .accessibilityHint(l10n.t("accessibility.newGameHint"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .alert(l10n.t("game.sideSwitchConfirmTitle"), isPresented: $showSideSwitchConfirm) {
            Button(l10n.t("common.cancel"), role: .cancel) {}
            Button(l10n.t("game.newGame")) {
                let newSide: Side = viewModel.humanSide == .red ? .black : .red
                viewModel.setHumanSide(newSide)
                viewModel.newGame()
            }
        } message: {
            Text(l10n.t("game.sideSwitchConfirmMessage"))
        }
        #else
        HStack(spacing: 12) {
            // 棋局控制组（左侧不动）
            HStack(spacing: 8) {
                Button(action: { viewModel.newGame() }) {
                    Label(l10n.t("game.newGame"), systemImage: "arrow.counterclockwise")
                }
                #if os(macOS)
                .keyboardShortcut("n", modifiers: .command)
                .controlSize(.small)
                .help(l10n.t("game.newGameTooltip"))
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
                .controlSize(.small)
                .help(l10n.t("game.undoMoveTooltip"))
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
                .controlSize(.small)
                .help(l10n.t("game.hintTooltip"))
                #endif
                .disabled(viewModel.isThinking || viewModel.gameState != .playing)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint(l10n.t("accessibility.hintActionHint"))

                Button(action: { viewModel.requestResign() }) {
                    Label(l10n.t("game.resign"), systemImage: "flag.fill")
                }
                #if os(macOS)
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .controlSize(.small)
                .help(l10n.t("game.resign"))
                #endif
                .disabled(viewModel.isThinking || viewModel.gameState != .playing)
                .buttonStyle(.bordered)
                .tint(.red)

                // FINAL-002: 对局结束后显示复盘按钮
                if viewModel.gameState != .playing, let onReplayRequest = onReplayRequest {
                    Button(action: onReplayRequest) {
                        Label(l10n.t("game.replay"), systemImage: "arrow.uturn.forward.circle")
                    }
                    #if os(macOS)
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                    .controlSize(.small)
                    .help(l10n.t("game.replay"))
                    #endif
                    .buttonStyle(.bordered)
                    .tint(.brown)
                }
            }

            // 自然分隔（替换 Divider）
            Spacer()

            // 设置组：难度 | 引擎 | 红黑圆点（低频操作放最右）
            HStack(spacing: 8) {
                // AI 难度：仅图标下拉
                Picker(l10n.t("difficulty.label"), selection: Binding(
                    get: { viewModel.difficulty },
                    set: { viewModel.setDifficulty($0) }
                )) {
                    Group {
                        Text(l10n.t("difficulty.lvl1")).tag(AIDifficulty.novice)
                        Text(l10n.t("difficulty.lvl2")).tag(AIDifficulty.beginner)
                        Text(l10n.t("difficulty.lvl3")).tag(AIDifficulty.amateurLow)
                        Text(l10n.t("difficulty.lvl4")).tag(AIDifficulty.amateurMid)
                        Text(l10n.t("difficulty.lvl5")).tag(AIDifficulty.amateurHigh)
                    }
                    Group {
                        Text(l10n.t("difficulty.lvl6")).tag(AIDifficulty.amateurDan)
                        Text(l10n.t("difficulty.lvl7")).tag(AIDifficulty.proApprentice)
                        Text(l10n.t("difficulty.lvl8")).tag(AIDifficulty.proExpert)
                        Text(l10n.t("difficulty.lvl9")).tag(AIDifficulty.proMaster)
                        Text(l10n.t("difficulty.lvl10")).tag(AIDifficulty.grandmaster)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 70)
                .help(l10n.t("difficulty.label"))

                // 执边选择：颜色圆点按钮（SF Symbol）
                Button(action: {
                    let newSide: Side = viewModel.humanSide == .red ? .black : .red
                    viewModel.setHumanSide(newSide)
                    viewModel.newGame()
                }) {
                    Circle()
                        .fill(viewModel.humanSide == .red ? Color.red : Color.black)
                        .frame(width: 12, height: 12)
                }
                .disabled(viewModel.isThinking)
                .opacity(viewModel.isThinking ? 0.5 : 1.0)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(l10n.t("game.sideTooltip", l10n.t(viewModel.humanSide == .red ? "game.redSide" : "game.blackSide")))
                .accessibilityLabel(l10n.t("game.sideLabel"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        #endif
    }

    // MARK: - Helpers

    /// v3.7.1 B2: 难度首字缩写（iOS 工具栏用）
    /// v6.0: 难度短名称（10 级独立短名，用于 iOS 工具栏）
    private func difficultyShortName(_ difficulty: AIDifficulty) -> String {
        switch difficulty {
        case .novice:        return l10n.t("difficulty.short.lvl1")
        case .beginner:      return l10n.t("difficulty.short.lvl2")
        case .amateurLow:    return l10n.t("difficulty.short.lvl3")
        case .amateurMid:    return l10n.t("difficulty.short.lvl4")
        case .amateurHigh:   return l10n.t("difficulty.short.lvl5")
        case .amateurDan:    return l10n.t("difficulty.short.lvl6")
        case .proApprentice: return l10n.t("difficulty.short.lvl7")
        case .proExpert:     return l10n.t("difficulty.short.lvl8")
        case .proMaster:     return l10n.t("difficulty.short.lvl9")
        case .grandmaster:   return l10n.t("difficulty.short.lvl10")
        }
    }
}
