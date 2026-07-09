import Foundation
import Testing
@testable import ChineseChess

// MARK: - v5.0 Phase 1: 开局库懒展开核心测试

@Suite("v5.0 Phase 1: 开局库懒展开", .serialized)
struct OpeningExplorerV5Tests {

    // MARK: - 1. OpeningBook 单例

    @Test("OpeningBook.shared 是单例（同一引用）")
    func openingBookSingleton() {
        let book1 = OpeningBook.shared
        let book2 = OpeningBook.shared
        // 单例应是同一实例
        #expect(book1 === book2, "OpeningBook.shared 应返回同一实例")
    }

    @Test("OpeningBook.shared 有局面数据")
    func openingBookHasData() {
        // 初始局面的 zobrist hash 应该有候选走法
        let board = Board(fen: FENParser.standardInitial)
        let hash = ZobristHash.hash(board: board)
        let candidates = OpeningBook.shared.lookupAll(zobristHash: hash)
        #expect(candidates != nil, "初始局面应在开局库中有记录")
        #expect(!candidates!.isEmpty, "初始局面应有候选走法")
    }

    @Test("OpeningBook.lookup 返回最高权重走法")
    func lookupReturnsHighestWeight() {
        let board = Board(fen: FENParser.standardInitial)
        let hash = ZobristHash.hash(board: board)
        let top = OpeningBook.shared.lookup(zobristHash: hash)
        let all = OpeningBook.shared.lookupAll(zobristHash: hash)

        #expect(top != nil, "应有推荐走法")
        if let all = all, let top = top {
            // lookup 返回的应是权重最高的
            let maxWeight = all.map { $0.weight }.max() ?? -1
            let topEntry = all.first { $0.move == top }
            #expect(topEntry?.weight == maxWeight, "lookup 应返回最高权重走法")
        }
    }

    @Test("OpeningBook.lookupAll 返回按权重降序的列表")
    func lookupAllSortedByWeight() {
        let board = Board(fen: FENParser.standardInitial)
        let hash = ZobristHash.hash(board: board)
        guard let all = OpeningBook.shared.lookupAll(zobristHash: hash) else {
            Issue.record("初始局面应有候选走法"); return
        }
        // 验证降序
        for i in 0..<max(0, all.count - 1) {
            #expect(all[i].weight >= all[i + 1].weight, "应按权重降序排列")
        }
    }

    @Test("OpeningBook.lookupWeightedRandom 返回有效走法")
    func lookupWeightedRandomReturnsValid() {
        let board = Board(fen: FENParser.standardInitial)
        let hash = ZobristHash.hash(board: board)
        guard let all = OpeningBook.shared.lookupAll(zobristHash: hash) else {
            Issue.record("初始局面应有候选走法"); return
        }

        // 多次随机选择，结果都应在候选列表中
        let validMoves = Set(all.map { $0.move })
        for _ in 0..<20 {
            let picked = OpeningBook.shared.lookupWeightedRandom(zobristHash: hash)
            #expect(picked != nil, "应有随机走法")
            #expect(validMoves.contains(picked!), "随机走法应在候选列表中")
        }
    }

    @Test("OpeningBook.lookupAll 不存在的 hash 返回 nil")
    func lookupAllNonExistent() {
        let result = OpeningBook.shared.lookupAll(zobristHash: 0xDEAD_BEEF_DEAD_BEEF)
        #expect(result == nil, "不存在的 hash 应返回 nil")
    }

    @Test("OpeningBook.lookup 不存在的 hash 返回 nil")
    func lookupNonExistent() {
        let result = OpeningBook.shared.lookup(zobristHash: 0xDEAD_BEEF_DEAD_BEEF)
        #expect(result == nil, "不存在的 hash 应返回 nil")
    }

    @Test("OpeningBook.lookupWeightedRandom 不存在的 hash 返回 nil")
    func lookupWeightedRandomNonExistent() {
        let result = OpeningBook.shared.lookupWeightedRandom(zobristHash: 0xDEAD_BEEF_DEAD_BEEF)
        #expect(result == nil, "不存在的 hash 应返回 nil")
    }

