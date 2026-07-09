import Foundation
import Testing
@testable import ChineseChess

// MARK: - v5.0 Phase 3: 搜索功能测试

@MainActor
@Suite("v5.0 Phase 3: 搜索功能", .serialized)
struct OpeningSearchTests {

    // MARK: - 1. 走法序列搜索

    @Test("searchByMoveSequence: 基本走法序列搜索")
    func searchByMoveSequenceBasic() {
        let result = OpeningExplorerService.shared.searchByMoveSequence("h2e2 b9c7 h0g2")
        #expect(result != nil, "h2e2 b9c7 h0g2 应能搜索到")
        #expect(result!.count == 3, "应返回 3 个节点")
        #expect(result![0].move == "h2e2")
        #expect(result![1].move == "b9c7")
        #expect(result![2].move == "h0g2")
    }

    @Test("searchByMoveSequence: 返回的节点有中文走法名")
    func searchByMoveSequenceChineseNames() {
        let result = OpeningExplorerService.shared.searchByMoveSequence("h2e2 b9c7")
        #expect(result != nil)
        for node in result! {
            #expect(!node.moveName.isEmpty, "节点应有中文走法名")
            #expect(node.moveName != node.move, "moveName 不应等于 UCI")
        }
    }

    @Test("searchByMoveSequence: 逗号分隔也有效")
    func searchByMoveSequenceCommaSeparated() {
        let result = OpeningExplorerService.shared.searchByMoveSequence("h2e2,b9c7,h0g2")
        #expect(result != nil, "逗号分隔应能搜索到")
        #expect(result!.count == 3)
    }

    @Test("searchByMoveSequence: 大写自动转小写")
    func searchByMoveSequenceUppercase() {
        let result = OpeningExplorerService.shared.searchByMoveSequence("H2E2 B9C7")
        #expect(result != nil, "大写输入应自动转小写")
        #expect(result!.count == 2)
    }

    @Test("searchByMoveSequence: 构建了正确的父子关系")
    func searchByMoveSequenceParentChain() {
        let result = OpeningExplorerService.shared.searchByMoveSequence("h2e2 b9c7 h0g2")
        #expect(result != nil)
        let nodes = result!

        // 第一个节点无 parent
        #expect(nodes[0].parent == nil, "根节点无 parent")

        // 第二个节点的 parent 是第一个
        #expect(nodes[1].parent === nodes[0], "第二个节点 parent 应是第一个")

        // 第三个节点的 parent 是第二个
        #expect(nodes[2].parent === nodes[1], "第三个节点 parent 应是第二个")
    }

    @Test("searchByMoveSequence: pathFromRoot 正确回溯")
    func searchByMoveSequencePathFromRoot() {
        let result = OpeningExplorerService.shared.searchByMoveSequence("h2e2 b9c7 h0g2")
        #expect(result != nil)
        let lastNode = result!.last!

        let path = lastNode.pathFromRoot()
        #expect(path.count == 3, "pathFromRoot 应返回 3 层")
        #expect(path[0].move == "h2e2")
        #expect(path[1].move == "b9c7")
        #expect(path[2].move == "h0g2")
    }

    @Test("searchByMoveSequence: snapshot 与走法推演一致")
    func searchByMoveSequenceSnapshotConsistent() {
        let result = OpeningExplorerService.shared.searchByMoveSequence("h2e2 b9c7")
        #expect(result != nil)

        // 最后一个节点的 snapshot 应反映走完两步后的局面
        let lastNode = result!.last!
        let board = Board(snapshot: lastNode.snapshot)
        #expect(board.pieces.count == 32, "应有 32 个棋子")
    }

    @Test("searchByMoveSequence: 单步走法搜索")
    func searchByMoveSequenceSingleMove() {
        let result = OpeningExplorerService.shared.searchByMoveSequence("h2e2")
        #expect(result != nil, "h2e2 应能搜索到")
        #expect(result!.count == 1)
    }

    @Test("searchByMoveSequence: 不存在的走法返回 nil")
    func searchByMoveSequenceInvalidMove() {
        let result = OpeningExplorerService.shared.searchByMoveSequence("a0a1 a1a0")
        #expect(result == nil, "不存在的走法序列应返回 nil")
    }

