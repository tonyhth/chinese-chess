import SwiftUI

// MARK: - v3.6.0 Phase 4: 开局树探索 UI

struct OpeningExplorerView: View {
    @State private var store = OpeningTreeStore.shared
    @State private var selectedNode: OpeningTreeNode?
    @State private var board = Board(fen: FENParser.standardInitial)
    @State private var moveHistory: [String] = []
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
                HStack(spacing: 0) {
                    // 左侧：开局树列表
                    treeList

                    // 右侧：棋盘预览
                    boardPreview
                }
            }
        }
        .background(Color(red: 44/255, green: 24/255, blue: 16/255))
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
                ForEach(store.roots) { node in
                    OpeningNodeRow(
                        node: node,
                        depth: 0,
                        onSelect: { selectNode(node) },
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
            // 棋盘
            Text(l10n.t("opening.explorer.preview"))
                .font(.caption)
                .foregroundColor(.gray)

            // 走法路径
            if !moveHistory.isEmpty {
                Text(moveHistory.joined(separator: " → "))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            // 收藏按钮
            let pathKey = moveHistory.joined(separator: ",")
            Button {
                store.toggleFavorite(pathKey)
            } label: {
                Image(systemName: store.isFavorite(pathKey) ? "heart.fill" : "heart")
                    .foregroundColor(store.isFavorite(pathKey) ? .red : .gray)
            }
            .buttonStyle(.plain)
            .disabled(moveHistory.isEmpty)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(red: 30/255, green: 16/255, blue: 10/255))
    }

    // MARK: - 选择节点

    private func selectNode(_ node: OpeningTreeNode) {
        // 重置棋盘并推演到该节点
        board = Board(fen: FENParser.standardInitial)
        moveHistory = []

        // 从根节点推演走法路径
        var current = board
        func walkPath(_ n: OpeningTreeNode) {
            if !n.move.isEmpty {
                moveHistory.append(n.moveName)
                // UCI → Move → execute
                if let m = UCIMoveConverter.move(from: n.move, on: current) {
                    current.execute(m)
                }
            }
            for child in n.children {
                walkPath(child)
            }
        }
        walkPath(node)
        board = current
        selectedNode = node
    }
}

// MARK: - 开局树节点行

struct OpeningNodeRow: View {
    let node: OpeningTreeNode
    let depth: Int
    let onSelect: () -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 当前节点
            HStack(spacing: 6) {
                // 缩进
                if depth > 0 {
                    Spacer().frame(width: CGFloat(depth) * 16)
                }

                // 展开/折叠图标
                if !node.children.isEmpty {
                    Button { onToggle() } label: {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }

                // 走法名
                Text(node.moveName)
                    .font(.caption.weight(depth == 0 ? .semibold : .regular))
                    .foregroundColor(depth == 0 ? .white : .white.opacity(0.8))

                // 权重
                if node.weight > 0 {
                    Text("(\(node.weight))")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            .padding(.vertical, 4)
            .padding(.leading, 4)

            // 子节点
            if node.isExpanded {
                ForEach(node.children) { child in
                    OpeningNodeRow(
                        node: child,
                        depth: depth + 1,
                        onSelect: { onSelect() },
                        onToggle: { child.isExpanded.toggle() }
                    )
                }
            }
        }
    }
}