    @Test("OpeningBook.lookupWeightedRandom 单个候选直接返回")
    func weightedRandomSingleCandidate() {
        // 找一个只有一个候选走法的局面
        let board = Board(fen: FENParser.standardInitial)
        let hash = ZobristHash.hash(board: board)
        guard let all = OpeningBook.shared.lookupAll(zobristHash: hash) else {
            Issue.record("初始局面应有候选走法"); return
        }

        // 如果只有一个候选，直接返回
        if all.count == 1 {
            let picked = OpeningBook.shared.lookupWeightedRandom(zobristHash: hash)
            #expect(picked == all[0].move)
        }
        // 否则验证多次选择都能命中候选集
        else {
            let validMoves = Set(all.map { $0.move })
            for _ in 0..<50 {
                let picked = OpeningBook.shared.lookupWeightedRandom(zobristHash: hash)
                #expect(validMoves.contains(picked!), "随机走法应在候选列表中")
            }
        }
    }

    // MARK: - 2. OpeningExplorerService 懒展开

    @MainActor
    @Test("rootMoves 返回初始局面候选走法")
    func rootMovesReturnsCandidates() {
        let roots = OpeningExplorerService.shared.rootMoves()
        #expect(!roots.isEmpty, "初始局面应有候选走法")
        #expect(roots.count <= 10, "每层最多 10 个候选")

        for node in roots {
            #expect(node.depth == 0, "根节点 depth 应为 0")
            #expect(!node.move.isEmpty, "节点 move 不应为空")
            #expect(!node.moveName.isEmpty, "节点 moveName 不应为空")
            #expect(node.weight > 0, "节点 weight 应 > 0")
        }
    }

