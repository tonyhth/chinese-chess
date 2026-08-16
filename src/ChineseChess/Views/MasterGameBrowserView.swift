import SwiftUI

// MARK: - 浏览模式枚举

enum MasterGameBrowseMode: String, CaseIterable, Identifiable {
    case opening   // 按开局
    case player    // 按棋手
    case event     // 按赛事

    var id: String { rawValue }

    var label: String {
        switch self {
        case .opening: return L10n.shared.t("master.mode.opening")
        case .player:  return L10n.shared.t("master.mode.player")
        case .event:   return L10n.shared.t("master.mode.event")
        }
    }
}

// MARK: - Sidebar 统一选中类型

/// 包装四种 sidebar 选中类型，供 macOS List(selection:) 使用
enum SidebarSelection: Hashable {
    case opening(OpeningCategory)
    case subcategory(OpeningSubcategory)
    case player(MasterStatsFile.PlayerStat)
    case event(MasterStatsFile.EventStat)
}

// MARK: - 大师棋谱浏览器

/// 独立的大师棋谱浏览视图（从 PuzzleDemoView 拆出）
/// macOS：分类筛选列表 + 棋谱播放（v4 移除 sidebar；v6.2 播放页改左右布局：棋盘左 + 右侧信息面板）
/// iOS：全屏列表 → 棋谱播放
struct MasterGameBrowserView: View {
    @State private var viewModel: DemoViewModel?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isDemoFocused: Bool

    @State private var masterStore = MasterGameStore.shared
    @State private var isLoadingIndex = false

    /// 浏览模式
    @State private var browseMode: MasterGameBrowseMode = .opening

    /// macOS sidebar 统一选中
    // （历史注记：v4 移除 sidebar，selection 无消费者已删；头部注释 v6.2 对齐）

    /// 当前选中的开局分类
    @State private var selectedOpening: OpeningCategory? = nil
    /// 当前选中的子分类
    @State private var selectedSubcategory: OpeningSubcategory? = nil
    /// 当前选中的棋手
    @State private var selectedPlayer: MasterStatsFile.PlayerStat? = nil
    /// 当前选中的赛事
    @State private var selectedEvent: MasterStatsFile.EventStat? = nil

    /// 搜索状态
    @State private var searchText = ""
    @State private var searchResults: [MasterSearchResult] = []
    @State private var isSearchActive = false
    @State private var searchDebounceTask: Task<Void, Never>? = nil

    /// iOS 子分类列表状态
    @State private var showSubcategoryList = false
    @State private var subcategoryParent: OpeningCategory? = nil

    /// 列表分页
    @State private var currentPage: Int = 1
    private let gamePageSize = 200
    private let categoryPageSize = 50

    /// 分类/棋手/赛事列表分段加载
    @State private var categoryDisplayCount: Int = 50

    /// 列表缓存
    @State private var cachedItems: [MasterGameDemoItem] = []
    @State private var cachedTotalCount: Int = 0

    /// 加载状态
    @State private var loadingGame = false
    @State private var loadError: String? = nil
    @State private var showLoadError = false
    @State private var showIncompleteWarning = false
    @State private var showMasterLoadError = false

    /// 统计不可用提示
    @State private var showStatsUnavailable = false

    /// Phase D: 开局探索联动——传入初始走法序列
    @State private var initialMoveSequence: [String] = []
    @State private var useMoveSequenceFilter: Bool = false

    private var hasMoreItems: Bool {
        cachedItems.count < cachedTotalCount
    }

    /// 搜索器（@State 避免每次重建）
    @State private var searcher: MasterGameSearch = MasterGameSearch(store: MasterGameStore.shared)

    /// 是否正在搜索（搜索框非空且有结果/正在输入）
    private var isSearching: Bool {
        isSearchActive && !searchText.isEmpty
    }

    var body: some View {
        if let vm = viewModel {
            #if os(iOS)
            iosPlayLayout(viewModel: vm)
            #else
            macosPlayLayout(viewModel: vm)
            #endif
        } else {
            browserLayout
        }
    }

    // Phase D: 支持从开局探索联动传入走法序列
    init(initialMoveSequence: [String] = []) {
        if !initialMoveSequence.isEmpty {
            _useMoveSequenceFilter = State(initialValue: true)
            _initialMoveSequence = State(initialValue: initialMoveSequence)
        }
    }

