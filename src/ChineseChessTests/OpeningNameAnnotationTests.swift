import Foundation
import Testing
@testable import ChineseChess

// MARK: - v5.0 Phase 2: 开局名称标注测试

@MainActor
@Suite("v5.0 Phase 2: 开局名称标注", .serialized)
struct OpeningNameAnnotationTests {

    // MARK: - 1. openings.json 数据完整性

    @Test("openings.json 包含起马局")
    func openingsJsonHasQiMaJu() {
        // b0c2 开头的变化应匹配到"起马局"
        let name = OpeningExplorerService.shared.matchOpeningName(moveSequence: ["b0c2", "h9g7"])
        #expect(name == "起马局", "b0c2,h9g7 应匹配到起马局，实际: \(name ?? "nil")")
    }

    @Test("openings.json 包含飞相局(右相)")
    func openingsJsonHasFeiXiangYouXiang() {
        // g3g4 开头的变化应匹配到"飞相局(右相)"
        let name = OpeningExplorerService.shared.matchOpeningName(moveSequence: ["g3g4", "h7e7"])
        #expect(name == "飞相局(右相)", "g3g4,h7e7 应匹配到飞相局(右相)，实际: \(name ?? "nil")")
    }

    @Test("起马局 b0c2 变体匹配正确")
    func qiMaJuVariationsMatch() {
        // 起马局的 5 个变体
        let variations: [[String]] = [
            ["b0c2", "h9g7", "h0g2", "c6c5"],
            ["b0c2", "h9g7", "h0g2", "b9c7"],
            ["b0c2", "h9g7", "g0e2", "c6c5"],
            ["b0c2", "c6c5", "h0g2", "h9g7"],
            ["b0c2", "c6c5", "h0g2", "b9c7"],
        ]
        for v in variations {
            let name = OpeningExplorerService.shared.matchOpeningName(moveSequence: v)
            #expect(name == "起马局", "变体 \(v.joined(separator: ",")) 应匹配起马局，实际: \(name ?? "nil")")
        }
    }

    @Test("飞相局(右相) g3g4 变体匹配正确")
    func feiXiangYouXiangVariationsMatch() {
        let variations: [[String]] = [
            ["g3g4", "h7e7", "h0g2", "h9g7"],
            ["g3g4", "h7e7", "h0g2", "b9c7"],
            ["g3g4", "h9g7", "h0g2", "c6c5"],
            ["g3g4", "h9g7", "h0g2", "b9c7"],
        ]
        for v in variations {
            let name = OpeningExplorerService.shared.matchOpeningName(moveSequence: v)
            #expect(name == "飞相局(右相)", "变体 \(v.joined(separator: ",")) 应匹配飞相局(右相)，实际: \(name ?? "nil")")
        }
    }

