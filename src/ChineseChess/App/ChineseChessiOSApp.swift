#if os(iOS)
import SwiftUI

@main
struct ChineseChessiOSApp: App {
    init() {
        FontRegistry.registerFonts()
    }

    // 面板互斥管理
    enum Panel: Equatable {
        case none, record, stats
    }
    @State private var activePanel: Panel = .none

    @State private var gameViewModel = GameViewModel()
    @State private var showPuzzles = false
    @State private var showReplay = false
    @State private var replayRecord: GameRecord?
    @State private var themeManager = ThemeManager.shared
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var historyReplayRecord: GameRecord?
    @State private var showThemePicker = false
    @State private var l10n = L10n.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ZStack {
                    // 背景
                    ThemeColors.forTheme(themeManager.currentTheme).appBackground
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        ToolbarView(viewModel: gameViewModel)

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
                .navigationTitle(l10n.t("app.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button(action: { activePanel = activePanel == .record ? .none : .record }) {
                            Label(l10n.t("toolbar.record"), systemImage: "doc.text")
                        }
                        Button(action: { showPuzzles = true }) {
                            Label(l10n.t("toolbar.puzzle"), systemImage: "puzzlepiece")
                        }
                        Button(action: {
                            if let record = gameViewModel.buildGameRecord() {
                                replayRecord = record
                                showReplay = true
                            }
                        }) {
                            Label(l10n.t("toolbar.replay"), systemImage: "play.circle")
                        }
                        .disabled(gameViewModel.gameMoves.isEmpty)

                        Spacer()

                        // 难度快捷入口
                        Menu {
                            Button(l10n.t("difficulty.beginner")) { gameViewModel.setDifficulty(.beginner) }
                            Button(l10n.t("difficulty.easy")) { gameViewModel.setDifficulty(.easy) }
                            Button(l10n.t("difficulty.medium")) { gameViewModel.setDifficulty(.medium) }
                            Button(l10n.t("difficulty.hard")) { gameViewModel.setDifficulty(.hard) }
                            Button(l10n.t("difficulty.master")) { gameViewModel.setDifficulty(.master) }
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
                                Label(l10n.t("toolbar.stats"), systemImage: "chart.bar")
                            }
                            Button(action: { showHistory = true }) {
                                Label(l10n.t("toolbar.history"), systemImage: "clock.arrow.circlepath")
                            }
                            Button(action: { showThemePicker = true }) {
                                Label(l10n.t("toolbar.theme"), systemImage: "paintpalette")
                            }
                            Button(action: { showSettings = true }) {
                                Label(l10n.t("toolbar.settings"), systemImage: "gearshape")
                            }
                        } label: {
                            Label(l10n.t("toolbar.more"), systemImage: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: Binding(
                    get: { activePanel == .record },
                    set: { if !$0 { activePanel = .none } }
                )) {
                    NavigationStack {
                        RecordPanelView(viewModel: gameViewModel)
                            .navigationTitle(l10n.t("record.title"))
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(l10n.t("common.done")) { activePanel = .none }
                                }
                            }
                    }
                }
                .sheet(isPresented: $showPuzzles) {
                    NavigationStack {
                        PuzzleSelectView()
                            .navigationTitle(l10n.t("puzzle.title"))
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(l10n.t("common.done")) { showPuzzles = false }
                                }
                            }
                    }
                }
                .fullScreenCover(isPresented: $showReplay) {
                    if let record = replayRecord {
                        ReplayView(record: record)
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                NavigationStack {
                    GameHistoryView(onReplayRequest: { record in
                        historyReplayRecord = record
                    })
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(l10n.t("common.done")) { showHistory = false }
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
                        .navigationTitle(l10n.t("stats.title"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(l10n.t("common.done")) { activePanel = .none }
                            }
                        }
                }
            }
            .sheet(isPresented: $showThemePicker) {
                NavigationStack {
                    ThemePickerView()
                        .navigationTitle(l10n.t("theme.title"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(l10n.t("common.done")) { showThemePicker = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(viewModel: gameViewModel)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(l10n.t("common.done")) { showSettings = false }
                            }
                        }
                }
            }
            .preferredColorScheme(.dark)
            .environment(l10n)
        }
    }
}
#endif
