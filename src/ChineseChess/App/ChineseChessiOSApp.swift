#if os(iOS)
import SwiftUI

@main
struct ChineseChessiOSApp: App {
    init() {
        FontRegistry.registerFonts()
        // v3.7.0 Phase 4: UserDefaults 历史数据迁移到 JSON 文件
        DataMigration.migrateGameHistoryToFiles()

        // P0-1 fix: 首次启动引导标志读取（在 onAppear 中触发弹窗）
        _firstLaunchNeeded = State(initialValue: !UserDefaults.standard.bool(forKey: "chinesechess.firstLaunchDialogShown"))
        _showStudyHubTooltip = State(initialValue: MigrationTooltipManager.shouldShow)
    }

    // v3.8.0 Phase 4 #4: 统一 sheet 管理（与 macOS 对齐）
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
        // .openingExplorer 已移至 StudyHubView，不再通过 sheet 触发

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
            }
        }
    }

    @State private var activeSheet: SheetDestination?

    // v4.0 Phase 4: RankUp + ReviewCard sheet 状态
    @State private var showRankUpSheet = false
    @State private var rankUpRank: Rank = .student
    @State private var showReviewCardSheet = false
    @State private var reviewCardData: GameReviewCard?
    @State private var reviewCardRecord: GameRecord?
    @State private var pendingReviewRecord: GameRecord?
    // v4.1 Bug 3: 引擎不可用时的复盘提示
    @State private var reviewCardUnavailableMessage: String? = nil
    // Bug 3 fix: CoachSession 入口状态
    @State private var coachSessionRecord: GameRecord?

    @State private var gameViewModel = GameViewModel()
    @State private var toolbarReplayRecord: GameRecord?
    @State private var themeManager = ThemeManager.shared
    @State private var historyReplayRecord: GameRecord?
    @State private var showImportFailAlert = false
    @State private var importFailMessage = ""
    @State private var showFirstLaunchDialog = false
    @State private var showTutorialSheet = false
    @State private var firstLaunchNeeded = false
    @State private var showStudyHubTooltip = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ZStack {
                    // 背景
                    ThemeColors.forTheme(themeManager.currentTheme).appBackground
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        ToolbarView(viewModel: gameViewModel)

                        ChessClockView(viewModel: gameViewModel)

                        BoardView(viewModel: gameViewModel)
                            .layoutPriority(1)

                        StatusBarView(viewModel: gameViewModel)
                    }

                    // 游戏结束弹窗
                    if gameViewModel.gameState != .playing {
                        GameOverOverlay(gameState: gameViewModel.gameState) {
                            gameViewModel.newGame()
                        }
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
                                showTutorialSheet = true
                            },
                            onSkip: {
                                UserDefaults.standard.set(true, forKey: "chinesechess.firstLaunchDialogShown")
                                TutorialViewModel.markTutorialCompleted()
                                showFirstLaunchDialog = false
                            }
                        )
                        .frame(maxWidth: 400)
                    }
                }
                .navigationTitle(L10n.shared.t("app.title"))
                .navigationBarTitleDisplayMode(.inline)
                // P1-2: 外部引擎 fallback 提示（iOS 上理论上不会触发，但保持一致）
                .alert(
                    L10n.shared.t("engine.fallbackTitle"),
                    isPresented: Binding(
                        get: { gameViewModel.engineFallbackMessage != nil },
                        set: { if !$0 { gameViewModel.engineFallbackMessage = nil } }
                    )
                ) {
                    Button(L10n.shared.t("common.ok")) { gameViewModel.engineFallbackMessage = nil }
                } message: {
                    Text(gameViewModel.engineFallbackMessage ?? "")
                }
                // P0-1 fix: 长将判负首次触发解释弹窗
                .alert(
                    L10n.shared.t("game.perpetualCheckTitle"),
                    isPresented: Binding(
                        get: { gameViewModel.perpetualCheckMessage != nil },
                        set: { if !$0 { gameViewModel.perpetualCheckMessage = nil } }
                    )
                ) {
                    Button(L10n.shared.t("common.gotIt")) { gameViewModel.perpetualCheckMessage = nil }
                } message: {
                    Text(gameViewModel.perpetualCheckMessage ?? "")
                }
                // v4.0 Phase 6: 长捉判负提示
                .alert(
                    L10n.shared.t("game.perpetualChaseTitle"),
                    isPresented: Binding(
                        get: { gameViewModel.perpetualChaseMessage != nil },
                        set: { if !$0 { gameViewModel.perpetualChaseMessage = nil } }
                    )
                ) {
                    Button(L10n.shared.t("common.gotIt")) { gameViewModel.perpetualChaseMessage = nil }
                } message: {
                    Text(gameViewModel.perpetualChaseMessage ?? "")
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button(action: { activeSheet = (activeSheet == .record) ? nil : .record }) {
                            Label(L10n.shared.t("toolbar.record"), systemImage: "doc.text")
                        }
                        ZStack(alignment: .top) {
                            NavigationLink {
                                StudyHubView()
                            } label: {
                                Label(L10n.shared.t("toolbar.study"), systemImage: "graduationcap")
                            }
                            if showStudyHubTooltip {
                                MigrationTooltip(
                                    text: L10n.shared.t("migration.studyHub"),
                                    onDismiss: {
                                        showStudyHubTooltip = false
                                        MigrationTooltipManager.markShown()
                                    }
                                )
                                .offset(y: -32)
                            }
                        }
                        Button(action: {
                            toolbarReplayRecord = gameViewModel.buildGameRecord()
                        }) {
                            Label(L10n.shared.t("toolbar.replay"), systemImage: "play.circle")
                        }
                        .disabled(gameViewModel.gameMoves.isEmpty)

                        Spacer()

                        // Bug 5 fix: 删除底部难度 Menu（与顶部 ToolbarView 重复），保留更多菜单
                        Menu {
                            Button(action: { activeSheet = (activeSheet == .stats) ? nil : .stats }) {
                                Label(L10n.shared.t("toolbar.stats"), systemImage: "chart.bar")
                            }
                            Button(action: { activeSheet = .history }) {
                                Label(L10n.shared.t("toolbar.history"), systemImage: "clock.arrow.circlepath")
                            }
                            Button(action: { activeSheet = .themePicker }) {
                                Label(L10n.shared.t("toolbar.theme"), systemImage: "paintpalette")
                            }
                            Divider()
                            Button(action: { activeSheet = .dailyChallenge }) {
                                Label(L10n.shared.t("toolbar.dailyChallenge"), systemImage: "calendar.badge.clock")
                            }
                            Button(action: { activeSheet = .achievements }) {
                                Label(L10n.shared.t("toolbar.achievements"), systemImage: "trophy")
                            }
                            Button(action: { activeSheet = .rankPrivilege }) {
                                Label(L10n.shared.t("toolbar.rankPrivilege"), systemImage: "medal")
                            }
                            Divider()
                            // 过渡期旧入口（下个版本移除）
                            Button(action: { activeSheet = .puzzles }) {
                                Label(L10n.shared.t("toolbar.puzzleLegacy"), systemImage: "puzzlepiece")
                            }
                            Button(action: {
                                // 开局探索已归入学棋，关闭更多菜单让用户看到学棋按钮
                                activeSheet = nil
                            }) {
                                Label(L10n.shared.t("toolbar.openingExplorerLegacy"), systemImage: "book")
                            }
                            Divider()
                            Button(action: { activeSheet = .settings }) {
                                Label(L10n.shared.t("toolbar.settings"), systemImage: "gearshape")
                            }
                        } label: {
                            Label(L10n.shared.t("toolbar.more"), systemImage: "ellipsis.circle")
                        }
                    }
                }
                // v3.8.0 Phase 4 #4: 统一 sheet — 与 macOS 对齐
                .sheet(item: $activeSheet) { destination in
                    switch destination {
                    case .record:
                        NavigationStack {
                            RecordPanelView(viewModel: gameViewModel, onExportRequest: {
                                if let record = gameViewModel.buildGameRecord() {
                                    copyRecordToClipboard(record)
                                }
                            })
                                .navigationTitle(L10n.shared.t("record.title"))
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                    }
                                }
                        }

                    case .stats:
                        NavigationStack {
                            StatsPanelView()
                                .navigationTitle(L10n.shared.t("stats.title"))
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                    }
                                }
                        }

                    case .puzzles:
                        NavigationStack {
                            PuzzleSelectView()
                                .navigationTitle(L10n.shared.t("puzzle.title"))
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                    }
                                }
                        }

                    case .history:
                        NavigationStack {
                            GameHistoryView(onReplayRequest: { record in
                                activeSheet = nil
                                historyReplayRecord = record
                            })
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                    }
                                }
                        }

                    case .themePicker:
                        NavigationStack {
                            ThemePickerView()
                                .navigationTitle(L10n.shared.t("theme.title"))
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                    }
                                }
                        }

                    case .settings:
                        NavigationStack {
                            SettingsView(viewModel: gameViewModel)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                    }
                                }
                        }

                    case .dailyChallenge:
                        NavigationStack {
                            DailyChallengeView()
                                .navigationTitle(L10n.shared.t("toolbar.dailyChallenge"))
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                    }
                                }
                        }

                    case .achievements:
                        NavigationStack {
                            AchievementView(profile: PlayerProfileStore.shared.profile)
                                .navigationTitle(L10n.shared.t("toolbar.achievements"))
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                    }
                                }
                        }

                    case .rankPrivilege:
                        NavigationStack {
                            RankPrivilegeView(profile: PlayerProfileStore.shared.profile)
                                .navigationTitle(L10n.shared.t("toolbar.rankPrivilege"))
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button(L10n.shared.t("common.done")) { activeSheet = nil }
                                    }
                                }
                        }
                    }
                }
                .fullScreenCover(item: $toolbarReplayRecord) { record in
                    ReplayView(record: record)
                }
                .fullScreenCover(item: $historyReplayRecord) { record in
                    ReplayView(record: record)
                }
                // P0-1 fix: 教程 sheet
                .sheet(isPresented: $showTutorialSheet) {
                    TutorialView(onComplete: { showTutorialSheet = false })
                }
                // v4.0 Phase 4: RankUp sheet
                .sheet(isPresented: $showRankUpSheet) {
                    RankUpView(newRank: rankUpRank) {
                        showRankUpSheet = false
                        // 竟态防护：RankUpView dismiss 后检查 pending review card
                        if let record = pendingReviewRecord {
                            pendingReviewRecord = nil
                            reviewCardRecord = record
                            showReviewCardSheet = true
                        }
                    }
                }
                // v4.0 Phase 4: ReviewCard sheet
                .sheet(isPresented: $showReviewCardSheet) {
                    if let card = reviewCardData {
                        NavigationStack {
                            ReviewCardView(
                                card: card,
                                onViewDetail: {
                                    showReviewCardSheet = false
                                    // Bug 3 fix: 关闭 ReviewCard 后打开 CoachSessionView
                                    if let record = reviewCardRecord {
                                        coachSessionRecord = record
                                    }
                                },
                                onClose: {
                                    showReviewCardSheet = false
                                }
                            )
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { showReviewCardSheet = false }
                                }
                            }
                        }
                    } else {
                        // Bug 1 fix: reviewCardData 为 nil 时显示提示而非空白
                        VStack(spacing: 16) {
                            Text(L10n.shared.t("analysis.engineUnavailable"))
                                .foregroundColor(.secondary)
                            Button(L10n.shared.t("common.done")) { showReviewCardSheet = false }
                                .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                // v4.1 Bug 3: 引擎不可用时不弹空复盘卡片
                .alert(reviewCardUnavailableMessage ?? "", isPresented: Binding(
                    get: { reviewCardUnavailableMessage != nil },
                    set: { if !$0 { reviewCardUnavailableMessage = nil } }
                )) {
                    Button(L10n.shared.t("common.ok"), role: .cancel) {}
                }
                // Bug 3 fix: CoachSessionView sheet（从 ReviewCard "查看详情" 进入）
                .sheet(item: $coachSessionRecord) { record in
                    CoachSessionView(record: record)
                }
                // v4.0 Phase 4: 监听段位升级
                .onReceive(NotificationCenter.default.publisher(for: .rankPromoted)) { notification in
                    if let newRank = notification.object as? Rank {
                        rankUpRank = newRank
                        // 竟态防护：段位升级优先，暂停 review card
                        showReviewCardSheet = false
                        if let record = reviewCardRecord {
                            pendingReviewRecord = record
                        }
                        showRankUpSheet = true
                    }
                }
                // v4.0 Phase 4: 对弈结束触发复盘卡片
                .onChange(of: gameViewModel.gameState) { _, newState in
                    if newState != .playing {
                        generateReviewCard()
                    } else {
                        reviewCardTask?.cancel()
                        showReviewCardSheet = false
                        reviewCardRecord = nil
                        reviewCardData = nil
                        pendingReviewRecord = nil
                    }
                }
                .preferredColorScheme(.dark)
                .onAppear {
                    TutorialViewModel.markLaunched()
                    if firstLaunchNeeded {
                        showFirstLaunchDialog = true
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        SoundEngine.shared.deactivateAudioSession()
                        Task { await EngineRouter.shared.shutdown() }
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
        }
    }

    // MARK: - 导出辅助

    private func copyRecordToClipboard(_ record: GameRecord) {
        let pgn = PGNExporter.export(record)
        UIPasteboard.general.string = pgn
    }

    // MARK: - v4.0 Phase 4: 复盘卡片生成

    /// v4.0 Phase 4: 复盘卡片生成 Task（用于取消）
    @State private var reviewCardTask: Task<Void, Never>?

    private func generateReviewCard() {
        guard let record = gameViewModel.buildGameRecord() else { return }
        guard !record.moves.isEmpty else { return }

        reviewCardRecord = record

        reviewCardTask?.cancel()
        reviewCardTask = Task {
            let uciMoves = record.moves.uciMoves
            let fen = record.initialFEN ?? FENParser.standardInitial
            let analysisVM = AnalysisViewModel()
            analysisVM.load(moves: uciMoves, initialFEN: fen, gameMoves: record.moves)
            await analysisVM.analyzeAll()

            // v4.1 Bug 3 fix: 引擎不可用时不弹空复盘卡片，改为提示
            if let unavailableMsg = await analysisVM.analysisUnavailableMessage {
                await MainActor.run {
                    guard reviewCardRecord?.id == record.id else { return }
                    reviewCardData = nil
                    reviewCardRecord = nil
                    reviewCardUnavailableMessage = unavailableMsg
                }
                return
            }

            let card = await CoachExplainer.shared.generateReviewCard(analyses: analysisVM.analyses)

            // Bug 1 fix: 空卡片防护 — 全部分析为 nil 时不弹 sheet
            if card.totalMoves == 0 {
                await MainActor.run {
                    guard reviewCardRecord?.id == record.id else { return }
                    reviewCardData = nil
                    reviewCardRecord = nil
                    reviewCardUnavailableMessage = L10n.shared.t("analysis.engineUnavailable")
                }
                return
            }

            // 竞态防护：如果 Task 被取消或 record 已被清理，不更新 UI
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard reviewCardRecord?.id == record.id else { return }
                reviewCardData = card
                if showRankUpSheet {
                    pendingReviewRecord = record
                } else {
                    showReviewCardSheet = true
                }
            }
        }
    }

    // MARK: - v3.7.0 Phase 3: 打开 .pgn 文件

    private func handleOpenURL(_ url: URL) {
        guard url.pathExtension == "pgn" else { return }
        guard url.startAccessingSecurityScopedResource() else {
            importFailMessage = L10n.shared.t("import.readFileFail")
            showImportFailAlert = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
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