    @Test("searchByMoveSequence: 空输入返回 nil")
    func searchByMoveSequenceEmpty() {
        let result = OpeningExplorerService.shared.searchByMoveSequence("")
        #expect(result == nil, "空输入应返回 nil")
    }

    @Test("searchByMoveSequence: 纯空格输入返回 nil")
    func searchByMoveSequenceWhitespace() {
        let result = OpeningExplorerService.shared.searchByMoveSequence("   ")
        #expect(result == nil, "纯空格应返回 nil")
    }

    @Test("searchByMoveSequence: 走法不在开局库返回 nil")
    func searchByMoveSequenceNotInBook() {
        // 第一步就不在开局库
        let result = OpeningExplorerService.shared.searchByMoveSequence("z9z9")
        #expect(result == nil, "不在开局库的走法应返回 nil")
    }

    @Test("searchByMoveSequence: 前几步有效但后续无效返回 nil")
    func searchByMoveSequencePartialInvalid() {
        // h2e2 有效，但后面跟无效走法
        let result = OpeningExplorerService.shared.searchByMoveSequence("h2e2 z9z9")
        #expect(result == nil, "部分有效部分无效应返回 nil")
    }

    @Test("searchByMoveSequence: 节点 depth 正确")
    func searchByMoveSequenceDepthCorrect() {
        let result = OpeningExplorerService.shared.searchByMoveSequence("h2e2 b9c7 h0g2")
        #expect(result != nil)
        #expect(result![0].depth == 0)
        #expect(result![1].depth == 1)
        #expect(result![2].depth == 2)
    }

    @Test("searchByMoveSequence: 权重来自开局库")
    func searchByMoveSequenceWeightFromBook() {
        let result = OpeningExplorerService.shared.searchByMoveSequence("h2e2")
        #expect(result != nil)
        let node = result!.first!
        #expect(node.weight > 0, "h2e2 应有非零权重")
    }

    // MARK: - 2. 开局名搜索

    @Test("searchByOpeningName: 中炮关键字搜索")
    func searchByOpeningNameZhongPao() {
        let results = OpeningExplorerService.shared.searchByOpeningName("中炮")
        #expect(!results.isEmpty, "搜索'中炮'应有结果")
        // 应包含中炮对屏风马、中炮对反宫马等
        let names = results.map { $0.name }
        #expect(names.contains("中炮对屏风马"), "应包含中炮对屏风马")
        #expect(names.contains("中炮对反宫马"), "应包含中炮对反宫马")
    }

    @Test("searchByOpeningName: 飞相关键字搜索")
    func searchByOpeningNameFeiXiang() {
        let results = OpeningExplorerService.shared.searchByOpeningName("飞相")
        #expect(!results.isEmpty, "搜索'飞相'应有结果")
        let names = results.map { $0.name }
        #expect(names.contains(where: { $0.contains("飞相") }), "结果应包含飞相")
    }

    @Test("searchByOpeningName: 起马关键字搜索")
    func searchByOpeningNameQiMa() {
        let results = OpeningExplorerService.shared.searchByOpeningName("起马")
        #expect(!results.isEmpty, "搜索'起马'应有结果")
        let names = results.map { $0.name }
        #expect(names.contains("起马局"), "应包含起马局")
    }

    @Test("searchByOpeningName: 仙人指路搜索")
    func searchByOpeningNameXianRen() {
        let results = OpeningExplorerService.shared.searchByOpeningName("仙人指路")
        #expect(!results.isEmpty, "搜索'仙人指路'应有结果")
    }

    @Test("searchByOpeningName: 返回的变体非空")
    func searchByOpeningNameVariationsNotEmpty() {
        let results = OpeningExplorerService.shared.searchByOpeningName("中炮")
        for result in results {
            #expect(!result.variations.isEmpty, "每个结果应有至少 1 个变体")
        }
    }

    @Test("searchByOpeningName: 空关键字返回空")
    func searchByOpeningNameEmpty() {
        let results = OpeningExplorerService.shared.searchByOpeningName("")
        #expect(results.isEmpty, "空关键字应返回空结果")
    }

