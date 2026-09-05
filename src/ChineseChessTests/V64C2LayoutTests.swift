import Testing
import Foundation
@testable import ChineseChess

// MARK: - v6.4 C2 区A：P3/P4 播放/演示页布局锚（源码面断言）
//
// 依据：v6.4-pages-all14.html P3/P4（唯一真相源）+ 排期 v1.1 C2 区A
// 对账规约（known-issues 398）：跑批后核对 "Test run with N tests" N 与预期一致。
// 断言面：迟滞接入（P3/P4 同 P1 口径）/ LAYOUT_DUMP 采样 / 三 tab 结构 / 控制条语言。

@Suite("v6.4 C2 区A：P3/P4 布局锚", .serialized)
struct V64C2LayoutTests {

    // MARK: - 切片二：窄窗迟滞接入（P3/P4 <1000 收右栏）

    @Test("P3 MasterGameBrowser 播放布局接入 AdaptiveRailState 迟滞")
    func p3RailHysteresis() throws {
        let src = try Self.source("src/ChineseChess/Views/MasterGameBrowserView.swift")
        #expect(src.contains("AdaptiveRailState"), "P3 应接入 C0 迟滞状态机")
        #expect(src.contains("railState.isExpanded"), "P3 右栏应由迟滞状态机驱动")
        #expect(src.contains("LayoutDump.sample(page: \"P3\""), "P3 应有 LAYOUT_DUMP 采样（page=P3）")
    }

    @Test("P4 PuzzleDemo 播放布局接入 AdaptiveRailState 迟滞")
    func p4RailHysteresis() throws {
        let src = try Self.source("src/ChineseChess/Views/PuzzleDemoView.swift")
        #expect(src.contains("AdaptiveRailState"), "P4 应接入 C0 迟滞状态机")
        #expect(src.contains("railState.isExpanded"), "P4 右栏应由迟滞状态机驱动")
        #expect(src.contains("LayoutDump.sample(page: \"P4\""), "P4 应有 LAYOUT_DUMP 采样（page=P4）")
    }

    @Test("P3/P4 迟滞窗口径与 P1 同源（LayoutSpec 单源，无散调字面量）")
    func railThresholdsSingleSource() throws {
        let browser = try Self.source("src/ChineseChess/Views/MasterGameBrowserView.swift")
        let puzzle = try Self.source("src/ChineseChess/Views/PuzzleDemoView.swift")
        // 禁单边散调：两文件不得出现 1000/1080 字面量（阈值只活在 LayoutSpec + AdaptiveRailState）
        for src in [browser, puzzle] {
            #expect(!src.contains("1000"), "P3/P4 禁阈值字面量散调（走 AdaptiveRailState 默认 LayoutSpec 单源）")
            #expect(!src.contains("1080"), "同上")
        }
    }

    // MARK: - 切片一回归锚（三 tab 结构）

    @Test("DemoSidePanel 三 tab + 定宽 300 单源")
    func sidePanelThreeTabs() throws {
        let src = try Self.source("src/ChineseChess/Views/DemoSidePanel.swift")
        #expect(src.contains("case info, commentary, moves"), "三 tab：信息/点评/走法")
        #expect(src.contains("LayoutSpec.p34RailWidth"), "面板定宽走 p34RailWidth 单源")
        #expect(src.contains("maxHeight: 220"), "点评区滚动高度自适应（max 220，all14 P4 口径）")
    }

    // MARK: - 切片三：控制条语言（all14 P3/P4 工具栏口径）

    @Test("P3/P4 控制条含步进/播放/重头（all14 工具栏语言）")
    func controlBarPlayLanguage() throws {
        let bar = try Self.source("src/ChineseChess/Views/DemoControlBar.swift")
        #expect(bar.contains("goToStart") || bar.contains("jumpToMove(at: 0)"),
                "控制条应含「重头」操作（P4 工具栏语言：🔁 重头）")
        #expect(bar.contains("togglePlay"), "控制条应含播放/暂停")
        #expect(bar.contains("stepBackward"), "控制条应含上一步")
    }

    // MARK: - 路径工具（#filePath 相对推导，同 V62LayoutTests 规约）

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func source(_ relative: String) throws -> String {
        let url = repoRoot.appendingPathComponent(relative)
        return try String(contentsOfFile: url.path, encoding: .utf8)
    }
}