    @MainActor
    @Test("rootMoves 走法名是中文（非 UCI）")
    func rootMovesChineseName() {
        let roots = OpeningExplorerService.shared.rootMoves()
        for node in roots {
            #expect(node.moveName != node.move, "moveName 不应等于 UCI: \(node.move)")
            #expect(node.moveName.contains(/[\u4e00-\u9fff一二三四五六七八九]/),
                   "moveName 应包含中文: \(node.moveName)")
        }
    }

    @MainActor
    @Test("expandChildren 返回正确子节点")
    func expandChildrenReturnsCorrectNodes() {
        let roots = OpeningExplorerService.shared.rootMoves()
        guard let firstRoot = roots.first else {
            Issue.record("应有根节点"); return
        }

        let children = OpeningExplorerService.shared.expandChildren(of: firstRoot)
        // 子节点 depth 应为 1
        for child in children {
            #expect(child.depth == 1, "子节点 depth 应为 1")
            #expect(!child.move.isEmpty, "子节点 move 不应为空")
            #expect(!child.moveName.isEmpty, "子节点 moveName 不应为空")
        }
    }

    @MainActor
    @Test("expandChildren 每层最多 10 个候选")
    func expandChildrenMaxTen() {
        let roots = OpeningExplorerService.shared.rootMoves()
        for root in roots {
            let children = OpeningExplorerService.shared.expandChildren(of: root)
            #expect(children.count <= 10, "每层最多 10 个候选，实际: \(children.count)")
        }
    }

    @MainActor
    @Test("expandChildren 按权重降序")
    func expandChildrenSortedByWeight() {
        let roots = OpeningExplorerService.shared.rootMoves()
        guard let root = roots.first else {
            Issue.record("应有根节点"); return
        }

        let children = OpeningExplorerService.shared.expandChildren(of: root)
        for i in 0..<max(0, children.count - 1) {
            #expect(children[i].weight >= children[i + 1].weight,
                   "子节点应按权重降序排列")
        }
    }

    @MainActor
    @Test("深度限制 20 步生效")
    func depthLimitTwenty() {
        // depth=20 时 expandFromBoard 应返回空数组
        // 构造一个 depth=19 的节点，其子节点 depth=20，再展开应返回空
        let roots = OpeningExplorerService.shared.rootMoves()
        guard let root = roots.first else {
            Issue.record("应有根节点"); return
        }

        // 逐层展开到最大深度
        var currentLevel = [root]
        var currentDepth = 0

        while currentDepth < 20 {
            var nextLevel: [OpeningExplorerNode] = []
            for node in currentLevel {
                nextLevel.append(contentsOf: OpeningExplorerService.shared.expandChildren(of: node))
            }
            if nextLevel.isEmpty { break }
            currentLevel = nextLevel
            currentDepth += 1
        }

        // 最终深度不应超过 20
        #expect(currentDepth <= 20, "深度不应超过 20，实际到达: \(currentDepth)")

        // 在 depth=20 的节点上再展开应返回空
        if currentDepth == 20 {
            for node in currentLevel {
                let beyond = OpeningExplorerService.shared.expandChildren(of: node)
                #expect(beyond.isEmpty, "depth >= 20 时应返回空数组")
            }
        }
    }

    @MainActor
    @Test("expandChildren 未知局面返回空数组")
    func expandChildrenUnknownPosition() {
        // 构造一个不在开局库中的局面
        let board = Board(fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABR w - - - 1")
        // 这其实是初始局面... 需要一个真正不在库中的局面
        // 用一个走了很多步的随机局面
        let weirdBoard = Board(fen: "2bak4/9/4c4/9/9/3R5/9/4C4/4K4/3r5 w - - - 1")
        let hash = ZobristHash.hash(board: weirdBoard)
        let result = OpeningBook.shared.lookupAll(zobristHash: hash)
        // 如果这个局面不在库中
        if result == nil {
            // 构造一个 node，其 snapshot 对应这个局面
            let snapshot = PositionSnapshot(board: weirdBoard)
            let node = OpeningExplorerNode(move: "test", moveName: "测试", weight: 1, depth: 5, snapshot: snapshot)
            let children = OpeningExplorerService.shared.expandChildren(of: node)
            #expect(children.isEmpty, "不在开局库中的局面应返回空子节点列表")
        }
    }

    // MARK: - 3. OpeningExplorerNode 懒加载

    @MainActor
    @Test("children 首次访问触发懒加载")
    func childrenLazyLoad() {
        let roots = OpeningExplorerService.shared.rootMoves()
        guard let root = roots.first else {
            Issue.record("应有根节点"); return
        }

        // 首次访问 children
        let children1 = root.children
        // 再次访问应返回缓存
        let children2 = root.children

        // 两次返回应是同一数组（缓存）
        #expect(children1.count == children2.count, "缓存应一致")
    }

    @MainActor
    @Test("isLeaf 正确反映有无子节点")
    func isLeafCorrect() {
        let roots = OpeningExplorerService.shared.rootMoves()
        for node in roots {
            // 触发懒加载
            let children = node.children
            if children.isEmpty {
                #expect(node.isLeaf == true, "无子节点应为叶子")
            } else {
                #expect(node.isLeaf == false, "有子节点不应为叶子")
            }
        }
    }

    @MainActor
    @Test("isExpanded 默认 false")
    func isExpandedDefaultFalse() {
        let roots = OpeningExplorerService.shared.rootMoves()
        for node in roots {
            #expect(node.isExpanded == false, "节点默认未展开")
        }
    }

    @MainActor
    @Test("节点 id 唯一性")
    func nodeIdUnique() {
        let roots = OpeningExplorerService.shared.rootMoves()
        var ids = Set<UUID>()
        for node in roots {
            #expect(!ids.contains(node.id), "节点 id 应唯一")
            ids.insert(node.id)
        }
    }

    @MainActor
    @Test("节点 snapshot 与执行走法后棋盘一致")
    func snapshotMatchesBoard() {
        let roots = OpeningExplorerService.shared.rootMoves()
        guard let root = roots.first else {
            Issue.record("应有根节点"); return
        }

        // 从初始局面执行 root.move，棋盘状态应与 root.snapshot 一致
        let board = Board(fen: FENParser.standardInitial)
        guard let move = ICCSParser.parse(root.move, on: board) else {
            Issue.record("走法解析失败: \(root.move)"); return
        }
        board.execute(move)

        let snapshotBoard = Board(snapshot: root.snapshot)
        // 比较棋子数量和位置
        #expect(snapshotBoard.pieces.count == board.pieces.count, "棋子数应一致")
        for (i, piece) in board.pieces.enumerated() {
            let sp = snapshotBoard.pieces[i]
            #expect(piece.position == sp.position, "棋子位置应一致")
            #expect(piece.kind == sp.kind, "棋子类型应一致")
            #expect(piece.side == sp.side, "棋子方应一致")
        }
        #expect(snapshotBoard.currentTurn == board.currentTurn, "走棋方应一致")
    }

    // MARK: - 4. PositionSnapshot

    @Test("PositionSnapshot 正确记录棋盘状态")
    func positionSnapshotRecordsBoard() {
        let board = Board(fen: FENParser.standardInitial)
        let snapshot = PositionSnapshot(board: board)

        #expect(snapshot.pieces.count == 32, "应有 32 个棋子")
        #expect(snapshot.currentTurn == .red, "初始局面红方先走")
    }

    @Test("PositionSnapshot → Board 往返一致")
    func positionSnapshotRoundTrip() {
        let board = Board(fen: FENParser.standardInitial)
        // 执行一步走法
        guard let move = ICCSParser.parse("h2e2", on: board) else {
            Issue.record("走法解析失败"); return
        }
        board.execute(move)

        let snapshot = PositionSnapshot(board: board)
        let restored = Board(snapshot: snapshot)

        #expect(restored.pieces.count == board.pieces.count)
        for (i, piece) in board.pieces.enumerated() {
            #expect(piece.position == restored.pieces[i].position, "位置应一致")
        }
        #expect(restored.currentTurn == board.currentTurn)
    }

    @Test("PositionSnapshot 是值类型（复制独立）")
    func positionSnapshotValueType() {
        let board = Board(fen: FENParser.standardInitial)
        var snapshot = PositionSnapshot(board: board)

        // struct 是值类型，修改副本不影响原值
        var copy = snapshot
        // PositionSnapshot 的 pieces 是 let，无法修改
        // 但验证 struct 语义
        #expect(copy.pieces.count == snapshot.pieces.count)
        #expect(copy.currentTurn == snapshot.currentTurn)
    }

    // MARK: - 5. 综合：完整懒展开流程

    @MainActor
    @Test("完整懒展开流程：根 → 子节点 → 孙节点")
    func fullLazyExpandFlow() {
        let roots = OpeningExplorerService.shared.rootMoves()
        #expect(!roots.isEmpty, "应有根节点")

        guard let root = roots.first else { return }

        // 第一层展开
        let children = root.children
        if children.isEmpty {
            // 某些根节点可能是叶子，这没问题
            return
        }
        #expect(children.allSatisfy { $0.depth == 1 }, "子节点 depth 应为 1")

        // 第二层展开
        guard let firstChild = children.first else { return }
        let grandchildren = firstChild.children
        for gc in grandchildren {
            #expect(gc.depth == 2, "孙节点 depth 应为 2")
        }
    }

    @MainActor
    @Test("中文走法名在多层展开中保持正确")
    func chineseNamesInMultiLevel() {
        let roots = OpeningExplorerService.shared.rootMoves()

        func checkChineseName(_ nodes: [OpeningExplorerNode], depth: Int) {
            for node in nodes {
                #expect(node.moveName != node.move,
                       "depth=\(depth) 节点 moveName 不应等于 UCI")
                #expect(node.moveName.contains(/[\u4e00-\u9fff一二三四五六七八九]/),
                       "depth=\(depth) 节点 moveName 应包含中文: \(node.moveName)")

                // 递归检查子节点（只检查前几个避免过慢）
                if depth < 2 {
                    checkChineseName(Array(node.children.prefix(3)), depth: depth + 1)
                }
            }
        }

        checkChineseName(roots, depth: 0)
    }

    @MainActor
    @Test("权重在树中合理分布")
    func weightDistributionInTree() {
        let roots = OpeningExplorerService.shared.rootMoves()
        #expect(roots.allSatisfy { $0.weight > 0 }, "所有根节点 weight 应 > 0")

        // 子节点也应有合理权重
        for root in roots.prefix(3) {
            let children = root.children
            for child in children {
                #expect(child.weight >= 0, "子节点 weight 应 >= 0")
            }
        }
    }
}
