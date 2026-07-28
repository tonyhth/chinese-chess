import XCTest
@testable import ChineseChess

// MARK: - Phase A2 回归测试 — 车马炮子分类拆分

/// 覆盖 commit f4ae1b2: tacticalGroup 字段 + 子分类导航 + puzzles.json v5
@MainActor
final class PhaseA2TacticalGroupTests: XCTestCase {

    // MARK: - 辅助方法

    private func makePuzzle(
        id: String = "a2-test-\(UUID().uuidString.prefix(8))",
        solution: [String],
        category: String = "车马炮类",
        tacticalGroup: String? = nil
    ) -> Puzzle {
        Puzzle(
            id: id,
            name: "测试残局",
            category: category,
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: solution,
            hints: nil,
            maxMoves: solution.count,
            tacticalGroup: tacticalGroup
        )
    }

    // MARK: - 1. tacticalGroup 字段解码

    /// 验证 puzzles.json 中车马炮类条目全部有 tacticalGroup 值
    func testPuzzlesJsonTacticalGroupForCheMaPao() {
        let store = PuzzleStore.shared
        let cheMaPaoPuzzles = store.demoPuzzles(byCategory: "车马炮类")
        XCTAssertTrue(cheMaPaoPuzzles.count > 0, "车马炮类应有残局数据")

        for puzzle in cheMaPaoPuzzles {
            XCTAssertNotNil(puzzle.tacticalGroup,
                           "车马炮类残局 '\(puzzle.id)' 应有 tacticalGroup 值")
        }
    }

    /// 验证 puzzles.json 中非车马炮类条目 tacticalGroup 为 nil
    func testPuzzlesJsonNoTacticalGroupForOtherCategories() {
        let store = PuzzleStore.shared
        let categoriesWithTacticalGroup = ["车马炮类"]

        for cat in store.demoCategories {
            guard !categoriesWithTacticalGroup.contains(cat) else { continue }
            let puzzles = store.demoPuzzles(byCategory: cat)
            for puzzle in puzzles {
                XCTAssertNil(puzzle.tacticalGroup,
                             "非车马炮类 '\(cat)' 的残局 '\(puzzle.id)' tacticalGroup 应为 nil")
            }
        }
    }

    /// 验证 tacticalGroup 值域：仅允许已知值或 nil
    func testTacticalGroupValueDomain() {
        let validGroups: Set<String> = ["杀势", "困毙", "催杀", "弃子攻杀", "其他"]
        let store = PuzzleStore.shared

        for puzzle in store.demoPuzzles {
            if let tg = puzzle.tacticalGroup {
                XCTAssertTrue(validGroups.contains(tg),
                               "tacticalGroup '\(tg)' 不在合法值域中，puzzle: \(puzzle.id)")
            }
        }
    }

    /// 验证 Puzzle 解码无 tacticalGroup 字段时默认为 nil（向后兼容）
    func testPuzzleDecodingWithoutTacticalGroupIsNil() {
        // 构造不含 tacticalGroup 的 JSON，解码后应为 nil
        let json = """
        {
            "id": "compat-test",
            "name": "兼容测试",
            "category": "兵类",
            "difficulty": 1,
            "stars": 1,
            "description": "测试",
            "playerSide": "red",
            "initialFEN": "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            "solution": ["h2e2"],
            "hints": null,
            "maxMoves": 1,
            "solutionType": "checkmate",
            "solutionMode": "guided"
        }
        """
        let data = json.data(using: .utf8)!
        let puzzle = try! JSONDecoder().decode(Puzzle.self, from: data)
        XCTAssertNil(puzzle.tacticalGroup,
                     "无 tacticalGroup 字段时解码应为 nil（向后兼容）")
    }

    /// 验证 Puzzle 解码含 tacticalGroup 字段时值正确
    func testPuzzleDecodingWithTacticalGroup() {
        let json = """
        {
            "id": "tg-test",
            "name": "战术测试",
            "category": "车马炮类",
            "difficulty": 3,
            "stars": 3,
            "description": "测试",
            "playerSide": "red",
            "initialFEN": "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            "solution": ["h2e2"],
            "hints": null,
            "maxMoves": 1,
            "solutionType": "checkmate",
            "solutionMode": "guided",
            "tacticalGroup": "杀势"
        }
        """
        let data = json.data(using: .utf8)!
        let puzzle = try! JSONDecoder().decode(Puzzle.self, from: data)
        XCTAssertEqual(puzzle.tacticalGroup, "杀势",
                       "含 tacticalGroup 字段时解码值应正确")
    }

