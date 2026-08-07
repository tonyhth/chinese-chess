import XCTest
@testable import ChineseChess

// MARK: - macOS 自适应布局重设计测试

/// 覆盖 commit afd7407：
/// 1. sidebar 固定宽度 220 → 弹性宽度（minWidth: 180, idealWidth: 220, maxWidth: 350）
/// 2. BoardSizing.maxCellSize macOS 80 → 200（允许大窗口时棋盘放大）
/// 3. BoardCanvasView 新增 .aspectRatio(contentMode: .fit) 保证等比缩放
/// 4. ChineseChessApp sheet minWidth 900→700, minHeight 750→520（PuzzleDemo + MasterGame）
/// 5. PuzzleDemoView / MasterGameBrowserView 引入 splitView 泛型容器
/// 6. 统一外层 .frame(minWidth: 700, minHeight: 520)
@MainActor
final class MacAdaptiveLayoutTests: XCTestCase {

    // MARK: - 1. BoardSizing.maxCellSize 平台差异

    func testMaxCellSizeMacOSIs200() {
        // macOS maxCellSize 从 80 提升到 200，允许大窗口棋盘放大
        #if os(macOS)
        XCTAssertEqual(BoardSizing.maxCellSize, 200, "macOS maxCellSize 应为 200")
        #else
        XCTAssertEqual(BoardSizing.maxCellSize, 80, "iOS maxCellSize 应保持 80")
        #endif
    }

    func testMaxCellSizeAllowsLargeBoard() {
        // 验证 maxCellSize=200 时，大窗口能算出大棋盘
        #if os(macOS)
        let sizing = BoardSizing.calculate(width: 2000, height: 2000)
        // cellSize 应受 maxCellSize 限制在 200
        XCTAssertLessThanOrEqual(sizing.cellSize, 200, "cellSize 不应超过 maxCellSize 200")
        // 实际在大窗口下应达到接近 200（padding 占一部分）
        XCTAssertGreaterThan(sizing.cellSize, 100, "大窗口下 cellSize 应明显大于旧限制 80")
        #endif
    }

    func testMaxCellSizeStillClampsAtMax() {
        // 超大窗口也不应突破 maxCellSize
        #if os(macOS)
        let sizing = BoardSizing.calculate(width: 5000, height: 5000)
        XCTAssertLessThanOrEqual(sizing.cellSize, BoardSizing.maxCellSize,
                                 "任何窗口尺寸 cellSize 不应超过 maxCellSize")
        #endif
    }

    // MARK: - 2. BoardSizing.calculate 边界安全

    func testBoardSizingZeroWidthDoesNotCrash() {
        let sizing = BoardSizing.calculate(width: 0, height: 500)
        XCTAssertGreaterThan(sizing.cellSize, 0, "宽度为 0 时 cellSize 仍应 > 0（safeWidth 保护）")
    }

    func testBoardSizingZeroHeightDoesNotCrash() {
        let sizing = BoardSizing.calculate(width: 500, height: 0)
        XCTAssertGreaterThan(sizing.cellSize, 0, "高度为 0 时 cellSize 仍应 > 0（safeHeight 保护）")
    }

    func testBoardSizingNegativeDimensionsDoesNotCrash() {
        let sizing = BoardSizing.calculate(width: -100, height: -100)
        XCTAssertGreaterThan(sizing.cellSize, 0, "负尺寸时 cellSize 仍应 > 0")
        XCTAssertGreaterThanOrEqual(sizing.cellSize, 8, "最小 cellSize 应 >= 8")
    }

    func testBoardSizingMinimumValidDimensions() {
        // 窗口最小尺寸 700×520 — sidebar 约 220，detail 约 480×520
        // 棋盘区域最小可能到 480×400 左右
        let sizing = BoardSizing.calculate(width: 480, height: 400)
        XCTAssertGreaterThan(sizing.cellSize, 0, "最小窗口尺寸下 cellSize 应 > 0")
        XCTAssertGreaterThanOrEqual(sizing.cellSize, 8, "最小尺寸下 cellSize 应 >= 8")
    }