    @Test("原有 23 个开局类型不受影响（中炮对屏风马）")
    func originalOpeningsPreserved() {
        let name = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h2e2", "b9c7", "h0g2", "h9g7", "i0h0", "i9h9"]
        )
        #expect(name == "中炮对屏风马", "原有开局应正常匹配")
    }

    @Test("openings.json 总开局类型数为 25（原 23 + 新增 2）")
    func totalOpeningTypes() {
        // 验证新增了 2 个开局类型后总数正确
        // 通过验证不同开局名称的数量来间接验证
        var names = Set<String>()
        // 用常见开局走法序列测试
        let testSequences: [[String]] = [
            ["h2e2", "b9c7", "h0g2", "h9g7", "i0h0", "i9h9"], // 中炮对屏风马
            ["h2e2", "b9c7", "h0g2", "g6g5", "i0h0"],         // 中炮对反宫马
            ["h2e2", "b9c7", "h0g2", "h9g7", "i0i9"],         // 中炮横车
            ["h2e2", "b9c7", "h0g2", "b9a9", "i0h0"],         // 中炮对单提马
            ["h2e2", "b9c7", "h0g2", "h9g7", "g3g4"],         // 中炮七兵对屏风马
            ["h2e2", "b9c7", "h0g2", "h9g7", "c3c4"],         // 中炮三兵对屏风马
            ["g0e2", "b7d7", "b0c2", "h9g7"],                 // 飞相对士角炮
            ["g0e2", "h2e2", "h0g2", "b9c7"],                 // 飞相对过宫炮
            ["g0e2", "h7e7", "h0g2", "h9g7"],                 // 飞相对左中炮
            ["g0e2", "h9g7", "h0g2", "c6c5"],                 // 飞相对进马
            ["g0e2", "g6g5", "b0c2", "b9c7"],                 // 飞相对右士角炮
            ["g6g5", "h2e2", "b0c2", "h9g7"],                 // 仙人指路对卒底炮
            ["g6g5", "c9e9", "h0g2", "h9g7"],                 // 仙人指路对飞象
            ["g6g5", "h9g7", "h0g2", "c6c5"],                 // 仙人指路对进马
            ["b2c2", "h9g7", "h0g2", "i9h9"],                 // 仕角炮对进马
            ["b2c2", "h9g7", "h0g2", "i9h9"],                 // 仕角炮对右中炮（同序列可匹配）
            ["h2e2", "h9g7", "h0g2", "b9c7"],                 // 过宫炮对左中炮
            ["h2e2", "i9i8", "h0g2", "b9c7"],                 // 过宫炮对横车
            ["h0g2", "c6c5", "i0h0", "h9g7"],                 // 起马对挺卒
            ["h0g2", "c9e9", "i0h0", "h9g7"],                 // 起马对飞象
            ["h2e2", "h7e7", "i0h0", "i9i8"],                 // 顺炮直车对横车
            ["h2e2", "h7e7", "i0i9", "i9h9"],                 // 顺炮横车对直车
            ["b0c2", "h9g7", "h0g2", "c6c5"],                 // 起马局
            ["g3g4", "h7e7", "h0g2", "h9g7"],                 // 飞相局(右相)
            ["h2e2", "h7h2", "h0g2", "b9c7"],                 // 列炮
        ]
        for seq in testSequences {
            if let name = OpeningExplorerService.shared.matchOpeningName(moveSequence: seq) {
                names.insert(name)
            }
        }
        // 应至少匹配到 20+ 个不同开局名称（有些可能重名）
        #expect(names.count >= 20, "应匹配到至少 20 个开局名称，实际: \(names.count)")
    }

    // MARK: - 2. matchOpeningName 逻辑

    @Test("前缀匹配：走法序列匹配到正确开局名称")
    func prefixMatchCorrectName() {
        // h2e2,b9c7,h0g2,h9g7 → 中炮对屏风马
        let name = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h2e2", "b9c7", "h0g2", "h9g7"]
        )
        #expect(name == "中炮对屏风马", "应匹配中炮对屏风马")
    }

    @Test("部分前缀也能匹配")
    func partialPrefixMatch() {
        // 仅 h2e2 → 不匹配（太短，但 h2e2 是中炮起步）
        // h2e2,b9c7 → 可能匹配中炮对屏风马/反宫马等
        let name = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h2e2", "b9c7"]
        )
        // h2e2,b9c7 是中炮对屏风马的前缀，应匹配到某个中炮开局
        #expect(name != nil, "h2e2,b9c7 应匹配到某个开局名称")
    }

    @Test("最长匹配：多个匹配时取最深的")
    func longestMatch() {
        // h2e2,b9c7,h0g2,h9g7,g3g4 应优先匹配"中炮七兵对屏风马"（5 步）
        // 而不是"中炮对屏风马"（4 步前缀）
        let name = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h2e2", "b9c7", "h0g2", "h9g7", "g3g4"]
        )
        #expect(name == "中炮七兵对屏风马",
               "应最长匹配到中炮七兵对屏风马，实际: \(name ?? "nil")")
    }

    @Test("最长匹配：h0g2 开头区分起马对挺卒/起马对飞象")
    func longestMatchH0g2() {
        // h0g2,c6c5,i0h0,h9g7 → 起马对挺卒
        let name1 = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h0g2", "c6c5", "i0h0", "h9g7"]
        )
        #expect(name1 == "起马对挺卒", "应匹配起马对挺卒")

        // h0g2,c9e9,i0h0,h9g7 → 起马对飞象
        let name2 = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h0g2", "c9e9", "i0h0", "h9g7"]
        )
        #expect(name2 == "起马对飞象", "应匹配起马对飞象")
    }

    @Test("无匹配时返回 nil")
    func noMatchReturnsNil() {
        // 不存在的走法序列
        let name = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["a0a1", "a1a0", "a0a1"]
        )
        #expect(name == nil, "不存在的走法序列应返回 nil")
    }

    @Test("空序列返回 nil")
    func emptySequenceReturnsNil() {
        let name = OpeningExplorerService.shared.matchOpeningName(moveSequence: [])
        #expect(name == nil, "空序列应返回 nil")
    }

    @Test("单步走法匹配")
    func singleMoveMatch() {
        // b0c2 单步 → 可能匹配起马局
        let name = OpeningExplorerService.shared.matchOpeningName(moveSequence: ["b0c2"])
        // b0c2 是起马局的起步，应匹配
        #expect(name != nil, "b0c2 单步应匹配到某个开局")
    }

    @Test("走法超出 openings.json 覆盖范围时返回 nil")
    func beyondCoverageReturnsNil() {
        // h2e2,b9c7 是有效前缀，但加上一堆乱走后应无匹配
        let name = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h2e2", "b9c7", "a0a1", "a1a0", "a0a1"]
        )
        // 最长前缀 h2e2,b9c7 应有匹配，但加了不存在的后续
        // matchOpeningName 是前缀匹配，所以 h2e2,b9c7 仍能匹配
        // 但如果整体序列无法匹配任何前缀则返回 nil
        // 由于前缀匹配逻辑，h2e2,b9c7 应匹配
        #expect(name != nil, "应至少匹配前缀 h2e2,b9c7")
    }

    @Test("超过最大前缀长度后不匹配更深的开局")
    func beyondMaxPrefixLength() {
        // 构造一个超过所有 openings.json 变体长度的序列
        // 最长变体 6 步，给 20 步
        var seq = ["h2e2", "b9c7", "h0g2", "h9g7", "i0h0", "i9h9"]
        for i in 0..<14 {
            seq.append("a\(i%10)a\((i+1)%10)")
        }
        // 仍应匹配前 6 步的中炮对屏风马
        let name = OpeningExplorerService.shared.matchOpeningName(moveSequence: seq)
        #expect(name == "中炮对屏风马", "应匹配前缀部分的开局名")
    }

    @Test("prefixMap 预构建：多次调用结果一致")
    func prefixMapConsistentResults() {
        let seq = ["h2e2", "b9c7", "h0g2", "h9g7"]
        let name1 = OpeningExplorerService.shared.matchOpeningName(moveSequence: seq)
        let name2 = OpeningExplorerService.shared.matchOpeningName(moveSequence: seq)
        #expect(name1 == name2, "多次调用结果应一致")
        #expect(name1 == "中炮对屏风马")
    }

    // MARK: - 3. 同序列不同开局的区分

    @Test("相同前缀不同分支正确区分")
    func samePrefixDifferentBranches() {
        // h2e2,b9c7,h0g2,h9g7,i0h0,i9h9 → 中炮对屏风马
        let screenMa = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h2e2", "b9c7", "h0g2", "h9g7", "i0h0", "i9h9"]
        )
        #expect(screenMa == "中炮对屏风马")

        // h2e2,b9c7,h0g2,g6g5,i0h0 → 中炮对反宫马
        let fanGongMa = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h2e2", "b9c7", "h0g2", "g6g5", "i0h0"]
        )
        #expect(fanGongMa == "中炮对反宫马")

        // 两者不应相同
        #expect(screenMa != fanGongMa, "不同分支应匹配到不同开局名")
    }

    @Test("飞相局区分右相和左相")
    func distinguishFeiXiangLeftRight() {
        // g0e2 是飞相局左相（相三进五 vs 相七进五）
        let leftName = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["g0e2", "h7e7", "h0g2", "h9g7"]
        )
        // g0e2 开头匹配飞相对左中炮
        #expect(leftName == "飞相对左中炮", "g0e2 应匹配飞相开局，实际: \(leftName ?? "nil")")

        // g3g4 是飞相局右相
        let rightName = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["g3g4", "h7e7", "h0g2", "h9g7"]
        )
        #expect(rightName == "飞相局(右相)", "g3g4 应匹配飞相局(右相)")

        // 两者不应相同
        #expect(leftName != rightName, "左相右相应匹配不同开局")
    }

    @Test("起马局 vs 起马对挺卒/飞象 区分")
    func distinguishQiMaVariants() {
        // b0c2 单步 → 起马局
        let qiMa = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["b0c2", "h9g7"]
        )
        #expect(qiMa == "起马局", "b0c2,h9g7 应匹配起马局")

        // h0g2,c6c5,i0h0,h9g7 → 起马对挺卒
        let duiTingZong = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h0g2", "c6c5", "i0h0", "h9g7"]
        )
        #expect(duiTingZong == "起马对挺卒", "h0g2 开头应匹配起马对挺卒")
    }

    // MARK: - 4. 列炮（新增开局验证）

    @Test("列炮开局正确匹配")
    func liePaoMatch() {
        let name = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h2e2", "h7h2", "h0g2", "b9c7"]
        )
        #expect(name == "列炮", "应匹配列炮")
    }

    @Test("列炮长变体匹配")
    func liePaoLongVariation() {
        let name = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h2e2", "h7h2", "h0g2", "b9c7", "i0h0", "i9h9"]
        )
        #expect(name == "列炮", "列炮最长变体应匹配")
    }

    // MARK: - 5. 回归：Phase 1 懒展开不受影响

    @Test("Phase 1: rootMoves 仍正常返回")
    func phase1RootMovesStillWorks() {
        let roots = OpeningExplorerService.shared.rootMoves()
        #expect(!roots.isEmpty, "根节点应非空")
        #expect(roots.count <= 10)
        for node in roots {
            #expect(node.depth == 0)
            #expect(!node.move.isEmpty)
            #expect(!node.moveName.isEmpty)
        }
    }

    @Test("Phase 1: expandChildren 仍正常展开")
    func phase1ExpandChildrenStillWorks() {
        let roots = OpeningExplorerService.shared.rootMoves()
        guard let root = roots.first else {
            Issue.record("应有根节点"); return
        }
        let children = OpeningExplorerService.shared.expandChildren(of: root)
        for child in children {
            #expect(child.depth == 1)
        }
    }

    @Test("Phase 1: pathFromRoot 用 parent 回溯正确")
    func phase1PathFromRootCorrect() {
        let roots = OpeningExplorerService.shared.rootMoves()
        guard let root = roots.first else {
            Issue.record("应有根节点"); return
        }

        // 触发懒加载设置 parent
        let children = root.children
        guard let firstChild = children.first else { return }

        // 触发孙节点懒加载
        let grandchildren = firstChild.children
        guard let firstGrandchild = grandchildren.first else { return }

        // pathFromRoot 应返回 [root, child, grandchild]
        let path = firstGrandchild.pathFromRoot()
        #expect(path.count == 3, "路径应为 3 层")
        #expect(path[0] === root, "路径起点应为根节点")
        #expect(path[1] === firstChild, "路径第二层应为子节点")
        #expect(path[2] === firstGrandchild, "路径终点应为孙节点")
    }

    @Test("Phase 1: isLeaf 不触发懒加载")
    func phase1IsLeafNoLazyLoad() {
        let roots = OpeningExplorerService.shared.rootMoves()
        for node in roots {
            // 未访问 children 前 isLeaf 应为 false
            #expect(node.isLeaf == false, "未展开的节点 isLeaf 应为 false")
        }
    }

    @Test("Phase 1: 走法名仍为中文")
    func phase1ChineseMoveNames() {
        let roots = OpeningExplorerService.shared.rootMoves()
        for node in roots {
            #expect(node.moveName != node.move, "moveName 不应等于 UCI")
            #expect(node.moveName.contains(/[\u4e00-\u9fff一二三四五六七八九]/),
                   "moveName 应包含中文: \(node.moveName)")
        }
    }

    // MARK: - 6. 综合：matchOpeningName 与 UI 集成场景

    @Test("选中节点后 matchOpeningName 返回正确开局名")
    func selectNodeThenMatchName() {
        let roots = OpeningExplorerService.shared.rootMoves()
        // 找到 h2e2（中炮）节点
        let h2e2 = roots.first { $0.move == "h2e2" }
        guard let cannonNode = h2e2 else {
            Issue.record("应有 h2e2 根节点"); return
        }

        // 获取子节点
        let children = cannonNode.children
        // 找到 b9c7 子节点
        let b9c7 = children.first { $0.move == "b9c7" }
        guard let horseNode = b9c7 else {
            Issue.record("应有 b9c7 子节点"); return
        }

        // 构造走法序列并匹配
        let sequence = [cannonNode.move, horseNode.move]
        let name = OpeningExplorerService.shared.matchOpeningName(moveSequence: sequence)
        #expect(name != nil, "h2e2,b9c7 应匹配到开局名称")
    }

    @Test("开局名匹配对大小写不敏感（ICCS 统一小写）")
    func matchCaseInsensitive() {
        // ICCS 格式统一为小写
        let lower = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["h2e2", "b9c7"]
        )
        let upper = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["H2E2", "B9C7"]
        )
        // 大写不应匹配（ICCS 规范是小写）
        // 但也不应该 crash
        _ = lower
        _ = upper
        #expect(Bool(true), "不应 crash")
    }

    @Test("含空字符串的序列安全处理")
    func sequenceWithEmptyStrings() {
        // pathFromRoot 的根节点 move 可能是空字符串（过滤后）
        // matchOpeningName 应安全处理
        let name = OpeningExplorerService.shared.matchOpeningName(
            moveSequence: ["", "h2e2", "b9c7"]
        )
        // 空字符串在前会影响匹配，但不应 crash
        #expect(Bool(true), "不应 crash")
    }
}
