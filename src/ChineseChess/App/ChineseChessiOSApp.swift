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
                .navigationTitle("中国象棋")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button(action: { activePanel = activePanel == .record ? .none : .record }) {
                            Label("棋谱", systemImage: "doc.text")
                        }
                        Button(action: { showPuzzles = true }) {
                            Label("残局", systemImage: "puzzlepiece")
                        }
                        Button(action: {
                            if let record = gameViewModel.buildGameRecord() {
                                replayRecord = record
                                showReplay = true
                            }
                        }) {
                            Label("回放", systemImage: "play.circle")
                        }
                        .disabled(gameViewModel.gameMoves.isEmpty)

                        Spacer()

                        // 难度快捷入口
                        Menu {
                            Button("新手") { gameViewModel.setDifficulty(.beginner) }
                            Button("初级") { gameViewModel.setDifficulty(.easy) }
                            Button("中级") { gameViewModel.setDifficulty(.medium) }
                            Button("高级") { gameViewModel.setDifficulty(.hard) }
                            Button("大师") { gameViewModel.setDifficulty(.master) }
                        } label: {
                            Label("难度", systemImage: "gauge.with.dots.needle.bottom.50percent")
                        }

                        // 更多菜单：低频操作
                        Menu {
                            Button(action: { activePanel = activePanel == .stats ? .none : .stats }) {
                                Label("统计", systemImage: "chart.bar")
                            }
                            Button(action: { showHistory = true }) {
                                Label("历史", systemImage: "clock.arrow.circlepath")
                            }
                            Button(action: { showThemePicker = true }) {
                                Label("主题", systemImage: "paintpalette")
                            }
                            Button(action: { showSettings = true }) {
                                Label("设置", systemImage: "gearshape")
                            }
                        } label: {
                            Label("更多", systemImage: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: Binding(
                    get: { activePanel == .record },
                    set: { if !$0 { activePanel = .none } }
                )) {
                    NavigationStack {
                        RecordPanelView(gameMoves: gameViewModel.gameMoves)
                            .navigationTitle("棋谱")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("完成") { activePanel = .none }
                                }
                            }
                    }
                }
                .sheet(isPresented: $showPuzzles) {
                    NavigationStack {
                        PuzzleSelectView()
                            .navigationTitle("残局闯关")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("完成") { showPuzzles = false }
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
                                Button("完成") { showHistory = false }
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
                        .navigationTitle("战绩统计")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") { activePanel = .none }
                            }
                        }
                }
            }
            .sheet(isPresented: $showThemePicker) {
                NavigationStack {
                    ThemePickerView()
                        .navigationTitle("主题选择")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") { showThemePicker = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(viewModel: gameViewModel)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") { showSettings = false }
                            }
                        }
                }
            }
            .preferredColorScheme(.dark)
            // 已改用硬编码中文字符串，不再依赖本地化系统
        }
    }
}
#endif
