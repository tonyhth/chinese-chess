import SwiftUI

// MARK: - 残局自动演示主视图

struct PuzzleDemoView: View {
    @State private var viewModel: DemoViewModel
    @Environment(\.dismiss) private var dismiss

    /// 当前分类过滤
    @State private var selectedCategory: String = PuzzleStore.shared.demoCategories.first ?? ""

    /// 所有分类（过滤掉 freePlay 无 solution 的局）
    private var categories: [String] {
        PuzzleStore.shared.demoCategories
    }

    /// 当前分类下的残局列表（只包含有 solution 的）
    private var filteredPuzzles: [Puzzle] {
        PuzzleStore.shared.demoPuzzles(byCategory: selectedCategory)
    }

    /// 当前残局在列表中的索引
    @State private var puzzleIndex: Int = 0

    var onClose: (() -> Void)? = nil

    init(puzzle: Puzzle, onClose: (() -> Void)? = nil) {
        self._viewModel = State(initialValue: DemoViewModel(puzzle: puzzle))
        self.onClose = onClose
    }

    var body: some View {
        #if os(iOS)
        iosLayout
        #else
        macosLayout
        #endif
    }

    // MARK: - macOS 布局

    private var macosLayout: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 160)

            Divider()

            mainContent
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    // MARK: - iOS 布局

    private var iosLayout: some View {
        VStack(spacing: 0) {
            categoryPicker
            mainContent
        }
    }

    // MARK: - 分类侧边栏 (macOS)

    private var sidebar: some View {
        List(categories, id: \.self, selection: $selectedCategory) { cat in
            let count = PuzzleStore.shared.demoPuzzles(byCategory: cat).count
            HStack {
                Text(cat)
                    .font(.subheadline)
                Spacer()
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .tag(cat)
        }
        .listStyle(.sidebar)
    }

    // MARK: - 分类 Picker (iOS)

    private var categoryPicker: some View {
        Picker("分类", selection: $selectedCategory) {
            ForEach(categories, id: \.self) { cat in
                let count = PuzzleStore.shared.demoPuzzles(byCategory: cat).count
                Text("\(cat) (\(count))").tag(cat)
            }
        }
        .pickerStyle(.menu)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - 主内容区

    private var mainContent: some View {
        VStack(spacing: 0) {
            // 信息栏
            DemoInfoBar(puzzle: viewModel.puzzle, viewModel: viewModel)

            // 棋盘 + 点评覆盖
            ZStack(alignment: .top) {
                DemoBoardView(board: viewModel.board, lastMove: viewModel.lastMove, isFlipped: viewModel.puzzle.side == .black)

                // 点评气泡
                if let commentary = viewModel.currentCommentary {
                    CommentaryOverlay(commentary: commentary, speed: viewModel.speed)
                        .padding(.top, 8)
                }
            }

            // 控制栏
            controlBar
        }
    }

    // MARK: - 控制栏

    private var controlBar: some View {
        VStack(spacing: 8) {
            // 进度条
            ProgressView(value: Double(viewModel.currentIndex), total: Double(max(viewModel.totalSteps, 1)))
                .padding(.horizontal, 16)

            // 按钮行
            HStack(spacing: 16) {
                Button(action: { viewModel.stepBackward() }) {
                    Image(systemName: "backward.frame")
                }
                .disabled(!viewModel.canGoBack)

                Button(action: { viewModel.togglePlay() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }

                Button(action: { viewModel.stepForward() }) {
                    Image(systemName: "forward.frame")
                }
                .disabled(!viewModel.canGoForward)

                Divider()
                    .frame(height: 24)

                // 速度选择
                Picker("速度", selection: $viewModel.speed) {
                    ForEach(DemoSpeed.allCases) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Divider()
                    .frame(height: 24)

                // 连播开关
                Toggle(isOn: Binding(
                    get: { viewModel.isAutoAdvance },
                    set: { _ in viewModel.toggleAutoAdvance() }
                )) {
                    Image(systemName: "repeat")
                }
                .toggleStyle(.button)

                Spacer()

                // 上一局 / 下一局
                Button(action: previousPuzzle) {
                    Image(systemName: "chevron.up")
                }
                .disabled(puzzleIndex <= 0)

                Button(action: nextPuzzle) {
                    Image(systemName: "chevron.down")
                }
                .disabled(puzzleIndex >= filteredPuzzles.count - 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    // MARK: - 残局切换

    private func nextPuzzle() {
        guard puzzleIndex < filteredPuzzles.count - 1 else { return }
        puzzleIndex += 1
        switchToPuzzle(filteredPuzzles[puzzleIndex])
    }

    private func previousPuzzle() {
        guard puzzleIndex > 0 else { return }
        puzzleIndex -= 1
        switchToPuzzle(filteredPuzzles[puzzleIndex])
    }

    private func switchToPuzzle(_ puzzle: Puzzle) {
        viewModel = DemoViewModel(puzzle: puzzle)
    }
}
