import SwiftUI

struct PuzzleSelectView: View {
    @State private var selectedCategory: String?
    @State private var selectedPuzzle: Puzzle?

    /// 面板背景色（统一常量，渐变遮罩也使用此色）
    private let panelBackground = Color(red: 40/255, green: 22/255, blue: 14/255)

    /// 底部渐变遮罩高度
    private let fadeHeight: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("残局闯关")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            // 分类选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryButton(title: "全部", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(PuzzleStore.shared.categories, id: \.self) { cat in
                        CategoryButton(title: cat, isSelected: selectedCategory == cat) {
                            selectedCategory = cat
                        }
                    }
                }
            }

            // 残局列表
            let list = filteredPuzzles
            if list.isEmpty {
                // 空状态提示
                VStack(spacing: 8) {
                    Image(systemName: "puzzlepiece")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("暂无残局")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ZStack(alignment: .bottom) {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(list) { puzzle in
                                PuzzleRow(puzzle: puzzle, progress: PuzzleStore.shared.progress(for: puzzle.id)) {
                                    selectedPuzzle = puzzle
                                }
                            }
                        }
                        // 底部留白，与遮罩高度匹配
                        Color.clear.frame(height: fadeHeight)
                    }

                    // 底部渐变遮罩，暗示可滚动
                    LinearGradient(
                        colors: [
                            panelBackground.opacity(0),
                            panelBackground
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: fadeHeight)
                    .allowsHitTesting(false)
                }
            }
        }
        .padding(12)
        .background(panelBackground)
        .cornerRadius(8)
        .sheet(item: $selectedPuzzle) { puzzle in
            PuzzlePlayView(puzzle: puzzle)
        }
    }

    private var filteredPuzzles: [Puzzle] {
        guard let cat = selectedCategory else {
            return PuzzleStore.shared.puzzles
        }
        return PuzzleStore.shared.puzzles.filter { $0.category == cat }
    }
}

// MARK: - 分类按钮

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.brown : Color.clear)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 残局行

struct PuzzleRow: View {
    let puzzle: Puzzle
    let progress: PuzzleProgress?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(puzzle.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    HStack(spacing: 4) {
                        Text(puzzle.description)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        if !puzzle.typeLabel.isEmpty {
                            Text(puzzle.typeLabel)
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(3)
                        }
                    }
                }

                Spacer()

                // 星级
                HStack(spacing: 2) {
                    ForEach(1...puzzle.stars, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                }

                // 完成标记 + 最佳星级
                if progress?.isCompleted == true {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        if let rating = progress?.bestRating {
                            Text("\(rating)★")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color(red: 50/255, green: 30/255, blue: 20/255))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 残局闯关视图

struct PuzzlePlayView: View {
    let puzzle: Puzzle
    @State private var viewModel: PuzzleViewModel
    @State private var showSolutionReplay = false
    @Environment(\.dismiss) private var dismiss

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        self._viewModel = State(initialValue: PuzzleViewModel(puzzle: puzzle))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Button("返回") { dismiss() }
                    .foregroundColor(.white)
                Spacer()
                Text(puzzle.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(viewModel.gameState == .success ? "通关 ✅" : "\(viewModel.gameMoves.count)/\(puzzle.maxMoves)")
                    .font(.system(size: 13))
                    .foregroundColor(viewModel.gameState == .success ? .green : .gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(red: 50/255, green: 30/255, blue: 20/255))

            // 棋盘
            ChessBoardView(mode: .playPuzzle(viewModel))
                .padding()

            // 操作栏
            HStack(spacing: 16) {
                Button(action: {
                    viewModel.undoMove()
                }) {
                    Label("悔棋", systemImage: "arrow.uturn.backward")
                }
                .disabled(viewModel.isThinking)
                .buttonStyle(.bordered)
                .tint(.brown)

                Button(action: { viewModel.showHint() }) {
                    Label("提示", systemImage: "lightbulb")
                }
                .buttonStyle(.bordered)
                .tint(.brown)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // 提示显示
            if let hint = viewModel.currentHint {
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundColor(.yellow)
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
                    .padding(.horizontal, 16)
                    .onTapGesture { viewModel.dismissHint() }
            }

            // 解法实时提示
            if let hint = viewModel.solutionHint {
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
            }

            // 棋谱
            if !viewModel.gameMoves.isEmpty {
                RecordPanelView(gameMoves: viewModel.gameMoves)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            // 通关弹窗（全屏遮罩 + 居中弹窗）
            if viewModel.gameState == .success {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { /* 阻止穿透 */ }

                VStack(spacing: 16) {
                    if viewModel.puzzle.solutionType == "sequence",
                       let desc = viewModel.puzzle.endDescription, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.yellow)
                    } else {
                        Text("🎉 将杀获胜")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    Text("星级: " + String(repeating: "★", count: viewModel.completionRating))
                        .font(.system(size: 20))
                        .foregroundColor(.yellow)
                    HStack(spacing: 12) {
                        Button("关闭") { dismiss() }
                            .buttonStyle(.bordered)
                            .tint(.brown)
                        if viewModel.buildSolutionRecord() != nil {
                            Button("查看完美解法") {
                                showSolutionReplay = true
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        }
                    }
                }
                .padding(24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .padding()
                .sheet(isPresented: $showSolutionReplay) {
                    if let record = viewModel.buildSolutionRecord() {
                        ReplayView(record: record)
                    }
                }
            }

            // 失败弹窗
            if viewModel.gameState == .failed {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { /* 阻止穿透 */ }

                VStack(spacing: 16) {
                    Text("挑战失败")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.red)
                    Text("不要气馁，再试一次吧！")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    HStack(spacing: 12) {
                        Button("重试") {
                            viewModel.resetPuzzle()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brown)

                        Button("返回") { dismiss() }
                            .buttonStyle(.bordered)
                            .tint(.brown)
                    }
                }
                .padding(24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .padding()
            }
        }
        .background(Color(red: 44/255, green: 24/255, blue: 16/255))
    }
}
