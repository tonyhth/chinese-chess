#if os(macOS)
import SwiftUI

@main
struct ChineseChessApp: App {
    init() {
        // v3.0: 命令行自对弈模式
        #if os(macOS)
        let args = CommandLine.arguments
        if args.count >= 2 && args[1] == "--selfplay" {
            runSelfPlayFromCLI()
            Foundation.exit(0)
        }
        #endif
        FontRegistry.registerFonts()
    }

    // 面板状态：互斥管理
    enum Panel: Equatable {
        case none, record, stats
    }

    // P1 #2: 引擎选择枚举（菜单栏绑定）
    enum EngineSelection: Equatable, Hashable {
        case native
        case external(UUID)
    }

    @State private var activePanel: Panel = .none

    @State private var viewModel = GameViewModel()
    @State private var showPuzzles = false
    @State private var toolbarReplayRecord: GameRecord?
    @State private var showThemePicker = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var historyReplayRecord: GameRecord?

    // P1 #2: 菜单栏引擎选择绑定
    private var engineSelectionBinding: Binding<EngineSelection> {
        Binding(
            get: {
                if let id = EngineConfigStore.shared.pendingEngineId ?? EngineConfigStore.shared.selectedEngineId {
                    return .external(id)
                }
                return .native
            },
            set: { newSelection in
                switch newSelection {
                case .native:
                    EngineConfigStore.shared.pendingEngineId = nil
                case .external(let id):
                    EngineConfigStore.shared.pendingEngineId = id
                }
                // 通知状态观察器
                EngineStateObserver.shared.setPendingSwitch(
                    pendingId: EngineConfigStore.shared.pendingEngineId
                )
            }
        )
    }

    var body: some Scene {
        WindowGroup(L10n.shared.t("app.title")) {
            ZStack {
                // 窗口背景
                Color(red: 44/255, green: 24/255, blue: 16/255)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ToolbarView(viewModel: viewModel)

                    BoardView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(minHeight: 280)
                        .layoutPriority(1)

                    StatusBarView(viewModel: viewModel)

                    // 底部操作栏
                    HStack(spacing: 8) {
                        Button(action: { activePanel = activePanel == .record ? .none : .record }) {
                            Image(systemName: "doc.text")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.record"))

                        Button(action: { activePanel = activePanel == .stats ? .none : .stats }) {
                            Image(systemName: "chart.bar")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.stats"))

                        Button(action: { showPuzzles.toggle() }) {
                            Image(systemName: "puzzlepiece")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.puzzle"))

                        Button(action: {
                            toolbarReplayRecord = viewModel.buildGameRecord()
                        }) {
                            Image(systemName: "play.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .disabled(viewModel.gameMoves.isEmpty)
                        .help(L10n.shared.t("toolbar.replay"))

                        Spacer()

                        Button(action: { showThemePicker.toggle() }) {
                            Image(systemName: "paintpalette")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.theme"))

                        Button(action: { showHistory.toggle() }) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.history"))

                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "gearshape")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.settings"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                // 游戏结束弹窗
                if viewModel.gameState != .playing {
                    GameOverOverlay(gameState: viewModel.gameState) {
                        viewModel.newGame()
                    } onViewRecord: {
                        toolbarReplayRecord = viewModel.buildGameRecord()
                    }
                }

            }
            .frame(minWidth: 600, minHeight: 700)
            .preferredColorScheme(.dark)
            // P1-2: 外部引擎 fallback 提示
            .alert(
                L10n.shared.t("engine.fallbackTitle"),
                isPresented: Binding(
                    get: { viewModel.engineFallbackMessage != nil },
                    set: { if !$0 { viewModel.engineFallbackMessage = nil } }
                )
            ) {
                Button(L10n.shared.t("common.ok")) { viewModel.engineFallbackMessage = nil }
            } message: {
                Text(viewModel.engineFallbackMessage ?? "")
            }
            // 棋谱/统计面板互斥 Sheet
            .sheet(isPresented: Binding(
                get: { activePanel == .record },
                set: { if !$0 { activePanel = .none } }
            )) {
                RecordPanelView(viewModel: viewModel)
                    .frame(minWidth: 280, minHeight: 250, maxHeight: 400)
            }
            .sheet(isPresented: Binding(
                get: { activePanel == .stats },
                set: { if !$0 { activePanel = .none } }
            )) {
                StatsPanelView()
                    .frame(minWidth: 280, minHeight: 180, maxHeight: 400)
            }
            .sheet(isPresented: $showPuzzles) {
                NavigationStack {
                    PuzzleSelectView()
                        .navigationTitle(L10n.shared.t("puzzle.title"))
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { showPuzzles = false }
                            }
                        }
                }
                .frame(minWidth: 600, minHeight: 700)
            }
            .sheet(item: $toolbarReplayRecord) { record in
                ReplayView(record: record)
                    .frame(minWidth: 600, minHeight: 750)
            }
            .sheet(isPresented: $showThemePicker) {
                NavigationStack {
                    VStack(spacing: 16) {
                        ThemePickerView()
                    }
                    .padding()
                    .navigationTitle(L10n.shared.t("theme.title"))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.shared.t("common.done")) { showThemePicker = false }
                        }
                    }
                }
                .frame(minWidth: 300, minHeight: 200)
            }
            .sheet(isPresented: $showHistory) {
                NavigationStack {
                    GameHistoryView(onReplayRequest: { record in
                        showHistory = false
                        historyReplayRecord = record
                    })
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { showHistory = false }
                            }
                        }
                }
                .frame(minWidth: 350, minHeight: 400)
            }
            .sheet(item: $historyReplayRecord) { record in
                ReplayView(record: record)
                    .frame(minWidth: 600, minHeight: 750)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(viewModel: viewModel)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { showSettings = false }
                            }
                        }
                }
                .frame(minWidth: 320, minHeight: 300, maxHeight: 500)
            }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 860)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(L10n.shared.t("game.settings")) {
                    showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu(L10n.shared.t("game.menuLabel")) {
                Button(L10n.shared.t("game.newGame")) {
                    viewModel.newGame()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button(L10n.shared.t("game.undoMove")) {
                    viewModel.undoMove()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(viewModel.isThinking || viewModel.board.moveHistory.isEmpty)

                Divider()

                Button(L10n.shared.t("game.hint")) {
                    viewModel.requestHint()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(viewModel.isThinking || viewModel.gameState != .playing)
            }

            // P1 #2: 引擎菜单（仅 macOS）
            CommandMenu("引擎") {
                Picker("选择引擎", selection: engineSelectionBinding) {
                    Text("内置引擎").tag(EngineSelection.native)
                    ForEach(EngineConfigStore.shared.engines.filter { $0.isEnabled }) { engine in
                        Text(engine.name).tag(EngineSelection.external(engine.id))
                    }
                }
                .pickerStyle(.inline)

                Divider()

                Button("配置引擎") {
                    showSettings = true
                }
            }
        }
    }
}
#endif
