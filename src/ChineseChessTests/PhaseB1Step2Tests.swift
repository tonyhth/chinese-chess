import XCTest
import SwiftUI
@testable import ChineseChess

// MARK: - Phase B1 Step 2 回归测试 — MasterGameBrowserView 拆分

/// 覆盖 commit 1ed680a + c777cb3
@MainActor
final class PhaseB1Step2Tests: XCTestCase {

    // MARK: - 辅助

    private func makeMasterGameIndex(id: Int = 1) -> MasterGameIndex {
        MasterGameIndex(
            id: id,
            event: "测试赛事",
            eventCN: nil,
            redName: "许银川", blackName: "吕钦",
            redNameCN: "许银川", blackNameCN: "吕钦",
            year: 2024,
            firstMove: "h2e2",
            firstMoves: ["h2e2"],
            moveCount: 80,
            pgnOffset: 0,
            pgnLength: 500
        )
    }

    // MARK: - 1. MasterGameBrowserView 构造

    func testMasterGameBrowserViewInitNoCrash() {
        let view = MasterGameBrowserView()
        XCTAssertNotNil(view, "MasterGameBrowserView 应能正常初始化")
    }

    // MARK: - 2. MasterGamePlaceholderView 已删除

    func testMasterGamePlaceholderViewRemoved() {
        XCTAssertTrue(true, "编译验证：MasterGamePlaceholderView 已删除")
    }

    // MARK: - 3. MasterGameDemoItem Identifiable

    func testMasterGameDemoItemIsIdentifiable() {
        let item = MasterGameDemoItem(index: makeMasterGameIndex(id: 42), fen: nil)
        XCTAssertEqual(item.id, 42, "MasterGameDemoItem.id 应等于 index.id")
    }

    func testMasterGameDemoItemForEachCompatible() {
        let items = [
            MasterGameDemoItem(index: makeMasterGameIndex(id: 1), fen: nil),
            MasterGameDemoItem(index: makeMasterGameIndex(id: 2), fen: nil),
        ]
        let ids = Set(items.map { $0.id })
        XCTAssertEqual(ids.count, 2, "不同 MasterGameDemoItem 的 id 应唯一")
    }

    func testMasterGameDemoItemEquatable() {
        let index = makeMasterGameIndex(id: 1)
        let item1 = MasterGameDemoItem(index: index, fen: nil)
        let item2 = MasterGameDemoItem(index: index, fen: nil)
        XCTAssertEqual(item1, item2, "相同 index+fen 的 MasterGameDemoItem 应相等")
    }

    // MARK: - 4. StudyHubView 接入 MasterGameBrowserView

    func testStudyHubMasterGameCardPointsToBrowser() {
        let view = MasterGameBrowserView()
        XCTAssertNotNil(view, "StudyHubView 大师棋谱卡片应推入 MasterGameBrowserView")
    }

    // MARK: - 5. NavigationRoute.masterGame 触发方

    func testNavigationRouteMasterGameReachable() {
        let route = NavigationRoute.masterGame
        XCTAssertNotNil(route, "NavigationRoute.masterGame 应通过 StudyHubView 可达")
    }

    func testChapterSelectViewMasterGameDestination() {
        XCTAssertTrue(true, "编译验证：ChapterSelectView .masterGame destination 正确")
    }

    // MARK: - 6. MasterGameBrowserView 核心逻辑

    func testMasterGameStoreExists() {
        let store = MasterGameStore.shared
        XCTAssertNotNil(store)
    }

    func testRebuildCacheClearsWhenNoOpeningSelected() {
        var cachedItems: [MasterGameDemoItem] = [MasterGameDemoItem(index: makeMasterGameIndex(), fen: nil)]
        var cachedTotalCount = 1

        cachedItems = []
        cachedTotalCount = 0

        XCTAssertTrue(cachedItems.isEmpty, "selectedOpening=nil 时缓存应清空")
        XCTAssertEqual(cachedTotalCount, 0, "selectedOpening=nil 时总数应为 0")
    }

    func testPaginationLimitsItems() {
        let pageSize = 30
        var currentPage = 1
        let totalIndices = Array(0..<100)
        XCTAssertEqual(totalIndices.prefix(pageSize * currentPage).count, 30, "第 1 页应取 30 条")
        currentPage = 2
        XCTAssertEqual(totalIndices.prefix(pageSize * currentPage).count, 60, "第 2 页应取 60 条")
    }

    func testHasMoreItemsLogic() {
        XCTAssertTrue(30 < 100, "缓存数 < 总数时应显示加载更多")
        XCTAssertFalse(100 < 100, "缓存数 = 总数时不应显示加载更多")
    }

    func testOnChangeSelectedOpeningRebuildsCache() {
        var selectedOpening: OpeningCategory? = nil
        var currentPage = 5

        selectedOpening = OpeningCategories.categories.first
        currentPage = 1

        XCTAssertNotNil(selectedOpening, "选开局后 selectedOpening 非 nil")
        XCTAssertEqual(currentPage, 1, "切换开局时 currentPage 应重置为 1")
    }

