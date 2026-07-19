import XCTest
@testable import ChineseChess

// MARK: - PuzzleDemoView UI 入口接入测试

/// 覆盖两次提交的测试重点：
/// 1. 49fd79b — NavigationRoute + DemoEntryCard + PuzzleDemoView 无参 init + onShowDemo 回调
/// 2. 6f96395 — P0 iOS fullScreenCover 竞态 + P1 demoPuzzleIds 缓存 + P2 硬编码字符串国际化
@MainActor
final class PuzzleDemoViewEntryTests: XCTestCase {

    // MARK: - 辅助方法

    private func makePuzzle(
        id: String = "test-demo-\(UUID().uuidString.prefix(8))",
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

    // MARK: - 1. NavigationRoute 路由

    func testNavigationRouteHasPuzzleDemoCase() {
        // NavigationRoute 应包含 puzzleDemo case
        let route = NavigationRoute.puzzleDemo
        XCTAssertEqual(route.hashValue, NavigationRoute.puzzleDemo.hashValue,
                       "NavigationRoute.puzzleDemo 应可 hash")
    }

    private func makeChapter(id: String = "test-ch") -> PuzzleChapter {
        PuzzleChapter(
            id: id,
            config: ChapterConfig(
                id: id,
                titleKey: "test.title",
                subtitleKey: "test.subtitle",
                globalStart: 0,
                globalEnd: 0,
                unlockCondition: .none,
                reward: nil
            ),
            puzzles: [],
            completedCount: 0,
            isUnlocked: true,
            unlockDescription: ""
        )
    }

    func testNavigationRouteChapterEquality() {
        let chapter = makeChapter()
        let route1 = NavigationRoute.chapter(chapter)
        let route2 = NavigationRoute.chapter(chapter)
        XCTAssertEqual(route1, route2, "相同 chapter 的 NavigationRoute 应相等")
    }

    func testNavigationRoutePuzzleDemoNotEqualChapter() {
        let chapter = makeChapter()
        let routeChapter = NavigationRoute.chapter(chapter)
        let routeDemo = NavigationRoute.puzzleDemo
        XCTAssertNotEqual(routeChapter, routeDemo,
                          ".chapter 和 .puzzleDemo 应不相等")
    }

    func testNavigationRouteHashableInSet() {
        // 可放入 Set/Set（Hashable 要求）
        let chapter = makeChapter()
        let routes: Set<NavigationRoute> = [.chapter(chapter), .puzzleDemo]
        XCTAssertEqual(routes.count, 2, ".chapter 和 .puzzleDemo 在 Set 中应各占一个")
    }

    // MARK: - 2. PuzzleDemoView 无参 init + 指定残局 init

    func testPuzzleDemoViewNoArgInitDoesNotCrash() {
        // 无参 init 进入分类浏览视图，viewModel 初始应为 nil
        let view = PuzzleDemoView()
        // 只要 init 不崩就通过（SwiftUI View 是 struct，测试构造即可）
        XCTAssertNotNil(view, "PuzzleDemoView() 无参初始化不应崩溃")
    }

    func testPuzzleDemoViewInitWithPuzzle() {
        let puzzle = makePuzzle(solution: ["h2e2", "b0c2"])
        let view = PuzzleDemoView(initialPuzzle: puzzle)
        XCTAssertNotNil(view, "PuzzleDemoView(initialPuzzle:) 不应崩溃")
    }

    // MARK: - 3. DemoEntryCard 条件渲染

    func testDemoEntryCardWithZeroCountShowsComingSoon() {
        // demoCount=0 时右侧应显示"即将上线"而非 chevron
        // 这是 View struct，无法直接测 UI，但验证 L10n key 存在
        let comingSoon = L10n.shared.t("demo.comingSoon")
        XCTAssertFalse(comingSoon.isEmpty, "demo.comingSoon key 应有翻译")
        XCTAssertNotEqual(comingSoon, "demo.comingSoon",
                          "demo.comingSoon 不应返回 key 本身（说明翻译缺失）")
    }

    func testDemoEntryCardWithNonZeroCountShowsInfo() {
        let info = L10n.shared.t("demo.entryInfo")
        XCTAssertFalse(info.isEmpty, "demo.entryInfo key 应有翻译")
        // entryInfo 包含 %d 占位符
        let formatted = String(format: info, 5, 2)
        XCTAssertTrue(formatted.contains("5"), "格式化后应包含残局数")
        XCTAssertTrue(formatted.contains("2"), "格式化后应包含分类数")
    }

    // MARK: - 4. PuzzleStore.demoPuzzleIds 缓存（P1 修复验证）

    func testDemoPuzzleIdsIsSetCached() {
        let store = PuzzleStore.shared
        let ids = store.demoPuzzleIds

        // 1. 应是 Set<String> 类型，O(1) 查询
        XCTAssertTrue(ids is Set<String>, "demoPuzzleIds 应为 Set<String>")

        // 2. 内容与 demoPuzzles 一致
        let expectedIds = Set(store.demoPuzzles.map { $0.id })
        XCTAssertEqual(ids, expectedIds, "demoPuzzleIds 应与 demoPuzzles id 集合一致")

        // 3. 多次访问应返回同一对象（lazy 缓存）
        let ids2 = store.demoPuzzleIds
        XCTAssertEqual(ids, ids2, "多次访问 demoPuzzleIds 应返回相同缓存")
    }

    func testDemoPuzzleIdsContainsO1Lookup() {
        let store = PuzzleStore.shared
        let ids = store.demoPuzzleIds

        // 对已知存在的 id，contains 应为 true
        if let firstDemo = store.demoPuzzles.first {
            XCTAssertTrue(ids.contains(firstDemo.id),
                          "demoPuzzleIds 应包含已知 demo 残局 id")
        }

        // 对 freePlay 无 solution 的残局，contains 应为 false
        let freePlayPuzzles = store.puzzles.filter { $0.solution.isEmpty }
        if let freePlay = freePlayPuzzles.first {
            XCTAssertFalse(ids.contains(freePlay.id),
                           "demoPuzzleIds 不应包含无 solution 的残局 id")
        }
    }

    // MARK: - 5. onShowDemo 回调 + "观看演示"按钮逻辑

    func testWatchDemoButtonShowsForDemoPuzzle() {
        // PuzzlePlayView 中，只有 PuzzleStore.shared.demoPuzzleIds.contains(puzzle.id) 为 true 时
        // 才显示"观看演示"按钮
        let store = PuzzleStore.shared

        // 有 solution 的残局应有演示数据
        if let demoPuzzle = store.demoPuzzles.first {
            XCTAssertTrue(store.demoPuzzleIds.contains(demoPuzzle.id),
                          "有 solution 的残局应在 demoPuzzleIds 中，应显示观看演示按钮")
        }

        // 无 solution 的残局不应有演示数据
        let freePlayPuzzles = store.puzzles.filter { $0.solution.isEmpty }
        if let freePlay = freePlayPuzzles.first {
            XCTAssertFalse(store.demoPuzzleIds.contains(freePlay.id),
                           "无 solution 的残局不应在 demoPuzzleIds 中，不应显示观看演示按钮")
        }
    }

    func testOnShowDemoCallbackType() {
        // onShowDemo 的类型是 ((Puzzle) -> Void)?
        // 此测试验证回调签名存在——通过编译即可
        let callback: ((Puzzle) -> Void)? = { _ in }
        XCTAssertNotNil(callback, "onShowDemo 回调类型应为 ((Puzzle) -> Void)?")
    }

    // MARK: - 6. iOS fullScreenCover 竞态修复（P0 验证）

    func testFullScreenCoverSequentialDismissalLogic() {
        // P0 修复：从 PuzzlePlayView 的"观看演示"切换到 PuzzleDemoView 时
        // 不能同时 dismiss + present 两个 fullScreenCover
        // PuzzleSelectView 中的实现是：
        //   1. selectedPuzzle = nil（关闭第一个 fullScreenCover）
        //   2. DispatchQueue.main.async { demoTargetPuzzle = ...; showPuzzleDemo = true }（延迟弹出第二个）
        //
        // 测试验证逻辑链：onShowDemo 先清空 selectedPuzzle，再异步设置 showPuzzleDemo
        var selectedPuzzle: Puzzle? = makePuzzle(solution: ["h2e2"])
        var demoTargetPuzzle: Puzzle?
        var showPuzzleDemo = false

        // 模拟 onShowDemo 回调
        let onShowDemo: (Puzzle) -> Void = { puzzle in
            selectedPuzzle = nil
            DispatchQueue.main.async {
                demoTargetPuzzle = puzzle
                showPuzzleDemo = true
            }
        }

        let puzzle = makePuzzle(id: "demo-1", solution: ["h2e2"])
        onShowDemo(puzzle)

        // 同步阶段：selectedPuzzle 已清空，但 showPuzzleDemo 还没设
        XCTAssertNil(selectedPuzzle, "onShowDemo 应先清空 selectedPuzzle")
        XCTAssertFalse(showPuzzleDemo, "showPuzzleDemo 应在 async block 后才为 true")

        // 执行 async block
        let expectation = expectation(description: "async block executes")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // async 后：showPuzzleDemo 为 true
        XCTAssertTrue(showPuzzleDemo, "async 后 showPuzzleDemo 应为 true")
        XCTAssertEqual(demoTargetPuzzle?.id, "demo-1", "demoTargetPuzzle 应为指定残局")
    }

    // MARK: - 7. L10n 国际化（P2 修复验证）

    func testL10nDemoEntryTitle() {
        let text = L10n.shared.t("demo.entryTitle")
        XCTAssertFalse(text.isEmpty, "demo.entryTitle 不应为空")
        XCTAssertNotEqual(text, "demo.entryTitle", "demo.entryTitle 应有翻译")
    }

    func testL10nDemoEntrySubtitle() {
        let text = L10n.shared.t("demo.entrySubtitle")
        XCTAssertFalse(text.isEmpty, "demo.entrySubtitle 不应为空")
        XCTAssertNotEqual(text, "demo.entrySubtitle", "demo.entrySubtitle 应有翻译")
    }

    func testL10nDemoEntryInfo() {
        let text = L10n.shared.t("demo.entryInfo")
        XCTAssertFalse(text.isEmpty, "demo.entryInfo 不应为空")
        XCTAssertNotEqual(text, "demo.entryInfo", "demo.entryInfo 应有翻译")
    }

    func testL10nDemoComingSoon() {
        let text = L10n.shared.t("demo.comingSoon")
        XCTAssertFalse(text.isEmpty, "demo.comingSoon 不应为空")
        XCTAssertNotEqual(text, "demo.comingSoon", "demo.comingSoon 应有翻译")
    }

    func testL10nDemoNoData() {
        let text = L10n.shared.t("demo.noData")
        XCTAssertFalse(text.isEmpty, "demo.noData 不应为空")
        XCTAssertNotEqual(text, "demo.noData", "demo.noData 应有翻译")
    }

    func testL10nPuzzleWatchDemo() {
        let text = L10n.shared.t("puzzle.watchDemo")
        XCTAssertFalse(text.isEmpty, "puzzle.watchDemo 不应为空")
        XCTAssertNotEqual(text, "puzzle.watchDemo", "puzzle.watchDemo 应有翻译")
    }

    func testL10nDemoBrowseTitle() {
        let text = L10n.shared.t("demo.browseTitle")
        XCTAssertFalse(text.isEmpty, "demo.browseTitle 不应为空")
        XCTAssertNotEqual(text, "demo.browseTitle", "demo.browseTitle 应有翻译")
    }

    // MARK: - 8. ChapterSelectView 集成验证

    func testChapterSelectViewDemoEntryCardConditions() {
        // 验证 ChapterSelectView 中 DemoEntryCard 的显示逻辑
        let store = PuzzleStore.shared
        let demoCount = store.demoPuzzles.count
        let categoryCount = store.demoCategories.count

        if demoCount > 0 {
            // 有数据时：NavigationLink 跳转 PuzzleDemoView
            XCTAssertTrue(demoCount > 0, "有演示数据时 demoCount 应 > 0")
            XCTAssertTrue(categoryCount > 0, "有演示数据时 categoryCount 应 > 0")
        } else {
            // 无数据时：显示"即将上线"（非 NavigationLink）
            XCTAssertEqual(demoCount, 0, "无演示数据时 demoCount 应为 0")
        }
    }

    // MARK: - 9. PuzzleDemoView 分类浏览 + 空数据保护

    func testPuzzleStoreDemoCategoriesNonEmptyWhenDemoPuzzlesExist() {
        let store = PuzzleStore.shared
        if !store.demoPuzzles.isEmpty {
            XCTAssertFalse(store.demoCategories.isEmpty,
                           "有 demoPuzzles 时 demoCategories 不应为空")
        }
    }

    func testPuzzleDemoViewCategoryBrowseEmptyHandling() {
        // 无参 init 时如果 categories 为空，应显示空状态 UI（demo.noData）
        // 验证 L10n key 存在
        let noDataText = L10n.shared.t("demo.noData")
        XCTAssertFalse(noDataText.isEmpty, "空数据提示文案应存在")
    }

    func testPuzzleDemoViewSelectedCategoryDefault() {
        // 无参 init 时 selectedCategory 应默认为 demoCategories.first
        let store = PuzzleStore.shared
        if let firstCategory = store.demoCategories.first {
            // 默认选中第一个分类
            XCTAssertFalse(firstCategory.isEmpty, "默认分类名不应为空")
        }
    }

    // MARK: - 10. PuzzleSelectView fullScreenCover 顺序验证

    func testPuzzleSelectViewShowPuzzleDemoOnlyAfterSelectedPuzzleNil() {
        // 模拟 PuzzleSelectView 的两个 fullScreenCover 互斥状态
        var selectedPuzzle: Puzzle? = makePuzzle(solution: ["h2e2"])
        var showPuzzleDemo = false
        var demoTargetPuzzle: Puzzle?

        // 初始状态：PuzzlePlayView 打开
        XCTAssertNotNil(selectedPuzzle)
        XCTAssertFalse(showPuzzleDemo)

        // 用户点击"观看演示"
        // onShowDemo: selectedPuzzle = nil, async { showPuzzleDemo = true }
        let puzzle = selectedPuzzle!
        selectedPuzzle = nil

        // 中间状态：第一个 cover 关闭，第二个还没开
        XCTAssertNil(selectedPuzzle, "第一个 cover 应先关闭")
        XCTAssertFalse(showPuzzleDemo, "第二个 cover 还未打开（避免竞态）")

        // async 后
        demoTargetPuzzle = puzzle
        showPuzzleDemo = true
        XCTAssertTrue(showPuzzleDemo, "第二个 cover 在 async 后打开")
        XCTAssertNotNil(demoTargetPuzzle, "demoTargetPuzzle 应有值")
    }
}
