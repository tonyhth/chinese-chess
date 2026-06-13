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
    @State private var languageManager = LanguageManager()

    var body: some Scene {
        WindowGroup(String(localized: "app.title")) {
            ZStack {
                // 窗口背景
                Color(red: 44/255, green: 24/255, blue: 16/255)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ToolbarView(viewModel: viewModel)

                    BoardView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(minHeight: 280)
                        .layoutPriority(1)

                    StatusBarView(viewModel: viewModel)

                    // 底部操作栏
                    HStack(spacing: 8) {
                        Button(action: { activePanel = activePanel == .record ? .none : .record }) {
                            Image(systemName: "doc.text")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(String(localized: "toolbar.record"))

                        Button(action: { activePanel = activePanel == .stats ? .none : .stats }) {
                            Image(systemName: "chart.bar")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(String(localized: "toolbar.stats"))

                        Button(action: { showPuzzles.toggle() }) {
                            Image(systemName: "puzzlepiece")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(String(localized: "toolbar.puzzle"))

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
                        .help(String(localized: "toolbar.replay"))

                        Spacer()

                        Button(action: { showThemePicker.toggle() }) {
                            Image(systemName: "paintpalette")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(String(localized: "toolbar.theme"))

                        Button(action: { showHistory.toggle() }) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(String(localized: "toolbar.history"))

                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "gearshape")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .help(String(localized: "toolbar.settings"))
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
                            replayRecord = record
                            showReplay = true
                        }
                    }
                }

            }
            .frame(minWidth: 500, minHeight: 600)
            .preferredColorScheme(.dark)
            .environmentObject(languageManager)
            .environment(\.locale, languageManager.currentLocale)
            // 已使用 String(localized:) 国际化
            // 棋谱/统计面板互斥 Sheet
            .sheet(isPresented: Binding(
                get: { activePanel == .record },
                set: { if !$0 { activePanel = .none } }
            )) {
                RecordPanelView(gameMoves: viewModel.gameMoves)
                    .frame(minWidth: 280, minHeight: 250, maxHeight: 400)
            }
            .sheet(isPresented: Binding(
                get: { activePanel == .stats },
                set: { if !$0 { activePanel = .none } }
            )) {
                StatsPanelView()
                    .frame(minWidth: 280, minHeight: 180, maxHeight: 400)
            }
            .sheet(isPresented: $showPuzzles) {
                NavigationStack {
                    PuzzleSelectView()
                        .navigationTitle(String(localized: "puzzle.title"))
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(String(localized: "common.done")) { showPuzzles = false }
                            }
                        }
                }
                .frame(minWidth: 350, minHeight: 400)
            }
            .sheet(isPresented: $showReplay) {
                if let record = replayRecord {
                    ReplayView(record: record)
                        .frame(minWidth: 520, minHeight: 680)
                }
            }
            .sheet(isPresented: $showThemePicker) {
                NavigationStack {
                    VStack(spacing: 16) {
                        ThemePickerView()
                    }
                    .padding()
                    .navigationTitle(String(localized: "theme.title"))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "common.done")) { showThemePicker = false }
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
                                Button(String(localized: "common.done")) { showHistory = false }
                            }
                        }
                }
                .frame(minWidth: 350, minHeight: 400)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(viewModel: viewModel)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(String(localized: "common.done")) { showSettings = false }
                            }
                        }
                }
                .environmentObject(languageManager)
                .frame(minWidth: 320, minHeight: 300, maxHeight: 500)
            }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 860)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(String(localized: "game.settings")) {
                    showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu(String(localized: "game.menuLabel")) {
                Button(String(localized: "game.newGame")) {
                    viewModel.newGame()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button(String(localized: "game.undoMove")) {
                    viewModel.undoMove()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(viewModel.isThinking || viewModel.board.moveHistory.isEmpty)

                Divider()

                Button(String(localized: "game.hint")) {
                    viewModel.requestHint()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(viewModel.isThinking || viewModel.gameState != .playing)
            }
        }
    }
}
#endif