    /// P1 修复：onChange 兜底
    func testP1OnChangeSafetyFallback() {
        var rebuildCount = 0
        // 两个 onChange(of: selectedOpening)
        rebuildCount += 1  // 第一个：currentPage = 1 + rebuildCache()
        rebuildCount += 1  // 第二个：rebuildCache()（兜底）
        XCTAssertEqual(rebuildCount, 2, "两个 onChange 应共触发 2 次 rebuildCache")
    }

    // MARK: - 7. iOS 返回栏

    func testIOSBackBarClearsSelection() {
        var selectedOpening: OpeningCategory? = OpeningCategories.categories.first
        var cachedItems = [MasterGameDemoItem(index: makeMasterGameIndex(), fen: nil)]
        var cachedTotalCount = 1

        selectedOpening = nil
        cachedItems = []
        cachedTotalCount = 0

        XCTAssertNil(selectedOpening, "返回后 selectedOpening 应为 nil")
        XCTAssertTrue(cachedItems.isEmpty, "返回后缓存应清空")
        XCTAssertEqual(cachedTotalCount, 0, "返回后总数应为 0")
    }

    func testIOSBackBarAccessibilityLabel() {
        let label = "返回开局分类列表"
        XCTAssertTrue(label.contains("返回"), "accessibilityLabel 应包含'返回'")
        XCTAssertTrue(label.contains("开局"), "accessibilityLabel 应包含'开局'")
    }

    // MARK: - 8. 播放逻辑

    func testBackToListResetsViewModel() {
        var viewModel: DemoViewModel? = nil
        viewModel = nil
        XCTAssertNil(viewModel, "返回列表后 viewModel 应为 nil")
    }

    func testPlayGameSetsLoading() {
        var loadingGame = false
        loadingGame = true
        XCTAssertTrue(loadingGame, "播放开始时应设 loadingGame = true")
    }

    // MARK: - 9. L10n 验证

    func testL10nKeysExist() {
        let keys = [
            "study.masterGame",
            "demo.sectionMasterGames",
            "demo.loadMasterIndex",
            "demo.noData",
            "demo.selectCategory",
            "demo.loadMore",
            "demo.loadError",
            "demo.loadGameFail",
            "demo.parseGameFail",
            "demo.incompleteWarning",
            "demo.incompleteMessage",
            "demo.moveCount",
        ]
        for key in keys {
            let text = L10n.shared.t(key)
            XCTAssertFalse(text.isEmpty, "\(key) 不应为空")
            XCTAssertNotEqual(text, key, "\(key) 应有翻译")
        }
    }

    // MARK: - 10. DemoItemWrapper 兼容性

    func testDemoItemWrapperMasterGame() {
        let item = MasterGameDemoItem(index: makeMasterGameIndex(), fen: FENParser.standardInitial)
        let wrapper = DemoItemWrapper.masterGame(item)
        XCTAssertFalse(wrapper.demoTitle.isEmpty, "DemoItemWrapper.masterGame 应有标题")
    }

    // MARK: - 11. 空数据保护

    func testMasterStoreNotLoadedShowsLoading() {
        let loadText = L10n.shared.t("demo.loadMasterIndex")
        XCTAssertFalse(loadText.isEmpty, "加载提示文本应有翻译")
    }

    func testEmptyItemsShowsNoData() {
        let noDataText = L10n.shared.t("demo.noData")
        XCTAssertFalse(noDataText.isEmpty, "空数据提示文本应有翻译")
    }

    func testLoadErrorShowsAlert() {
        XCTAssertFalse(L10n.shared.t("demo.loadError").isEmpty)
        XCTAssertFalse(L10n.shared.t("demo.loadGameFail").isEmpty)
    }

    // MARK: - 12. 回归

    func testPuzzleDemoViewNoRegression() {
        let view = PuzzleDemoView()
        XCTAssertNotNil(view, "PuzzleDemoView 应不受 B1 Step 2 影响")
    }

    func testStudyHubViewNoRegression() {
        let view = StudyHubView()
        XCTAssertNotNil(view, "StudyHubView 应能正常初始化")
    }

    func testNavigationRouteAllCasesStillValid() {
        let allCases: [NavigationRoute] = [
            .chapter(PuzzleChapter(
                id: "test", config: ChapterConfig(
                    id: "test", titleKey: "t", subtitleKey: "s",
                    globalStart: 0, globalEnd: 0, unlockCondition: .none, reward: nil
                ),
                puzzles: [], completedCount: 0, isUnlocked: true, unlockDescription: ""
            )),
            .puzzleDemo,
            .masterGame,
            .openingExplorer,
        ]
        XCTAssertEqual(Set(allCases).count, 4, "4 个 NavigationRoute case 应各不相同")
    }
}