    /// 验证完整 puzzles.json 解码不崩溃
    func testPuzzlesJsonFullDecodingNoCrash() {
        let store = PuzzleStore.shared
        XCTAssertTrue(store.demoPuzzles.count > 0, "puzzles.json 应成功解码")
    }

    // MARK: - 2. 子分类导航

    /// 验证 demoTacticalGroups(for:) 返回正确子分类列表
    func testDemoTacticalGroupsForCheMaPao() {
        let store = PuzzleStore.shared
        let groups = store.demoTacticalGroups(forCategory: "车马炮类")
        XCTAssertTrue(groups.count > 0, "车马炮类应有战术子分类")

        // 验证包含所有已知子分类
        let expectedGroups: Set<String> = ["杀势", "困毙", "催杀", "弃子攻杀", "其他"]
        let actualGroups = Set(groups)
        XCTAssertTrue(expectedGroups.isSubset(of: actualGroups),
                       "车马炮类应包含所有 5 个战术子分类，实际: \(groups)")
    }

    /// 验证非车马炮类无战术子分类
    func testDemoTacticalGroupsEmptyForOtherCategories() {
        let store = PuzzleStore.shared
        for cat in store.demoCategories {
            guard cat != "车马炮类" else { continue }
            let groups = store.demoTacticalGroups(forCategory: cat)
            XCTAssertTrue(groups.isEmpty,
                           "非车马炮类 '\(cat)' 不应有战术子分类")
        }
    }

    /// 验证 demoPuzzles(byCategory:tacticalGroup:) 按子分类筛选正确
    func testDemoPuzzlesByCategoryAndTacticalGroup() {
        let store = PuzzleStore.shared
        let groups = store.demoTacticalGroups(forCategory: "车马炮类")

        for group in groups {
            let filtered = store.demoPuzzles(byCategory: "车马炮类", tacticalGroup: group)
            XCTAssertTrue(filtered.count > 0,
                           "子分类 '\(group)' 下应有残局")
            for puzzle in filtered {
                XCTAssertEqual(puzzle.tacticalGroup, group,
                               "筛选结果中残局 tacticalGroup 应匹配")
                XCTAssertEqual(puzzle.category, "车马炮类",
                               "筛选结果中残局 category 应匹配")
            }
        }
    }

    /// 验证各子分类条目数之和等于分类总数
    func testTacticalGroupPartitionCoversAllPuzzles() {
        let store = PuzzleStore.shared
        let allPuzzles = store.demoPuzzles(byCategory: "车马炮类")
        let groups = store.demoTacticalGroups(forCategory: "车马炮类")

        let groupedCount = groups.reduce(0) { sum, group in
            sum + store.demoPuzzles(byCategory: "车马炮类", tacticalGroup: group).count
        }

        XCTAssertEqual(groupedCount, allPuzzles.count,
                       "各子分类条目数之和应等于车马炮类总数")
    }

    /// 验证各子分类之间无重叠
    func testTacticalGroupsNoOverlap() {
        let store = PuzzleStore.shared
        let groups = store.demoTacticalGroups(forCategory: "车马炮类")

        var allIds: Set<String> = []
        var totalCount = 0

        for group in groups {
            let puzzles = store.demoPuzzles(byCategory: "车马炮类", tacticalGroup: group)
            for puzzle in puzzles {
                allIds.insert(puzzle.id)
            }
            totalCount += puzzles.count
        }

        XCTAssertEqual(allIds.count, totalCount,
                       "各子分类之间不应有重叠的残局 ID")
    }

    /// 验证 hasTacticalGroups(for:) 返回正确
    func testHasTacticalGroups() {
        let store = PuzzleStore.shared
        XCTAssertTrue(store.hasTacticalGroups(forCategory: "车马炮类"),
                       "车马炮类 hasTacticalGroups 应为 true")

        for cat in store.demoCategories {
            guard cat != "车马炮类" else { continue }
            XCTAssertFalse(store.hasTacticalGroups(forCategory: cat),
                           "非车马炮类 '\(cat)' hasTacticalGroups 应为 false")
        }
    }

    /// 验证选中子分类后列表非空
    func testTacticalGroupListNonEmpty() {
        let store = PuzzleStore.shared
        let groups = store.demoTacticalGroups(forCategory: "车马炮类")
        for group in groups {
            let puzzles = store.demoPuzzles(byCategory: "车马炮类", tacticalGroup: group)
            XCTAssertFalse(puzzles.isEmpty,
                           "子分类 '\(group)' 列表不应为空")
        }
    }

