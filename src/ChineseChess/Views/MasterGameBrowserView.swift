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
/// macOS：sidebar（按开局/棋手/赛事分类）+ 列表 + 棋谱播放
/// iOS：全屏列表 → 棋谱播放
struct MasterGameBrowserView: View {
    @State private var viewModel: DemoViewModel?
    @Environment(\.dismiss) private var dismiss

    @State private var masterStore = MasterGameStore.shared
    @State private var isLoadingIndex = false

    /// 浏览模式
    @State private var browseMode: MasterGameBrowseMode = .opening

    /// macOS sidebar 统一选中
    @State private var sidebarSelection: SidebarSelection? = nil

    /// 当前选中的开局分类
    @State private var selectedOpening: OpeningCategory? = nil
    /// 当前选中的子分类
    @State private var selectedSubcategory: OpeningSubcategory? = nil
    /// 当前选中的棋手
    @State private var selectedPlayer: MasterStatsFile.PlayerStat? = nil
    /// 当前选中的赛事
    @State private var selectedEvent: MasterStatsFile.EventStat? = nil

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

    private var hasMoreItems: Bool {
        cachedItems.count < cachedTotalCount
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

    // MARK: - 浏览布局

    private var browserLayout: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            sidebar
                .frame(width: 200)
            Divider()
            listContent
        }
        .frame(minWidth: 720, minHeight: 520)
        .alert(L10n.shared.t("master.statsUnavailable"), isPresented: $showStatsUnavailable) {
            Button("OK") {}
        } message: {
            Text(L10n.shared.t("master.statsUnavailable"))
        }
        #else
        Group {
            if !masterStore.isLoaded {
                loadingView
            } else if browseMode == .opening && selectedOpening == nil && !showSubcategoryList {
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
            switchToMode(newMode)
        }
    }

    // MARK: - macOS Sidebar

    #if os(macOS)
    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            Section {
                modePicker
                    .listRowSeparator(.hidden)
            }