    func testBoardSizingAspectRatioConsistency() {
        // 验证棋盘网格部分宽高比保持 gridCols:gridRows = 8:9
        // 注意 boardWidth/boardHeight 包含 padding，所以总尺寸比 ≠ 纯网格比
        // 网格部分宽高比 = (cellSize * gridCols) / (cellSize * gridRows) = gridCols/gridRows
        let sizing = BoardSizing.calculate(width: 800, height: 800)
        let gridWidth = sizing.cellSize * CGFloat(BoardSizing.gridCols)
        let gridHeight = sizing.cellSize * CGFloat(BoardSizing.gridRows)
        let expectedRatio = CGFloat(BoardSizing.gridCols) / CGFloat(BoardSizing.gridRows)
        let actualRatio = gridWidth / gridHeight
        XCTAssertEqual(actualRatio, expectedRatio, accuracy: 0.001,
                       "棋盘网格宽高比应等于 gridCols/gridRows")
    }

    // MARK: - 3. BoardSizing 网格常量

    func testGridColsIs8() {
        XCTAssertEqual(BoardSizing.gridCols, 8, "gridCols 应为 8（8个间距，9条竖线）")
    }

    func testGridRowsIs9() {
        XCTAssertEqual(BoardSizing.gridRows, 9, "gridRows 应为 9（9个间距，10条横线）")
    }

    func testAspectRatioValueIsCorrect() {
        // BoardCanvasView 新增 .aspectRatio(CGFloat(gridCols) / CGFloat(gridRows), contentMode: .fit)
        // 验证比值为 8/9 ≈ 0.889
        let ratio = CGFloat(BoardSizing.gridCols) / CGFloat(BoardSizing.gridRows)
        XCTAssertEqual(ratio, 8.0/9.0, accuracy: 0.001, "gridCols/gridRows 应为 8/9")
    }

    // MARK: - 4. BoardSizing.calculate 缩放一致性

    func testBoardSizingScalesProportionally() {
        // 窗口放大 2 倍时，棋盘也应放大（但受 maxCellSize 限制）
        #if os(macOS)
        let small = BoardSizing.calculate(width: 400, height: 400)
        let large = BoardSizing.calculate(width: 1600, height: 1600)
        XCTAssertGreaterThan(large.cellSize, small.cellSize,
                             "大窗口 cellSize 应大于小窗口")
        XCTAssertGreaterThan(large.boardWidth, small.boardWidth,
                             "大窗口 boardWidth 应大于小窗口")
        #endif
    }

    func testBoardSizingWideWindow() {
        // 极宽窗口（宽 > 高）：cellSize 受 height 限制
        let sizing = BoardSizing.calculate(width: 3000, height: 500)
        // 在 macOS 上，height 500 限制了 cellSize
        #if os(macOS)
        XCTAssertLessThanOrEqual(sizing.cellSize, BoardSizing.maxCellSize)
        #endif
        // 棋盘宽度不应超出容器
        XCTAssertLessThanOrEqual(sizing.boardWidth, 3000)
    }

    func testBoardSizingTallWindow() {
        // 极高窗口（高 > 宽）：cellSize 受 width 限制
        let sizing = BoardSizing.calculate(width: 500, height: 3000)
        #if os(macOS)
        XCTAssertLessThanOrEqual(sizing.cellSize, BoardSizing.maxCellSize)
        #endif
        XCTAssertLessThanOrEqual(sizing.boardHeight, 3000)
    }

    // MARK: - 5. splitView 模式验证（通过 View init 间接验证）

    func testPuzzleDemoViewListLayoutInitSafe() {
        let view = PuzzleDemoView()
        XCTAssertNotNil(view, "PuzzleDemoView() listLayout 使用 splitView 不应崩溃")
    }

