import SwiftUI

@main
struct ChineseChessApp: App {
    @State private var viewModel = GameViewModel()
    @State private var showStats = false
    @State private var showRecord = false
    @State private var showPuzzles = false
    @State private var showReplay = false
    @State private var replayRecord: GameRecord?
    @State private var showThemePicker = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 窗口背景
                Color(red: 44/255, green: 24/255, blue: 16/255)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ToolbarView(viewModel: viewModel)

                    BoardView(viewModel: viewModel)
                        .padding()

                    StatusBarView(viewModel: viewModel)

                    // 底部操作栏
                    HStack(spacing: 12) {
                        Button(action: { showRecord.toggle() }) {
                            Label("棋谱", systemImage: "doc.text")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)

                        Button(action: { showStats.toggle() }) {
                            Label("统计", systemImage: "chart.bar")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)

                        Button(action: { showPuzzles.toggle() }) {
                            Label("残局", systemImage: "puzzlepiece")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)

                        Button(action: {
                            if let record = viewModel.buildGameRecord() {
                                replayRecord = record
                                showReplay = true
                            }
                        }) {
                            Label("回放", systemImage: "play.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        .disabled(viewModel.gameMoves.isEmpty)

                        Spacer()

                        Button(action: { showThemePicker.toggle() }) {
                            Label("主题", systemImage: "paintpalette")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
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

                // 棋谱面板
                if showRecord {
                    VStack {
                        Spacer()
                        RecordPanelView(gameMoves: viewModel.gameMoves)
                            .frame(maxWidth: 300, maxHeight: 300)
                            .padding()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // 统计面板
                if showStats {
                    VStack {
                        Spacer()
                        StatsPanelView()
                            .frame(maxWidth: 300)
                            .padding()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(minWidth: 600, minHeight: 720)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showPuzzles) {
                PuzzleSelectView()
                    .frame(minWidth: 400, minHeight: 500)
            }
            .sheet(isPresented: $showReplay) {
                if let record = replayRecord {
                    ReplayView(record: record)
                        .frame(minWidth: 600, minHeight: 720)
                }
            }
            .sheet(isPresented: $showThemePicker) {
                VStack(spacing: 20) {
                    Text("选择主题")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(.top)

                    ThemePickerView()

                    Spacer()

                    Button("关闭") { showThemePicker = false }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                }
                .frame(width: 280, height: 200)
                .background(Color(red: 44/255, green: 24/255, blue: 16/255))
            }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 660, height: 780)
    }
}
