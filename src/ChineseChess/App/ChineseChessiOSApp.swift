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
    @State private var languageManager = LanguageManager()

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
                .navigationTitle(String(localized: "app.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button(action: { activePanel = activePanel == .record ? .none : .record }) {
                            Label(String(localized: "toolbar.record"), systemImage: "doc.text")
                        }
                        Button(action: { showPuzzles = true }) {
                            Label(String(localized: "toolbar.puzzle"), systemImage: "puzzlepiece")
                        }
                        Button(action: {
                            if let record = gameViewModel.buildGameRecord() {
                                replayRecord = record
                                showReplay = true
                            }
                        }) {
                            Label(String(localized: "toolbar.replay"), systemImage: "play.circle")
                        }
                        .disabled(gameViewModel.gameMoves.isEmpty)

                        Spacer()

                        // 难度快捷入口
                        Menu {
                            Button(String(localized: "difficulty.beginner")) { gameViewModel.setDifficulty(.beginner) }
                            Button(String(localized: "difficulty.easy")) { gameViewModel.setDifficulty(.easy) }
                            Button(String(localized: "difficulty.medium")) { gameViewModel.setDifficulty(.medium) }
                            Button(String(localized: "difficulty.hard")) { gameViewModel.setDifficulty(.hard) }
                            Button(String(localized: "difficulty.master")) { gameViewModel.setDifficulty(.master) }
                        } label: {
                            Label(String(localized: "difficulty.label"), systemImage: "gauge.with.dots.needle.bottom.50percent")
                        }

                        // 更多菜单：低频操作
                        Menu {
                            Button(action: { activePanel = activePanel == .stats ? .none : .stats }) {
                                Label(String(localized: "toolbar.stats"), systemImage: "chart.bar")
                            }
                            Button(action: { showHistory = true }) {
                                Label(String(localized: "toolbar.history"), systemImage: "clock.arrow.circlepath")
                            }
                            Button(action: { showThemePicker = true }) {
                                Label(String(localized: "toolbar.theme"), systemImage: "paintpalette")
                            }
                            Button(action: { showSettings = true }) {
                                Label(String(localized: "toolbar.settings"), systemImage: "gearshape")
                            }
                        } label: {
                            Label(String(localized: "toolbar.more"), systemImage: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: Binding(
                    get: { activePanel == .record },
                    set: { if !$0 { activePanel = .none } }
                )) {
                    NavigationStack {
                        RecordPanelView(gameMoves: gameViewModel.gameMoves)
                            .navigationTitle(String(localized: "record.title"))
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(String(localized: "common.done")) { activePanel = .none }
                                }
                            }
                    }
                }
                .sheet(isPresented: $showPuzzles) {
                    NavigationStack {
                        PuzzleSelectView()
                            .navigationTitle(String(localized: "puzzle.title"))
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(String(localized: "common.done")) { showPuzzles = false }
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
                    GameHistoryView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(String(localized: "common.done")) { showHistory = false }
                            }
                        }
                }
            }
            .sheet(isPresented: Binding(
                get: { activePanel == .stats },
                set: { if !$0 { activePanel = .none } }
            )) {
                NavigationStack {
                    StatsPanelView()
                        .navigationTitle(String(localized: "stats.title"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(String(localized: "common.done")) { activePanel = .none }
                            }
                        }
                }
            }
            .sheet(isPresented: $showThemePicker) {
                NavigationStack {
                    ThemePickerView()
                        .navigationTitle(String(localized: "theme.title"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(String(localized: "common.done")) { showThemePicker = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(viewModel: gameViewModel)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(String(localized: "common.done")) { showSettings = false }
                            }
                        }
                }
            }
            .preferredColorScheme(.dark)
            .environmentObject(languageManager)
            .environment(\.locale, languageManager.currentLocale)
            // 已使用 String(localized:) 国际化
        }
    }
}
#endif