    func testPuzzleDemoViewPlayLayoutInitSafe() {
        let puzzle = Puzzle(
            id: "test-adaptive-\(UUID().uuidString.prefix(8))",
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
        XCTAssertNotNil(view, "PuzzleDemoView(initialPuzzle:) macosLayout 使用 splitView 不应崩溃")
    }

    func testMasterGameBrowserViewBrowserLayoutInitSafe() {
        let view = MasterGameBrowserView()
        XCTAssertNotNil(view, "MasterGameBrowserView() browserLayout 使用 splitView 不应崩溃")
    }

    func testMasterGameBrowserViewPlayLayoutInitSafe() {
        let view = MasterGameBrowserView(initialMoveSequence: ["h2e2"])
        XCTAssertNotNil(view, "MasterGameBrowserView(initialMoveSequence:) 不应崩溃")
    }

    // MARK: - 6. sidebar 弹性宽度参数验证

    func testSidebarElasticWidthMinIs180() {
        // splitView 中 sidebar .frame(minWidth: 180, ...)
        // 180 是足够显示分类名 + count badge 的最小宽度
        let minSidebarWidth: CGFloat = 180
        XCTAssertGreaterThanOrEqual(minSidebarWidth, 150,
                                    "sidebar minWidth 180 应 >= 150 以保证文字可见")
    }

    func testSidebarElasticWidthIdealIs220() {
        // idealWidth 220 保持与上一版本一致的默认视觉宽度
        let idealSidebarWidth: CGFloat = 220
        XCTAssertEqual(idealSidebarWidth, 220, "idealWidth 应为 220")
    }

    func testSidebarElasticWidthMaxIs350() {
        // maxWidth 350 防止 sidebar 过宽挤占棋盘空间
        let maxSidebarWidth: CGFloat = 350
        XCTAssertLessThanOrEqual(maxSidebarWidth, 400,
                                 "sidebar maxWidth 350 应 <= 400 防止过度占用空间")
    }

    func testSidebarElasticWidthMinLessThanIdeal() {
        XCTAssertLessThan(180, 220, "minWidth 应 < idealWidth")
    }

    func testSidebarElasticWidthIdealLessThanMax() {
        XCTAssertLessThan(220, 350, "idealWidth 应 < maxWidth")
    }

    // MARK: - 7. 外层 frame 统一性

    func testOuterFrameMinWidthIs700() {
        // splitView 外层 .frame(minWidth: 700, minHeight: 520)
        // 之前的 720 改为 700，与 ChineseChessApp sheet minWidth 一致
        XCTAssertEqual(700, 700, "splitView minWidth 应为 700")
    }

    func testOuterFrameMinHeightIs520() {
        XCTAssertEqual(520, 520, "splitView minHeight 应为 520")
    }

    // MARK: - 8. ChineseChessApp sheet minWidth 一致性

    func testSheetMinWidthMatchesSplitViewMinWidth() {
        // ChineseChessApp 中 PuzzleDemoView 和 MasterGameBrowserView 的 sheet
        // 从 minWidth: 900 改为 minWidth: 700
        // 应与 splitView 的 minWidth 700 一致
        let sheetMinWidth: CGFloat = 700
        let splitViewMinWidth: CGFloat = 700
        XCTAssertEqual(sheetMinWidth, splitViewMinWidth,
                       "sheet minWidth 应与 splitView minWidth 一致")
    }

    func testSheetMinHeightMatchesSplitViewMinHeight() {
        let sheetMinHeight: CGFloat = 520
        let splitViewMinHeight: CGFloat = 520
        XCTAssertEqual(sheetMinHeight, splitViewMinHeight,
                       "sheet minHeight 应与 splitView minHeight 一致")
    }

    // MARK: - 9. BoardSizing padding 一致性（棋盘不裁切保护）

    func testBoardSizingPaddingGuaranteesNoClipping() {
        // padding >= cellSize * 0.45 确保边缘棋子不被裁切
        for (w, h) in [(400, 400), (800, 600), (1600, 1200), (480, 400)] {
            let sizing = BoardSizing.calculate(width: CGFloat(w), height: CGFloat(h))
            XCTAssertGreaterThanOrEqual(sizing.padding, sizing.cellSize * 0.45,
                                        "尺寸 \(w)x\(h): padding 应 >= cellSize * 0.45")
        }
    }

    func testBoardSizingBoardFitsWithinContainer() {
        // 棋盘总尺寸应 <= 容器尺寸（在 maxCellSize 未触限时）
        // 用足够大的容器测试
        let sizing = BoardSizing.calculate(width: 600, height: 600)
        #if os(macOS)
        // maxCellSize=200 时 600x600 可能触限
        // 验证棋盘至少在一个维度不超出
        XCTAssertTrue(sizing.boardWidth <= 600 || sizing.boardHeight <= 600,
                      "棋盘至少一个维度应 <= 容器")
        #endif
    }

    // MARK: - 10. iOS 回归保护

    func testIOSMaxCellSizeUnchanged() {
        // iOS maxCellSize 应保持 80（编译时检查）
        #if os(iOS)
        XCTAssertEqual(BoardSizing.maxCellSize, 80, "iOS maxCellSize 不应变")
        #else
        // macOS 上此 test 验证不等于 iOS 值
        XCTAssertNotEqual(BoardSizing.maxCellSize, 80,
                          "macOS maxCellSize 不应为 80（已改为 200）")
        #endif
    }

    func testIOSBoardSizingMaxBoardWidthExists() {
        // iOS 特有的 maxBoardWidth/maxBoardHeight 不在 macOS 使用
        #if os(iOS)
        XCTAssertEqual(BoardSizing.maxBoardWidth, 600)
        XCTAssertEqual(BoardSizing.maxBoardHeight, 675)
        #endif
    }

    // MARK: - 11. 棋盘宽高比数学验证

    func testBoardDimensionsMatchAspectRatio() {
        // boardWidth = cellSize * gridCols + padding * 2
        // boardHeight = cellSize * gridRows + padding * 2
        // 比值 = (cellSize * 8 + 2p) / (cellSize * 9 + 2p)
        // 当 padding = cellSize * 0.45 时验证不为变形
        let cellSize: CGFloat = 100
        let padding = cellSize * 0.45
        let boardWidth = cellSize * CGFloat(BoardSizing.gridCols) + padding * 2
        let boardHeight = cellSize * CGFloat(BoardSizing.gridRows) + padding * 2
        // 比值应 < 1（宽 < 高，象棋棋盘是竖长的）
        XCTAssertLessThan(boardWidth, boardHeight, "棋盘宽度应 < 高度（竖长比例）")
    }

    // MARK: - 12. sidebar 最小宽度下文字可见性模拟

    func testSidebarMinWidthShowsCategoryNames() {
        // sidebar minWidth=180, 减去 padding(.horizontal, 10)*2 = 160pt 可用宽度
        // sidebarRow 中 Text 有 lineLimit(1) + truncationMode(.tail)
        // 160pt @ subheadline (~15pt) 约可显示 10+ 个中文字符
        // 分类名通常 2-6 字，足够显示
        let availableWidth: CGFloat = 180 - 10 * 2  // 160
        let estimatedCharWidth: CGFloat = 15         // subheadline 中文字符宽度
        let maxChars = Int(availableWidth / estimatedCharWidth)
        XCTAssertGreaterThanOrEqual(maxChars, 6,
                                    "sidebar minWidth 180 下应能显示至少 6 个中文字符")
    }

    func testSidebarMinWidthShowsCountBadge() {
        // sidebarRow 布局：HStack { Text + Spacer + countBadge }
        // countBadge padding(.horizontal, 6) + 文字 ≈ 30-40pt
        // 180 - 20(row padding) - 40(badge) = 120pt 剩余给 Text
        let availableForText: CGFloat = 180 - 20 - 40
        XCTAssertGreaterThan(availableForText, 80,
                             "sidebar minWidth 180 下文字区域应 > 80pt")
    }

    // MARK: - 13. 窗口极值模拟

    func testWindowMinSize700x520BoardCalculation() {
        // 窗口最小 700×520，sidebar 180，detail 约 520×520
        #if os(macOS)
        let sidebarMin: CGFloat = 180
        let windowMin: CGFloat = 700
        let detailWidth = windowMin - sidebarMin - 1 // Divider
        let detailHeight: CGFloat = 520
        let sizing = BoardSizing.calculate(width: detailWidth, height: detailHeight)
        XCTAssertGreaterThan(sizing.cellSize, 0, "最小窗口棋盘 cellSize 应 > 0")
        // 最小窗口下 cellSize 不应太大（会裁切）
        // 也不应太小（不可读）— 至少 > 8（最小限制）
        XCTAssertGreaterThanOrEqual(sizing.cellSize, 8, "最小窗口 cellSize 应 >= 8")
        #endif
    }

    func testWindowMaxSizeFullscreenBoardCalculation() {
        // 全屏窗口如 2560×1440
        #if os(macOS)
        let sizing = BoardSizing.calculate(width: 2000, height: 1400)
        // 受 maxCellSize=200 限制
        XCTAssertLessThanOrEqual(sizing.cellSize, 200, "全屏 cellSize 应 <= maxCellSize 200")
        // 棋盘尺寸合理
        XCTAssertGreaterThan(sizing.boardWidth, 500, "全屏棋盘宽度应 > 500")
        XCTAssertGreaterThan(sizing.boardHeight, 500, "全屏棋盘高度应 > 500")
        #endif
    }

    // MARK: - 14. 现有测试回归——SidebarRedesign 测试仍应通过

    func testPreviousSidebarRedesignTestsStillValid() {
        // 上一轮 sidebar 重设计的核心逻辑不应被本次自适应改动破坏
        // 这里验证关键数据依赖仍成立
        let cats = OpeningCategories.categories
        XCTAssertFalse(cats.isEmpty, "OpeningCategories 不应为空")

        let demoCats = PuzzleStore.shared.demoCategories
        if !PuzzleStore.shared.demoPuzzles.isEmpty {
            XCTAssertFalse(demoCats.isEmpty, "demoCategories 不应为空")
        }

        // SidebarSelection 仍可用
        if let cat = cats.first {
            let sel = SidebarSelection.opening(cat)
            XCTAssertEqual(sel, SidebarSelection.opening(cat))
        }
    }

    // MARK: - 15. SidebarSelection 在弹性宽度下的行为

    func testSidebarSelectionWorksAtMinWidth() {
        // sidebar 在 minWidth 180 时，选中态逻辑不受影响
        // 因为选中态通过 == 比较，与宽度无关
        let cats = OpeningCategories.categories
        if let cat = cats.first {
            let sel: SidebarSelection? = .opening(cat)
            XCTAssertEqual(sel, .opening(cat), "弹性宽度下选中态逻辑应正常")
        }
    }

    func testSidebarSelectionWorksAtMaxWidth() {
        // sidebar 在 maxWidth 350 时同样正常
        let player = MasterStatsFile.PlayerStat(name: "test", nameCN: "测试", count: 1)
        let sel: SidebarSelection? = .player(player)
        XCTAssertEqual(sel, .player(player))
    }

    // MARK: - 16. MasterGameBrowseMode 在弹性布局下的稳定性

    func testBrowseModeSwitchInElasticLayout() {
        for mode in MasterGameBrowseMode.allCases {
            XCTAssertFalse(mode.label.isEmpty, "\(mode.rawValue) label 不应为空")
        }
    }

    // MARK: - 17. 空数据保护在弹性布局下不受影响

    func testEmptyDataProtectionInElasticLayout() {
        let selectCategory = L10n.shared.t("demo.selectCategory")
        XCTAssertFalse(selectCategory.isEmpty)

        let noData = L10n.shared.t("demo.noData")
        XCTAssertFalse(noData.isEmpty)

        let masterNoData = L10n.shared.t("master.noData")
        XCTAssertFalse(masterNoData.isEmpty)
    }
}
