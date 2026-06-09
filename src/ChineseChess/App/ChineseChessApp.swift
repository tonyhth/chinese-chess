#if os(macOS)
import SwiftUI

@main
struct ChineseChessApp: App {
    init() {
        FontRegistry.registerFonts()
    }

    // 面板状态：互斥管理
    enum Panel: Equatable {
        case none, record, stats
    }
    @State private var activePanel: Panel = .none

    @State private var viewModel = GameViewModel()
    @State private var showPuzzles = false
    @State private var showReplay = false
    @State private var replayRecord: GameRecord?
    @State private var showThemePicker = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var historyReplayRecord: GameRecord?

    var body: some Scene {
        WindowGroup("中国象棋") {
            ZStack {
                // 窗口背景
                Color(red: 44/255, green: 24/255, blue: 16/255)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ToolbarView(viewModel: viewModel)

                    BoardView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    StatusBarView(viewModel: viewModel)

                    // 底部操作栏
                    HStack(spacing: 8) {
                        Button(action: { activePanel = activePanel == .record ? .none : .record }) {
                            Image(systemName: "doc.text")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help("棋谱")

                        Button(action: { activePanel = activePanel == .stats ? .none : .stats }) {
                            Image(systemName: "chart.bar")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help("统计")

                        Button(action: { showPuzzles.toggle() }) {
                            Image(systemName: "puzzlepiece")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help("残局")

                        Button(action: {
                            if let record = viewModel.buildGameRecord() {
                                replayRecord = record
                                showReplay = true
                            }
                        }) {
                            Image(systemName: "play.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .disabled(viewModel.gameMoves.isEmpty)
                        .help("回放")

                        Spacer()

                        Button(action: { showThemePicker.toggle() }) {
                            Image(systemName: "paintpalette")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help("主题")

                        Button(action: { showHistory.toggle() }) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help("历史")

                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "gearshape")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help("设置")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                // 游戏结束弹窗
                if viewModel.gameState != .playing {
                    GameOverOverlay(gameState: viewModel.gameState) {
                        viewModel.newGame()
                    }
                }

            }
            .frame(minWidth: 600, minHeight: 720)
            .preferredColorScheme(.dark)
            // 棋谱/统计面板互斥 Sheet
            .sheet(isPresented: Binding(
                get: { activePanel == .record },
                set: { if !$0 { activePanel = .none } }
            )) {
                RecordPanelView(gameMoves: viewModel.gameMoves)
                    .frame(minWidth: 320, minHeight: 300, maxHeight: 400)
            }
            .sheet(isPresented: Binding(
                get: { activePanel == .stats },
                set: { if !$0 { activePanel = .none } }
            )) {
                StatsPanelView()
                    .frame(minWidth: 320, minHeight: 200, maxHeight: 400)
            }
            .sheet(isPresented: $showPuzzles) {
                NavigationStack {
                    PuzzleSelectView()
                        .navigationTitle("残局闯关")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") { showPuzzles = false }
                            }
                        }
                }
                .frame(minWidth: 400, minHeight: 500)
            }
            .sheet(isPresented: $showReplay) {
                if let record = replayRecord {
                    ReplayView(record: record)
                        .frame(minWidth: 600, minHeight: 720)
                }
            }
            .sheet(isPresented: $showThemePicker) {
                NavigationStack {
                    VStack(spacing: 16) {
                        ThemePickerView()
                    }
                    .padding()
                    .navigationTitle("选择主题")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showThemePicker = false }
                        }
                    }
                }
                .frame(minWidth: 300, minHeight: 200)
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
                .frame(minWidth: 500, minHeight: 500)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(viewModel: viewModel)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") { showSettings = false }
                            }
                        }
                }
                .frame(minWidth: 320, minHeight: 300, maxHeight: 500)
            }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 660, height: 760)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置") {
                    showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("棋局") {
                Button("新局") {
                    viewModel.newGame()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("悔棋") {
                    viewModel.undoMove()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(viewModel.isThinking || viewModel.board.moveHistory.isEmpty)

                Divider()

                Button("提示") {
                    viewModel.requestHint()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(viewModel.isThinking || viewModel.gameState != .playing)
            }
        }
    }
}
#endif
