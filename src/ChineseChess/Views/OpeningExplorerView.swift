import SwiftUI

// MARK: - v5.0 开局树探索 UI（懒展开 + PositionSnapshot + 搜索）
// v6.4 C4a：macOS 按 all14 原型 V15 重排——棋树固定窄栏 320 + 棋盘吃满余量 + 右侧统计栏 240；
// 窄窗口径（all14 narrow 注记）：<1080 收统计栏（迟滞 1080/1120）、<900 棋树折叠为顶部下拉（迟滞 900/940）。
// 数据诚信口径：开局库仅含 weight（出现局数），无胜率字段——节点徽章与统计栏展示真实局数，
// 不按原型"红 41%"造假胜率（偏差回传 Luke 知悉）。
// iOS 分支本期不动（v6.4 平台口径：iOS 零投入）。

struct OpeningExplorerView: View {
    @State private var rootNodes: [OpeningExplorerNode] = []
    @State private var selectedNode: OpeningExplorerNode?
    @State private var board = Board(fen: FENParser.standardInitial)
    @State private var moveHistory: [String] = []

    // Phase D: 搜索状态
    @State private var searchText: String = ""
    @State private var searchResults: [OpeningSearchResultItem] = []
    @State private var isSearching: Bool = false
    @State private var showRelatedGames: Bool = false

    // v6.4 C4a：窄窗收展双迟滞（C0 状态机，阈值 LayoutSpec 单源）
    @State private var statsRail = AdaptiveRailState(
        initiallyExpanded: true,
        collapseBelow: LayoutSpec.p8StatsCollapseBelow,
        expandAbove: LayoutSpec.p8StatsExpandAbove)
    @State private var treeRail = AdaptiveRailState(
        initiallyExpanded: true,
        collapseBelow: LayoutSpec.p8TreeCollapseBelow,
        expandAbove: LayoutSpec.p8TreeExpandAbove)

    @Environment(\.dismiss) private var dismiss

    private let l10n = L10n.shared
    private let profile = PlayerProfileStore.shared.profile

    // 段位门禁：秀才以上（v5.5.9: 走 isFeatureUnlocked 使 DeveloperMode 生效）
    private var hasAccess: Bool {
        profile.isFeatureUnlocked(.openingTreeBrowse)
    }

    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            headerBar
            #else
            toolbarRow   // v6.4 C4a：all14 V15 工具行（返回/回起始/后退/搜索）
            #endif

