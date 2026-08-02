import SwiftUI

// MARK: - v5.0 开局树探索 UI（懒展开 + PositionSnapshot + 搜索）

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

    @Environment(\.dismiss) private var dismiss

    private let l10n = L10n.shared
    private let profile = PlayerProfileStore.shared.profile

    // 段位门禁：秀才以上
    private var hasAccess: Bool {
        profile.rank >= .scholar
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if !hasAccess {
                lockedView
            } else {
                // 搜索栏
                searchBar

                // 搜索结果或开局名称标注栏
                if isSearching && !searchResults.isEmpty {
                    searchResultsList
                } else {
                    openingNameBar
                }

                #if os(iOS)
                // v5.5.1 fix 问题3: iOS 改上下布局，棋盘获得更多空间
                VStack(spacing: 0) {
                    treeList
                        .frame(maxHeight: 280)
                    Divider()
                    boardPreview
                }
                #else
                HStack(spacing: 0) {
                    // 左侧：开局树列表
                    treeList

                    // 右侧：棋盘预览
                    boardPreview
                }
                #endif
            }
        }
        .background(Color(red: 44/255, green: 24/255, blue: 16/255))
        .task {
            // 首次加载根节点
            if rootNodes.isEmpty {
                rootNodes = OpeningExplorerService.shared.rootMoves()
            }
        }
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

    // MARK: - 标题栏

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

    // MARK: - 搜索栏（Phase 3）

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundColor(.gray)

            TextField(l10n.t("opening.explorer.search.placeholder"), text: $searchText)
                .font(.caption)
                .foregroundColor(.white)
                .disableAutocorrection(true)
                .onSubmit { performSearch() }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                    isSearching = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Button(l10n.t("opening.explorer.search")) { performSearch() }
                .font(.caption)
                .foregroundColor(.orange)
                .disabled(searchText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(red: 36/255, green: 18/255, blue: 12/255))
    }

    // MARK: - 搜索结果列表（Phase 3）

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(searchResults) { result in
                    Button {
                        jumpToSearchResult(result)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: result.iconName)
                                .font(.caption2)
                                .foregroundColor(result.iconColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white)

                                if let subtitle = result.subtitle {
                                    Text(subtitle)
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                }
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .frame(maxHeight: 200)
        .background(Color(red: 38/255, green: 20/255, blue: 14/255))
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
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(name)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                )
                .padding(.vertical, 4)
            } else if let node = selectedNode {
                // 无匹配时 fallback 显示走法名
                HStack(spacing: 4) {
                    Image(systemName: "bookmark")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(node.moveName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 40/255, green: 22/255, blue: 14/255))
    }

    // MARK: - 锁定

    private var lockedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text(String(format: l10n.t("opening.explorer.unlock"), l10n.t("rank.scholar")))
                .foregroundColor(.gray)

            Button(l10n.t("common.close")) { dismiss() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 开局树列表

    private var treeList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
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
            .padding(8)
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 38/255, green: 20/255, blue: 14/255))
    }

    // MARK: - 棋盘预览

    private var boardPreview: some View {
        VStack(spacing: 8) {
            Text(l10n.t("opening.explorer.preview"))
                .font(.caption)
                .foregroundColor(.gray)

            // 棋盘渲染（从当前 board 状态渲染）
            OpeningBoardPreview(board: board)
                .cornerRadius(6)

            // 走法路径
            if !moveHistory.isEmpty {
                Text(moveHistory.joined(separator: " → "))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            // Phase D: 查看相关大师对局
            if !currentMoveSequence.isEmpty {
                Button(action: { showRelatedGames = true }) {
                    Label(l10n.t("opening.relatedGames"), systemImage: "crown.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(red: 30/255, green: 16/255, blue: 10/255))
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

// MARK: - 开局树节点行（v5.0：适配 OpeningExplorerNode）

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
                // 缩进
                if depth > 0 {
                    Spacer().frame(width: CGFloat(depth) * 16)
                }

                // 展开/折叠图标
                if !node.isLeaf {
                    Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                        .onTapGesture { onToggle() }
                }

                // 走法名
                Text(node.moveName)
                    .font(.caption.weight(depth == 0 ? .semibold : .regular))
                    .foregroundColor(isSelected ? .orange : (depth == 0 ? .white : .white.opacity(0.8)))

                // 权重数值
                if node.weight > 0 {
                    Text("w:\(node.weight)")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelectNode(node) }
            .padding(.vertical, 4)
            .padding(.leading, 4)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isSelected ? Color.orange.opacity(0.15) : Color.clear)
            )

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