    // MARK: - 浏览布局

    private var browserLayout: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            browserTopBar
            if !isSearching && masterStore.isLoaded && browseMode == .opening {
                categoryFilterBar
            }
            Divider()
            listContent
        }
        .frame(minWidth: 600, minHeight: 700)
        .alert(L10n.shared.t("master.statsUnavailable"), isPresented: $showStatsUnavailable) {
            Button("OK") {}
        } message: {
            Text(L10n.shared.t("master.statsUnavailable"))
        }
        #else
        Group {
            if !masterStore.isLoaded {
                loadingView
            } else if browseMode == .opening && selectedOpening == nil && selectedSubcategory == nil && !showSubcategoryList {
                iosCategoryList
            } else if browseMode == .opening && showSubcategoryList {
                iosSubcategoryList
            } else if browseMode == .player && selectedPlayer == nil {
                iosPlayerList
            } else if browseMode == .event && selectedEvent == nil {
                iosEventList
            } else {
                VStack(spacing: 0) {
                    iosBackBar
                    listContent
                }
            }
        }
        .alert(L10n.shared.t("master.statsUnavailable"), isPresented: $showStatsUnavailable) {
            Button("OK") {}
        } message: {
            Text(L10n.shared.t("master.statsUnavailable"))
        }
        .sheet(isPresented: $isSearchActive) {
            iosSearchSheet
        }
        #endif
    }

    // MARK: - 模式 Picker

    private var modePicker: some View {
        Picker("", selection: $browseMode) {
            ForEach(MasterGameBrowseMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: browseMode) { _, newMode in
            useMoveSequenceFilter = false  // Phase D fix: 用户切换浏览模式时退出联动
            switchToMode(newMode)
        }
    }

    // MARK: - macOS 顶部工具栏

    #if os(macOS)
    /// modePicker + searchField 水平排列
    private var browserTopBar: some View {
        HStack(spacing: 8) {
            modePicker
                .frame(maxWidth: 240)
            searchField
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    /// 开局模式一级分类标签栏
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(OpeningCategories.categories.filter { opening in
                    opening.firstMove.isEmpty || masterStore.byOpening(opening.firstMove).count > 0
                }) { opening in
                    let isSelected = selectedOpening != nil && selectedOpening == opening
                    Button(action: {
                        if viewModel != nil { cleanupViewModel() }
                        selectedOpening = opening
                        selectedSubcategory = nil
                        selectedPlayer = nil
                        selectedEvent = nil
                        currentPage = 1
                        rebuildCache()
                    }) {
                        HStack(spacing: 4) {
                            Text(opening.name)
                                .font(.subheadline)
                            Text("\(masterStore.gameCount(for: opening))")
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
        .background(Color.secondary.opacity(0.05))
    }

    /// macOS 棋手列表（browserLayout 中显示）
    private var playerListContent: some View {
        Group {
            if let players = masterStore.stats?.players {
                let sorted = players.sorted { $0.count > $1.count }
                let visible = Array(sorted.prefix(categoryDisplayCount))
                List {
                    ForEach(visible, id: \.stableId) { player in
                        Button(action: {
                            selectedPlayer = player
                            selectedOpening = nil
                            selectedSubcategory = nil
                            selectedEvent = nil
                            currentPage = 1
                            rebuildCache()
                        }) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(player.localizedName)
                                    .font(.body)
                                Spacer()
                                Text("\(player.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if visible.count < sorted.count {
                        HStack {
                            Spacer()
                            Button(String(format: L10n.shared.t("master.loadMorePlayers"), visible.count, sorted.count)) {
                                categoryDisplayCount += categoryPageSize
                            }
                            .buttonStyle(.bordered)
                            .tint(.brown)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            } else {
                Text(L10n.shared.t("master.statsUnavailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// macOS 赛事列表（browserLayout 中显示）
    private var eventListContent: some View {
        Group {
            if let events = masterStore.stats?.events {
                let sorted = events.sorted { $0.count > $1.count }
                let visible = Array(sorted.prefix(categoryDisplayCount))
                List {
                    ForEach(visible, id: \.stableId) { event in
                        Button(action: {
                            selectedEvent = event
                            selectedOpening = nil
                            selectedSubcategory = nil
                            selectedPlayer = nil
                            currentPage = 1
                            rebuildCache()
                        }) {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(event.localizedName)
                                    .font(.body)
                                if let year = event.year {
                                    Text("\(year)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Text("\(event.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if visible.count < sorted.count {
                        HStack {
                            Spacer()
                            Button(String(format: L10n.shared.t("master.loadMoreEvents"), visible.count, sorted.count)) {
                                categoryDisplayCount += categoryPageSize
                            }
                            .buttonStyle(.bordered)
                            .tint(.brown)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            } else {
                Text(L10n.shared.t("master.statsUnavailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// macOS 搜索结果列表（browserLayout 中显示）
    private var searchResultListContent: some View {
        List {
            if searchResults.isEmpty {
                Text(L10n.shared.t("master.search.noResult"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(searchResults) { result in
                    Button(action: { selectSearchResult(result) }) {
                        HStack {
                            Image(systemName: resultIcon(result))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.displayName)
                                    .font(.body)
                                if let sub = result.subtitle {
                                    Text(sub)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(result.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 搜索 UI 组件

    /// macOS/iOS 共用搜索框
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(L10n.shared.t("master.search.placeholder"), text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .onChange(of: searchText) { _, newValue in
                    debounceSearch(query: newValue)
                }
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchResults = []
                    isSearchActive = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(6)
    }
    #endif

    // MARK: - iOS 搜索 Sheet（独立块，不在 macOS sidebar 块内）
    #if os(iOS)
    private var iosSearchSheet: some View {
        NavigationStack {
            List {
                // 内联搜索框（searchField 在 macOS 块内定义，iOS 直接内联）
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(L10n.shared.t("master.search.placeholder"), text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .onChange(of: searchText) { _, newValue in
                            debounceSearch(query: newValue)
                        }
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                            isSearchActive = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(8)
                .listRowSeparator(.hidden)

                if !searchText.isEmpty {
                    if searchResults.isEmpty {
                        ContentUnavailableView(
                            L10n.shared.t("master.search.noResult"),
                            systemImage: "magnifyingglass"
                        )
                    } else {
                        ForEach(searchResults) { result in
                            Button(action: {
                                selectSearchResult(result)
                                searchText = ""
                                searchResults = []
                                isSearchActive = false
                            }) {
                                HStack {
                                    Image(systemName: resultIcon(result))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.displayName)
                                            .font(.body)
                                        if let sub = result.subtitle {
                                            Text(sub)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("\(result.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(L10n.shared.t("master.search.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.shared.t("common.cancel")) {
                        searchText = ""
                        searchResults = []
                        isSearchActive = false
                    }
                }
            }
        }
    }
    #endif

    private func resultIcon(_ result: MasterSearchResult) -> String {
        switch result {
        case .player: return "person.fill"
        case .event:  return "trophy.fill"
        }
    }

    // MARK: - 搜索逻辑

    /// 300ms 防抖搜索
    private func debounceSearch(query: String) {
        searchDebounceTask?.cancel()
        if query.isEmpty {
            searchResults = []
            isSearchActive = false
            return
        }
        isSearchActive = true
        searchDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            searchResults = searcher.search(query: query)
        }
    }

    /// 选中搜索结果 → 复用 B2 的 byPlayer()/byEvent() 过滤
    private func selectSearchResult(_ result: MasterSearchResult) {
        switch result {
        case .player(let player, _):
            selectedPlayer = player
            selectedOpening = nil
            selectedSubcategory = nil
            selectedEvent = nil
        case .event(let event, _):
            selectedEvent = event
            selectedOpening = nil
            selectedSubcategory = nil
            selectedPlayer = nil
        }
        // 清空搜索
        searchText = ""
        searchResults = []
        isSearchActive = false
        currentPage = 1
        rebuildCache()
    }

    // MARK: - iOS 分类列表

    #if os(iOS)
    private var iosCategoryList: some View {
        List {
            Section {
                modePicker
            }

            ForEach(OpeningCategories.categories.filter { opening in
                opening.firstMove.isEmpty || masterStore.byOpening(opening.firstMove).count > 0
            }) { opening in
                Button(action: {
                    if !opening.subcategories.isEmpty {
                        // 有子分类：进入子分类列表
                        subcategoryParent = opening
                        showSubcategoryList = true
                    } else {
                        // 无子分类：直接进入对局列表
                        selectedOpening = opening
                    }
                }) {
                    HStack {
                        Text(opening.name)
                            .font(.body)
                        Spacer()
                        Text("\(masterStore.gameCount(for: opening))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                        if !opening.subcategories.isEmpty {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.shared.t("study.masterGame"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { isSearchActive = true }) {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
    }

    private var iosPlayerList: some View {
        List {
            Section {
                modePicker
            }

            if let players = masterStore.stats?.players {
                let sorted = players.sorted { $0.count > $1.count }
                let visible = Array(sorted.prefix(categoryDisplayCount))
                ForEach(visible, id: \.stableId) { player in
                    Button(action: {
                        selectedPlayer = player
                    }) {
                        HStack {
                            Text(player.localizedName)
                                .font(.body)
                            Spacer()
                            Text("\(player.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if visible.count < sorted.count {
                    HStack {
                        Spacer()
                        Button(String(format: L10n.shared.t("master.loadMorePlayers"), visible.count, sorted.count)) {
                            categoryDisplayCount += categoryPageSize
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            } else {
                Text(L10n.shared.t("master.statsUnavailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.shared.t("study.masterGame"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { isSearchActive = true }) {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
    }

    private var iosEventList: some View {
        List {
            Section {
                modePicker
            }

            if let events = masterStore.stats?.events {
                let sorted = events.sorted { $0.count > $1.count }
                let visible = Array(sorted.prefix(categoryDisplayCount))
                ForEach(visible, id: \.stableId) { event in
                    Button(action: {
                        selectedEvent = event
                    }) {
                        HStack {
                            Text(event.localizedName)
                                .font(.body)
                            if let year = event.year {
                                Text("\(year)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text("\(event.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if visible.count < sorted.count {
                    HStack {
                        Spacer()
                        Button(String(format: L10n.shared.t("master.loadMoreEvents"), visible.count, sorted.count)) {
                            categoryDisplayCount += categoryPageSize
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            } else {
                Text(L10n.shared.t("master.statsUnavailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.shared.t("study.masterGame"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { isSearchActive = true }) {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
    }

    private var iosSubcategoryList: some View {
        List {
            // "全部"选项
            if let parent = subcategoryParent {
                Button(action: {
                    selectedOpening = parent
                    selectedSubcategory = nil
                    showSubcategoryList = false
                }) {
                    HStack {
                        Text(L10n.shared.t("master.mode.opening"))
                            .font(.body)
                        Text("— \(parent.name)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(masterStore.gameCount(for: parent))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ForEach(parent.subcategories) { sub in
                    Button(action: {
                        selectedSubcategory = sub
                        selectedOpening = nil
                        showSubcategoryList = false
                    }) {
                        HStack {
                            Text(sub.name)
                                .font(.body)
                            Spacer()
                            Text("\(masterStore.gameCount(for: sub))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(subcategoryParent?.name ?? "")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    showSubcategoryList = false
                    subcategoryParent = nil
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L10n.shared.t("study.masterGame"))
                    }
                }
            }
        }
    }

    private var iosBackBar: some View {
        Button(action: {
            switch browseMode {
            case .opening:
                if selectedSubcategory != nil {
                    showSubcategoryList = true
                    selectedSubcategory = nil
                } else if selectedOpening != nil && subcategoryParent != nil {
                    showSubcategoryList = true
                    selectedOpening = nil
                } else {
                    selectedOpening = nil
                    showSubcategoryList = false
                    subcategoryParent = nil
                }
            case .player:  selectedPlayer = nil
            case .event:   selectedEvent = nil
            }
            cachedItems = []
            cachedTotalCount = 0
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                backBarTitle
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

    private var backBarTitle: some View {
        switch browseMode {
        case .opening:
            if selectedSubcategory != nil {
                return Text(subcategoryParent?.name ?? L10n.shared.t("master.mode.opening"))
            } else {
                return Text(L10n.shared.t("master.mode.opening"))
            }
        case .player:  return Text(L10n.shared.t("master.mode.player"))
        case .event:   return Text(L10n.shared.t("master.mode.event"))
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(L10n.shared.t("study.masterGame"))
                .font(.title3)
                .foregroundStyle(.secondary)

            Button(action: loadIndex) {
                if isLoadingIndex {
                    ProgressView()
                } else {
                    Label(L10n.shared.t("demo.loadMasterIndex"), systemImage: "arrow.down.circle")
                }
            }
            .buttonStyle(.bordered)
            .tint(.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(L10n.shared.t("study.masterGame"))
    }
    #endif

    // MARK: - 列表内容

    /// 开局子分类过滤栏（macOS，显示在 gameListContent 顶部）
    #if os(macOS)
    private func subcategoryFilterBar(_ opening: OpeningCategory) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // "全部"选项
                Button(action: {
                    selectedSubcategory = nil
                    currentPage = 1
                    rebuildCache()
                }) {
                    Text(L10n.shared.t("puzzle.all"))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(selectedSubcategory == nil ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
                        )
                        .foregroundColor(selectedSubcategory == nil ? .accentColor : .primary)
                }
                .buttonStyle(.plain)

                ForEach(opening.subcategories) { sub in
                    let isSelected = selectedSubcategory == sub
                    Button(action: {
                        selectedSubcategory = sub
                        currentPage = 1
                        rebuildCache()
                    }) {
                        HStack(spacing: 3) {
                            Text(sub.name)
                                .font(.caption)
                            Text("\(masterStore.gameCount(for: sub))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
                        )
                        .foregroundColor(isSelected ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .background(Color.secondary.opacity(0.05))
    }
    #endif

    /// 对局列表（选中分类/棋手/赛事后显示）
    private var gameListContent: some View {
        Group {
            // 开局模式：有子分类时显示子分类过滤栏
            #if os(macOS)
            if browseMode == .opening, let opening = selectedOpening, !opening.subcategories.isEmpty {
                subcategoryFilterBar(opening)
            }
            #endif

            if cachedItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(L10n.shared.t("master.noData"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(cachedItems) { item in
                        Button(action: { playGame(item) }) {
                            masterGameRow(item)
                        }
                        .buttonStyle(.plain)
                    }

                    if hasMoreItems {
                        HStack {
                            Spacer()
                            Button(String(format: L10n.shared.t("demo.loadMore"), cachedItems.count, cachedTotalCount)) {
                                currentPage += 1
                                rebuildCache()
                            }
                            .buttonStyle(.bordered)
                            .tint(.brown)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                }
                .overlay {
                    if loadingGame { ProgressView() }
                }
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
    }

    private var listContent: some View {
        Group {
            #if os(macOS)
            // 搜索模式
            if isSearching {
                searchResultListContent
            } else if masterStore.isLoaded {
                switch browseMode {
                case .opening:
                    // 开局模式：选中分类后显示对局列表
                    if selectedOpening == nil && selectedSubcategory == nil {
                        // 未选分类 → 提示选择
                        VStack(spacing: 12) {
                            Image(systemName: "rectangle.grid.2x2")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text(L10n.shared.t("demo.selectCategory"))
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        gameListContent
                    }
                case .player:
                    // 棋手模式：未选棋手 → 显示棋手列表；已选 → 显示对局
                    if selectedPlayer == nil {
                        playerListContent
                    } else {
                        gameListContent
                    }
                case .event:
                    // 赛事模式
                    if selectedEvent == nil {
                        eventListContent
                    } else {
                        gameListContent
                    }
                }
            } else {
                // 未加载索引
                VStack(spacing: 12) {
                    Image(systemName: "crown")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(L10n.shared.t("demo.selectCategory"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Button(action: loadIndex) {
                        if isLoadingIndex {
                            ProgressView()
                        } else {
                            Label(L10n.shared.t("demo.loadMasterIndex"), systemImage: "arrow.down.circle")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #else
            if !masterStore.isLoaded {
                VStack(spacing: 12) {
                    Image(systemName: "crown")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(L10n.shared.t("demo.selectCategory"))
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    #if os(macOS)
                    Button(action: loadIndex) {
                        if isLoadingIndex {
                            ProgressView()
                        } else {
                            Label(L10n.shared.t("demo.loadMasterIndex"), systemImage: "arrow.down.circle")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                    .padding(.top, 8)
                    #endif
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if cachedItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(L10n.shared.t("master.noData"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(cachedItems) { item in
                        Button(action: { playGame(item) }) {
                            masterGameRow(item)
                        }
                        .buttonStyle(.plain)
                    }

                    if hasMoreItems {
                        HStack {
                            Spacer()
                            Button(String(format: L10n.shared.t("demo.loadMore"), cachedItems.count, cachedTotalCount)) {
                                currentPage += 1
                                rebuildCache()
                            }
                            .buttonStyle(.bordered)
                            .tint(.brown)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                }
                .overlay {
                    if loadingGame { ProgressView() }
                }
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
            #endif
        }
        .alert(L10n.shared.t("demo.loadError"), isPresented: $showMasterLoadError) {
            Button("OK") {}
        } message: {
            Text(masterStore.loadError ?? "")
        }
        .onChange(of: selectedOpening) { _, _ in
            useMoveSequenceFilter = false  // Phase D fix: 退出联动
            currentPage = 1
            rebuildCache()
        }
        .onChange(of: selectedSubcategory) { _, _ in
            useMoveSequenceFilter = false  // Phase D fix: 退出联动
            currentPage = 1
            rebuildCache()
        }
        .onChange(of: selectedPlayer) { _, _ in
            currentPage = 1
            rebuildCache()
        }
        .onChange(of: selectedEvent) { _, _ in
            currentPage = 1
            rebuildCache()
        }
        .onAppear {
            if !masterStore.isLoaded {
                loadIndex()
            } else if useMoveSequenceFilter {
                rebuildCache()
            } else if selectedEvent != nil || selectedPlayer != nil || selectedOpening != nil || selectedSubcategory != nil {
                // iOS: listContent 首次挂载时 onChange 已错过，需手动 rebuild
                rebuildCache()
            }
        }
    }

    // MARK: - 列表行

    @ViewBuilder
    private func masterGameRow(_ item: MasterGameDemoItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.index.localizedRedName) vs \(item.index.localizedBlackName)")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let year = item.index.year {
                        Text("\(year)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(item.index.localizedEvent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(String(format: L10n.shared.t("demo.moveCount"), item.index.moveCount))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    // MARK: - 缓存重建

    private func rebuildCache() {
        // Phase D: 走法序列过滤（从开局探索联动）
        if useMoveSequenceFilter && !initialMoveSequence.isEmpty {
            let indices = masterStore.games(matchingFirstMoves: initialMoveSequence)
            cachedTotalCount = indices.count
            let page = indices.prefix(gamePageSize * currentPage)
            cachedItems = page.map { MasterGameDemoItem(index: $0, fen: nil) }
            return
        }

        let indices: [MasterGameIndex]
        if let sub = selectedSubcategory {
            indices = masterStore.bySubcategory(sub.id)
        } else if let opening = selectedOpening {
            indices = masterStore.byOpening(opening.firstMove)
        } else {
            switch browseMode {
            case .opening:
                cachedItems = []
                cachedTotalCount = 0
                return
            case .player:
                guard let player = selectedPlayer else {
                    cachedItems = []
                    cachedTotalCount = 0
                    return
                }
                indices = masterStore.byPlayer(player.name)
            case .event:
                guard let event = selectedEvent else {
                    cachedItems = []
                    cachedTotalCount = 0
                    return
                }
                indices = masterStore.byEvent(event.name)
            }
        }
        cachedTotalCount = indices.count
        let page = indices.prefix(gamePageSize * currentPage)
        cachedItems = page.map { MasterGameDemoItem(index: $0, fen: nil) }
    }

    // MARK: - 模式切换

    private func switchToMode(_ mode: MasterGameBrowseMode) {
        // 清空所有选中状态
        selectedOpening = nil
        selectedSubcategory = nil
        selectedPlayer = nil
        selectedEvent = nil
        showSubcategoryList = false
        subcategoryParent = nil
        cachedItems = []
        cachedTotalCount = 0
        currentPage = 1
        categoryDisplayCount = categoryPageSize

        // 统计不可用时回退到开局模式
        if mode != .opening && masterStore.stats == nil {
            browseMode = .opening
            showStatsUnavailable = true
        }
    }

    // MARK: - 播放对局

    private func playGame(_ item: MasterGameDemoItem) {
        // P0-4: 连播替换 ViewModel 前安全清理旧对象
        cleanupViewModel()

        loadingGame = true
        loadError = nil
        Task.detached {
            let result = MasterGameLoader.loadGame(item.index)
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
                    let updatedItem = MasterGameDemoItem(index: item.index, fen: fen)
                    let wrapper = DemoItemWrapper.masterGame(updatedItem)
                    let newVM = DemoViewModel(item: wrapper, moves: convertResult.moves)
                    newVM.onAutoAdvanceHandler = {
                        self.loadNextGame(after: item)
                    }
                    viewModel = newVM

                    if !convertResult.isComplete {
                        showIncompleteWarning = true
                    }
                }
            }
        }
    }

    /// 加载下一局大师对局
    private func loadNextGame(after current: MasterGameDemoItem) {
        if let currentIndex = cachedItems.firstIndex(where: { $0.index.id == current.index.id }),
           currentIndex + 1 < cachedItems.count {
            playGame(cachedItems[currentIndex + 1])
        } else if !cachedItems.isEmpty {
            playGame(cachedItems[0])  // 循环回第一局
        }
    }

    // MARK: - 加载索引

    private func loadIndex() {
        guard !isLoadingIndex else { return }
        isLoadingIndex = true
        Task {
            await masterStore.loadIfNeeded()
            await MainActor.run {
                isLoadingIndex = false
                if masterStore.loadError != nil {
                    showMasterLoadError = true
                } else if useMoveSequenceFilter {
                    rebuildCache()
                }
            }
        }
    }

    // MARK: - 播放布局

    #if os(macOS)
    private func macosPlayLayout(viewModel vm: DemoViewModel) -> some View {
        // v6.2 左右布局（v1.2 §三.1）：棋盘左（等比缩放）+ 右侧信息面板
        // 点评从底部 overlay 改右侧常驻（P1-3），走法记录面板本页新增（P1-2）
        ManagedSplitView {
            ZStack {
                DemoBoardView(board: vm.board, lastMove: vm.lastMove, isFlipped: vm.item.shouldFlipBoard)

                // FINAL-010: 补齐与 iOS 一致的过渡 loading overlay
                if vm.playState == .transitioning {
                    Color.black.opacity(0.3)
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
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
        // v1.2 §三.2：左右布局需 min 800（左 400 + 右 300 + handle 8）；高度 750→600
        .frame(minWidth: 800, minHeight: 600)
    }
    #endif

    private func iosPlayLayout(viewModel vm: DemoViewModel) -> some View {
        VStack(spacing: 0) {
            playContent(viewModel: vm)
        }
    }

    @ViewBuilder
    private func playContent(viewModel: DemoViewModel) -> some View {
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
        // ⌘→ 下一局
        .background {
            Button("") { loadNextGameShortcut() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            Button("") { loadPrevGameShortcut() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
        }
        #endif
    }

    // MARK: - 连播快捷键

    private func loadNextGameShortcut() {
        guard let vm = viewModel else { return }
        // 从 viewModel 的 masterGame item 中获取 index id
        guard case .masterGame(let currentItem) = vm.item else { return }
        if let currentIndex = cachedItems.firstIndex(where: { $0.index.id == currentItem.index.id }),
           currentIndex + 1 < cachedItems.count {
            playGame(cachedItems[currentIndex + 1])
        } else if !cachedItems.isEmpty {
            playGame(cachedItems[0])
        }
    }

    private func loadPrevGameShortcut() {
        guard let vm = viewModel else { return }
        guard case .masterGame(let currentItem) = vm.item else { return }
        if let currentIndex = cachedItems.firstIndex(where: { $0.index.id == currentItem.index.id }),
           currentIndex > 0 {
            playGame(cachedItems[currentIndex - 1])
        } else if !cachedItems.isEmpty {
            playGame(cachedItems[cachedItems.count - 1])
        }
    }

    /// 安全清理旧 ViewModel（P0-4: 防止回调竞态）
    private func cleanupViewModel() {
        guard let vm = viewModel else { return }
        vm.pause()                       // 停止播放 + 取消 autoPlayTask
        vm.resultDisplayTimer?.cancel()   // 取消结果展示定时器
        vm.onAutoAdvanceHandler = nil     // 断开回调，防止旧对象触发
    }

    // MARK: - 返回列表

    private func backToList() {
        cleanupViewModel()
        viewModel = nil
        rebuildCache()
    }
}
