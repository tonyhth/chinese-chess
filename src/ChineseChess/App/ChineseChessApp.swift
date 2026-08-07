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

        // v3.7.1 fix: 迁移旧 Bundle ID 的偏好数据
        // 必须在所有读取 UserDefaults 的逻辑之前执行
        PreferencesMigration.migrateIfNeeded()

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

        // P0-1 fix: 首次启动引导标志读取（在 onAppear 中触发弹窗）
        _firstLaunchNeeded = State(initialValue: !UserDefaults.standard.bool(forKey: "chinesechess.firstLaunchDialogShown"))
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

        // ✅ v3.7.2: 新增 3 个 UI 入口
        case analysis(GameRecord)
        case coach(GameRecord)
        case studyHub
        case tutorial

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
            case .analysis: return "analysis"
            case .coach: return "coach"
            case .studyHub: return "studyHub"
            case .tutorial: return "tutorial"
            }
        }
    }

    @State private var activeSheet: SheetDestination?

    @State private var viewModel = GameViewModel()
    @State private var showImportFailAlert = false
    @State private var importFailMessage = ""
    @State private var rankUpRank: Rank?
    @State private var showFirstLaunchDialog = false
    @State private var firstLaunchNeeded = false

    // v3.7.2 Phase 4: 对弈结束复盘卡片
    @State private var showReviewCard = false
    @State private var reviewCardRecord: GameRecord?
    @State private var reviewCardData: GameReviewCard?
    @State private var pendingReviewRecord: GameRecord?  // RankUpView dismiss 后检查

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

                        Button(action: {
                            if let record = viewModel.buildGameRecord() {
                                activeSheet = .analysis(record)
                            }
                        }) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .disabled(viewModel.gameMoves.isEmpty)
                        .help(L10n.shared.t("toolbar.analysis"))
                        .keyboardShortcut("a", modifiers: [.command, .shift])

                        Button(action: {
                            if let record = viewModel.buildGameRecord() {
                                activeSheet = .coach(record)
                            }
                        }) {
                            Image(systemName: "brain.head.profile")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .disabled(viewModel.gameMoves.isEmpty)
                        .help(L10n.shared.t("toolbar.coach"))
                        .keyboardShortcut("t", modifiers: [.command, .shift])

                        Divider().frame(height: 24)

                        // 学棋组
                        Button(action: { activeSheet = .puzzles }) {
                            Image(systemName: "puzzlepiece")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.puzzle"))
                        .keyboardShortcut("p", modifiers: [.command, .shift])

                        Button(action: {
                            activeSheet = .studyHub
                        }) {
                            Image(systemName: "graduationcap.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.study"))
                        .keyboardShortcut("s", modifiers: [.command, .shift])

                        Button(action: { activeSheet = .dailyChallenge }) {
                            Image(systemName: "calendar.badge.clock")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.dailyChallenge"))

                        Divider().frame(height: 24)

                        // 设置组
                        Button(action: { activeSheet = (activeSheet?.id == "stats") ? nil : .stats }) {
                            Image(systemName: "chart.bar")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.stats"))

                        Button(action: { activeSheet = .history }) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.history"))

                        Button(action: { activeSheet = .themePicker }) {
                            Image(systemName: "paintpalette")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(L10n.shared.t("toolbar.theme"))

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

                // v3.7.2 Phase 4: 对弈结束复盘卡片
                if showReviewCard, let card = reviewCardData, let record = reviewCardRecord {
                    VStack {
                        Spacer()
                        ReviewCardView(
                            card: card,
                            onViewDetail: {
                                showReviewCard = false
                                activeSheet = .coach(record)
                            },
                            onClose: {
                                showReviewCard = false
                            }
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showReviewCard)
                }

                // P0-1 fix: 首次启动引导弹窗
                if showFirstLaunchDialog {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    FirstLaunchDialog(
                        isPresented: $showFirstLaunchDialog,
                        onShowTutorial: {
                            UserDefaults.standard.set(true, forKey: "chinesechess.firstLaunchDialogShown")
                            showFirstLaunchDialog = false
                            activeSheet = .tutorial
                        },
                        onSkip: {
                            UserDefaults.standard.set(true, forKey: "chinesechess.firstLaunchDialogShown")
                            TutorialViewModel.markTutorialCompleted()
                            showFirstLaunchDialog = false
                        }
                    )
                    .frame(maxWidth: 500)
                }

            }
            // Q2: 监听段位升级通知
            .onReceive(NotificationCenter.default.publisher(for: .rankPromoted)) { notification in
                if let newRank = notification.object as? Rank {
                    rankUpRank = newRank
                    // 竟态防护：段位升级优先，暂停 review card
                    showReviewCard = false
                    if let record = reviewCardRecord {
                        pendingReviewRecord = record
                    }
                    activeSheet = .rankUp(newRank)
                }
            }
            // v3.7.2 Phase 4: 对弈结束触发复盘卡片
            .onChange(of: viewModel.gameState) { _, newState in
                if newState != .playing {
                    generateReviewCard()
                } else {
                    // 新局开始，清理
                    showReviewCard = false
                    reviewCardRecord = nil
                    reviewCardData = nil
                    pendingReviewRecord = nil
                }
            }
            .frame(minWidth: 900, minHeight: 750)
            .onAppear {
                TutorialViewModel.markLaunched()
                if firstLaunchNeeded {
                    showFirstLaunchDialog = true
                }
            }
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
            // P0-1 fix: 长将判负首次触发解释弹窗
            .alert(
                L10n.shared.t("game.perpetualCheckTitle"),
                isPresented: Binding(
                    get: { viewModel.perpetualCheckMessage != nil },
                    set: { if !$0 { viewModel.perpetualCheckMessage = nil } }
                )
            ) {
                Button(L10n.shared.t("common.gotIt")) { viewModel.perpetualCheckMessage = nil }
            } message: {
                Text(viewModel.perpetualCheckMessage ?? "")
            }
            // v4.0 Phase 6: 长捉判负提示
            .alert(
                L10n.shared.t("game.perpetualChaseTitle"),
                isPresented: Binding(
                    get: { viewModel.perpetualChaseMessage != nil },
                    set: { if !$0 { viewModel.perpetualChaseMessage = nil } }
                )
            ) {
                Button(L10n.shared.t("common.gotIt")) { viewModel.perpetualChaseMessage = nil }
            } message: {
                Text(viewModel.perpetualChaseMessage ?? "")
            }
            // v3.7.1 P0: 统一 sheet — 解决多 .sheet 串联导致弹不出的 bug
            .sheet(item: $activeSheet) { destination in
                switch destination {
                case .puzzles:
                    NavigationStack {
                        ChapterSelectView()
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 900, minHeight: 750)

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
                        // 竟态防护：RankUpView dismiss 后检查 pending review card
                        if let record = pendingReviewRecord {
                            pendingReviewRecord = nil
                            reviewCardRecord = record
                            showReviewCard = true
                        }
                    }
                    .frame(minWidth: 320, minHeight: 300)

                case .record:
                    RecordPanelView(viewModel: viewModel, onExportRequest: {
                        if let record = viewModel.buildGameRecord() {
                            copyRecordToClipboard(record)
                        }
                    })
                    .frame(minWidth: 280, minHeight: 250, maxHeight: 600)

                case .stats:
                    StatsPanelView()
                        .frame(minWidth: 280, minHeight: 180, maxHeight: 400)

                // ✅ v3.7.2: 新增 UI 入口 placeholder
                case .analysis(let record):
                    AnalysisView(record: record)
                        .frame(minWidth: 600, minHeight: 700)

                case .coach(let record):
                    NavigationStack {
                        CoachSessionView(record: record)
                            .navigationTitle(L10n.shared.t("coach.title"))
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 500, minHeight: 600)

                case .studyHub:
                    NavigationStack {
                        StudyHubView()  // 学棋中心
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                }
                            }
                    }
                    .frame(minWidth: 900, minHeight: 750)

                case .tutorial:
                    TutorialView(onComplete: { activeSheet = nil })
                        .frame(minWidth: 400, minHeight: 400)
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
            } else if newPhase == .active {
                // P1 fix L2-10: 后台 shutdown 后回到前台需要重新启动引擎
                Task { await EngineRouter.shared.switchEngineIfNeeded() }
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
            CommandMenu(L10n.shared.t("engine.menuLabel")) {
                Toggle(L10n.shared.t("engine.usePikafishMenu"), isOn: useEmbeddedEngineBinding)

                Divider()

                Button(L10n.shared.t("engine.configureLabel")) {
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

    // MARK: - v3.7.2 Phase 4: 复盘卡片生成

    private func generateReviewCard() {
        guard let record = viewModel.buildGameRecord() else { return }
        guard !record.moves.isEmpty else { return }

        reviewCardRecord = record

        // 异步分析 + 生成 review card
        Task {
            let uciMoves = record.moves.uciMoves

            let fen = record.initialFEN ?? FENParser.standardInitial
            let analysisVM = AnalysisViewModel()
            analysisVM.load(moves: uciMoves, initialFEN: fen, gameMoves: record.moves)
            await analysisVM.analyzeAll()

            let card = await CoachExplainer.shared.generateReviewCard(analyses: analysisVM.analyses)

            await MainActor.run {
                reviewCardData = card
                // 如果正在显示 RankUpView，延后显示
                if activeSheet?.id == "rankUp" {
                    pendingReviewRecord = record
                } else {
                    showReviewCard = true
                }
            }
        }
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