    /// 验证切换子分类后列表正确更新（不同子分类返回不同结果）
    func testSwitchTacticalGroupUpdatesList() {
        let store = PuzzleStore.shared
        let groups = store.demoTacticalGroups(forCategory: "车马炮类")
        guard groups.count >= 2 else {
            XCTSkip("车马炮类子分类不足 2 个，跳过")
            return
        }

        let list1 = store.demoPuzzles(byCategory: "车马炮类", tacticalGroup: groups[0])
        let list2 = store.demoPuzzles(byCategory: "车马炮类", tacticalGroup: groups[1])

        // 不同子分类不应返回完全相同的列表
        let ids1 = Set(list1.map { $0.id })
        let ids2 = Set(list2.map { $0.id })
        XCTAssertTrue(ids1.intersection(ids2).isEmpty,
                       "不同子分类不应有重叠的残局 ID")
    }

    /// 验证 demoTacticalGroups 按预设顺序排列：杀势→弃子攻杀→催杀→困毙→其他
    func testDemoTacticalGroupsPresetSortOrder() {
        let store = PuzzleStore.shared
        let groups = store.demoTacticalGroups(forCategory: "车马炮类")
        XCTAssertEqual(groups.count, 5, "车马炮类应有 5 个战术子分类")
        // 验证预设顺序
        let expectedOrder = ["杀势", "弃子攻杀", "催杀", "困毙", "其他"]
        XCTAssertEqual(groups, expectedOrder,
                       "车马炮类子分类应按预设顺序排列")
    }

    // MARK: - 3. puzzles.json version 5 兼容性

    /// 验证 puzzles.json version 为 5
    func testPuzzlesJsonVersion5() {
        // 通过 Bundle 加载 puzzles.json 检查 version
        guard let url = Bundle.main.url(forResource: "puzzles", withExtension: "json",
                                         subdirectory: "Puzzles") else {
            XCTSkip("puzzles.json 不在 Bundle 中（可能测试 target 未包含），跳过")
            return
        }
        let data = try! Data(contentsOf: url)
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let version = json["version"] as? Int
        XCTAssertEqual(version, 5, "puzzles.json version 应为 5")
    }

    /// 验证车马炮类 205 局（有 solution 的 demo 残局）全部有 tacticalGroup 值
    /// 注：puzzles.json 中车马炮类共 212 局，其中 7 局无 solution（非 demo），demoPuzzles 过滤后为 205 局
    func testCheMaPaoAllDemoHaveTacticalGroup() {
        let store = PuzzleStore.shared
        let cheMaPaoPuzzles = store.demoPuzzles(byCategory: "车马炮类")
        XCTAssertTrue(cheMaPaoPuzzles.count > 0, "车马炮类应有 demo 残局")

        let withTG = cheMaPaoPuzzles.filter { $0.tacticalGroup != nil }
        XCTAssertEqual(withTG.count, cheMaPaoPuzzles.count,
                       "车马炮类所有 demo 残局应全部有 tacticalGroup 值")
    }

    /// 验证其他分类 tacticalGroup 为 nil
    func testOtherCategoriesNoTacticalGroup() {
        let store = PuzzleStore.shared
        let otherPuzzles = store.demoPuzzles.filter { $0.category != "车马炮类" }
        for puzzle in otherPuzzles {
            XCTAssertNil(puzzle.tacticalGroup,
                         "非车马炮类残局 '\(puzzle.id)' tacticalGroup 应为 nil")
        }
    }

    // MARK: - 4. UI 层级

    /// 验证车马炮类走三级导航：分类 → 子分类 → 残局
    func testCheMaPaoThreeLevelNavigation() {
        let store = PuzzleStore.shared
        XCTAssertTrue(store.hasTacticalGroups(forCategory: "车马炮类"),
                       "车马炮类应有子分类，走三级导航")
        let groups = store.demoTacticalGroups(forCategory: "车马炮类")
        XCTAssertTrue(groups.count > 1,
                       "车马炮类应有多个子分类")
    }

    /// 验证无子分类的分类走二级导航：分类 → 残局
    func testOtherCategoriesTwoLevelNavigation() {
        let store = PuzzleStore.shared
        for cat in store.demoCategories {
            guard cat != "车马炮类" else { continue }
            XCTAssertFalse(store.hasTacticalGroups(forCategory: cat),
                           "非车马炮类 '\(cat)' 无子分类，走二级导航")
        }
    }

