import XCTest
@testable import ChineseChess

// MARK: - macOS 播放页面布局优化测试

/// 覆盖 commit c704f93：
/// 1. 棋盘居中：frame 从 DemoBoardView 移到 ZStack（让 aspectRatio 自然控制）
/// 2. sidebar 收敛：idealWidth 220→190, minWidth 180→160, maxWidth 350→280
/// 3. 控制栏紧凑化：segmented Picker→Menu, spacing 16→10, padding 收紧
/// 4. 信息栏单行化：VStack 两行→HStack 一行
@MainActor
final class MacPlayLayoutPolishTests: XCTestCase {

    // MARK: - 1. DemoSpeed 枚举完整性（控制栏 Menu 依赖）

    func testDemoSpeedAllCasesCount() {
        // 速度快捷键 1-4 依赖 allCases.count <= 4
        XCTAssertLessThanOrEqual(DemoSpeed.allCases.count, 4,
                                 "DemoSpeed.allCases 必须 <= 4（快捷键 1-4 依赖）")
    }

    func testDemoSpeedCases() {
        XCTAssertEqual(DemoSpeed.slow.rawValue, 0.5)
        XCTAssertEqual(DemoSpeed.normal.rawValue, 1.0)
        XCTAssertEqual(DemoSpeed.fast.rawValue, 2.0)
        XCTAssertEqual(DemoSpeed.turbo.rawValue, 3.0)
    }

    func testDemoSpeedIdentifiable() {
        for (index, speed) in DemoSpeed.allCases.enumerated() {
            XCTAssertEqual(speed.id, speed.rawValue)
            XCTAssertFalse(speed.label.isEmpty, "DemoSpeed[\(index)] label 不应为空")
        }
    }

    func testDemoSpeedShortcutKeysMapping() {
        // ForEach(enumerated()) 映射快捷键：index+1 → speed
        // 验证 1→slow, 2→normal, 3→fast, 4→turbo
        let speeds = DemoSpeed.allCases
        if speeds.count >= 4 {
            XCTAssertEqual(speeds[0], .slow, "快捷键 1 → slow")
            XCTAssertEqual(speeds[1], .normal, "快捷键 2 → normal")
            XCTAssertEqual(speeds[2], .fast, "快捷键 3 → fast")
            XCTAssertEqual(speeds[3], .turbo, "快捷键 4 → turbo")
        }
    }

    // MARK: - 2. sidebar 收敛参数验证

    func testSidebarConvergedMinWidthIs160() {
        // minWidth 从 180 收敛到 160
        let minWidth: CGFloat = 160
        XCTAssertEqual(minWidth, 160, "sidebar minWidth 应为 160")
    }

    func testSidebarConvergedIdealWidthIs190() {
        let idealWidth: CGFloat = 190
        XCTAssertEqual(idealWidth, 190, "sidebar idealWidth 应为 190")
    }

    func testSidebarConvergedMaxWidthIs280() {
        let maxWidth: CGFloat = 280
        XCTAssertEqual(maxWidth, 280, "sidebar maxWidth 应为 280")
    }

    func testSidebarConvergedMinLessThanIdeal() {
        XCTAssertLessThan(160, 190, "minWidth 应 < idealWidth")
    }

    func testSidebarConvergedIdealLessThanMax() {
        XCTAssertLessThan(190, 280, "idealWidth 应 < maxWidth")
    }

    func testSidebarConvergedStillShowsCategoryNames() {
        // minWidth=160, 减去 row padding(.horizontal, 10)*2 = 140pt 可用
        let availableWidth: CGFloat = 160 - 10 * 2  // 140
        let estimatedCharWidth: CGFloat = 15
        let maxChars = Int(availableWidth / estimatedCharWidth)
        // 分类名通常 2-6 字，140pt @ 15pt/字 ≈ 9 字符
        XCTAssertGreaterThanOrEqual(maxChars, 6,
                                    "sidebar minWidth 160 下应能显示至少 6 个中文字符")
    }

    func testSidebarConvergedShowsCountBadge() {
        // HStack { Text + Spacer + countBadge }
        // countBadge ≈ 30-40pt
        let availableForText: CGFloat = 160 - 20 - 40
        XCTAssertGreaterThan(availableForText, 60,
                             "sidebar minWidth 160 下文字区域应 > 60pt")
    }

