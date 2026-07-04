import Foundation

// MARK: - v3.6.0 Phase 4: 开局树探索

/// 开局树节点
class OpeningTreeNode: Identifiable {
    let id = UUID()
    let move: String           // UCI 走法（如 "h2e2"）
    let moveName: String       // 中文走法名（如 "炮二平五"）
    let weight: Int            // 权重（出现频率）
    let children: [OpeningTreeNode]

    var isExpanded: Bool = false
    var isFavorite: Bool = false

    init(move: String, moveName: String = "", weight: Int = 0, children: [OpeningTreeNode] = []) {
        self.move = move
        self.moveName = moveName
        self.weight = weight
        self.children = children
    }
}

/// 开局树构建器（从 openings.json 构建树结构）
struct OpeningTreeBuilder {

    /// 可变中间结构（构建树时用，构建完 freeze 为 OpeningTreeNode）
    private struct MutableNode {
        var move: String
        var moveName: String
        var weight: Int
        var children: [String: MutableNode] = [:]
    }

    /// 从 openings.json 的 v1 格式构建树
    static func buildFromV1(_ entries: [OpeningV1Entry]) -> [OpeningTreeNode] {
        var rootMoves: [String: MutableNode] = [:]

        for entry in entries {
            for variation in entry.variations {
                guard !variation.isEmpty else { continue }

                let firstMove = variation[0]
                let firstName = moveName(for: firstMove)

                if rootMoves[firstMove] == nil {
                    rootMoves[firstMove] = MutableNode(move: firstMove, moveName: firstName, weight: 0)
                }
                rootMoves[firstMove]!.weight += 1

                // 递归构建子树
                if variation.count > 1 {
                    let remaining = Array(variation[1...])
                    addMutableChild(remaining, to: &rootMoves[firstMove]!, depth: 1)
                }
            }
        }

        return rootMoves.values
            .sorted { $0.weight > $1.weight }
            .map { freeze($0) }
    }

    /// 将可变节点递归冻结为不可变 OpeningTreeNode
    private static func freeze(_ node: MutableNode) -> OpeningTreeNode {
        let children = node.children.values
            .sorted { $0.weight > $1.weight }
            .map { freeze($0) }
        return OpeningTreeNode(
            move: node.move,
            moveName: node.moveName,
            weight: node.weight,
            children: children
        )
    }

    /// 递归添加子节点（可变版本）
    private static func addMutableChild(_ moves: [String], to parent: inout MutableNode, depth: Int) {
        guard !moves.isEmpty else { return }
        guard depth < 10 else { return }

        let move = moves[0]
        let name = moveName(for: move)

        if parent.children[move] == nil {
            parent.children[move] = MutableNode(move: move, moveName: name, weight: 0)
        }
        parent.children[move]!.weight += 1

        if moves.count > 1 {
            let remaining = Array(moves[1...])
            addMutableChild(remaining, to: &parent.children[move]!, depth: depth + 1)
        }
    }


    /// UCI → 中文走法名（简化映射）
    static func moveName(for uci: String) -> String {
        // 简化：返回 UCI 本身
        // 精确映射需要 Board 推演，在 UI 层按需计算
        return uci
    }
}

/// v1 格式条目
struct OpeningV1Entry: Codable {
    let name: String
    let variations: [[String]]
}

/// 开局树管理器
@Observable
final class OpeningTreeStore {
    static let shared = OpeningTreeStore()

    /// 根节点列表
    private(set) var roots: [OpeningTreeNode] = []

    /// 当前展开路径
    var currentPath: [OpeningTreeNode] = []

    /// 收藏的开局
    var favorites: [String] = []  // UCI 走法序列的 joined

    private init() {
        loadTree()
        loadFavorites()
    }

    // MARK: - 加载

    private func loadTree() {
        // 从 openings.json 构建
        var url = ResourceBundle.url(forResource: "openings", withExtension: "json",
                                      subdirectory: "OpeningBook")
        if url == nil {
            url = ResourceBundle.url(forResource: "openings", withExtension: "json")
        }

        guard let url = url,
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([OpeningV1Entry].self, from: data)
        else { return }

        // 简化构建：每个开局名称作为根节点，variations 作为子节点
        var rootNodes: [OpeningTreeNode] = []
        for entry in entries {
            for variation in entry.variations {
                guard !variation.isEmpty else { continue }
                let node = buildNode(from: variation, name: entry.name, index: 0)
                rootNodes.append(node)
            }
        }

        // 按权重排序
        self.roots = rootNodes.sorted { $0.weight > $1.weight }
    }

    /// 从走法序列构建节点树
    private func buildNode(from moves: [String], name: String, index: Int) -> OpeningTreeNode {
        guard index < moves.count else {
            return OpeningTreeNode(move: "", moveName: name, weight: 1)
        }

        let move = moves[index]
        let child = buildNode(from: moves, name: name, index: index + 1)
        let weight = moves.count - index  // 越深的走法权重越低

        return OpeningTreeNode(
            move: move,
            moveName: index == 0 ? name : move,
            weight: weight,
            children: index < moves.count - 1 ? [child] : []
        )
    }

    // MARK: - 收藏

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "openingFavorites"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            favorites = decoded
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: "openingFavorites")
        }
    }

    func toggleFavorite(_ path: String) {
        if let idx = favorites.firstIndex(of: path) {
            favorites.remove(at: idx)
        } else {
            favorites.append(path)
        }
        saveFavorites()
    }

    func isFavorite(_ path: String) -> Bool {
        favorites.contains(path)
    }
}
