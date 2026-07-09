import Foundation
import Testing
@testable import ChineseChess

// MARK: - Phase 5 #1: OpeningTreeNode 数据转换逻辑测试

@Suite("Phase 5 #1: OpeningTreeNode 数据转换测试", .serialized)
struct OpeningTreeNodeTests {

    // MARK: - 1. OpeningTreeNode 基础属性

    @Test("OpeningTreeNode 初始化：必填参数")
    func nodeInitRequired() {
        let node = OpeningTreeNode(move: "h2e2", moveName: "炮二平五", weight: 10)
        #expect(node.move == "h2e2")
        #expect(node.moveName == "炮二平五")
        #expect(node.weight == 10)
        #expect(node.children.isEmpty, "默认 children 应为空")
    }

    @Test("OpeningTreeNode 初始化：带 children")
    func nodeInitWithChildren() {
        let child1 = OpeningTreeNode(move: "h9g7", moveName: "马8进7", weight: 5)
        let child2 = OpeningTreeNode(move: "i9h9", moveName: "车9平8", weight: 3)
        let parent = OpeningTreeNode(move: "h2e2", moveName: "炮二平五", weight: 10, children: [child1, child2])

        #expect(parent.children.count == 2)
        #expect(parent.children[0].move == "h9g7")
        #expect(parent.children[1].move == "i9h9")
    }

    @Test("OpeningTreeNode 默认参数")
    func nodeDefaultParams() {
        let node = OpeningTreeNode(move: "h2e2")
        #expect(node.moveName == "", "默认 moveName 应为空字符串")
        #expect(node.weight == 0, "默认 weight 应为 0")
        #expect(node.children.isEmpty, "默认 children 应为空")
    }

    @Test("OpeningTreeNode 状态标记：isExpanded 和 isFavorite")
    func nodeStateFlags() {
        let node = OpeningTreeNode(move: "h2e2")
        #expect(node.isExpanded == false, "默认 isExpanded 应为 false")
        #expect(node.isFavorite == false, "默认 isFavorite 应为 false")

        node.isExpanded = true
        #expect(node.isExpanded == true)

        node.isFavorite = true
        #expect(node.isFavorite == true)
    }

    @Test("OpeningTreeNode id 唯一性")
    func nodeIdUnique() {
        let node1 = OpeningTreeNode(move: "h2e2")
        let node2 = OpeningTreeNode(move: "h2e2")
        #expect(node1.id != node2.id, "每个 node 的 id 应唯一（UUID）")
    }

    // MARK: - 2. OpeningV1Entry JSON 解析