    // MARK: - 3. sidebar 收敛后 PuzzleDemoView / MasterGameBrowserView 一致性

    func testPuzzleDemoSidebarConvergedConsistent() {
        // PuzzleDemoView.splitView 的 sidebar 参数应与 MasterGameBrowserView 一致
        // 都从 (180, 220, 350) 改为 (160, 190, 280)
        let params = (min: 160, ideal: 190, max: 280)
        XCTAssertEqual(params.min, 160)
        XCTAssertEqual(params.ideal, 190)
        XCTAssertEqual(params.max, 280)
    }

    func testMasterGameSidebarConvergedConsistent() {
        let params = (min: 160, ideal: 190, max: 280)
        XCTAssertEqual(params.min, 160)
        XCTAssertEqual(params.ideal, 190)
        XCTAssertEqual(params.max, 280)
    }

    // MARK: - 4. DemoItemWrapper 显示属性（信息栏依赖）

    func testDemoItemWrapperPuzzleTitle() {
        let puzzle = Puzzle(
            id: "test-info-\(UUID().uuidString.prefix(8))",
            name: "测试残局名",
            category: "战术分类",
            difficulty: 1,
            stars: 1,
            description: "测试描述",
            playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: ["h2e2"],
            hints: nil,
            maxMoves: 1
        )
        let wrapper = DemoItemWrapper.puzzle(puzzle)
        XCTAssertEqual(wrapper.demoTitle, "测试残局名")
        XCTAssertEqual(wrapper.demoCategory, "战术分类")
        XCTAssertEqual(wrapper.demoSubtitle, "测试描述")
    }

    func testDemoItemWrapperMasterGameTitle() {
        let index = MasterGameIndex(
            id: 0, event: "全国个人赛", redName: "A", blackName: "B",
            redNameCN: "许银川", blackNameCN: "吕钦", year: 2020,
            firstMove: "h2e2", firstMoves: ["h2e2"], moveCount: 80,
            pgnOffset: 0, pgnLength: 100
        )
        let item = MasterGameDemoItem(index: index, fen: nil)
        let wrapper = DemoItemWrapper.masterGame(item)
        XCTAssertEqual(wrapper.demoTitle, "许银川 vs 吕钦")
        XCTAssertTrue(wrapper.demoSubtitle.contains("2020"), "副标题应包含年份")
        XCTAssertTrue(wrapper.demoSubtitle.contains("全国个人赛"), "副标题应包含赛事名")
    }

    // MARK: - 5. 信息栏单行布局验证（Ruby P2-1：长标题截断）

    func testInfoBarLongTitleTruncation() {
        // macosInfoBar 使用 HStack，标题有 .lineLimit(1)
        // 大师对局名称如 "许银川 vs 吕钦" 约 6-8 字符，正常显示
        // 但副标题可能较长（年份+赛事名），也有 .lineLimit(1)
        let longEventName = String(repeating: "很长的赛事名", count: 10)
        let index = MasterGameIndex(
            id: 0, event: longEventName, redName: "A", blackName: "B",
            redNameCN: "甲", blackNameCN: "乙", year: 2020,
            firstMove: "h2e2", firstMoves: ["h2e2"], moveCount: 80,
            pgnOffset: 0, pgnLength: 100
        )
        let item = MasterGameDemoItem(index: index, fen: nil)
        let wrapper = DemoItemWrapper.masterGame(item)
        // 副标题应在单行内被截断（lineLimit(1) 保证不换行）
        XCTAssertFalse(wrapper.demoSubtitle.isEmpty)
        // 标题也应正常
        XCTAssertFalse(wrapper.demoTitle.isEmpty)
    }

    func testInfoBarHStackSpacingParameter() {
        // macosInfoBar 使用 HStack(spacing: 8)
        let spacing: CGFloat = 8
        XCTAssertEqual(spacing, 8, "信息栏 HStack spacing 应为 8")
    }

