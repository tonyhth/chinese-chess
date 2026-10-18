import SwiftUI

/// v6.4 C1：工具栏溢出菜单项（LJ-2 根治——低频操作收敛 ⋯ 菜单）
struct ToolbarOverflowItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    var disabled: Bool = false
    var isDivider: Bool = false
    var action: () -> Void = {}

    static func divider(id: String) -> ToolbarOverflowItem {
        ToolbarOverflowItem(id: id, title: "", icon: "", isDivider: true)
    }
}

struct ToolbarView: View {
    let viewModel: GameViewModel
    var onReplayRequest: (() -> Void)? = nil
    // T-1020-OC-02 随批修 B：学棋提权入内联的 sheet 回调（与 onReplayRequest 同构）
    var onStudyHubRequest: (() -> Void)? = nil
    // v6.4 C1（LJ-2 根治）：低频操作入溢出菜单（macOS；iOS 本期不动）
    var overflowItems: [ToolbarOverflowItem] = []

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
                    // P2-4: 公共数据源（与 macOS Picker/设置页同源，防第三套词汇表）
                    ForEach(AIDifficulty.amateurLevels, id: \.self) { d in
                        Button(l10n.t("difficulty.\(d.rawValue)")) { viewModel.setDifficulty(d) }
                    }
                    Divider()
                    ForEach(AIDifficulty.visibleProfessionalLevels, id: \.self) { d in
                        Button(l10n.t("difficulty.\(d.rawValue)")) { viewModel.setDifficulty(d) }
                    }
                } label: {
                    // v6.2 洪涛令：级位短标签退场，顶部与设置页统一 10 级长名词汇
                    Text(l10n.t("difficulty.\(viewModel.difficulty.rawValue)"))
                        .font(.caption.weight(.bold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
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
                    // v6.4 C1 refine#1：键帽常驻（⌘Z）
                    Text("⌘Z").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
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
                    // v6.4 C1 refine#1：键帽常驻（⌘I；v2.1 定案：⌘H 与 macOS Hide 冲突弃用）
                    Text("⌘I").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                }
                #if os(macOS)
                .keyboardShortcut("i", modifiers: .command)
                .controlSize(.small)
                .help(l10n.t("game.hintTooltip"))
                #endif
                .disabled(viewModel.isThinking || viewModel.gameState != .playing)
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityHint(l10n.t("accessibility.hintActionHint"))

                // T-1020-OC-02 随批修 B：学棋提权入内联（洪涛主诉学棋折叠找不到；裁定 A+B）
                Button(action: { onStudyHubRequest?() }) {
                    Label(l10n.t("toolbar.study"), systemImage: "graduationcap.fill")
                }
                #if os(macOS)
                .controlSize(.small)
                .help(l10n.t("toolbar.study"))
                #endif
                .buttonStyle(.bordered)
                .tint(.brown)
                .accessibilityLabel(l10n.t("toolbar.study"))

                // v6.4 C1：认输/复盘/低频项全部入溢出菜单（下方 overflowMenu）
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
                    // P2-4: 公共数据源（与 iOS 菜单/设置页同源）
                    ForEach(AIDifficulty.amateurLevels, id: \.self) { d in
                        Text(l10n.t("difficulty.\(d.rawValue)")).tag(d)
                    }
                    ForEach(AIDifficulty.visibleProfessionalLevels, id: \.self) { d in
                        Text(l10n.t("difficulty.\(d.rawValue)")).tag(d)
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

                // v6.4 C1：溢出菜单（低频操作收纳，LJ-2 根治）
                if !overflowItems.isEmpty {
                    Menu {
                        ForEach(overflowItems) { item in
                            if item.isDivider {
                                Divider()
                            } else {
                                Button(action: item.action) {
                                    Label(item.title, systemImage: item.icon)
                                }
                                .disabled(item.disabled)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help(l10n.t("p1.overflow"))
                    .accessibilityLabel(l10n.t("p1.overflow"))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        // T-1020-OC-02 ④：工具栏宽度采样（LayoutDump 基线；Debug+env LAYOUT_DUMP=1 门控，产品零影响；
        // Ruby R2 约束：background GeometryReader + onChange，禁 onGeometryChange）
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        LayoutDump.sample(page: "T1020-toolbar", width: geo.size.width,
                          params: ["overflow": String(overflowItems.count), "studyHubInline": "1"])
                    }
                    .onChange(of: geo.size.width) { _, w in
                        LayoutDump.sample(page: "T1020-toolbar", width: w,
                          params: ["overflow": String(overflowItems.count), "studyHubInline": "1"])
                    }
            }
        )
        #endif
    }

    // MARK: - Helpers

}