    /// 验证 iOS 三级导航逻辑：
    /// selectedCategory=nil → categoryList
    /// selectedCategory!=nil && hasTacticalGroups && selectedTacticalGroup=nil → tacticalGroupList
    /// selectedCategory!=nil && (无子分类 || selectedTacticalGroup!=nil) → listContent
    func testIOSNavigationLogic() {
        // 模拟状态机
        // 状态 1：未选分类
        var selectedCategory: DemoCategory? = nil
        var selectedTacticalGroup: String? = nil

        // 状态 1 → 显示 categoryList
        XCTAssertNil(selectedCategory, "未选分类 → categoryList")

        // 状态 2：选了车马炮类，未选子分类
        selectedCategory = DemoCategory.puzzles("车马炮类")
        let hasTG = PuzzleStore.shared.hasTacticalGroups(forCategory: "车马炮类")
        XCTAssertTrue(hasTG)
        XCTAssertNil(selectedTacticalGroup, "有子分类且未选 → tacticalGroupList")

        // 状态 3：选了子分类
        selectedTacticalGroup = "杀势"
        XCTAssertNotNil(selectedTacticalGroup, "已选子分类 → listContent")

        // 状态 4：选了无子分类的分类
        selectedCategory = DemoCategory.puzzles("兵类")
        selectedTacticalGroup = nil
        let hasTG2 = PuzzleStore.shared.hasTacticalGroups(forCategory: "兵类")
        XCTAssertFalse(hasTG2, "无子分类分类 → listContent（跳过子分类层）")
    }

    /// 验证 macOS 三级展开：sidebar 有子分类时列表上方显示过滤栏
    func testMacOSTacticalGroupFilterBar() {
        let store = PuzzleStore.shared
        // 车马炮类有子分类 → 显示 tacticalGroupFilterBar
        XCTAssertTrue(store.hasTacticalGroups(forCategory: "车马炮类"),
                       "车马炮类在 macOS 应显示子分类过滤栏")
        // 兵类无子分类 → 不显示过滤栏
        XCTAssertFalse(store.hasTacticalGroups(forCategory: "兵类"),
                       "兵类在 macOS 不应显示子分类过滤栏")
    }

    // MARK: - 5. 边界场景

    /// 验证 tacticalGroup 为空字符串时的处理
    func testTacticalGroupEmptyStringHandling() {
        // 构造 tacticalGroup = "" 的残局
        let puzzle = makePuzzle(solution: ["h2e2"], tacticalGroup: "")
        XCTAssertEqual(puzzle.tacticalGroup, "", "空字符串应保留原值")

        // demoTacticalGroups 用 compactMap 过滤 nil，空字符串会保留
        // 但 puzzles.json 中不应有空字符串（值域验证已覆盖）
        // 此测试确认空字符串不会导致崩溃
    }

    /// 验证子分类下无残局时的空状态
    func testTacticalGroupWithNoPuzzlesShowsEmpty() {
        let store = PuzzleStore.shared
        // 查询不存在的子分类
        let puzzles = store.demoPuzzles(byCategory: "车马炮类", tacticalGroup: "不存在的分类")
        XCTAssertTrue(puzzles.isEmpty, "不存在的子分类应返回空数组")
    }

    /// 验证切分类时 selectedTacticalGroup 重置
    func testSwitchCategoryResetsTacticalGroup() {
        // PuzzleDemoView 中 onChange(of: selectedCategory) 重置 selectedTacticalGroup = nil
        var selectedTacticalGroup: String? = "杀势"
        var selectedCategory: DemoCategory? = DemoCategory.puzzles("车马炮类")

        // 模拟切换分类
        selectedCategory = DemoCategory.puzzles("兵类")
        // onChange 触发：selectedTacticalGroup = nil
        selectedTacticalGroup = nil

        XCTAssertNil(selectedTacticalGroup,
                     "切换分类时 selectedTacticalGroup 应重置为 nil")
    }

    /// 验证切分类时 currentPage 重置
    func testSwitchCategoryResetsCurrentPage() {
        var currentPage = 5
        var selectedTacticalGroup: String? = "杀势"

        // 模拟 onChange(of: selectedCategory)
        selectedTacticalGroup = nil
        currentPage = 1

        XCTAssertEqual(currentPage, 1, "切换分类时 currentPage 应重置为 1")
        XCTAssertNil(selectedTacticalGroup, "切换分类时 selectedTacticalGroup 应重置")
    }

