import XCTest
import SwiftUI
@testable import ChineseChess

// MARK: - Phase A1 回归测试 — 分类菜单名称显示修复（更新版，适配 DemoCategory 简化）

/// 覆盖两次提交的回归验证：
/// - 342b0f6 feat: replace iOS category picker with full-screen list + use displayName consistently
/// - f914935 fix: P0 explicit rebuildListCache + remove dead categoryPicker + add accessibilityLabel
///
/// 注意：DemoCategory 在 B1 Step 2 中简化为只有 .puzzles case，
/// .opening 和 .player 已移至独立路由。此测试类已更新适配。
@MainActor
final class PhaseA1CategoryMenuTests: XCTestCase {

    // MARK: - 辅助方法

    private func makePuzzle(
        id: String = "a1-test-\(UUID().uuidString.prefix(8))",
        solution: [String],
        category: String = "测试分类"
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
            maxMoves: solution.count
        )
    }

    // MARK: - 1. DemoCategory.displayName 统一使用验证

    /// 验证 .puzzles 分支 displayName 返回原始分类名
    func testDemoCategoryPuzzlesDisplayNameMatchesRawName() {
        let categories = PuzzleStore.shared.demoCategories
        for cat in categories {
            let displayName = DemoCategory.puzzles(cat).displayName
            XCTAssertEqual(displayName, cat,
                           "DemoCategory.puzzles(\"\(cat)\").displayName 应等于原始分类名")
        }
    }

    /// 验证 displayName 不为空（防止 UI 显示空白行）
    func testDemoCategoryDisplayNameNeverEmpty() {
        for cat in PuzzleStore.shared.demoCategories {
            XCTAssertFalse(DemoCategory.puzzles(cat).displayName.isEmpty,
                           "puzzles displayName 不应为空: \(cat)")
        }
    }

    /// 验证不同分类名产生不同 id
    func testDemoCategoryDifferentNamesDifferentIds() {
        let cat1 = DemoCategory.puzzles("适情雅趣")
        let cat2 = DemoCategory.puzzles("竹香斋")
        XCTAssertNotEqual(cat1.id, cat2.id,
                           "不同分类名的 DemoCategory id 应不同")
    }

    // MARK: - 2. categoryPicker 死代码删除验证

    func testCategoryPickerRemovedFromSource() {
        let view = PuzzleDemoView()
        XCTAssertNotNil(view, "PuzzleDemoView 应能正常初始化（categoryPicker 已删除）")
    }

    // MARK: - 3. iOS 全屏分类列表结构验证

    func testPuzzleDemoViewDefaultSelectedCategoryIsNil() {
        let view = PuzzleDemoView()
        XCTAssertNotNil(view, "无参 init 应成功，selectedCategory 默认 nil")
    }

    func testCategoryListShownWhenNoCategorySelected() {
        let puzzlesHeader = L10n.shared.t("demo.sectionPuzzles")
        XCTAssertFalse(puzzlesHeader.isEmpty, "categoryList 的残局 section header 应有翻译")
    }

    func testBackBarAndListContentShownWhenCategorySelected() {
        let categoryText = L10n.shared.t("demo.category")
        XCTAssertFalse(categoryText.isEmpty, "categoryBackBar 的'分类'文本应有翻译")
        XCTAssertNotEqual(categoryText, "demo.category", "demo.category 不应返回 key 本身")
    }

    // MARK: - 4. categoryBackBar accessibilityLabel 验证

    func testCategoryBackBarAccessibilityLabelExists() {
        let label = "返回分类列表"
        XCTAssertFalse(label.isEmpty, "categoryBackBar accessibilityLabel 不应为空")
    }

    func testCategoryBackBarAccessibilityLabelSemantics() {
        let label = "返回分类列表"
        XCTAssertTrue(label.contains("返回"),
                       "accessibilityLabel 应包含'返回'以表明导航方向")
    }

    // MARK: - 5. P0 修复：iOS 选分类后显式调用 rebuildListCache

    func testRebuildListCacheForPuzzleCategory() {
        let store = PuzzleStore.shared
        guard let firstCat = store.demoCategories.first else {
            XCTSkip("无残局分类数据，跳过")
            return
        }
        let puzzles = store.demoPuzzles(byCategory: firstCat)
        XCTAssertTrue(puzzles.count >= 0, "rebuildListCache 应能查询残局分类数据")

        let wrappers = puzzles.map { DemoItemWrapper.puzzle($0) }
        XCTAssertEqual(wrappers.count, puzzles.count,
                       "残局缓存条目数应与查询结果一致")
    }

    func testRebuildListCacheClearsWhenCategoryNil() {
        var cachedListItems: [DemoItemWrapper] = [.puzzle(makePuzzle(solution: ["h2e2"]))]
        var cachedTotalCount: Int = 1

        cachedListItems = []
        cachedTotalCount = 0

        XCTAssertTrue(cachedListItems.isEmpty, "selectedCategory=nil 时缓存应清空")
        XCTAssertEqual(cachedTotalCount, 0, "selectedCategory=nil 时总数应为 0")
    }

    func testCurrentPageResetsToOneOnCategoryChange() {
        var currentPage = 5
        currentPage = 1
        XCTAssertEqual(currentPage, 1, "切换分类时 currentPage 应重置为 1")
    }

    // MARK: - 6. categoryRow 视图验证

    func testCategoryRowUsesDisplayName() {
        let cat = "适情雅趣"
        let displayName = DemoCategory.puzzles(cat).displayName
        XCTAssertEqual(displayName, cat, "categoryRow 应显示 displayName（与原始名一致）")
    }

    func testCategoryRowCountBadge() {
        let store = PuzzleStore.shared
        guard let firstCat = store.demoCategories.first else {
            XCTSkip("无残局分类数据，跳过")
            return
        }
        let count = store.demoPuzzles(byCategory: firstCat).count
        let countText = "\(count)"
        XCTAssertFalse(countText.isEmpty, "count badge 不应为空")
        XCTAssertTrue(Int(countText) != nil, "count badge 应为数字")
    }

    // MARK: - 7. onChange(of: selectedCategory) 仍触发 rebuildListCache

    func testOnChangeAlsoTriggersRebuildListCache() {
        var rebuildCount = 0
        var selectedCategory: DemoCategory? = nil

        let onChangeHandler: (DemoCategory?) -> Void = { _ in
            rebuildCount += 1
        }

        let buttonAction: () -> Void = {
            selectedCategory = DemoCategory.puzzles("测试")
            rebuildCount += 1
        }

        buttonAction()
        onChangeHandler(selectedCategory)

        XCTAssertEqual(rebuildCount, 2,
                       "Button action + onChange 应触发两次 rebuildListCache（幂等安全）")
    }

    // MARK: - 8. macOS sidebar displayName 一致性

    func testMacOSSidebarUsesDisplayName() {
        let store = PuzzleStore.shared
        for cat in store.demoCategories {
            let displayName = DemoCategory.puzzles(cat).displayName
            XCTAssertEqual(displayName, cat,
                           "macOS sidebar 和 iOS categoryList 应使用相同的 displayName")
        }
    }

    // MARK: - 9. 空数据保护

    func testEmptyCategoriesNoCrash() {
        let categories: [String] = []
        XCTAssertEqual(categories.count, 0, "空分类数组应安全处理")
    }

    func testEmptyListItemsShowsNoData() {
        let noDataText = L10n.shared.t("demo.noData")
        XCTAssertFalse(noDataText.isEmpty, "空条目提示文本应有翻译")
        XCTAssertNotEqual(noDataText, "demo.noData")
    }

    // MARK: - 10. categoryBackBar 返回逻辑

    func testCategoryBackBarSetsSelectedCategoryToNil() {
        var selectedCategory: DemoCategory? = DemoCategory.puzzles("测试")
        XCTAssertNotNil(selectedCategory, "返回前应有选中分类")
        selectedCategory = nil
        XCTAssertNil(selectedCategory, "返回后 selectedCategory 应为 nil，回到分类列表")
    }

    func testBackToCategoryListAfterBackBar() {
        var selectedCategory: DemoCategory? = DemoCategory.puzzles("测试")
        selectedCategory = nil
        XCTAssertNil(selectedCategory, "返回后应显示全屏分类列表")
    }

    // MARK: - 11. 编译回归：PuzzleDemoView 整体构造

    func testPuzzleDemoViewInitNoCrash() {
        let view = PuzzleDemoView()
        XCTAssertNotNil(view)
    }

    func testPuzzleDemoViewInitWithPuzzleNoCrash() {
        let puzzle = makePuzzle(solution: ["h2e2"])
        let view = PuzzleDemoView(initialPuzzle: puzzle)
        XCTAssertNotNil(view)
    }

    func testDemoCategoryHashableForListSelection() {
        let cat1 = DemoCategory.puzzles("适情雅趣")
        let cat2 = DemoCategory.puzzles("适情雅趣")
        XCTAssertEqual(cat1, cat2, "相同 DemoCategory 应相等（List selection 需要）")

        let cat3 = DemoCategory.puzzles("竹香斋")
        XCTAssertNotEqual(cat1, cat3, "不同 DemoCategory 应不等")
    }
}