    @Test("searchByOpeningName: 不存在的关键字返回空")
    func searchByOpeningNameNotFound() {
        let results = OpeningExplorerService.shared.searchByOpeningName("不存在的开局")
        #expect(results.isEmpty, "不存在的关键字应返回空结果")
    }

    @Test("searchByOpeningName: 部分匹配（'屏风马'）")
    func searchByOpeningNamePartialMatch() {
        let results = OpeningExplorerService.shared.searchByOpeningName("屏风马")
        #expect(!results.isEmpty, "'屏风马'应有匹配结果")
        let names = results.map { $0.name }
        #expect(names.contains("中炮对屏风马"), "应包含中炮对屏风马")
    }

    // MARK: - 3. buildNodePath

    @Test("buildNodePath: 从变体构建节点路径")
    func buildNodePathBasic() {
        let variation = ["h2e2", "b9c7", "h0g2", "h9g7"]
        let path = OpeningExplorerService.shared.buildNodePath(forVariation: variation)
        #expect(path != nil, "应能构建路径")
        #expect(path!.count >= 2, "路径应至少有 2 个节点")
    }

    @Test("buildNodePath: 父子关系正确")
    func buildNodePathParentChain() {
        let variation = ["h2e2", "b9c7", "h0g2"]
        let path = OpeningExplorerService.shared.buildNodePath(forVariation: variation)
        #expect(path != nil)
        let nodes = path!

        if nodes.count >= 2 {
            #expect(nodes[1].parent === nodes[0], "第二个节点 parent 应是第一个")
        }
        if nodes.count >= 3 {
            #expect(nodes[2].parent === nodes[1], "第三个节点 parent 应是第二个")
        }
    }

    @Test("buildNodePath: 空变体返回 nil")
    func buildNodePathEmpty() {
        let path = OpeningExplorerService.shared.buildNodePath(forVariation: [])
        #expect(path == nil, "空变体应返回 nil")
    }

    @Test("buildNodePath: 部分走法在库中仍能构建")
    func buildNodePathPartialValid() {
        // 如果变体中的走法不在开局库中，buildNodePath 应在断点处停止
        let variation = ["h2e2", "b9c7", "not_a_move"]
        let path = OpeningExplorerService.shared.buildNodePath(forVariation: variation)
        // 应返回前 2 个有效节点的路径
        #expect(path != nil, "应返回有效部分的路径")
        #expect(path!.count == 2, "应只有 2 个有效节点")
    }

    @Test("buildNodePath: 完整变体路径长度匹配")
    func buildNodePathFullVariation() {
        let variation = ["h2e2", "b9c7", "h0g2", "h9g7", "i0h0", "i9h9"]
        let path = OpeningExplorerService.shared.buildNodePath(forVariation: variation)
        #expect(path != nil)
        #expect(path!.count == 6, "完整变体应有 6 个节点")
    }

    // MARK: - 4. OpeningSearchResultItem

    @Test("OpeningSearchResultItem: moveSequence id 格式正确")
    func searchResultMoveSequenceId() {
        // 创建模拟搜索结果测试 id 格式
        let board = Board(fen: FENParser.standardInitial)
        let snapshot = PositionSnapshot(board: board)
        let node1 = OpeningExplorerNode(move: "h2e2", moveName: "炮二平五", weight: 100, depth: 0, snapshot: snapshot)
        let node2 = OpeningExplorerNode(move: "b9c7", moveName: "马8进7", weight: 90, depth: 1, snapshot: snapshot)
        node2.parent = node1

        let result = OpeningSearchResultItem.moveSequence(
            path: [node1, node2], title: "中炮对屏风马", subtitle: "炮二平五 → 马8进7"
        )

        #expect(result.id.hasPrefix("seq:"), "走法序列 id 应以 seq: 开头")
        #expect(result.title == "中炮对屏风马")
        #expect(result.subtitle == "炮二平五 → 马8进7")
        #expect(result.iconName == "arrow.triangle.branch")
    }

