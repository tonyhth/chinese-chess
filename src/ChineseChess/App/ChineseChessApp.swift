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

        // v3.7.0 Phase 4: UserDefaults 历史数据迁移到 JSON 文件
        DataMigration.migrateGameHistoryToFiles()
    }

    // v3.7.1 P0: 统一 sheet 管理 — 解决多 .sheet 串联导致 sheet 弹不出的 bug
    enum SheetDestination: Identifiable {
        case record
        case stats
        case puzzles
        case themePicker
        case history
        case settings
        case dailyChallenge
        case achievements
        case rankPrivilege
        case rankUp(Rank)
        case toolbarReplay(GameRecord)
        case historyReplay(GameRecord)

        var id: String {
            switch self {
            case .record: return "record"
            case .stats: return "stats"
            case .puzzles: return "puzzles"
            case .themePicker: return "themePicker"
            case .history: return "history"
            case .settings: return "settings"
            case .dailyChallenge: return "dailyChallenge"
            case .achievements: return "achievements"
            case .rankPrivilege: return "rankPrivilege"
            case .rankUp: return "rankUp"
            case .toolbarReplay: return "toolbarReplay"
            case .historyReplay: return "historyReplay"
            }
        }
    }

    @State private var activeSheet: SheetDestination?

    @State private var viewModel = GameViewModel()
    @State private var showImportFailAlert = false
    @State private var importFailMessage = ""
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
                        Button(action: { activeSheet = (activeSheet?.id == "record") ? nil : .record }) {
                            Image(systemName: "doc.text")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.record"))

                        Button(action: { activeSheet = (activeSheet?.id == "stats") ? nil : .stats }) {
                            Image(systemName: "chart.bar")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.stats"))

                        Button(action: { activeSheet = .puzzles }) {
                            Image(systemName: "puzzlepiece")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.puzzle"))

                        Button(action: {
                            if let record = viewModel.buildGameRecord() {
                                activeSheet = .toolbarReplay(record)
                            }
                        }) {
                            Image(systemName: "play.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .disabled(viewModel.gameMoves.isEmpty)
                        .help(L10n.shared.t("toolbar.replay"))

                        Spacer()

                        Button(action: { activeSheet = .themePicker }) {
                            Image(systemName: "paintpalette")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.theme"))

                        Button(action: { activeSheet = .history }) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.history"))

                        Button(action: { activeSheet = .dailyChallenge }) {
                            Image(systemName: "calendar.badge.clock")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.dailyChallenge"))

                        Button(action: { activeSheet = .achievements }) {
                            Image(systemName: "trophy")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.achievements"))

                        Button(action: { activeSheet = .rankPrivilege }) {
                            Image(systemName: "medal")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.rankPrivilege"))

                        Button(action: { activeSheet = .settings }) {
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
                        if let record = viewModel.buildGameRecord() {
                            activeSheet = .toolbarReplay(record)
                        }
                    }
                }

            }
            // Q2: 监听段位升级通知
            .onReceive(NotificationCenter.default.publisher(for: .rankPromoted)) { notification in
                if let newRank = notification.object as? Rank {
                    rankUpRank = newRank
                    activeSheet = .rankUp(newRank)
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
            // v3.7.1 P0: 统一 sheet — 解决多 .sheet 串联导致弹不出的 bug
            .sheet(item: $activeSheet) { destination in
                switch destination {
                case .puzzles:
                    NavigationStack {
                        PuzzleSelectView()
                            .navigationTitle(L10n.shared.t("puzzle.title"))
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 600, minHeight: 700)

                case .toolbarReplay(let record):
                    ReplayView(record: record)
                        .frame(minWidth: 600, minHeight: 750)

                case .themePicker:
                    NavigationStack {
                        VStack(spacing: 16) {
                            ThemePickerView()
                        }
                        .padding()
                        .navigationTitle(L10n.shared.t("theme.title"))
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { activeSheet = nil }
                            }
                        }
                    }
                    .frame(minWidth: 300, minHeight: 200)

                case .history:
                    NavigationStack {
                        GameHistoryView(onReplayRequest: { record in
                            activeSheet = .historyReplay(record)
                        })
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { activeSheet = nil }
                            }
                        }
                    }
                    .frame(minWidth: 350, minHeight: 400)

                case .historyReplay(let record):
                    ReplayView(record: record)
                        .frame(minWidth: 600, minHeight: 750)

                case .settings:
                    NavigationStack {
                        SettingsView(viewModel: viewModel)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 320, minHeight: 300, maxHeight: 500)

                case .dailyChallenge:
                    NavigationStack {
                        DailyChallengeView()
                            .navigationTitle(L10n.shared.t("toolbar.dailyChallenge"))
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 400, minHeight: 500)

                case .achievements:
                    NavigationStack {
                        AchievementView(profile: PlayerProfileStore.shared.profile)
                            .navigationTitle(L10n.shared.t("toolbar.achievements"))
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 400, minHeight: 500)

                case .rankPrivilege:
                    NavigationStack {
                        RankPrivilegeView(profile: PlayerProfileStore.shared.profile)
                            .navigationTitle(L10n.shared.t("toolbar.rankPrivilege"))
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 400, minHeight: 500)

                case .rankUp(let rank):
                    RankUpView(newRank: rank) {
                        activeSheet = nil
                    }
                    .frame(minWidth: 320, minHeight: 300)

                case .record:
                    RecordPanelView(viewModel: viewModel, onExportRequest: {
                        if let record = viewModel.buildGameRecord() {
                            copyRecordToClipboard(record)
                        }
                    })
                    .frame(minWidth: 280, minHeight: 250, maxHeight: 400)

                case .stats:
                    StatsPanelView()
                        .frame(minWidth: 280, minHeight: 180, maxHeight: 400)
                }
            }
            // v3.7.0 Phase 3: 打开 .pgn 文件
            .onOpenURL { url in
                handleOpenURL(url)
            }
            .alert(L10n.shared.t("import.resultTitle"), isPresented: $showImportFailAlert) {
                Button(L10n.shared.t("common.ok"), role: .cancel) {}
            } message: {
                Text(importFailMessage)
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
                    activeSheet = .settings
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
                    activeSheet = .settings
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

    // MARK: - v3.7.0 Phase 3: 打开 .pgn 文件

    private func handleOpenURL(_ url: URL) {
        guard url.pathExtension == "pgn" else { return }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            importFailMessage = L10n.shared.t("import.readFileFail")
            showImportFailAlert = true
            return
        }
        let result = PGNImporter.parse(text)
        for record in result.records {
            GameRecordStore.shared.addRecord(record)
        }
        if !result.records.isEmpty {
            activeSheet = .history
        } else {
            importFailMessage = L10n.shared.t("import.parseFail")
            showImportFailAlert = true
        }
    }
}
#endif