    @Test("OpeningV1Entry 解码：标准格式")
    func decodeV1Entry() throws {
        let json = """
        {
            "name": "中炮",
            "variations": [
                ["h2e2", "h9g7"],
                ["h2e2", "b7e7"]
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let entry = try JSONDecoder().decode(OpeningV1Entry.self, from: data)

        #expect(entry.name == "中炮")
        #expect(entry.variations.count == 2)
        #expect(entry.variations[0] == ["h2e2", "h9g7"])
        #expect(entry.variations[1] == ["h2e2", "b7e7"])
    }

    @Test("OpeningV1Entry 解码：空 variations")
    func decodeV1EntryEmptyVariations() throws {
        let json = """
        {
            "name": "空开局",
            "variations": []
        }
        """
        let data = json.data(using: .utf8)!
        let entry = try JSONDecoder().decode(OpeningV1Entry.self, from: data)
        #expect(entry.variations.isEmpty)
    }

    @Test("OpeningV1Entry 解码：单步 variation")
    func decodeV1EntrySingleMove() throws {
        let json = """
        {
            "name": "飞相",
            "variations": [["g0e2"]]
        }
        """
        let data = json.data(using: .utf8)!
        let entry = try JSONDecoder().decode(OpeningV1Entry.self, from: data)
        #expect(entry.variations.count == 1)
        #expect(entry.variations[0] == ["g0e2"])
    }

    @Test("OpeningV1Entry 数组解码")
    func decodeV1EntryArray() throws {
        let json = """
        [
            {"name": "中炮", "variations": [["h2e2"]]},
            {"name": "飞相", "variations": [["g0e2"]]}
        ]
        """
        let data = json.data(using: .utf8)!
        let entries = try JSONDecoder().decode([OpeningV1Entry].self, from: data)
        #expect(entries.count == 2)
        #expect(entries[0].name == "中炮")
        #expect(entries[1].name == "飞相")
    }

    // MARK: - 3. OpeningTreeBuilder

    @Test("OpeningTreeBuilder.moveName: 返回 UCI 本身")
    func moveNameReturnsUCI() {
        let name = OpeningTreeBuilder.moveName(for: "h2e2")
        #expect(name == "h2e2", "moveName 应返回 UCI 本身（简化映射）")
    }

    @Test("OpeningTreeBuilder.moveName: 不同 UCI 返回不同名称")
    func moveNameDifferentUCI() {
        let n1 = OpeningTreeBuilder.moveName(for: "h2e2")
        let n2 = OpeningTreeBuilder.moveName(for: "h9g7")
        #expect(n1 == "h2e2")
        #expect(n2 == "h9g7")
        #expect(n1 != n2)
    }

    @Test("OpeningTreeBuilder.buildFromV1: 基础构建")
    func buildFromV1Basic() {
        let entries = [
            OpeningV1Entry(name: "中炮", variations: [["h2e2", "h9g7"]])
        ]
        let roots = OpeningTreeBuilder.buildFromV1(entries)
        #expect(!roots.isEmpty, "应至少有一个根节点")
        #expect(roots[0].move == "h2e2", "第一个根节点 move 应为 h2e2")
    }

    @Test("OpeningTreeBuilder.buildFromV1: 空 entries 返回空数组")
    func buildFromV1Empty() {
        let roots = OpeningTreeBuilder.buildFromV1([])
        #expect(roots.isEmpty, "空 entries 应返回空数组")
    }

    @Test("OpeningTreeBuilder.buildFromV1: 空 variation 被跳过")
    func buildFromV1EmptyVariation() {
        let entries = [
            OpeningV1Entry(name: "空", variations: [[], ["h2e2"]])
        ]
        let roots = OpeningTreeBuilder.buildFromV1(entries)
        // 空 variation 应被跳过，只有 h2e2 被构建
        #expect(roots.count >= 1)
        #expect(roots[0].move == "h2e2")
    }

    @Test("OpeningTreeBuilder.buildFromV1: 多个不同首步")
    func buildFromV1MultipleRoots() {
        let entries = [
            OpeningV1Entry(name: "中炮", variations: [["h2e2"]]),
            OpeningV1Entry(name: "飞相", variations: [["g0e2"]]),
        ]
        let roots = OpeningTreeBuilder.buildFromV1(entries)
        #expect(roots.count == 2, "应有两个根节点")
    }

    @Test("OpeningTreeBuilder.buildFromV1: 结果按权重排序")
    func buildFromV1SortedByWeight() {
        let entries = [
            OpeningV1Entry(name: "低权", variations: [["h9g7"]]),
            OpeningV1Entry(name: "高权", variations: [["h2e2"], ["h2e2"]]),
        ]
        let roots = OpeningTreeBuilder.buildFromV1(entries)
        // 排序后权重高的应在前
        #expect(!roots.isEmpty)
        // h2e2 出现两次（weight=2），h9g7 出现一次（weight=1）
        let h2e2 = roots.first { $0.move == "h2e2" }
        #expect(h2e2 != nil)
        // 排序后 h2e2 应在 h9g7 前
        if let h2e2Idx = roots.firstIndex(where: { $0.move == "h2e2" }),
           let h9g7Idx = roots.firstIndex(where: { $0.move == "h9g7" }) {
            #expect(h2e2Idx < h9g7Idx, "权重高的应排在前面")
        }
    }

    // MARK: - 4. OpeningTreeStore 收藏功能

    @Test("OpeningTreeStore.toggleFavorite: 添加和移除收藏")
    func toggleFavoriteAddRemove() {
        let store = OpeningTreeStore.shared
        let path = "h2e2_h9g7_test_\(UUID().uuidString)"

        // 初始状态：未收藏
        #expect(store.isFavorite(path) == false)

        // 添加收藏
        store.toggleFavorite(path)
        #expect(store.isFavorite(path) == true)

        // 移除收藏
        store.toggleFavorite(path)
        #expect(store.isFavorite(path) == false)
    }

    @Test("OpeningTreeStore.isFavorite: 不存在的路径返回 false")
    func isFavoriteNonExistent() {
        let store = OpeningTreeStore.shared
        let path = "nonexistent_\(UUID().uuidString)"
        #expect(store.isFavorite(path) == false)
    }

    @Test("OpeningTreeStore.toggleFavorite: 多个独立收藏")
    func multipleFavorites() {
        let store = OpeningTreeStore.shared
        let path1 = "fav1_\(UUID().uuidString)"
        let path2 = "fav2_\(UUID().uuidString)"

        store.toggleFavorite(path1)
        store.toggleFavorite(path2)
        #expect(store.isFavorite(path1))
        #expect(store.isFavorite(path2))

        // 移除一个不影响另一个
        store.toggleFavorite(path1)
        #expect(!store.isFavorite(path1))
        #expect(store.isFavorite(path2))

        // 清理
        store.toggleFavorite(path2)
    }

    // MARK: - 5. OpeningTreeNode 树结构验证

    @Test("OpeningTreeNode: 深层嵌套 children")
    func deepNesting() {
        let leaf = OpeningTreeNode(move: "h9g7", moveName: "马8进7", weight: 1)
        let mid = OpeningTreeNode(move: "h2e2", moveName: "炮二平五", weight: 5, children: [leaf])
        let root = OpeningTreeNode(move: "g0e2", moveName: "飞相", weight: 10, children: [mid])

        #expect(root.children.count == 1)
        #expect(root.children[0].move == "h2e2")
        #expect(root.children[0].children[0].move == "h9g7")
    }

    @Test("OpeningTreeNode: 多 children 排序")
    func multipleChildrenOrder() {
        let c1 = OpeningTreeNode(move: "a", weight: 1)
        let c2 = OpeningTreeNode(move: "b", weight: 5)
        let c3 = OpeningTreeNode(move: "c", weight: 3)
        let parent = OpeningTreeNode(move: "root", weight: 10, children: [c1, c2, c3])

        #expect(parent.children.count == 3)
        #expect(parent.children[0].move == "a")
        #expect(parent.children[1].move == "b")
        #expect(parent.children[2].move == "c")
    }
}