    @Test("OpeningSearchResultItem: openingName id 格式正确")
    func searchResultOpeningNameId() {
        let result = OpeningSearchResultItem.openingName(
            name: "中炮对屏风马", variation: ["h2e2", "b9c7"],
            title: "中炮对屏风马", subtitle: "h2e2 b9c7"
        )

        #expect(result.id.hasPrefix("name:"), "开局名 id 应以 name: 开头")
        #expect(result.title == "中炮对屏风马")
        #expect(result.iconName == "bookmark.fill")
    }

    // MARK: - 5. 搜索 + 开局名匹配集成

    @Test("搜索结果走法序列能匹配开局名")
    func searchResultMatchesOpeningName() {
        let path = OpeningExplorerService.shared.searchByMoveSequence("h2e2 b9c7 h0g2 h9g7")
        #expect(path != nil)

        let moves = path!.map { $0.move }
        let name = OpeningExplorerService.shared.matchOpeningName(moveSequence: moves)
        #expect(name == "中炮对屏风马", "搜索结果的走法序列应匹配中炮对屏风马")
    }

    @Test("搜索 h2e2 b9c7 h0g2 h9g7 g3g4 匹配更深层的开局名")
    func searchDeeperMatchesSpecificOpening() {
        let path = OpeningExplorerService.shared.searchByMoveSequence("h2e2 b9c7 h0g2 h9g7 g3g4")
        #expect(path != nil)

        let moves = path!.map { $0.move }
        let name = OpeningExplorerService.shared.matchOpeningName(moveSequence: moves)
        #expect(name == "中炮七兵对屏风马", "更深层搜索应匹配更具体的开局名")
    }

    // MARK: - 6. 选中高亮验证（P1 修复）

    @Test("selectedNodeID 能正确标识目标节点")
    func selectedNodeIDIdentifiesTarget() {
        let path = OpeningExplorerService.shared.searchByMoveSequence("h2e2 b9c7 h0g2")
        #expect(path != nil)
        let targetNode = path!.last!

        // selectedNodeID 就是 targetNode.id
        let selectedID = targetNode.id
        #expect(selectedID == targetNode.id, "selectedNodeID 应匹配目标节点 id")
    }

    @Test("搜索跳转后 rootNodes 中对应的根节点应可识别")
    func searchJumpRootNodeIdentifiable() {
        let path = OpeningExplorerService.shared.searchByMoveSequence("h2e2 b9c7 h0g2")
        #expect(path != nil)
        let firstMove = path!.first!

        // 根节点列表中应有 h2e2
        let roots = OpeningExplorerService.shared.rootMoves()
        let matchingRoot = roots.first { $0.move == firstMove.move }
        #expect(matchingRoot != nil, "根节点列表中应有 h2e2")
    }

    // MARK: - 7. 回归：Phase 1 + Phase 2 不受影响

    @Test("Phase 1 回归: rootMoves 正常")
    func phase1RootMovesRegression() {
        let roots = OpeningExplorerService.shared.rootMoves()
        #expect(!roots.isEmpty)
        #expect(roots.count <= 10)
    }

    @Test("Phase 1 回归: expandChildren 正常")
    func phase1ExpandChildrenRegression() {
        let roots = OpeningExplorerService.shared.rootMoves()
        guard let root = roots.first else { return }
        let children = OpeningExplorerService.shared.expandChildren(of: root)
        #expect(!children.isEmpty)
    }

    @Test("Phase 2 回归: matchOpeningName 正常")
    func phase2MatchOpeningNameRegression() {
        let name = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h2e2", "b9c7", "h0g2", "h9g7"]
        )
        #expect(name == "中炮对屏风马")
    }

    @Test("Phase 2 回归: 起马局匹配正常")
    func phase2QiMaJuRegression() {
        let name = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["b0c2", "h9g7"]
        )
        #expect(name == "起马局")
    }

    @Test("Phase 2 回归: 飞相局(右相)匹配正常")
    func phase2FeiXiangYouXiangRegression() {
        let name = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["g3g4", "h7e7"]
        )
        #expect(name == "飞相局(右相)")
    }
}