            if !hasAccess {
                lockedView
            } else {
                // 搜索结果或开局名称标注栏（既有交互保留，v6.4 token 化样式）
                if isSearching && !searchResults.isEmpty {
                    searchResultsList
                } else {
                    openingNameBar
                }

                #if os(iOS)
                // v5.5.1 fix 问题3: iOS 改上下布局，棋盘获得更多空间（本期不动）
                VStack(spacing: 0) {
                    treeList
                        .frame(maxHeight: 280)
                    Divider()
                    boardPreview
                }
                #else
                // v6.4 C4a：<900 棋树折叠为顶部下拉（all14 narrow 条款）
                if !treeRail.isExpanded {
                    treePicker
                }

                HStack(spacing: LayoutSpec.space3) {
                    if treeRail.isExpanded {
                        treeList
                            .frame(width: LayoutSpec.p8TreeWidth)   // T1：固定窄栏 320 单源
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    // 棋盘吃满余量（T1）
                    boardPreview
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // 右侧统计栏（<1080 迟滞收起，T3）
                    if statsRail.isExpanded {
                        statsColumn
                            .frame(width: LayoutSpec.p8StatsWidth)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(LayoutSpec.space3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #endif
            }
        }
        .background(Color.controlBackground)
        .task {
            // 首次加载根节点
            if rootNodes.isEmpty {
                rootNodes = OpeningExplorerService.shared.rootMoves()
            }
        }
        // v6.4 C4a：页级宽度采样喂双迟滞 + LAYOUT_DUMP（C0 通道，参数名只增不改）
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { feed(width: geo.size.width) }
                    .onChange(of: geo.size.width) { _, w in feed(width: w) }
            }
        )
        .sheet(isPresented: $showRelatedGames) {
            NavigationStack {
                MasterGameBrowserView(initialMoveSequence: currentMoveSequence)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(l10n.t("common.done")) { showRelatedGames = false }
                        }
                    }
            }
        }
    }

    // v6.4 C4a：双迟滞喂入 + 页级 dump
    private func feed(width: CGFloat) {
        statsRail.update(width: width)
        treeRail.update(width: width)
        guard LayoutDump.isEnabled else { return }
        LayoutDump.sample(
            page: "P8", width: width,
            params: [
                "stats": statsRail.isExpanded ? "shown" : "hidden",
                "tree": treeRail.isExpanded ? "shown" : "hidden",
                "sel": selectedNode?.moveName ?? "—",
            ])
    }

    // MARK: - 标题栏（iOS 保留原样）

    #if os(iOS)
    private var headerBar: some View {
        ZStack {
            Text(l10n.t("opening.explorer.title"))
                .font(.callout.weight(.bold))
                .foregroundColor(.white)

            HStack {
                Button(l10n.t("common.close")) { dismiss() }
                    .foregroundColor(.white)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(red: 50/255, green: 30/255, blue: 20/255))
    }
    #endif

    // MARK: - 工具行（v6.4 C4a，all14 V15：返回学棋中心 | 回起始 | 后退 | 搜索）

    #if os(macOS)
    private var toolbarRow: some View {
        HStack(spacing: LayoutSpec.space2) {
            // 🔙 学棋中心（hot 主操作：dismiss 回宿主页）
            Button {
                dismiss()
            } label: {
                Label(l10n.t("opening.explorer.backToHub"), systemImage: "chevron.backward")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Divider().frame(height: 18)

            // ↺ 回起始（棋盘回初始局面，清选择）
            Button {
                resetToRoot()
            } label: {
                Label(l10n.t("opening.explorer.resetRoot"), systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(selectedNode == nil && moveHistory.isEmpty)

            // ⬅ 后退（选父节点）
            Button {
                stepBack()
            } label: {
                Label(l10n.t("opening.explorer.stepBack"), systemImage: "backward.frame")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(selectedNode == nil)  // P3-7：首层可回起始（stepBack 已处理 parent==nil→resetToRoot），仅未选中才禁用

            Spacer(minLength: LayoutSpec.space2)

            // 🔍 搜局面（原搜索逻辑保留，T5）
            HStack(spacing: LayoutSpec.space2) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: LayoutSpec.fontSizeCaption))
                    .foregroundStyle(.secondary)
                TextField(l10n.t("opening.explorer.search.placeholder"), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(width: 220)   // all14 .search flex-basis 220
                    .onSubmit { performSearch() }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                        isSearching = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: LayoutSpec.fontSizeCaption))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(l10n.t("common.clear"))
                }
                Button(l10n.t("opening.explorer.search")) { performSearch() }
                    .controlSize(.small)
                    .disabled(searchText.isEmpty)
            }
        }
        .padding(.horizontal, LayoutSpec.space3)
        .padding(.vertical, LayoutSpec.space2)
        .background(.bar)
    }
    #endif

    // MARK: - 窄窗棋树下拉（<900 折叠态，all14 narrow：棋树折叠为顶部下拉）

    #if os(macOS)
    private var treePicker: some View {
        HStack(spacing: LayoutSpec.space2) {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundStyle(.secondary)
            Menu(l10n.t("opening.explorer.treeMenu")) {
                Button(l10n.t("opening.explorer.rootPosition")) { resetToRoot() }
                Divider()
                ForEach(rootNodes) { node in
                    Menu(node.moveName) {
                        Button(l10n.t("common.select")) { selectNode(node) }
                        ForEach(node.children.prefix(6)) { child in
                            Button(child.moveName) { selectNode(child) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .controlSize(.small)
            if let node = selectedNode {
                Spacer()
                Text(node.moveName)
                    .font(.system(size: LayoutSpec.fontSizeCaption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(node.moveName)   // LJ-1 三件套
            }
        }
        .padding(.horizontal, LayoutSpec.space3)
        .padding(.vertical, LayoutSpec.space1)
        .background(.bar)
    }
    #endif

    // MARK: - 搜索结果列表（Phase 3 保留，样式 token 化）

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LayoutSpec.space1) {
                ForEach(searchResults) { result in
                    Button {
                        jumpToSearchResult(result)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: result.iconName)
                                .font(.system(size: LayoutSpec.fontSizeCaption))
                                .foregroundStyle(result.iconColor)  // P3-11：恢复结果类型语义色（moveSequence=蓝/openingName=橙）

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.system(size: LayoutSpec.fontSizeBody))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .help(result.title)   // LJ-1 三件套

                                if let subtitle = result.subtitle {
                                    Text(subtitle)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .help(subtitle)
                                }
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, LayoutSpec.space1)
                        .padding(.horizontal, LayoutSpec.space2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(LayoutSpec.space2)
        }
        .frame(maxHeight: 200)
    }

    // MARK: - 开局名称标注栏

    /// 当前选中节点的走法序列（ICCS 格式，从根到选中节点）
    private var currentMoveSequence: [String] {
        guard let node = selectedNode else { return [] }
        return node.pathFromRoot().map { $0.move }.filter { !$0.isEmpty }
    }

    /// 当前匹配到的开局名称
    private var currentOpeningName: String? {
        let seq = currentMoveSequence
        guard !seq.isEmpty else { return nil }
        return OpeningExplorerService.shared.matchOpeningName(moveSequence: seq)
    }

    private var openingNameBar: some View {
        Group {
            if let name = currentOpeningName {
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: LayoutSpec.fontSizeCaption))
                        .foregroundStyle(.orange)
                    Text(name)
                        .font(.system(size: LayoutSpec.fontSizeBody))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(name)   // LJ-1 三件套
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.05))
                )
                .padding(.vertical, 4)
            } else if let node = selectedNode {
                // 无匹配时 fallback 显示走法名
                HStack(spacing: 4) {
                    Image(systemName: "bookmark")
                        .font(.system(size: LayoutSpec.fontSizeCaption))
                        .foregroundStyle(.secondary)
                    Text(node.moveName)
                        .font(.system(size: LayoutSpec.fontSizeBody))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(node.moveName)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    // MARK: - 锁定

    private var lockedView: some View {
        // v6.2 P1-2: 空态统一 ContentUnavailableView（唯一带 action 场景，Eric）
        ContentUnavailableView {
            Label(String(format: l10n.t("opening.explorer.unlock"), l10n.t("rank.scholar")),
                  systemImage: "lock.circle")
        } actions: {
            Button(l10n.t("common.close")) { dismiss() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 开局树列表（v6.4 C4a：固定窄栏 + 行高压缩 + 局数徽章）

    private var treeList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                // 根行：起始局面（all14 .tn 首行）
                treeRootRow
                ForEach(rootNodes) { node in
                    ExplorerNodeRow(
                        node: node,
                        depth: 0,
                        isSelected: selectedNode?.id == node.id,
                        selectedNodeID: selectedNode?.id,
                        onSelectNode: { selectNode($0) },
                        onToggle: { node.isExpanded.toggle() }
                    )
                }
            }
            .padding(LayoutSpec.space2)
        }
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: LayoutSpec.panelCornerRadius)
                .fill(Color.controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LayoutSpec.panelCornerRadius)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: LayoutSpec.panelCornerRadius))
        .background(
            // 树实宽采样（验收锚：树宽=320 档）
            GeometryReader { geo in
                Color.clear
                    .onAppear { dumpTreeWidth(geo.size.width) }
                    .onChange(of: geo.size.width) { _, w in dumpTreeWidth(w) }
            }
        )
    }

    private func dumpTreeWidth(_ w: CGFloat) {
        guard LayoutDump.isEnabled else { return }
        LayoutDump.sample(page: "P8", width: w, params: ["part": "tree"])
    }

    private var treeRootRow: some View {
        let isRoot = selectedNode == nil
        return Button {
            resetToRoot()
        } label: {
            HStack(spacing: LayoutSpec.space2) {
                Text(l10n.t("opening.explorer.rootPosition"))
                    .font(.system(size: LayoutSpec.fontSizeCaption))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(l10n.t("opening.explorer.rootPosition"))
                Spacer(minLength: LayoutSpec.space1)
                Text("—")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, LayoutSpec.space2)
            .padding(.vertical, 3)   // T2：行高压缩 4→3
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isRoot ? AnyShapeStyle(Color.accentColor)
                   : AnyShapeStyle(Color.clear),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .foregroundStyle(isRoot ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
    }

    // MARK: - 棋盘预览（v6.4 C4a：吃满余量，路径/相关大师局保留）

    private var boardPreview: some View {
        VStack(spacing: LayoutSpec.space2) {
            OpeningBoardPreview(board: board)
                .cornerRadius(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, LayoutSpec.space1)

            // 走法路径
            if !moveHistory.isEmpty {
                Text(moveHistory.joined(separator: " → "))
                    .font(.system(size: LayoutSpec.fontSizeCaption))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, LayoutSpec.space2)
            }

            // Phase D: 查看相关大师对局（T5 保留）
            if !currentMoveSequence.isEmpty {
                Button(action: { showRelatedGames = true }) {
                    Label(l10n.t("opening.relatedGames"), systemImage: "crown.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(LayoutSpec.space2)
    }

    // MARK: - 右侧统计栏（v6.4 C4a：all14 V15 "当前局面"面板；数据诚信=真实局数）

    #if os(macOS)
    private var statsColumn: some View {
        VStack(spacing: LayoutSpec.space2) {
            // 面板头（all14 .panel-h 语言：色签+标题）
            HStack(spacing: LayoutSpec.space2) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: 14)
                Text(l10n.t("opening.explorer.stats.current"))
                    .font(.system(size: LayoutSpec.fontSizeBody))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, LayoutSpec.space2)
            .padding(.top, LayoutSpec.space2)

            Divider()

            VStack(alignment: .leading, spacing: LayoutSpec.space2) {
                statRow(l10n.t("opening.explorer.stats.move"),
                        selectedNode?.moveName ?? l10n.t("opening.explorer.rootPosition"))
                statRow(l10n.t("opening.explorer.stats.games"),
                        selectedNode.map { formatCount($0.weight) } ?? "—")
                if let reply = topReply {
                    statRow(l10n.t("opening.explorer.stats.reply"), reply)
                }
                if let name = currentOpeningName {
                    statRow(l10n.t("opening.explorer.stats.opening"), name)
                }
                Spacer(minLength: 0)
            }
            .padding(LayoutSpec.space2)
        }
        .background(
            RoundedRectangle(cornerRadius: LayoutSpec.panelCornerRadius)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LayoutSpec.panelCornerRadius)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: LayoutSpec.panelCornerRadius))
    }

    /// 常见应手：同层最高 weight 子着法 + 其层内占比（真实数据，非胜率）
    private var topReply: String? {
        let siblings: [OpeningExplorerNode]
        if let node = selectedNode {
            siblings = node.children
        } else {
            siblings = rootNodes
        }
        guard let top = siblings.max(by: { $0.weight < $1.weight }), top.weight > 0 else {
            return nil
        }
        let total = siblings.reduce(0) { $0 + $1.weight }
        let pct = total > 0 ? Int(Double(top.weight) / Double(total) * 100) : 0
        return "\(top.moveName) · \(pct)%"
    }

    @ViewBuilder
    private func statRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: LayoutSpec.fontSizeCaption))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: LayoutSpec.fontSizeBody))
                .lineLimit(1)
                .truncationMode(.tail)
                .help(value)   // LJ-1 三件套
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatCount(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
    #endif

    // MARK: - 走法操作（v6.4 C4a 工具行配套）

    private func resetToRoot() {
        board = Board(fen: FENParser.standardInitial)
        moveHistory = []
        selectedNode = nil
    }

    private func stepBack() {
        guard let node = selectedNode else { return }
        if let parent = node.parent {
            selectNode(parent)
        } else {
            resetToRoot()
        }
    }

    // MARK: - 选择节点（v5.0：用 PositionSnapshot + parent 回溯，无需 DFS）

    private func selectNode(_ node: OpeningExplorerNode) {
        // 从 snapshot 重建 Board
        board = Board(snapshot: node.snapshot)

        // P1 fix: 用 parent 指针回溯路径，O(depth)，不触发懒加载
        moveHistory = node.pathFromRoot().map { $0.moveName }

        selectedNode = node
    }

    // MARK: - 搜索逻辑（Phase 3）

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        var results: [OpeningSearchResultItem] = []

        // 1. 尝试走法序列搜索（输入看起来像 ICCS 走法）
        let looksLikeMoves = query.allSatisfy { char in
            (char.isASCII && (char.isLetter || char.isNumber)) || char == " " || char == ","
        }
        if looksLikeMoves {
            if let path = OpeningExplorerService.shared.searchByMoveSequence(query),
               let lastNode = path.last {
                let moveNames = path.map { $0.moveName }.joined(separator: " → ")
                let openingName = OpeningExplorerService.shared.matchOpeningName(
                    moveSequence: path.map { $0.move }
                )
                _ = lastNode  // lastNode 用于确认 path 非空，title/subtitle 已包含信息
                results.append(.moveSequence(
                    path: path,
                    title: openingName ?? moveNames,
                    subtitle: moveNames
                ))
            }
        }

        // 2. 开局名搜索
        let nameResults = OpeningExplorerService.shared.searchByOpeningName(query)
        for result in nameResults {
            // 每个变体作为一个搜索结果
            for variation in result.variations.prefix(3) {
                let moveNames = variation.map { move -> String in
                    // 简短显示走法
                    return move
                }.joined(separator: " ")
                results.append(.openingName(
                    name: result.name,
                    variation: variation,
                    title: result.name,
                    subtitle: moveNames
                ))
            }
        }

        searchResults = results
        isSearching = !results.isEmpty
    }

    /// 跳转到搜索结果
    private func jumpToSearchResult(_ result: OpeningSearchResultItem) {
        switch result {
        case .moveSequence(let path, _, _):
            // 走法序列：跳转到最后一个节点
            guard let lastNode = path.last else { return }
            selectNode(lastNode)
            isSearching = false
            searchResults = []
            searchText = ""

        case .openingName(_, let variation, _, _):
            // 开局名：构建节点路径并跳转
            if let path = OpeningExplorerService.shared.buildNodePath(forVariation: variation) {
                guard let lastNode = path.last else { return }
                selectNode(lastNode)
            }
            isSearching = false
            searchResults = []
            searchText = ""
        }
    }
}

