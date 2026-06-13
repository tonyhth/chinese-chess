import SwiftUI

struct PuzzleSelectView: View {
    @State private var selectedCategory: String?
    @State private var selectedPuzzle: Puzzle?
    @State private var selectedStars: Int? = nil
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var debouncedSearchText = ""

    /// 面板背景色（统一常量，渐变遮罩也使用此色）
    private let panelBackground = Color(red: 40/255, green: 22/255, blue: 14/255)

    /// 底部渐变遮罩高度
    private let fadeHeight: CGFloat = 24

    /// 搜索防抖 Timer
    @State private var searchDebounceTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏 + 搜索按钮
            HStack {
                Text(String(localized: "puzzle.title"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearching.toggle()
                        if !isSearching {
                            searchText = ""
                            debouncedSearchText = ""
                        }
                    }
                }) {
                    Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            // 搜索框
            if isSearching {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    TextField(String(localized: "puzzle.searchPlaceholder"), text: $searchText)
                        .font(.system(size: 13))
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .onChange(of: searchText) { _, newValue in
                            searchDebounceTask?.cancel()
                            searchDebounceTask = Task {
                                try? await Task.sleep(nanoseconds: 300_000_000)
                                guard !Task.isCancelled else { return }
                                debouncedSearchText = newValue
                            }
                        }
                    if !searchText.isEmpty {
                        Button(action: { searchText = ""; debouncedSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(red: 60/255, green: 40/255, blue: 30/255))
                .cornerRadius(6)
                .transition(.opacity)
            }

            // 分类选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryButton(title: String(localized: "puzzle.all"), isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                        selectedStars = nil
                    }
                    ForEach(PuzzleStore.shared.categories, id: \.self) { cat in
                        CategoryButton(title: cat, isSelected: selectedCategory == cat) {
                            selectedCategory = cat
                            selectedStars = nil
                        }
                    }
                }
            }

            // 难度子筛选栏
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    DifficultyFilterButton(
                        title: String(localized: "puzzle.all"),
                        isSelected: selectedStars == nil
                    ) {
                        selectedStars = nil
                    }
                    ForEach(1...5, id: \.self) { stars in
                        DifficultyFilterButton(
                            title: String(repeating: "★", count: stars),
                                isSelected: selectedStars == stars
                    ) {
                        selectedStars = stars
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
                        .foregroundColor(.secondary)
                    Text(debouncedSearchText.isEmpty ? String(localized: "puzzle.empty") : String(localized: "puzzle.noMatch"))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ZStack(alignment: .bottom) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            // 按50局分组显示
                            let groups = groupedPuzzles(from: list)
                            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                                // 组标题（仅多组时显示）
                                if groups.count > 1 {
                                    HStack {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 0.5)
                                        Text(String(localized: "puzzle.groupLabel", defaultValue: "第 \(group.rangeLabel) 局"))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 0.5)
                                    }
                                    .padding(.top, 4)
                                }

