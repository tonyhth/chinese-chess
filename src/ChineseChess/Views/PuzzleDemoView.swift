import SwiftUI

// MARK: - 残局自动演示主视图

struct PuzzleDemoView: View {
    @State private var viewModel: DemoViewModel?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isDemoFocused: Bool

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
        VStack(spacing: 0) {
            categoryFilterBar
            tacticalGroupFilterBar
            Divider()
            listContent
        }
        .frame(minWidth: 600, minHeight: 700)
        .onAppear {
            if selectedCategory == nil, let firstCat = PuzzleStore.shared.demoCategories.first {
                selectedCategory = .puzzles(firstCat)
                currentPage = 1
                rebuildListCache()
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            selectedTacticalGroup = nil
            currentPage = 1
            rebuildListCache()
        }
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
        .onChange(of: selectedCategory) { _, _ in
            selectedTacticalGroup = nil
            currentPage = 1
            rebuildListCache()
        }
        #endif
    }

    // MARK: - 分类标签栏 (macOS) — 替代 sidebar
    #if os(macOS)
    /// 横向分类标签栏
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PuzzleStore.shared.demoCategories, id: \.self) { cat in
                    let category = DemoCategory.puzzles(cat)
                    let count = PuzzleStore.shared.demoPuzzles(byCategory: cat).count
                    let isSelected = selectedCategory == category
                    Button(action: {
                        if viewModel != nil { cleanupViewModel() }
                        selectedCategory = category
                    }) {
                        HStack(spacing: 4) {
                            Text(category.displayName)
                                .font(.subheadline)
                            Text("\(count)")
                                .font(.caption2)
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.08))
                        )
                        .foregroundColor(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
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
        .accessibilityLabel(L10n.shared.t("demo.backToCategories"))
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
        .accessibilityLabel(selectedCategoryHasTacticalGroups ? L10n.shared.t("demo.backToTacticalGroups") : L10n.shared.t("demo.backToCategories"))
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
        // v6.2 左右布局（v1.2 §三.1，与 MasterGameBrowserView 同构）：
        // 棋盘左（等比缩放）+ 右侧信息面板；点评从 iOS overlay 语境改为右侧常驻
        // （macOS 此前无点评显示，v6.2 面板化补齐）；走法记录面板新增（P1-2）
        ManagedSplitView {
            DemoBoardView(board: vm.board, lastMove: vm.lastMove, isFlipped: vm.item.shouldFlipBoard)
                .aspectRatio(CGFloat(BoardSizing.gridCols) / CGFloat(BoardSizing.gridRows), contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } right: {
            DemoSidePanel(
                commentary: vm.showCommentary ? vm.currentCommentary : nil,
                notations: vm.moveNotations,
                currentIndex: vm.currentIndex,
                onMoveTap: { row in vm.jumpToMove(at: row + 1) },
                header: {
                    DemoInfoBar(item: vm.item, viewModel: vm, onBackToList: { backToList() })
                },
                footer: {
                    DemoControlBar(viewModel: vm, onBackToList: { backToList() })
                }
            )
        }
        // v1.2 §三.2：左右布局需 min 800；高度 700→600
        .frame(minWidth: 800, minHeight: 600)
    }
    #endif

    // MARK: - iOS 布局

    /// iOS 棋谱面板展开状态
    @State private var showIOSRecordPanel: Bool = false

    private func iosLayout(viewModel vm: DemoViewModel) -> some View {
        VStack(spacing: 0) {
            mainContent(viewModel: vm)
            
            // Phase D: iOS 棋谱回放面板（可折叠）
            iosRecordPanel(viewModel: vm)
        }
    }

    // MARK: - iOS 棋谱面板（Phase D）

    @ViewBuilder
    private func iosRecordPanel(viewModel: DemoViewModel) -> some View {
        VStack(spacing: 0) {
            Divider()
            iosRecordHeader(viewModel: viewModel)
            if showIOSRecordPanel {
                iosRecordContent(viewModel: viewModel)
            }
        }
    }

    private func iosRecordHeader(viewModel: DemoViewModel) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                showIOSRecordPanel.toggle()
            }
        }) {
            HStack {
                Image(systemName: showIOSRecordPanel ? "chevron.down" : "chevron.up")
                    .font(.caption2)
                Text(L10n.shared.t("demo.recordPanel"))
                    .font(.caption)
                Spacer()
                Text("\(viewModel.currentIndex + 1)/\(viewModel.totalSteps)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .buttonStyle(.plain)
    }

    private func iosRecordContent(viewModel: DemoViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(viewModel.moveNotations.enumerated()), id: \.offset) { idx, notation in
                    HStack(spacing: 8) {
                        Text("\(idx / 2 + 1).")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                        Text(notation)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 200)
    }

    // MARK: - 主内容区（播放模式）

    @ViewBuilder
    private func mainContent(viewModel: DemoViewModel) -> some View {
        VStack(spacing: 0) {
            DemoInfoBar(item: viewModel.item, viewModel: viewModel, onBackToList: { backToList() })

            ZStack {
                DemoBoardView(board: viewModel.board, lastMove: viewModel.lastMove, isFlipped: viewModel.item.shouldFlipBoard)

                // P1-2: 连播过渡 UI — 半透明 loading overlay
                if viewModel.playState == .transitioning {
                    Color.black.opacity(0.3)
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            ZStack(alignment: .bottom) {
                DemoControlBar(viewModel: viewModel, onBackToList: { backToList() })
                if viewModel.showCommentary, let commentary = viewModel.currentCommentary {
                    CommentaryOverlay(commentary: commentary, speed: viewModel.speed)
                        .padding(.bottom, 8)
                        .allowsHitTesting(false)
                }
            }
        }
        #if os(macOS)
        .focused($isDemoFocused)
        .onAppear { isDemoFocused = true }
        // ⌘→ 下一局（隐藏按钮 + keyboardShortcut，比 onKeyPress 更可靠）
        .background {
            Button("") { loadNextPuzzleShortcut() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            Button("") { loadPrevPuzzleShortcut() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
        }
        #endif
    }

    // MARK: - 连播快捷键

    private func loadNextPuzzleShortcut() {
        guard let vm = viewModel else { return }
        if let currentIndex = cachedListItems.firstIndex(where: { $0.id == vm.item.id }),
           currentIndex + 1 < cachedListItems.count {
            playItem(cachedListItems[currentIndex + 1])
        } else if !cachedListItems.isEmpty {
            playItem(cachedListItems[0])
        }
    }

    private func loadPrevPuzzleShortcut() {
        guard let vm = viewModel else { return }
        if let currentIndex = cachedListItems.firstIndex(where: { $0.id == vm.item.id }),
           currentIndex > 0 {
            playItem(cachedListItems[currentIndex - 1])
        } else if !cachedListItems.isEmpty {
            playItem(cachedListItems[cachedListItems.count - 1])
        }
    }

    // MARK: - 返回列表

    private func backToList() {
        cleanupViewModel()
        viewModel = nil
        rebuildListCache()
    }
}