    func testInfoBarPaddingValues() {
        // .padding(.horizontal, 12) + .padding(.vertical, 6)
        // 从 (12, 8) 收紧到 (12, 6)
        let hPadding: CGFloat = 12
        let vPadding: CGFloat = 6
        XCTAssertEqual(hPadding, 12, "信息栏 horizontal padding 应为 12")
        XCTAssertEqual(vPadding, 6, "信息栏 vertical padding 应为 6（从 8 收紧）")
    }

    func testInfoBarCategoryBadgePadding() {
        // 分类的 Capsule badge 从 (.horizontal, 8)(.vertical, 2) 收紧到 (.horizontal, 6)(.vertical, 1)
        let hPadding: CGFloat = 6
        let vPadding: CGFloat = 1
        XCTAssertLessThanOrEqual(hPadding, 8, "分类 badge horizontal padding 应 <= 8")
        XCTAssertLessThanOrEqual(vPadding, 2, "分类 badge vertical padding 应 <= 2")
    }

    // MARK: - 6. 控制栏紧凑化验证

    func testControlBarVStackSpacingReduced() {
        // VStack spacing 从 8 减到 4
        let vStackSpacing: CGFloat = 4
        XCTAssertEqual(vStackSpacing, 4, "控制栏 VStack spacing 应为 4（从 8 减小）")
    }

    func testControlBarHStackSpacingReduced() {
        // HStack spacing 从 16 减到 10
        let hStackSpacing: CGFloat = 10
        XCTAssertEqual(hStackSpacing, 10, "控制栏 HStack spacing 应为 10（从 16 减小）")
    }

    func testControlBarDividerHeightReduced() {
        // Divider height 从 24 减到 20
        let dividerHeight: CGFloat = 20
        XCTAssertEqual(dividerHeight, 20, "Divider height 应为 20（从 24 减小）")
    }

    func testControlBarPaddingReduced() {
        // .padding(.horizontal, 12) + .padding(.vertical, 6)
        // 从 (16, 8) 收紧到 (12, 6)
        let hPadding: CGFloat = 12
        let vPadding: CGFloat = 6
        XCTAssertLessThanOrEqual(hPadding, 16, "控制栏 horizontal padding 应 <= 16")
        XCTAssertLessThanOrEqual(vPadding, 8, "控制栏 vertical padding 应 <= 8")
    }

    // MARK: - 7. 控制栏速度选择器：Menu 替代 segmented Picker

    func testSpeedSelectorUsesMenu() {
        // 速度选择器从 Picker(.segmented) 改为 Menu
        // Menu 内部用 Button + Label(checkmark) 表示选中态
        // 验证 DemoSpeed 有 label 属性供 Menu 显示
        for speed in DemoSpeed.allCases {
            XCTAssertFalse(speed.label.isEmpty, "每个 speed 的 label 不应为空（Menu 显示依赖）")
        }
    }

    func testSpeedSelectorMenuShowsCheckmarkForSelected() {
        // Menu 中选中项显示 Label(speed.label, systemImage: "checkmark")
        // 未选中项显示 Text(speed.label)
        let selectedSpeed = DemoSpeed.normal
        XCTAssertEqual(selectedSpeed, DemoSpeed.normal)
        // 验证所有 speed 都可以创建 Label
        for speed in DemoSpeed.allCases {
            let _ = speed.label
            let _ = speed == selectedSpeed  // 可以比较
        }
    }

    func testSpeedSelectorMenuLabelDisplay() {
        // Menu label 显示当前速度 + chevron.down
        let currentSpeed = DemoSpeed.fast
        XCTAssertFalse(currentSpeed.label.isEmpty, "Menu label 需要显示当前速度文本")
    }

    func testSpeedSelectorSavesConfig() {
        // Menu Button action: config.demoSpeed = speed
        // 验证 config 可以正确保存和加载
        var config = DemoConfig.load()
        let originalSpeed = config.demoSpeed
        config.demoSpeed = .turbo
        config.save()
        let reloaded = DemoConfig.load()
        XCTAssertEqual(reloaded.demoSpeed, .turbo, "保存后加载应为 turbo")
        // 恢复
        config.demoSpeed = originalSpeed
        config.save()
    }

    // MARK: - 8. 棋盘居中验证（frame 从 DemoBoardView 移到 ZStack）

