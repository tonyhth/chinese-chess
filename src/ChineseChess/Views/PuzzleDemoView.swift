import SwiftUI

// MARK: - 残局自动演示主视图

struct PuzzleDemoView: View {
    @State private var viewModel: DemoViewModel?
    @Environment(\.dismiss) private var dismiss

    // TODO: 后续迭代统一传入参数或用 @Environment 注入，解除 PuzzleStore.shared 硬依赖

    /// 当前选中的演示分类
    @State private var selectedCategory: DemoCategory? = nil

    /// 当前选中的战术子分类（车马炮类专用）
    @State private var selectedTacticalGroup: String? = nil

    /// 列表模式：分页
    @State private var currentPage: Int = 1
    private let pageSize = 30

    /// [P0 fix] 缓存列表条目，切分类时重建，避免 computed property 重复计算
    @State private var cachedListItems: [DemoItemWrapper] = []
    @State private var cachedTotalCount: Int = 0

    /// 无参初始化：显示分类浏览视图，用户选择后进入演示
    init() {
        self._viewModel = State(initialValue: nil)
    }

    /// 指定残局初始化：直接进入该残局的演示
    init(initialPuzzle: Puzzle) {
        self._viewModel = State(initialValue: DemoViewModel(puzzle: initialPuzzle))
    }

    var body: some View {
        if let vm = viewModel {
            // 有选中残局 → 显示演示
            #if os(iOS)
            iosLayout(viewModel: vm)
            #else
            macosLayout(viewModel: vm)
            #endif
        } else {
            // 无选中残局 → 显示列表模式
            listLayout
        }
    }

    // MARK: - 列表缓存重建

    /// 切分类或翻页时重建缓存
    private func rebuildListCache() {
        guard let cat = selectedCategory else {
            cachedListItems = []
            cachedTotalCount = 0
            return
        }
        switch cat {
        case .puzzles(let name):
            let puzzles: [Puzzle]
            if let group = selectedTacticalGroup {
                puzzles = PuzzleStore.shared.demoPuzzles(byCategory: name, tacticalGroup: group)
            } else {
                puzzles = PuzzleStore.shared.demoPuzzles(byCategory: name)
            }
            cachedTotalCount = puzzles.count
            cachedListItems = puzzles.map { .puzzle($0) }
        }
    }

    /// 当前选中分类是否有战术子分类
    private var selectedCategoryHasTacticalGroups: Bool {
        guard let cat = selectedCategory, case .puzzles(let name) = cat else { return false }
        return PuzzleStore.shared.hasTacticalGroups(forCategory: name)
    }

    // MARK: - 列表模式（未选中具体对局时显示）

    private var listLayout: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            sidebar
                .frame(width: 200)

            Divider()

            VStack(spacing: 0) {
                tacticalGroupFilterBar
                listContent
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        #else
        Group {
        // iOS 三级导航：分类列表 → 子分类列表（如有） → 条目列表
        if selectedCategory == nil {
            categoryList
        } else if selectedCategoryHasTacticalGroups && selectedTacticalGroup == nil {
            tacticalGroupList
        } else {
            VStack(spacing: 0) {
                iosBackBar
                listContent
            }
        }
        }
        #endif
    }

