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

    /// MasterGameStore 懒加载
    @State private var masterStore = MasterGameStore.shared
    @State private var isLoadingMasterIndex = false

    /// 列表模式：分页
    @State private var currentPage: Int = 1
    private let pageSize = 30

    /// [P0 fix] 缓存列表条目，切分类时重建，避免 computed property 重复计算
    @State private var cachedListItems: [DemoItemWrapper] = []
    @State private var cachedTotalCount: Int = 0

    /// 加载状态
    @State private var loadingGame = false
    @State private var loadError: String? = nil
    @State private var showLoadError = false
    @State private var showIncompleteWarning = false
    @State private var showMasterLoadError = false

    /// 是否有更多数据可加载
    private var hasMoreItems: Bool {
        cachedListItems.count < cachedTotalCount
    }

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
        case .opening(let opening):
            let indices = masterStore.byOpening(opening.firstMove)
            cachedTotalCount = indices.count
            let page = indices.prefix(pageSize * currentPage)
            cachedListItems = page.map { .masterGame(MasterGameDemoItem(index: $0, fen: nil)) }
        case .player:
            cachedListItems = []
            cachedTotalCount = 0
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
        // iOS 三级导航：分类列表 → 子分类列表（如有）→ 条目列表
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
        #endif
    }

    // MARK: - 分类侧边栏 (macOS)
    #if os(macOS)
    private var sidebar: some View {
        List(selection: $selectedCategory) {
            // 残局 Section
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

            // 大师棋谱 Section
            if masterStore.isLoaded {
                Section(L10n.shared.t("demo.sectionMasterGames")) {
                    ForEach(OpeningCategories.categories.filter { opening in
                        masterStore.byOpening(opening.firstMove).count > 0
                    }) { opening in
                        let count = masterStore.byOpening(opening.firstMove).count
                        HStack {
                            Text(DemoCategory.opening(opening).displayName)
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
                        .tag(DemoCategory.opening(opening))
                    }
                }
            } else {
                Section(L10n.shared.t("demo.sectionMasterGames")) {
                    Button(action: loadMasterIndex) {
                        HStack {
                            if isLoadingMasterIndex {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(.accentColor)
                            }
                            Text(L10n.shared.t("demo.loadMasterIndex"))
                                .font(.subheadline)
                        }
                    }
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
            // 残局 Section
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

            // 大师棋谱 Section
            if masterStore.isLoaded {
                Section {
                    ForEach(OpeningCategories.categories.filter { opening in
                        masterStore.byOpening(opening.firstMove).count > 0
                    }) { opening in
                        let category = DemoCategory.opening(opening)
                        let count = masterStore.byOpening(opening.firstMove).count
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
                    Text(L10n.shared.t("demo.sectionMasterGames"))
                }
            } else {
                Section {
                    Button(action: loadMasterIndex) {
                        HStack {
                            if isLoadingMasterIndex {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(.accentColor)
                            }
                            Text(L10n.shared.t("demo.loadMasterIndex"))
                        }
                    }
                } header: {
                    Text(L10n.shared.t("demo.sectionMasterGames"))
                }
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
            .foregroundStyle(.accentColor)
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
            .foregroundStyle(.accentColor)
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
                    categoryRow(name: "全部", count: allCount)
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
                        tacticalGroupFilterButton(title: "全部", isSelected: selectedTacticalGroup == nil) {
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
                // 未选择分类
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(L10n.shared.t("demo.selectCategory"))
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    // iOS 上如果大师棋谱未加载，显示加载按钮
                    #if os(iOS)
                    if !masterStore.isLoaded {
                        Button(action: loadMasterIndex) {
                            if isLoadingMasterIndex {
                                ProgressView()
                            } else {
                                Label(L10n.shared.t("demo.loadMasterIndex"), systemImage: "arrow.down.circle")
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.accentColor)
                        .padding(.top, 8)
                    }
                    #endif
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

                    // 加载更多按钮
                    if hasMoreItems {
                        HStack {
                            Spacer()
                            Button(String(format: L10n.shared.t("demo.loadMore"), cachedListItems.count, cachedTotalCount)) {
                                currentPage += 1
                                rebuildListCache()
                            }
                            .buttonStyle(.bordered)
                            .tint(.brown)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                }
                .overlay {
                    if loadingGame {
                        ProgressView()
                    }
                }
                // [P2 fix] 标准化 alert 绑定：用 @State Bool 控制显示
                .alert(L10n.shared.t("demo.loadError"), isPresented: $showLoadError) {
                    Button("OK") { loadError = nil }
                } message: {
                    Text(loadError ?? "")
                }
                .alert(L10n.shared.t("demo.incompleteWarning"), isPresented: $showIncompleteWarning) {
                    Button("OK") {}
                } message: {
                    Text(L10n.shared.t("demo.incompleteMessage"))
                }
            }
        }
        // 大师棋谱索引加载失败提示
        .alert(L10n.shared.t("demo.loadError"), isPresented: $showMasterLoadError) {
            Button("OK") {}
        } message: {
            Text(masterStore.loadError ?? "")
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
                // 难度星级
                HStack(spacing: 1) {
                    ForEach(0..<puzzle.stars, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
            }

        case .masterGame(let demoItem):
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(demoItem.index.redNameCN) vs \(demoItem.index.blackNameCN)")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        if let year = demoItem.index.year {
                            Text("\(year)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text(demoItem.index.event)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                // [P2 fix] 步数国际化
                Text(String(format: L10n.shared.t("demo.moveCount"), demoItem.index.moveCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 播放条目

    private func playItem(_ wrapper: DemoItemWrapper) {
        switch wrapper {
        case .puzzle(let puzzle):
            // 残局：走法从 solution 直接解析
            let convertResult = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
            viewModel = DemoViewModel(item: wrapper, moves: convertResult.moves)

        case .masterGame(let demoItem):
            // [P1 fix] 大师棋谱：先设 loading，再切后台线程执行 I/O
            loadingGame = true
            loadError = nil
            Task.detached {
                let result = MasterGameLoader.loadGame(demoItem.index)
                guard let record = result.records.first else {
                    await MainActor.run {
                        loadingGame = false
                        loadError = L10n.shared.t("demo.loadGameFail")
                        showLoadError = true
                    }
                    return
                }
                let fen = record.initialFEN ?? FENParser.standardInitial
                let convertResult = DemoMoveConverter.convertGameMoves(record.moves, initialFEN: fen)

                await MainActor.run {
                    loadingGame = false
                    if convertResult.moves.isEmpty {
                        loadError = L10n.shared.t("demo.parseGameFail")
                        showLoadError = true
                    } else {
                        // 用实际 FEN 替换 MasterGameDemoItem 中的默认 FEN
                        let updatedItem = MasterGameDemoItem(index: demoItem.index, fen: fen)
                        viewModel = DemoViewModel(item: .masterGame(updatedItem), moves: convertResult.moves)

                        if !convertResult.isComplete {
                            showIncompleteWarning = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - 大师棋谱索引懒加载

    private func loadMasterIndex() {
        guard !isLoadingMasterIndex else { return }
        isLoadingMasterIndex = true
        Task {
            await masterStore.loadIfNeeded()
            await MainActor.run {
                isLoadingMasterIndex = false
                if masterStore.loadError != nil {
                    showMasterLoadError = true
                }
            }
        }
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
            // 信息栏
            DemoInfoBar(item: viewModel.item, viewModel: viewModel)

            // 棋盘 + 点评覆盖
            ZStack(alignment: .top) {
                DemoBoardView(board: viewModel.board, lastMove: viewModel.lastMove, isFlipped: viewModel.item.shouldFlipBoard)

                // 点评气泡
                if let commentary = viewModel.currentCommentary {
                    CommentaryOverlay(commentary: commentary, speed: viewModel.speed)
                        .padding(.top, 8)
                }
            }

            // 控制栏
            controlBar(viewModel: viewModel)
        }
    }

    // MARK: - 控制栏

    private func controlBar(viewModel: DemoViewModel) -> some View {
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
                Picker(L10n.shared.t("demo.speed"), selection: Binding(
                    get: { viewModel.speed },
                    set: { viewModel.speed = $0 }
                )) {
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

                // 返回列表
                Button(action: { backToList() }) {
                    Image(systemName: "list.bullet")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    // MARK: - 返回列表

    private func backToList() {
        viewModel?.pause()
        viewModel = nil
        rebuildListCache()
    }
}
