#if os(iOS)
import SwiftUI

@main
struct ChineseChessiOSApp: App {
    @State private var gameViewModel = GameViewModel()
    @State private var showStats = false
    @State private var showRecord = false
    @State private var showPuzzles = false
    @State private var showReplay = false
    @State private var replayRecord: GameRecord?
    @State private var showThemePicker = false
    @State private var themeManager = ThemeManager.shared

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
                        Button(action: { showStats = true }) {
                            Label("统计", systemImage: "chart.bar")
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
                        Button(action: { showThemePicker = true }) {
                            Label("主题", systemImage: "paintpalette")
                        }
                    }
                }
                .sheet(isPresented: $showStats) {
                    NavigationStack {
                        StatsPanelView()
                            .navigationTitle("统计")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("完成") { showStats = false }
                                }
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
                .sheet(isPresented: $showThemePicker) {
                    NavigationStack {
                        VStack(spacing: 20) {
                            Text("选择主题")
                                .font(.title2)
                                .padding(.top)

                            ThemePickerView()

                            Spacer()
                        }
                        .navigationTitle("主题")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") { showThemePicker = false }
                            }
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
#endif