// MARK: - 搜索结果项（Phase 3）

enum OpeningSearchResultItem: Identifiable {
    case moveSequence(path: [OpeningExplorerNode], title: String, subtitle: String?)
    case openingName(name: String, variation: [String], title: String, subtitle: String?)

    var id: String {
        switch self {
        case .moveSequence(let path, _, _):
            return "seq:" + path.map { $0.move }.joined(separator: ",")
        case .openingName(let name, let variation, _, _):
            return "name:\(name):\(variation.joined(separator: ","))"
        }
    }

    var title: String {
        switch self {
        case .moveSequence(_, let title, _): return title
        case .openingName(_, _, let title, _): return title
        }
    }

    var subtitle: String? {
        switch self {
        case .moveSequence(_, _, let sub): return sub
        case .openingName(_, _, _, let sub): return sub
        }
    }

    var iconName: String {
        switch self {
        case .moveSequence: return "arrow.triangle.branch"
        case .openingName: return "bookmark.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .moveSequence: return .blue
        case .openingName: return .orange
        }
    }
}

// MARK: - 开局预览棋盘（只读，复用 v4.1 修复）

struct OpeningBoardPreview: View {
    let board: Board
    var theme: ThemeColors = ThemeManager.shared.colors

    var body: some View {
        GeometryReader { geo in
            let sizing = BoardSizing.calculate(width: geo.size.width, height: geo.size.height)
            let cellSize = sizing.cellSize
            let padding = sizing.padding
            let boardWidth = sizing.boardWidth
            let boardHeight = sizing.boardHeight

            ZStack {
                // 棋盘背景
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: theme.boardBackground,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(4)

                // 棋盘线条
                Canvas { context, _ in
                    drawLines(context: &context, cellSize: cellSize, padding: padding)
                }

                // 楚河汉界
                let yRiver = padding + 4 * cellSize + cellSize / 2
                HStack(spacing: cellSize * 2) {
                    Text("楚  河")
                        .font(.custom(FontRegistry.bestAvailableFontName, size: cellSize * 0.4))
                    Text("汉  界")
                        .font(.custom(FontRegistry.bestAvailableFontName, size: cellSize * 0.4))
                }
                .foregroundColor(theme.riverTextColor)
                .position(x: boardWidth / 2, y: yRiver)

                // 棋子
                ForEach(board.pieces) { piece in
                    let col = piece.position.col
                    let row = piece.position.row
                    let x = padding + CGFloat(col) * cellSize
                    let y = padding + CGFloat(row) * cellSize
                    PieceView(piece: piece, isSelected: false, cellSize: cellSize, theme: theme)
                        .position(x: x, y: y)
                }
            }
            .frame(width: boardWidth, height: boardHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(CGFloat(BoardSizing.gridCols) / CGFloat(BoardSizing.gridRows), contentMode: .fit)
    }

    private func drawLines(context: inout GraphicsContext, cellSize: CGFloat, padding: CGFloat) {
        var path = Path()
        for row in 0...BoardSizing.gridRows {
            let y = padding + CGFloat(row) * cellSize
            path.move(to: CGPoint(x: padding, y: y))
            path.addLine(to: CGPoint(x: padding + CGFloat(BoardSizing.gridCols) * cellSize, y: y))
        }
        for col in [0, BoardSizing.gridCols] {
            let x = padding + CGFloat(col) * cellSize
            path.move(to: CGPoint(x: x, y: padding))
            path.addLine(to: CGPoint(x: x, y: padding + CGFloat(BoardSizing.gridRows) * cellSize))
        }
        let riverTop = padding + 4 * cellSize
        let riverBottom = padding + 5 * cellSize
        for col in 1..<BoardSizing.gridCols {
            let x = padding + CGFloat(col) * cellSize
            context.stroke(Path { p in
                p.move(to: CGPoint(x: x, y: padding))
                p.addLine(to: CGPoint(x: x, y: riverTop))
            }, with: .color(theme.lineColor), lineWidth: 1)
            context.stroke(Path { p in
                p.move(to: CGPoint(x: x, y: riverBottom))
                p.addLine(to: CGPoint(x: x, y: padding + CGFloat(BoardSizing.gridRows) * cellSize))
            }, with: .color(theme.lineColor), lineWidth: 1)
        }
        context.stroke(path, with: .color(theme.lineColor), lineWidth: 1)
    }
}

// MARK: - 开局树节点行（v5.0：适配 OpeningExplorerNode；v6.4 C4a 行高压缩+局数徽章）

struct ExplorerNodeRow: View {
    let node: OpeningExplorerNode
    let depth: Int
    var isSelected: Bool = false
    let onSelectNode: (OpeningExplorerNode) -> Void
    let onToggle: () -> Void

    private let selectedNodeID: UUID?

    init(node: OpeningExplorerNode, depth: Int, isSelected: Bool = false, selectedNodeID: UUID? = nil, onSelectNode: @escaping (OpeningExplorerNode) -> Void, onToggle: @escaping () -> Void) {
        self.node = node
        self.depth = depth
        self.isSelected = isSelected
        self.selectedNodeID = selectedNodeID
        self.onSelectNode = onSelectNode
        self.onToggle = onToggle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // 缩进（all14 .tn padding-left 14px/级）
                if depth > 0 {
                    Spacer().frame(width: CGFloat(depth) * 14)
                }

                // 展开/折叠图标
                if !node.isLeaf {
                    Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                        .onTapGesture { onToggle() }
                } else {
                    Color.clear.frame(width: 14, height: 14)
                }

                // 走法名（LJ-1 三件套）
                Text(node.moveName)
                    .font(.system(size: LayoutSpec.fontSizeCaption,
                                  weight: depth == 0 ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(node.moveName)

                Spacer(minLength: LayoutSpec.space1)

                // v6.4 C4a：局数徽章（真实数据；all14 .ev 位——原型为胜率，本机库无此字段，
                // 数据诚信口径展示出现局数，偏差已回传）
                if node.weight > 0 {
                    Text("\(node.weight)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(isSelected ? AnyShapeStyle(Color.white.opacity(0.75))
                                                    : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelectNode(node) }
            .padding(.vertical, 3)      // T2：行高压缩 4→3
            .padding(.leading, LayoutSpec.space1)
            .padding(.trailing, LayoutSpec.space2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.9) : Color.clear)
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)

            // 子节点（P1 fix: 透传 selectedNodeID）
            if node.isExpanded {
                ForEach(node.children) { child in
                    ExplorerNodeRow(
                        node: child,
                        depth: depth + 1,
                        isSelected: selectedNodeID == child.id,
                        selectedNodeID: selectedNodeID,
                        onSelectNode: onSelectNode,
                        onToggle: { child.isExpanded.toggle() }
                    )
                }
            }
        }
    }
}
