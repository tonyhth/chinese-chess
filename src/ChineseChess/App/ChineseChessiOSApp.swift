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
    @State private var toolbarReplayRecord: GameRecord?
    @State private var themeManager = ThemeManager.shared
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var historyReplayRecord: GameRecord?
    @State private var showThemePicker = false

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
                .navigationTitle(L10n.shared.t("app.title"))
                .navigationBarTitleDisplayMode(.inline)
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
                        RecordPanelView(viewModel: gameViewModel)
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
            .preferredColorScheme(.dark)
        }
    }
}
#endif