                                ForEach(group.puzzles) { puzzle in
                                    PuzzleRow(
                                        puzzle: puzzle,
                                        progress: PuzzleStore.shared.progress(for: puzzle.id)
                                    ) {
                                        selectedPuzzle = puzzle
                                    }
                                }
                            }
                        }
                        // 底部留白，与遮罩高度匹配 + 统计栏高度
                        Color.clear.frame(height: fadeHeight + 28)
                    }

                    VStack(spacing: 0) {
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

                        // 底部统计
                        HStack {
                            let completed = list.filter { PuzzleStore.shared.progress(for: $0.id)?.isCompleted == true }.count
                            Text(String(localized: "stats.completedCount", defaultValue: "已完成 \(completed)/\(list.count)"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            let groups = groupedPuzzles(from: list)
                            Text(String(localized: "stats.totalGroups", defaultValue: "共 \(groups.count) 组"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(panelBackground)
                    }
                }
            }
        }
        .padding(12)
        .background(panelBackground)
        .cornerRadius(8)
        #if os(iOS)
        .fullScreenCover(item: $selectedPuzzle) { puzzle in
            PuzzlePlayView(puzzle: puzzle)
        }
        #else
        .sheet(item: $selectedPuzzle) { puzzle in
            PuzzlePlayView(puzzle: puzzle)
                .frame(minWidth: 520, minHeight: 680)
        }
        #endif
    }

    // MARK: - 筛选逻辑

    /// 最终展示的残局列表（分类 + 难度 + 搜索三重过滤）
    private var filteredPuzzles: [Puzzle] {
        var result = PuzzleStore.shared.puzzles

        // 1. 分类筛选
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }

        // 2. 难度筛选
        if let stars = selectedStars {
            result = result.filter { $0.stars == stars }
        }

        // 3. 搜索筛选
        if !debouncedSearchText.isEmpty {
            let q = debouncedSearchText.lowercased()
            result = result.filter { p in
                p.name.lowercased().contains(q) ||
                p.description.lowercased().contains(q) ||
                p.category.lowercased().contains(q)
            }
        }

        // 4. 排序：未完成排前面
        let progress = PuzzleStore.shared.progressMap
        result.sort { a, b in
            let aDone = progress[a.id]?.isCompleted == true
            let bDone = progress[b.id]?.isCompleted == true
            if aDone != bDone { return !aDone }
            return a.id < b.id
        }

        return result
    }

    // MARK: - 分组

    struct PuzzleGroup {
        let rangeLabel: String
        let puzzles: [Puzzle]
    }

    private func groupedPuzzles(from puzzles: [Puzzle]) -> [PuzzleGroup] {
        let groupSize = 50
        var groups: [PuzzleGroup] = []
        let total = puzzles.count
        var start = 0
        while start < total {
            let end = min(start + groupSize, total)
            let batch = Array(puzzles[start..<end])
            let label = "\(start + 1)-\(end)"
            groups.append(PuzzleGroup(rangeLabel: label, puzzles: batch))
            start = end
        }
        return groups
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

// MARK: - 难度筛选按钮

struct DifficultyFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .yellow : .gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.brown.opacity(0.6) : Color.clear)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.yellow.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
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
                            .foregroundColor(.secondary)
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
                        // 自由对弈标签
                        if puzzle.effectiveMode == .freePlay {
                            Text(String(localized: "puzzle.freePlay"))
                                .font(.system(size: 10))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.cyan.opacity(0.15))
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

    /// 是否为自由对弈模式
    private var isFreePlay: Bool {
        puzzle.effectiveMode == .freePlay
    }

    /// 底部区域最大高度（动态计算，防止挤压棋盘）
    private var bottomAreaMaxHeight: CGFloat {
        #if os(iOS)
        let screenHeight = UIScreen.main.bounds.height
        if UIDevice.current.userInterfaceIdiom == .pad {
            return screenHeight * 0.15  // iPad 占 15%
        } else {
            return screenHeight <= 667 ? screenHeight * 0.25 : screenHeight * 0.20
        }
        #else
        return 180  // macOS 固定值，窗口可调
        #endif
    }

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        self._viewModel = State(initialValue: PuzzleViewModel(puzzle: puzzle))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Button(String(localized: "common.back")) { dismiss() }
                    .foregroundColor(.white)
                Spacer()
                Text(puzzle.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                // 步数显示
                if viewModel.gameState == .success {
                    Text(String(localized: "puzzle.completed"))
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                } else if isFreePlay {
                    Text(String(localized: "puzzle.moveCount", defaultValue: "步数: \(viewModel.gameMoves.count)"))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                } else {
                    Text(String(localized: "puzzle.moveProgress", defaultValue: "\(viewModel.gameMoves.count)/\(puzzle.maxMoves)"))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(red: 50/255, green: 30/255, blue: 20/255))

            // 棋盘（优先占据空间，不被底部条件内容挤压）
            ChessBoardView(mode: .playPuzzle(viewModel))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 280)
                .layoutPriority(1)
                .padding()

            // 底部固定区域：高度有上限，避免挤压棋盘
            VStack(spacing: 4) {
                // 操作栏
                HStack(spacing: 16) {
                    Button(action: {
                        viewModel.undoMove()
                    }) {
                        Label(String(localized: "game.undoMove"), systemImage: "arrow.uturn.backward")
                    }
                    .disabled(viewModel.isThinking)
                    .buttonStyle(.bordered)
                    .tint(.brown)

                    Button(action: { viewModel.showHint() }) {
                        Label(String(localized: "game.hint"), systemImage: "lightbulb")
                    }
                    .buttonStyle(.bordered)
                    .tint(.brown)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // 提示显示
                if let hint = viewModel.currentHint {
                    HStack {
                        Text(hint)
                            .font(.system(size: 13))
                            .foregroundColor(.yellow)
                        Spacer()
                        Button(String(localized: "puzzle.continueLabel")) {
                            viewModel.dismissHint()
                        }
                        .font(.system(size: 12, weight: .medium))
                        .buttonStyle(.bordered)
                        .tint(.brown)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
                    .padding(.horizontal, 16)
                }

                // 解法实时提示（仅 guided 模式）
                if !isFreePlay, let hint = viewModel.solutionHint {
                    Text(hint)
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                }

                // 棋谱（内部自带 ScrollView，外层不套 ScrollView 避免嵌套冲突）
                if !viewModel.gameMoves.isEmpty {
                    RecordPanelView(gameMoves: viewModel.gameMoves)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
            .frame(maxHeight: bottomAreaMaxHeight)
            .layoutPriority(0)

            // 通关弹窗
            if viewModel.gameState == .success {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { }

                VStack(spacing: 16) {
                    if viewModel.puzzle.solutionType == "sequence",
                       let desc = viewModel.puzzle.endDescription, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.yellow)
                    } else {
                        Text(isFreePlay ? String(localized: "puzzle.winFreePlay") : String(localized: "puzzle.checkmateWin"))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    if !isFreePlay {
                        Text(String(localized: "puzzle.stars", defaultValue: "星级: \(String(repeating: "★", count: viewModel.completionRating))"))
                            .font(.system(size: 20))
                            .foregroundColor(.yellow)
                    }
                    HStack(spacing: 12) {
                        Button(String(localized: "common.close")) { dismiss() }
                            .buttonStyle(.bordered)
                            .tint(.brown)
                        // 解法回放仅 guided 模式且有解法时显示
                        if !isFreePlay, viewModel.buildSolutionRecord() != nil {
                            Button(String(localized: "puzzle.viewSolution")) {
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
                    .onTapGesture { }

                VStack(spacing: 16) {
                    Text(String(localized: "puzzle.failed"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.red)
                    Text(String(localized: "puzzle.tryAgain"))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Button(String(localized: "common.retry")) {
                            viewModel.resetPuzzle()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brown)

                        Button(String(localized: "common.back")) { dismiss() }
                            .buttonStyle(.bordered)
                            .tint(.brown)
                    }
                }
                .padding(24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .padding()
            }

            // 超步警告弹窗（仅 freePlay 模式）
            if viewModel.gameState == .maxMovesWarning {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { }

                VStack(spacing: 16) {
                    Text(String(localized: "puzzle.maxMovesWarning"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.yellow)
                    Text(String(localized: "puzzle.continueChallenge"))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Button(String(localized: "puzzle.continueChallengeButton")) {
                            viewModel.dismissMaxMovesWarning()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brown)

                        Button(String(localized: "common.back")) { dismiss() }
                            .buttonStyle(.bordered)
                            .tint(.brown)
                    }
                }
                .padding(24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .padding()
            }

            // 和局弹窗（仅 freePlay 模式）
            if viewModel.gameState == .draw {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { }

                VStack(spacing: 16) {
                    Text(String(localized: "gameover.drawTitle"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.yellow)
                    Text(String(localized: "gameover.drawDesc"))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Button(String(localized: "common.retry")) {
                            viewModel.resetPuzzle()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brown)

                        Button(String(localized: "common.back")) { dismiss() }
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