    // MARK: - 分类侧边栏 (macOS)
    #if os(macOS)
    private var sidebar: some View {
        List(selection: $selectedCategory) {
            Section(L10n.shared.t("demo.sectionPuzzles")) {
                ForEach(PuzzleStore.shared.demoCategories, id: \.self) { cat in
                    let count = PuzzleStore.shared.demoPuzzles(byCategory: cat).count
                    HStack {
                        Text(DemoCategory.puzzles(cat).displayName)
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
                    .tag(DemoCategory.puzzles(cat))
                }
            }
        }
        .listStyle(.sidebar)
    }
    #endif

    // MARK: - 分类全屏列表 (iOS)

    #if os(iOS)
    private var categoryList: some View {
        List {
            Section {
                ForEach(PuzzleStore.shared.demoCategories, id: \.self) { cat in
                    let category = DemoCategory.puzzles(cat)
                    let count = PuzzleStore.shared.demoPuzzles(byCategory: cat).count
                    Button(action: {
                        selectedCategory = category
                        currentPage = 1
                        rebuildListCache()
                    }) {
                        categoryRow(name: category.displayName, count: count)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(L10n.shared.t("demo.sectionPuzzles"))
            }
        }
        .listStyle(.insetGrouped)
    }

    /// 返回分类列表的顶栏按钮
    private var categoryBackBar: some View {
        Button(action: { selectedCategory = nil }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text(L10n.shared.t("demo.category"))
            }
            .font(.subheadline)
            .foregroundStyle(Color.accentColor)
        }
        .accessibilityLabel("返回分类列表")
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// iOS 智能返回栏：有子分类时返回子分类列表，否则返回分类列表
    private var iosBackBar: some View {
        Button(action: {
            if selectedCategoryHasTacticalGroups {
                selectedTacticalGroup = nil
                rebuildListCache()
            } else {
                selectedCategory = nil
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                if selectedCategoryHasTacticalGroups {
                    Text(selectedCategory?.displayName ?? L10n.shared.t("demo.category"))
                } else {
                    Text(L10n.shared.t("demo.category"))
                }
            }
            .font(.subheadline)
            .foregroundStyle(Color.accentColor)
        }
        .accessibilityLabel(selectedCategoryHasTacticalGroups ? "返回子分类列表" : "返回分类列表")
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - 战术子分类列表 (iOS)

    #if os(iOS)
    private var tacticalGroupList: some View {
        List {
            if case .puzzles(let name) = selectedCategory {
                // "全部"选项
                let allCount = PuzzleStore.shared.demoPuzzles(byCategory: name).count
                Button(action: {
                    selectedTacticalGroup = nil
                    currentPage = 1
                    rebuildListCache()
                }) {
                    categoryRow(name: L10n.shared.t("puzzle.all"), count: allCount)
                }
                .buttonStyle(.plain)

                // 各战术子分类
                ForEach(PuzzleStore.shared.demoTacticalGroups(forCategory: name), id: \.self) { group in
                    let count = PuzzleStore.shared.demoPuzzles(byCategory: name, tacticalGroup: group).count
                    Button(action: {
                        selectedTacticalGroup = group
                        currentPage = 1
                        rebuildListCache()
                    }) {
                        categoryRow(name: group, count: count)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .top) {
            categoryBackBar
        }
    }
    #endif
    #endif

    // MARK: - 分类行视图（displayName + badge 计数）

    @ViewBuilder
    private func categoryRow(name: String, count: Int) -> some View {
        HStack {
            Text(name)
                .font(.body)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    // MARK: - macOS 子分类过滤栏

    #if os(macOS)
    /// macOS：选中分类有战术子分类时，在列表内容上方显示过滤栏
    private var tacticalGroupFilterBar: some View {
        Group {
            if selectedCategoryHasTacticalGroups,
               case .puzzles(let name) = selectedCategory {
                let groups = PuzzleStore.shared.demoTacticalGroups(forCategory: name)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "全部"
                        tacticalGroupFilterButton(title: L10n.shared.t("puzzle.all"), isSelected: selectedTacticalGroup == nil) {
                            selectedTacticalGroup = nil
                            currentPage = 1
                            rebuildListCache()
                        }
                        // 各子分类
                        ForEach(groups, id: \.self) { group in
                            tacticalGroupFilterButton(title: group, isSelected: selectedTacticalGroup == group) {
                                selectedTacticalGroup = group
                                currentPage = 1
                                rebuildListCache()
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .background(.bar)
            }
        }
    }

    private func tacticalGroupFilterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
    #endif

    // MARK: - 列表内容区

    private var listContent: some View {
        Group {
            if selectedCategory == nil {
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(L10n.shared.t("demo.selectCategory"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if cachedListItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(L10n.shared.t("demo.noData"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(cachedListItems) { wrapper in
                        Button(action: { playItem(wrapper) }) {
                            demoItemRow(wrapper)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            selectedTacticalGroup = nil
            currentPage = 1
            rebuildListCache()
        }
    }

    // MARK: - 列表项行视图

    @ViewBuilder
    private func demoItemRow(_ wrapper: DemoItemWrapper) -> some View {
        switch wrapper {
        case .puzzle(let puzzle):
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(puzzle.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(puzzle.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 1) {
                    ForEach(0..<puzzle.stars, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
            }
        case .masterGame:
            // 大师棋谱已迁至 MasterGameBrowserView，此分支不再使用
            EmptyView()
        }
    }

    // MARK: - 播放条目

    private func playItem(_ wrapper: DemoItemWrapper) {
        // P0-4: 连播替换 ViewModel 前安全清理旧对象
        cleanupViewModel()

        switch wrapper {
        case .puzzle(let puzzle):
            let convertResult = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
            let newVM = DemoViewModel(item: wrapper, moves: convertResult.moves)
                    newVM.onAutoAdvanceHandler = {
                        self.loadNextPuzzle(after: wrapper)
                    }
                    viewModel = newVM
        case .masterGame:
            break
        }
    }

    /// 加载下一局残局
    private func loadNextPuzzle(after current: DemoItemWrapper) {
        if let currentIndex = cachedListItems.firstIndex(where: { $0.id == current.id }),
           currentIndex + 1 < cachedListItems.count {
            playItem(cachedListItems[currentIndex + 1])
        } else if !cachedListItems.isEmpty {
            playItem(cachedListItems[0])  // 循环回第一局
        }
    }

    /// 安全清理旧 ViewModel（P0-4: 防止回调竞态）
    private func cleanupViewModel() {
        guard let vm = viewModel else { return }
        vm.pause()                       // 停止播放 + 取消 autoPlayTask
        vm.resultDisplayTimer?.cancel()   // 取消结果展示定时器
        vm.onAutoAdvanceHandler = nil     // 断开回调，防止旧对象触发
    }

    // MARK: - macOS 布局
    #if os(macOS)
    private func macosLayout(viewModel vm: DemoViewModel) -> some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 200)

            Divider()

            mainContent(viewModel: vm)
        }
        .frame(minWidth: 720, minHeight: 520)
    }
    #endif

    // MARK: - iOS 布局

    private func iosLayout(viewModel vm: DemoViewModel) -> some View {
        VStack(spacing: 0) {
            mainContent(viewModel: vm)
        }
    }

    // MARK: - 主内容区（播放模式）

    @ViewBuilder
    private func mainContent(viewModel: DemoViewModel) -> some View {
        VStack(spacing: 0) {
            DemoInfoBar(item: viewModel.item, viewModel: viewModel, onBackToList: { backToList() })

            ZStack(alignment: .top) {
                DemoBoardView(board: viewModel.board, lastMove: viewModel.lastMove, isFlipped: viewModel.item.shouldFlipBoard)

                if let commentary = viewModel.currentCommentary {
                    CommentaryOverlay(commentary: commentary, speed: viewModel.speed)
                        .padding(.top, 8)
                }

                // P1-2: 连播过渡 UI — 半透明 loading overlay
                if viewModel.playState == .transitioning {
                    Color.black.opacity(0.3)
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }

            DemoControlBar(viewModel: viewModel, onBackToList: { backToList() })
        }
    }

    // MARK: - 返回列表

    private func backToList() {
        cleanupViewModel()
        viewModel = nil
        rebuildListCache()
    }
}