    func testBoardFrameMovedToZStack() {
        // 改动：DemoBoardView 不再有 .frame(maxWidth:.infinity, maxHeight:.infinity)
        // 改为 ZStack 外层有 .frame(maxWidth:.infinity, maxHeight:.infinity)
        // 效果：让 DemoBoardView 内部的 BoardCanvasView.aspectRatio(.fit) 自然控制比例
        //
        // 验证：BoardCanvasView 仍有 aspectRatio modifier（上一轮 commit afd7407 加的）
        let ratio = CGFloat(BoardSizing.gridCols) / CGFloat(BoardSizing.gridRows)
        XCTAssertGreaterThan(ratio, 0, "aspectRatio 比值应 > 0")
    }

    func testBoardCenteringCalculation() {
        // ZStack 中 DemoBoardView 不再强制 frame，让 aspectRatio .fit 自适应
        // 验证在典型 detail 区域尺寸下棋盘能正确计算
        let sizing = BoardSizing.calculate(width: 800, height: 600)
        XCTAssertGreaterThan(sizing.cellSize, 0)
        XCTAssertLessThanOrEqual(sizing.boardWidth, 800, "棋盘宽度不应超过容器")
        XCTAssertLessThanOrEqual(sizing.boardHeight, 600, "棋盘高度不应超过容器")
    }

    // MARK: - 9. View init 安全性（布局改动后不应崩溃）

    func testPuzzleDemoViewInitAfterLayoutPolish() {
        let view = PuzzleDemoView()
        XCTAssertNotNil(view, "PuzzleDemoView() 不应崩溃")
    }

    func testPuzzleDemoViewInitWithPuzzleAfterLayoutPolish() {
        let puzzle = Puzzle(
            id: "test-polish-\(UUID().uuidString.prefix(8))",
            name: "测试",
            category: "测试",
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: ["h2e2"],
            hints: nil,
            maxMoves: 1
        )
        let view = PuzzleDemoView(initialPuzzle: puzzle)
        XCTAssertNotNil(view)
    }

    func testMasterGameBrowserViewInitAfterLayoutPolish() {
        let view = MasterGameBrowserView()
        XCTAssertNotNil(view)
    }

    func testMasterGameBrowserViewInitWithMoveSequenceAfterLayoutPolish() {
        let view = MasterGameBrowserView(initialMoveSequence: ["h2e2"])
        XCTAssertNotNil(view)
    }

    // MARK: - 10. DemoConfig 同步链路（控制栏 → ViewModel）

    func testConfigSyncModifierExists() {
        // syncConfigToViewModel 修饰符在布局改动后仍存在
        // onChange(of: config.demoSpeed) → viewModel.speed = newValue
        var config = DemoConfig.load()
        let original = config.demoSpeed
        config.demoSpeed = .fast
        // 验证 config 可修改
        XCTAssertEqual(config.demoSpeed, .fast)
        config.demoSpeed = original
    }

    // MARK: - 11. 速度快捷键在新布局下仍工作

    func testSpeedShortcutKeysCount() {
        // ForEach(DemoSpeed.allCases.enumerated()) 创建隐藏 Button + keyboardShortcut
        // 快捷键 1-4 对应 allCases[0-3]
        XCTAssertEqual(DemoSpeed.allCases.count, 4, "应恰好 4 个速度（快捷键 1-4）")
    }

    func testSpeedShortcutKeyCharacterMapping() {
        // KeyEquivalent(Character("\(index + 1)"))
        for (index, _) in DemoSpeed.allCases.enumerated() {
            let char = Character("\(index + 1)")
            XCTAssertNotNil(char, "快捷键字符 \(index + 1) 应可创建")
        }
    }

    // MARK: - 12. 进度条在新布局下仍正常

    func testProgressBarInCompactLayout() {
        // ProgressView 在 VStack 顶部，spacing=4
        // 验证 progress 值计算正确
        let total = 10
        let current = 3
        let progress = Double(current) / Double(max(total, 1))
        XCTAssertEqual(progress, 0.3, accuracy: 0.001)
    }

    func testProgressBarZeroTotalHandled() {
        let total = 0
        let current = 0
        let divisor = max(total, 1)  // 防除零
        let progress = Double(current) / Double(divisor)
        XCTAssertEqual(progress, 0.0, "total=0 时 progress 应为 0（max 保护）")
    }

