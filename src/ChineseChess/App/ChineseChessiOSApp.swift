#if os(iOS)
import SwiftUI

@main
struct ChineseChessiOSApp: App {
    init() {
        FontRegistry.registerFonts()
        // v3.7.0 Phase 4: UserDefaults 历史数据迁移到 JSON 文件
        DataMigration.migrateGameHistoryToFiles()
    }

    // 面板互斥管理
    enum Panel: Equatable {
        case none, record, stats
    }
    @State private var activePanel: Panel = .none

    @State private var gameViewModel = GameViewModel()
    @State private var showPuzzles = false
    @State private var toolbarReplayRecord: GameRecord?
    @State private var themeManager = ThemeManager.shared
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var historyReplayRecord: GameRecord?
    @State private var showThemePicker = false
    @State private var showDailyChallenge = false
    @State private var showAchievements = false
    @State private var showRankPrivilege = false
    @State private var showImportFailAlert = false
    @State private var importFailMessage = ""

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
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button(action: { activePanel = activePanel == .record ? .none : .record }) {
                            Label(L10n.shared.t("toolbar.record"), systemImage: "doc.text")
                        }
                        Button(action: { showPuzzles = true }) {
                            Label(L10n.shared.t("toolbar.puzzle"), systemImage: "puzzlepiece")
                        }
                        Button(action: {
                            toolbarReplayRecord = gameViewModel.buildGameRecord()
                        }) {
                            Label(L10n.shared.t("toolbar.replay"), systemImage: "play.circle")
                        }
                        .disabled(gameViewModel.gameMoves.isEmpty)

                        Spacer()

                        // 难度快捷入口
                        Menu {
                            Button(L10n.shared.t("difficulty.beginner")) { gameViewModel.setDifficulty(.beginner) }
                            Button(L10n.shared.t("difficulty.easy")) { gameViewModel.setDifficulty(.easy) }
                            Button(L10n.shared.t("difficulty.medium")) { gameViewModel.setDifficulty(.medium) }
                            Button(L10n.shared.t("difficulty.hard")) { gameViewModel.setDifficulty(.hard) }
                            Button(L10n.shared.t("difficulty.master")) { gameViewModel.setDifficulty(.master) }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                                Text(gameViewModel.difficulty.displayName)
                                    .font(.system(size: 9))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }

                        // 更多菜单：低频操作
                        Menu {
                            Button(action: { activePanel = activePanel == .stats ? .none : .stats }) {
                                Label(L10n.shared.t("toolbar.stats"), systemImage: "chart.bar")
                            }
                            Button(action: { showHistory = true }) {
                                Label(L10n.shared.t("toolbar.history"), systemImage: "clock.arrow.circlepath")
                            }
                            Button(action: { showThemePicker = true }) {
                                Label(L10n.shared.t("toolbar.theme"), systemImage: "paintpalette")
                            }
                            Divider()
                            Button(action: { showDailyChallenge = true }) {
                                Label(L10n.shared.t("toolbar.dailyChallenge"), systemImage: "calendar.badge.clock")
                            }
                            Button(action: { showAchievements = true }) {
                                Label(L10n.shared.t("toolbar.achievements"), systemImage: "trophy")
                            }
                            Button(action: { showRankPrivilege = true }) {
                                Label(L10n.shared.t("toolbar.rankPrivilege"), systemImage: "medal")
                            }
                            Divider()
                            Button(action: { showSettings = true }) {
                                Label(L10n.shared.t("toolbar.settings"), systemImage: "gearshape")
                            }
                        } label: {
                            Label(L10n.shared.t("toolbar.more"), systemImage: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: Binding(
                    get: { activePanel == .record },
                    set: { if !$0 { activePanel = .none } }
                )) {
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
                                    Button(L10n.shared.t("common.done")) { activePanel = .none }
                                }
                            }
                    }
                }
                .sheet(isPresented: $showPuzzles) {
                    NavigationStack {
                        PuzzleSelectView()
                            .navigationTitle(L10n.shared.t("puzzle.title"))
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(L10n.shared.t("common.done")) { showPuzzles = false }
                                }
                            }
                    }
                }
                .fullScreenCover(item: $toolbarReplayRecord) { record in
                    ReplayView(record: record)
                }
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
            }
            .fullScreenCover(item: $historyReplayRecord) { record in
                ReplayView(record: record)
            }
            .sheet(isPresented: Binding(
                get: { activePanel == .stats },
                set: { if !$0 { activePanel = .none } }
            )) {
                NavigationStack {
                    StatsPanelView()
                        .navigationTitle(L10n.shared.t("stats.title"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { activePanel = .none }
                            }
                        }
                }
            }
            .sheet(isPresented: $showThemePicker) {
                NavigationStack {
                    ThemePickerView()
                        .navigationTitle(L10n.shared.t("theme.title"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { showThemePicker = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(viewModel: gameViewModel)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { showSettings = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showDailyChallenge) {
                NavigationStack {
                    DailyChallengeView()
                        .navigationTitle(L10n.shared.t("toolbar.dailyChallenge"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { showDailyChallenge = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showAchievements) {
                NavigationStack {
                    AchievementView(profile: PlayerProfileStore.shared.profile)
                        .navigationTitle(L10n.shared.t("toolbar.achievements"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { showAchievements = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showRankPrivilege) {
                NavigationStack {
                    RankPrivilegeView(profile: PlayerProfileStore.shared.profile)
                        .navigationTitle(L10n.shared.t("toolbar.rankPrivilege"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.shared.t("common.done")) { showRankPrivilege = false }
                            }
                        }
                }
            }
            .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
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

    // MARK: - 导出辅助

    private func copyRecordToClipboard(_ record: GameRecord) {
        let pgn = PGNExporter.export(record)
        UIPasteboard.general.string = pgn
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
            showHistory = true
        } else {
            importFailMessage = L10n.shared.t("import.parseFail")
            showImportFailAlert = true
        }
    }
}
#endif