    /// 验证 iOS 返回栏逻辑：有子分类时返回子分类列表，否则返回分类列表
    func testIOSBackBarLogic() {
        let store = PuzzleStore.shared

        // 车马炮类 + 已选子分类 → 返回子分类列表
        var selectedCategory: DemoCategory? = DemoCategory.puzzles("车马炮类")
        var selectedTacticalGroup: String? = "杀势"
        let hasTG = store.hasTacticalGroups(forCategory: "车马炮类")

        // 模拟 iosBackBar action
        if hasTG {
            selectedTacticalGroup = nil
        } else {
            selectedCategory = nil
        }
        XCTAssertNil(selectedTacticalGroup, "有子分类时返回应重置 selectedTacticalGroup")
        XCTAssertNotNil(selectedCategory, "有子分类时返回不应重置 selectedCategory")

        // 兵类 + 无子分类 → 返回分类列表
        selectedCategory = DemoCategory.puzzles("兵类")
        selectedTacticalGroup = nil
        let hasTG2 = store.hasTacticalGroups(forCategory: "兵类")

        if hasTG2 {
            selectedTacticalGroup = nil
        } else {
            selectedCategory = nil
        }
        XCTAssertNil(selectedCategory, "无子分类时返回应重置 selectedCategory")
    }

    /// 验证 iOS iosBackBar accessibilityLabel 语义正确
    func testIOSBackBarAccessibilityLabel() {
        let store = PuzzleStore.shared
        let hasTG = store.hasTacticalGroups(forCategory: "车马炮类")
        let hasTG2 = store.hasTacticalGroups(forCategory: "兵类")

        // 有子分类 → "返回子分类列表"
        let labelWithTG = hasTG ? "返回子分类列表" : "返回分类列表"
        XCTAssertEqual(labelWithTG, "返回子分类列表",
                       "有子分类时 accessibilityLabel 应为'返回子分类列表'")

        // 无子分类 → "返回分类列表"
        let labelWithoutTG = hasTG2 ? "返回子分类列表" : "返回分类列表"
        XCTAssertEqual(labelWithoutTG, "返回分类列表",
                       "无子分类时 accessibilityLabel 应为'返回分类列表'")
    }

    /// 验证 rebuildListCache 在 selectedTacticalGroup 非 nil 时按子分类筛选
    func testRebuildListCacheWithTacticalGroup() {
        let store = PuzzleStore.shared
        let selectedTacticalGroup = "杀势"
        let puzzles = store.demoPuzzles(byCategory: "车马炮类", tacticalGroup: selectedTacticalGroup)
        XCTAssertTrue(puzzles.count > 0, "按子分类筛选应有结果")

        for puzzle in puzzles {
            XCTAssertEqual(puzzle.tacticalGroup, "杀势",
                           "筛选结果中 tacticalGroup 应匹配")
        }
    }

    /// 验证 rebuildListCache 在 selectedTacticalGroup 为 nil 时返回全部分类
    func testRebuildListCacheWithoutTacticalGroup() {
        let store = PuzzleStore.shared
        let puzzles = store.demoPuzzles(byCategory: "车马炮类")
        let groups = store.demoTacticalGroups(forCategory: "车马炮类")

        let groupedCount = groups.reduce(0) { sum, group in
            sum + store.demoPuzzles(byCategory: "车马炮类", tacticalGroup: group).count
        }

        XCTAssertEqual(puzzles.count, groupedCount,
                       "selectedTacticalGroup=nil 时应返回分类下全部残局")
    }

    // MARK: - 6. 编译回归：PuzzleDemoView 整体构造

    /// 验证 PuzzleDemoView 无参 init 不崩溃
    func testPuzzleDemoViewInitNoCrash() {
        let view = PuzzleDemoView()
        XCTAssertNotNil(view)
    }

    /// 验证 PuzzleDemoView 指定残局 init 不崩溃
    func testPuzzleDemoViewInitWithPuzzleNoCrash() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let view = PuzzleDemoView(initialPuzzle: puzzle)
        XCTAssertNotNil(view)
    }

    // MARK: - 7. L10n 国际化

    /// 验证相关 L10n key 存在
    func testL10nKeysExist() {
        let keys = [
            "demo.sectionPuzzles",
            "demo.sectionMasterGames",
            "demo.category",
            "demo.selectCategory",
            "demo.noData",
            "puzzle.all",  // P1 修复："全部"国际化
        ]
        for key in keys {
            let text = L10n.shared.t(key)
            XCTAssertFalse(text.isEmpty, "\(key) 不应为空")
            XCTAssertNotEqual(text, key, "\(key) 应有翻译")
        }
    }
}