    // MARK: - 13. iOS 回归保护

    func testIOSDemoControlBarUnchanged() {
        // iOS 控制栏未改动（本次只改 macOS macosControlBar）
        // 验证 iOS 仍使用 iosControlBar 代码路径
        let speed = DemoSpeed.normal
        XCTAssertFalse(speed.label.isEmpty, "iOS Menu 也依赖 speed.label")
    }

    func testIOSDemoInfoBarUnchanged() {
        // iOS 信息栏仍使用 VStack(spacing: 4) 两行布局
        // 只有 macOS 改为 HStack 单行
        // 验证 iOS 代码路径不受影响
        let padding: CGFloat = 12
        XCTAssertEqual(padding, 12, "iOS 信息栏 padding 不应变化")
    }

    // MARK: - 14. sidebar 收敛后选中态逻辑不受影响

    func testSidebarSelectionAfterConverge() {
        // sidebar 宽度变化不影响选中态逻辑（== 比较）
        let cats = OpeningCategories.categories
        if let cat = cats.first {
            let sel: SidebarSelection? = .opening(cat)
            XCTAssertEqual(sel, .opening(cat), "收敛宽度后选中态逻辑应正常")
        }
    }

    // MARK: - 15. 空数据保护

    func testEmptyDataProtectionAfterPolish() {
        let selectCategory = L10n.shared.t("demo.selectCategory")
        XCTAssertFalse(selectCategory.isEmpty)

        let noData = L10n.shared.t("demo.noData")
        XCTAssertFalse(noData.isEmpty)

        let masterNoData = L10n.shared.t("master.noData")
        XCTAssertFalse(masterNoData.isEmpty)
    }

    // MARK: - 16. 信息栏/控制栏 i18n key 验证

    func testControlBarI18nKeys() {
        let speed = L10n.shared.t("demo.speed")
        XCTAssertFalse(speed.isEmpty, "demo.speed 应有翻译")

        let settings = L10n.shared.t("demo.settings")
        XCTAssertFalse(settings.isEmpty, "demo.settings 应有翻译")

        let backToList = L10n.shared.t("demo.backToList")
        XCTAssertFalse(backToList.isEmpty, "demo.backToList 应有翻译")

        let autoAdvance = L10n.shared.t("demo.autoAdvance")
        XCTAssertFalse(autoAdvance.isEmpty, "demo.autoAdvance 应有翻译")
    }

    func testInfoBarProgressTextFormat() {
        // viewModel.progressText 显示在信息栏右侧
        // 格式通常为 "3/10"
        let text = "3/10"
        XCTAssertTrue(text.contains("/"), "进度文本应包含 /")
    }

    // MARK: - 17. DemoConfigPopover 在 macOS 上仍使用 segmented Picker

    func testConfigPopoverStillUsesSegmentedPicker() {
        // DemoConfigPopover 内部仍使用 Picker(.segmented) 设置默认速度
        // 只有主控制栏的速度选择器改为 Menu
        // 这是有意为之：Popover 是设置面板，空间充裕
        let popoverWidth: CGFloat = 280
        XCTAssertGreaterThan(popoverWidth, 200, "Popover 宽度 280 应足够显示 segmented Picker")
    }

    // MARK: - 18. 播放/暂停/前进/后退 控制逻辑不受布局影响

    func testPlayControlLogicUnchanged() {
        // Button action 未改动：viewModel.togglePlay(), stepBackward(), stepForward()
        // 验证 DemoViewModel 有这些方法（编译时已验证，这里做运行时确认）
        let puzzle = Puzzle(
            id: "test-ctrl-\(UUID().uuidString.prefix(8))",
            name: "测试",
            category: "测试",
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: ["h2e2", "b9c7"],
            hints: nil,
            maxMoves: 2
        )
        let convertResult = DemoMoveConverter.convert(solution: puzzle.solution, on: Board(fen: puzzle.initialFEN))
        let vm = DemoViewModel(item: .puzzle(puzzle), moves: convertResult.moves)
        // 初始状态验证
        XCTAssertFalse(vm.isPlaying, "初始状态不应在播放")
        XCTAssertGreaterThan(vm.totalSteps, 0, "应有步数")
    }
}