            if masterStore.isLoaded {
                switch browseMode {
                case .opening:
                    openingSidebarContent
                case .player:
                    playerSidebarContent
                case .event:
                    eventSidebarContent
                }
            } else {
                Section(L10n.shared.t("demo.sectionMasterGames")) {
                    Button(action: loadIndex) {
                        HStack {
                            if isLoadingIndex {
                                ProgressView().scaleEffect(0.7)
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
        .onChange(of: sidebarSelection) { _, newSelection in
            guard let sel = newSelection else { return }
            currentPage = 1
            switch sel {
            case .opening(let opening):
                selectedOpening = opening
                selectedSubcategory = nil
                selectedPlayer = nil
                selectedEvent = nil
            case .subcategory(let sub):
                selectedSubcategory = sub
                selectedOpening = nil
                selectedPlayer = nil
                selectedEvent = nil
            case .player(let player):
                selectedPlayer = player
                selectedOpening = nil
                selectedEvent = nil
            case .event(let event):
                selectedEvent = event
                selectedOpening = nil
                selectedPlayer = nil
            }
            rebuildCache()
        }
    }

    private var openingSidebarContent: some View {
        Section(L10n.shared.t("demo.sectionMasterGames")) {
            ForEach(OpeningCategories.categories.filter { opening in
                opening.firstMove.isEmpty || masterStore.byOpening(opening.firstMove).count > 0
            }) { opening in
                if opening.subcategories.isEmpty {
                    // 无子分类：直接选择
                    HStack {
                        Text(opening.name)
                            .font(.subheadline)
                        Spacer()
                        countBadge(masterStore.gameCount(for: opening))
                    }
                    .tag(SidebarSelection.opening(opening))
                } else {
                    // 有子分类：DisclosureGroup 展开
                    DisclosureGroup {
                        ForEach(opening.subcategories) { sub in
                            HStack {
                                Text(sub.name)
                                    .font(.subheadline)
                                Spacer()
                                countBadge(masterStore.gameCount(for: sub))
                            }
                            .tag(SidebarSelection.subcategory(sub))
                        }
                    } label: {
                        HStack {
                            Text(opening.name)
                                .font(.subheadline)
                            Spacer()
                            countBadge(masterStore.gameCount(for: opening))
                        }
                        .tag(SidebarSelection.opening(opening))
                    }
                }
            }
        }
    }

    private var playerSidebarContent: some View {
        Section(L10n.shared.t("master.mode.player")) {
            if let players = masterStore.stats?.players {
                let sorted = players.sorted { $0.count > $1.count }
                let visible = Array(sorted.prefix(categoryDisplayCount))
                ForEach(visible, id: \.stableId) { player in
                    HStack {
                        Text(player.nameCN)
                            .font(.subheadline)
                        Spacer()
                        countBadge(player.count)
                    }
                    .tag(SidebarSelection.player(player))
                }
                if visible.count < sorted.count {
                    HStack {
                        Spacer()
                        Button(String(format: L10n.shared.t("master.loadMorePlayers"), visible.count, sorted.count)) {
                            categoryDisplayCount += categoryPageSize
                        }
                        .font(.caption)
                        Spacer()
                    }
                }
            } else {
                Text(L10n.shared.t("master.statsUnavailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var eventSidebarContent: some View {
        Section(L10n.shared.t("master.mode.event")) {
            if let events = masterStore.stats?.events {
                let sorted = events.sorted { $0.count > $1.count }
                let visible = Array(sorted.prefix(categoryDisplayCount))
                ForEach(visible, id: \.stableId) { event in
                    HStack {
                        Text(event.nameCN)
                            .font(.subheadline)
                        if let year = event.year {
                            Text("\(year)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        countBadge(event.count)
                    }
                    .tag(SidebarSelection.event(event))
                }
                if visible.count < sorted.count {
                    HStack {
                        Spacer()
                        Button(String(format: L10n.shared.t("master.loadMoreEvents"), visible.count, sorted.count)) {
                            categoryDisplayCount += categoryPageSize
                        }
                        .font(.caption)
                        Spacer()
                    }
                }
            } else {
                Text(L10n.shared.t("master.statsUnavailable"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func countBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
    }
    #endif

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
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.shared.t("study.masterGame"))
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
                            Text(player.nameCN)
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
                            Text(event.nameCN)
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

    private var listContent: some View {
        Group {
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
                    Text(L10n.shared.t("demo.noData"))
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
        .alert(L10n.shared.t("demo.loadError"), isPresented: $showMasterLoadError) {
            Button("OK") {}
        } message: {
            Text(masterStore.loadError ?? "")
        }
        .onChange(of: selectedOpening) { _, _ in
            currentPage = 1
            rebuildCache()
        }
        .onChange(of: selectedSubcategory) { _, _ in
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
            if !masterStore.isLoaded { loadIndex() }
        }
    }

    // MARK: - 列表行

    @ViewBuilder
    private func masterGameRow(_ item: MasterGameDemoItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.index.redNameCN) vs \(item.index.blackNameCN)")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let year = item.index.year {
                        Text("\(year)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(item.index.event)
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
    }

    // MARK: - 缓存重建

    private func rebuildCache() {
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
        sidebarSelection = nil
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
                    viewModel = DemoViewModel(item: wrapper, moves: convertResult.moves)

                    if !convertResult.isComplete {
                        showIncompleteWarning = true
                    }
                }
            }
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
                }
            }
        }
    }

    // MARK: - 播放布局

    #if os(macOS)
    private func macosPlayLayout(viewModel vm: DemoViewModel) -> some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 200)
            Divider()
            playContent(viewModel: vm)
        }
        .frame(minWidth: 720, minHeight: 520)
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
            DemoInfoBar(item: viewModel.item, viewModel: viewModel)

            ZStack(alignment: .top) {
                DemoBoardView(board: viewModel.board, lastMove: viewModel.lastMove, isFlipped: viewModel.item.shouldFlipBoard)
                if let commentary = viewModel.currentCommentary {
                    CommentaryOverlay(commentary: commentary, speed: viewModel.speed)
                        .padding(.top, 8)
                }
            }

            DemoControlBar(viewModel: viewModel, onBackToList: { backToList() })
        }
    }

    // MARK: - 返回列表

    private func backToList() {
        viewModel?.pause()
        viewModel = nil
        rebuildCache()
    }
}
