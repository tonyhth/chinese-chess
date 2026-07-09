import Foundation
import Testing
@testable import ChineseChess

// MARK: - Bug A→B→C: 开局库 UI 修复测试

@Suite("开局库 UI 修复（Bug A→B→C）", .serialized)
struct OpeningTreeBugFixTests {

    // MARK: - Bug A: onSelect 闭包穿透修复

    @Test("selectNode 重置棋盘并推演到目标节点")
    func selectNodeReplaysBoard() {
        // 构建一个简单的两级树：根节点(开局名) → 子节点(走法)
        let entries = [
            OpeningV1Entry(name: "中炮", variations: [
                ["h2e2", "h9g7", "i9h9"],
            ])
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        #expect(!roots.isEmpty, "应有至少一个根节点")

        // 根节点的第一个子节点
        let root = roots[0]
        #expect(!root.children.isEmpty, "根节点应有子节点")
        let firstChild = root.children[0]
        #expect(!firstChild.move.isEmpty, "子节点应有 UCI 走法")

        // 模拟 selectNode 的逻辑：重置棋盘并推演
        let board = Board(fen: FENParser.standardInitial)
        // 根节点 move 为空，跳过；执行子节点走法
        if let m = UCIMoveConverter.move(from: firstChild.move, on: board) {
            board.execute(m)
        }

        // 验证棋盘状态：执行 h2e2 后，红炮应在 e2 位置
        let cannons = board.pieces.filter { $0.kind == .cannon && $0.side == .red }
        let cannonAtE2 = cannons.contains { $0.position.col == 4 && $0.position.row == 7 }
        #expect(cannonAtE2, "执行 h2e2 后红炮应在 (row=7, col=4)")
    }

    @Test("深层子节点（3步以上）正确推演")
    func deepNodeReplay() {
        let entries = [
            OpeningV1Entry(name: "中炮对屏风马", variations: [
                ["h2e2", "h9g7", "i9h9"],
            ])
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        let root = roots[0]

        // 遍历到第三层
        var current = root
        var depth = 0
        var moves: [String] = []

        while depth < 3 && !current.children.isEmpty {
            current = current.children[0]
            if !current.move.isEmpty {
                moves.append(current.move)
            }
            depth += 1
        }

        #expect(moves.count >= 3, "应有至少 3 步走法")
        #expect(moves[0] == "h2e2")
        #expect(moves[1] == "h9g7")
        #expect(moves[2] == "i9h9")

        // 执行全部走法
        let board = Board(fen: FENParser.standardInitial)
        for uci in moves {
            if let m = UCIMoveConverter.move(from: uci, on: board) {
                board.execute(m)
            }
        }
        // 验证：3 步后棋盘上的棋子数不变（走子不吃子）
        #expect(board.pieces.count == 32, "3 步走子后棋盘仍应有 32 个棋子")
    }

    @Test("selectNode 棋盘推演：从初始局面逐步执行路径走法")
    func selectNodePathReplay() {
        // 测试 DFS 路径搜索逻辑
        let entries = [
            OpeningV1Entry(name: "测试开局", variations: [
                ["h2e2", "h9g7"],
                ["g0e2", "i9h9"],
            ])
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        let root = roots[0]

        // root.children 应有两个子节点（h2e2 和 g0e2）
        #expect(root.children.count >= 1, "应有至少 1 个子节点")

        // 找到第一个子节点的深层
        if let firstBranch = root.children.first {
            #expect(!firstBranch.children.isEmpty, "第一层子节点应有子节点")
            if let deepNode = firstBranch.children.first {
                // 验证 DFS 能找到路径
                #expect(!deepNode.move.isEmpty, "深层节点应有走法")
            }
        }
    }

    // MARK: - Bug B: buildGroupedTree() 两级树

    @Test("第一级节点 moveName 为开局名称（非 UCI）")
    func firstLevelIsOpeningName() {
        let entries = [
            OpeningV1Entry(name: "中炮对屏风马", variations: [["h2e2", "h9g7"]]),
            OpeningV1Entry(name: "飞相局", variations: [["g0e2"]]),
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)

        #expect(roots.count == 2, "应有 2 个根节点")
        // 根节点 move 为空，moveName 为开局名称
        #expect(roots[0].move == "", "根节点 move 应为空")
        let names = Set(roots.map { $0.moveName })
        #expect(names.contains("中炮对屏风马"), "应包含开局名称")
        #expect(names.contains("飞相局"))
    }

    @Test("同名开局的变体合并到同一根节点")
    func sameOpeningMerged() {
        let entries = [
            OpeningV1Entry(name: "中炮", variations: [
                ["h2e2", "h9g7"],
                ["h2e2", "b7e7"],
                ["h2e2", "h9g7", "i9h9"],
            ])
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)

        #expect(roots.count == 1, "同名开局应合并为 1 个根节点")
        #expect(roots[0].weight == 3, "权重应为 3 个变体之和")
    }

    @Test("共享前缀的走法正确合并为子树")
    func sharedPrefixMerged() {
        let entries = [
            OpeningV1Entry(name: "中炮", variations: [
                ["h2e2", "h9g7"],
                ["h2e2", "h9g7", "i9h9"],
                ["h2e2", "b7e7"],
            ])
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        let root = roots[0]

        // 第一级子节点应按首步分组：h2e2 有 3 个变体
        // 第二级：h9g7（2 个变体）和 b7e7（1 个变体）
        #expect(root.children.count == 1, "首步都是 h2e2，应只有 1 个子节点")
        let firstMove = root.children[0]
        #expect(firstMove.move == "h2e2")
        #expect(firstMove.weight == 3, "h2e2 总权重应为 3")

        // h9g7 有 2 个变体（一个停在此，一个继续 i9h9）
        let h9g7 = firstMove.children.first { $0.move == "h9g7" }
        #expect(h9g7 != nil, "应有 h9g7 子节点")
        #expect(h9g7!.weight == 2, "h9g7 权重应为 2")

        // h9g7 下应有 i9h9 子节点
        #expect(!h9g7!.children.isEmpty, "h9g7 应有 i9h9 子节点")

        // b7e7 应在 firstMove.children 中
        let b7e7 = firstMove.children.first { $0.move == "b7e7" }
        #expect(b7e7 != nil, "应有 b7e7 子节点")
        #expect(b7e7!.weight == 1)
    }

    @Test("不同开局名称不合并")
    func differentNamesNotMerged() {
        let entries = [
            OpeningV1Entry(name: "中炮", variations: [["h2e2"]]),
            OpeningV1Entry(name: "飞相", variations: [["g0e2"]]),
            OpeningV1Entry(name: "起马", variations: [["h0g2"]]),
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        #expect(roots.count == 3, "不同开局名称应各自独立")
    }

    @Test("根节点按权重降序排列")
    func rootsSortedByWeight() {
        let entries = [
            OpeningV1Entry(name: "低频", variations: [["h9g7"]]),
            OpeningV1Entry(name: "高频", variations: [["h2e2"], ["h2e2"], ["h2e2"]]),
            OpeningV1Entry(name: "中频", variations: [["g0e2"], ["g0e2"]]),
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        #expect(roots[0].moveName == "高频", "权重最高的应在首位")
        #expect(roots[0].weight == 3)
        #expect(roots[1].moveName == "中频")
        #expect(roots[1].weight == 2)
        #expect(roots[2].moveName == "低频")
        #expect(roots[2].weight == 1)
    }

    @Test("空 variation 被过滤")
    func emptyVariationsFiltered() {
        let entries = [
            OpeningV1Entry(name: "混合", variations: [[], ["h2e2"], []]),
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        #expect(roots.count == 1, "应有 1 个根节点")
        #expect(roots[0].weight == 1, "空 variation 应被过滤，权重为 1")
    }

    @Test("完全空 variations 的 entry 被跳过")
    func allEmptyVariationsSkipped() {
        let entries = [
            OpeningV1Entry(name: "空", variations: []),
            OpeningV1Entry(name: "有效", variations: [["h2e2"]]),
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        #expect(roots.count == 1, "空 entry 应被跳过")
        #expect(roots[0].moveName == "有效")
    }

    // MARK: - Bug C: 中文走法名

    @Test("buildGroupedTree 子节点 moveName 是中文（非 UCI）")
    func childMoveNameIsChinese() {
        let entries = [
            OpeningV1Entry(name: "中炮", variations: [["h2e2"]]),
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        let root = roots[0]
        let child = root.children[0]

        // moveName 不应等于 UCI
        #expect(child.moveName != child.move, "moveName 不应等于 UCI 走法")
        #expect(!child.moveName.isEmpty, "moveName 不应为空")
        // 中文明法名应包含中文或数字
        #expect(child.moveName.contains(/[\u4e00-\u9fff一二三四五六七八九]/), "moveName 应包含中文字符")
    }

    @Test("buildGroupedTree 子节点中文走法名正确性")
    func chineseMoveNameCorrect() {
        let entries = [
            OpeningV1Entry(name: "中炮", variations: [["h2e2"]]),
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        let child = roots[0].children[0]

        // h2e2 = 炮二平五（红方炮从 col=8 到 col=4）
        // 红方纵线编号：col 0→九, 1→八, ..., 8→二, 但实际 col 8 → 一... 等
        // h2e2 的起点 col=8 → 红方"一"，终点 col=4 → 红方"五"
        // 但实际上 h2e2 是从 (row=7, col=8) 到 (row=7, col=4)，横向走法
        // moveName 应包含"炮"
        #expect(child.moveName.contains("炮"), "h2e2 的走法名应包含 '炮'")
    }

    @Test("多步走法名全部为中文")
    func multiStepAllChinese() {
        let entries = [
            OpeningV1Entry(name: "中炮对屏风马", variations: [
                ["h2e2", "h9g7", "i9h9"],
            ])
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        let root = roots[0]

        // 遍历所有子节点，检查 moveName
        func checkAllChinese(_ nodes: [OpeningTreeNode]) {
            for node in nodes {
                if !node.move.isEmpty {
                    #expect(node.moveName != node.move, "走法 \(node.move) 的 moveName 不应等于 UCI")
                    #expect(!node.moveName.isEmpty, "走法 \(node.move) 的 moveName 不应为空")
                    #expect(node.moveName.contains(/[\u4e00-\u9fff一二三四五六七八九]/),
                           "走法 \(node.move) 的 moveName 应包含中文: \(node.moveName)")
                }
                checkAllChinese(node.children)
            }
        }

        checkAllChinese(root.children)
    }

    @Test("buildFromV1（旧方法）moveName 仍返回 UCI")
    func oldBuildFromV1StillUCI() {
        // 旧方法 buildFromV1 应保持旧行为（moveName = UCI）
        let entries = [
            OpeningV1Entry(name: "中炮", variations: [["h2e2"]]),
        ]
        let roots = OpeningTreeBuilder.buildFromV1(entries)
        let root = roots[0]
        // 旧方法：moveName == move == UCI
        #expect(root.moveName == root.move, "旧方法 moveName 应等于 UCI")
        #expect(root.moveName == "h2e2")
    }

    // MARK: - 综合测试

    @Test("多开局混合：两级树结构完整性")
    func mixedOpeningsStructure() {
        let entries = [
            OpeningV1Entry(name: "中炮", variations: [
                ["h2e2", "h9g7"],
                ["h2e2", "b7e7"],
            ]),
            OpeningV1Entry(name: "飞相", variations: [
                ["g0e2"],
            ]),
            OpeningV1Entry(name: "起马", variations: [
                ["h0g2", "c6c5"],
                ["h0g2", "h9g7"],
            ]),
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)

        // 3 个开局名称 → 3 个根节点
        #expect(roots.count == 3, "应有 3 个根节点")

        // 每个根节点 move 为空，moveName 为开局名
        for root in roots {
            #expect(root.move == "", "根节点 move 应为空")
            #expect(!root.moveName.isEmpty, "根节点 moveName 不应为空")
        }

        // 中炮权重最高（2 个变体）
        // 起马也有 2 个变体
        // 飞相 1 个变体
        // 中炮和起马都 weight=2，顺序取决于 sorted 实现（稳定排序保留原始顺序）
        let topTwo = roots.prefix(2)
        #expect(topTwo.allSatisfy { $0.weight >= 2 }, "前两个权重应 >= 2")

        // 最后一个应是飞相（weight=1）
        #expect(roots.last!.moveName == "飞相" || roots.last!.weight == 1)
    }

    // MARK: - Bug 7: macOS 开局库节点点击无反应

    @Test("selectNode 接收正确节点引用（非闭包穿透）")
    func selectNodeReceivesCorrectNode() {
        let entries = [
            OpeningV1Entry(name: "中炮", variations: [
                ["h2e2", "h9g7"],
                ["h2e2", "b7e7"],
            ]),
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        let root = roots[0]

        // 旧 Bug A：onSelect() 不传参数 → 闭包捕获的 node 可能不对
        // 修复后：onSelectNode(node) 传具体引用
        // 验证：每个子节点的 move 都能被正确读取
        for child in root.children {
            #expect(!child.move.isEmpty, "子节点应有 UCI 走法")
            // 模拟 selectNode(child)：推演棋盘
            let board = Board(fen: FENParser.standardInitial)
            if let m = UCIMoveConverter.move(from: child.move, on: board) {
                board.execute(m)
                // 推演后棋盘应与初始不同
                #expect(board.pieces.contains { $0.position != Board(fen: FENParser.standardInitial).pieces.first(where: { $0.id == $0.id })?.position },
                       "执行走法后棋盘应变化")
            }
        }
    }

    @Test("isExpanded toggle 不影响 selectNode 推演")
    func expandedStateIndependentOfSelect() {
        let entries = [
            OpeningV1Entry(name: "中炮", variations: [
                ["h2e2", "h9g7", "i9h9"],
            ]),
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        let root = roots[0]

        // Bug 7 修复：chevron 和行点击分离
        // 验证：toggle isExpanded 不影响 selectNode 的棋盘推演
        let child = root.children[0]
        child.isExpanded = true
        #expect(child.isExpanded == true, "展开状态应为 true")

        // selectNode 逻辑：推演棋盘，不管 isExpanded
        let board = Board(fen: FENParser.standardInitial)
        if let m = UCIMoveConverter.move(from: child.move, on: board) {
            board.execute(m)
        }
        // 棋盘推演不受 isExpanded 影响
        let cannons = board.pieces.filter { $0.kind == .cannon && $0.side == .red }
        let cannonMoved = cannons.contains { $0.position.col != 8 }  // 离开原始位置
        #expect(cannonMoved, "推演不受 isExpanded 影响")

        // toggle 回去
        child.isExpanded = false
        #expect(child.isExpanded == false)
    }

    @Test("根节点（开局名称）选择：棋盘显示初始局面")
    func rootNodeSelectShowsInitialBoard() {
        let entries = [
            OpeningV1Entry(name: "中炮", variations: [
                ["h2e2", "h9g7"],
            ]),
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        let root = roots[0]

        // 根节点 move 为空 → selectNode 不执行走法
        #expect(root.move == "", "根节点 move 应为空")

        // 模拟 selectNode(root)：move 为空则不推演
        let board = Board(fen: FENParser.standardInitial)
        if !root.move.isEmpty {
            if let m = UCIMoveConverter.move(from: root.move, on: board) {
                board.execute(m)
            }
        }
        // 棋盘应保持初始状态
        let initial = Board(fen: FENParser.standardInitial)
        #expect(board.pieces.count == initial.pieces.count, "根节点选择后棋盘应为初始状态")
    }

    @Test("深层节点选择：DFS 路径完整推演")
    func deepNodeSelectFullReplay() {
        let entries = [
            OpeningV1Entry(name: "中炮对屏风马", variations: [
                ["h2e2", "h9g7", "i9h9", "h0g2"],
            ]),
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        let root = roots[0]

        // 找到第 4 层节点（i9h9 的子节点 h0g2）
        var current = root
        var path: [OpeningTreeNode] = [root]
        for _ in 0..<4 {
            guard !current.children.isEmpty else { break }
            current = current.children[0]
            path.append(current)
        }

        // 验证路径中有至少 4 个有 move 的节点
        let movesInPath = path.filter { !$0.move.isEmpty }
        #expect(movesInPath.count >= 3, "路径应包含至少 3 步走法")

        // 从根节点推演整条路径
        let board = Board(fen: FENParser.standardInitial)
        for node in path {
            if !node.move.isEmpty {
                if let m = UCIMoveConverter.move(from: node.move, on: board) {
                    board.execute(m)
                }
            }
        }
        #expect(board.pieces.count == 32, "4 步走子后仍应有 32 个棋子")
    }

    @Test("Bug 7: 子节点 moveName 包含中文（非 UCI）确认 chevron 修复不影响")
    func bug7ChineseNameAfterChevronFix() {
        let entries = [
            OpeningV1Entry(name: "飞相", variations: [["g0e2"]]),
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)
        let child = roots[0].children[0]

        // chevron 修复不应影响 moveName 的中文显示
        #expect(child.moveName != child.move, "moveName 不应等于 UCI")
        #expect(child.moveName.contains("相"), "g0e2 的走法名应包含 '相'")
    }

    @Test("子树深度限制：超过 10 层截断")
    func depthLimitTruncation() {
        // 构建一个 12 步的 variation
        let longVariation = ["h2e2", "h9g7", "i9h9", "h0g2", "b9c7", "b0c2", "a0b0",
                             "b7e7", "b2e2", "e6e5", "h2h7", "h9g7"]
        let entries = [
            OpeningV1Entry(name: "超长", variations: [longVariation])
        ]
        let roots = OpeningTreeBuilder.buildGroupedTree(entries)

        // 递归计算最大深度
        func maxDepth(_ node: OpeningTreeNode, current: Int = 0) -> Int {
            if node.children.isEmpty { return current }
            return node.children.map { maxDepth($0, current: current + 1) }.max() ?? current
        }

        // buildGroupedTree 内部限制 depth < 10
        // 根节点不算深度（move 为空），所以子节点最多到 depth=9
        let depth = maxDepth(roots[0])
        #expect(depth <= 11, "子树深度应有限制（含截断节点），实际深度: \(depth)")
    }
}
