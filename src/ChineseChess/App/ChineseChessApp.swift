#if os(macOS)
import SwiftUI
import AppKit

// macOS 退出钩子兜底：scenePhase 在 macOS 上不保证触发
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // 同步紧急关闭引擎，不走 actor isolation 避免 MainActor 死锁
        EngineRouter.shared.emergencyShutdown()
    }
}

@main
struct ChineseChessApp: App {
    init() {
        // v3.0: 命令行自对弈模式（CLI-only，非用户路径）
        #if os(macOS)
        let args = CommandLine.arguments
        if args.count >= 2 && args[1] == "--selfplay" {
            Task {
                await runSelfPlayFromCLI()
                Foundation.exit(0)
            }
            RunLoop.main.run()
            // 不应到达此处
            fatalError("selfplay CLI should have exited")
        }
        // v3.1: CMA-ES 自动调参模式（CLI-only，非用户路径）
        if args.count >= 2 && args[1] == "--cmaes" {
            Task.detached {
                await runCMAESFromCLI()
                Foundation.exit(0)
            }
            RunLoop.main.run()
            fatalError("cmaes CLI should have exited")
        }
        #endif
        FontRegistry.registerFonts()

        // P2: 一次性清理 bonus 脏数据（dailyStreak=0 但 bonusSpecialTheme=true 不可能）
        if !UserDefaults.standard.bool(forKey: "chinesechess.bonusDataCleaned_v1") {
            let store = PlayerProfileStore.shared
            let profile = store.profile
            if profile.dailyStreak == 0 && profile.bonusSpecialTheme {
                _ = store.update { p in
                    p.bonusSpecialTheme = false
                    p.bonusPuzzlesUnlocked = false
                    p.bonusMasterNoPenalty = false
                    p.bonusChapter7EarlyUnlock = false
                    p.bonusDoubleScore = false
                    p.bonusPieceStyle = false
                    p.bonusExtraHints = 0
                }
            }
            UserDefaults.standard.set(true, forKey: "chinesechess.bonusDataCleaned_v1")
        }
    }

    // 面板状态:互斥管理
    enum Panel: Equatable {
        case none, record, stats
    }

    @State private var activePanel: Panel = .none

    @State private var viewModel = GameViewModel()
    @State private var showPuzzles = false
    @State private var toolbarReplayRecord: GameRecord?
    @State private var showThemePicker = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var historyReplayRecord: GameRecord?
    @State private var showDailyChallenge = false
    @State private var showAchievements = false
    @State private var showRankPrivilege = false
    @State private var showRankUp = false
    @State private var rankUpRank: Rank?

    @Environment(\.scenePhase) private var scenePhase

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Phase C: 引擎开关绑定(简化版)
    private var useEmbeddedEngineBinding: Binding<Bool> {
        Binding(
            get: { EngineConfigStore.shared.useEmbeddedEngine },
            set: { newValue in
                EngineConfigStore.shared.useEmbeddedEngine = newValue
                Task { await EngineRouter.shared.switchEngineIfNeeded() }
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

                    ChessClockView(viewModel: viewModel)

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

                        Button(action: { showDailyChallenge.toggle() }) {
                            Image(systemName: "calendar.badge.clock")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.dailyChallenge"))

                        Button(action: { showAchievements.toggle() }) {
                            Image(systemName: "trophy")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.achievements"))

                        Button(action: { showRankPrivilege.toggle() }) {
                            Image(systemName: "medal")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.rankPrivilege"))

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
            // Q2: 监听段位升级通知
            .onReceive(NotificationCenter.default.publisher(for: .rankPromoted)) { notification in
                if let newRank = notification.object as? Rank {
                    rankUpRank = newRank
                    showRankUp = true
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
                RecordPanelView(viewModel: viewModel, onExportRequest: {
                    if let record = viewModel.buildGameRecord() {
                        copyRecordToClipboard(record)
                    }
                })
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
            .sheet(isPresented: $showDailyChallenge) {
                NavigationStack {
                    DailyChallengeView()
                        .navigationTitle(L10n.shared.t("toolbar.dailyChallenge"))
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { showDailyChallenge = false }
                            }
                        }
                }
                .frame(minWidth: 400, minHeight: 500)
            }
            .sheet(isPresented: $showAchievements) {
                NavigationStack {
                    AchievementView(profile: PlayerProfileStore.shared.profile)
                        .navigationTitle(L10n.shared.t("toolbar.achievements"))
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { showAchievements = false }
                            }
                        }
                }
                .frame(minWidth: 400, minHeight: 500)
            }
            .sheet(isPresented: $showRankPrivilege) {
                NavigationStack {
                    RankPrivilegeView(profile: PlayerProfileStore.shared.profile)
                        .navigationTitle(L10n.shared.t("toolbar.rankPrivilege"))
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { showRankPrivilege = false }
                            }
                        }
                }
                .frame(minWidth: 400, minHeight: 500)
            }
            // Q2: 段位升级奖励弹窗
            .sheet(isPresented: $showRankUp) {
                if let rank = rankUpRank {
                    RankUpView(newRank: rank) {
                        showRankUp = false
                    }
                    .frame(minWidth: 320, minHeight: 300)
                }
            }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 860)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                Task { await EngineRouter.shared.shutdown() }
            }
        }
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

            // Phase C: 引擎菜单（简化版，仅 macOS）
            CommandMenu("引擎") {
                Toggle(L10n.shared.t("engine.usePikafishMenu"), isOn: useEmbeddedEngineBinding)

                Divider()

                Button("配置引擎") {
                    showSettings = true
                }
            }
        }
    }

    // MARK: - 导出辅助

    private func copyRecordToClipboard(_ record: GameRecord) {
        let pgn = PGNExporter.export(record)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pgn, forType: .string)
    }
}
#endif
