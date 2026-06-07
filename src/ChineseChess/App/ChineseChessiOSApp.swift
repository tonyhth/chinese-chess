#if os(iOS)
import SwiftUI

@main
struct ChineseChessiOSApp: App {
    @State private var gameViewModel = GameViewModel()
    @State private var showRecord = false
    @State private var showPuzzles = false
    @State private var showReplay = false
    @State private var replayRecord: GameRecord?
    @State private var themeManager = ThemeManager.shared
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var historyReplayRecord: GameRecord?
    @State private var showStats = false
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
                        Button(action: { showRecord = true }) {
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

                        Button(action: { showHistory = true }) {
                            Label("历史", systemImage: "clock.arrow.circlepath")
                        }
                        Button(action: { showStats = true }) {
                            Label("统计", systemImage: "chart.bar")
                        }
                        Button(action: { showThemePicker = true }) {
                            Label("主题", systemImage: "paintpalette")
                        }
                        Button(action: { showSettings = true }) {
                            Label("设置", systemImage: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $showRecord) {
                    NavigationStack {
                        RecordPanelView(gameMoves: gameViewModel.gameMoves)
                            .navigationTitle("棋谱")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("完成") { showRecord = false }
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
                .sheet(isPresented: $showReplay) {
                    if let record = replayRecord {
                        NavigationStack {
                            ReplayView(record: record)
                                .navigationTitle("对局回放")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button("完成") { showReplay = false }
                                    }
                                }
                        }
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
            .sheet(isPresented: $showStats) {
                NavigationStack {
                    StatsPanelView()
                        .navigationTitle("战绩统计")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") { showStats = false }
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
        }
    }
}
#endif
