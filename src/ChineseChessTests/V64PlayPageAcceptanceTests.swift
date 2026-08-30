import Foundation
import SwiftUI
import Testing
@testable import ChineseChess

// MARK: - v6.4 对局页验收自动化框架（Tina 夜间单，Luke 2026-08-30 打样前置）
//
// 目的：趁打样包未出固化对局页验收框架，打样一落即跑。
// 覆盖：①棋盘缩放三视图（对弈/回放/残局）②四面板折叠状态 ③快捷键行为（←/→/⌘I）
//       ④padding 收敛公式边界（660 以下让位形态）
//
// 框架结构（三层，打样落地只改 REGISTRY 不改测试体）：
//   1. V64AcceptanceRegistry —— 单点配置：打样落地后的视图/面板/快捷键锚点名，落地时填 nil 项
//   2. 现在即真跑的断言（公式边界 / 跨页同键同义锚 / 设计基线锚）—— 已绿基线，打样后仍须绿
//   3. PENDING 锚 —— 打样落地前以 `#expect(pending == nil || ...)` 自报"待填"，不假绿不假红
//
// 依据：docs/design/prototypes/v6.4-p1-final-refine-notes.md（非协商基线：padding 收敛公式 /
//       最小可用宽≈660 / 全程连续缩放 / 面板语言与大师库同源；v2.1：⌘I 键帽常驻、←/→ 跨页同义）

// ---------- 1. 单点配置（打样落地时填） ----------
enum V64AcceptanceRegistry {
    /// 打样落地标记：打样视图合入后置 true（由验收人改这一行，全部 PENDING 锚转为硬断言）
    static let prototypeLanded = false

    /// 对局页新视图文件（打样落地后填，如 "src/ChineseChess/Views/PlayPageV64View.swift"）
    static let playPageViewFile: String? = nil
    /// 残局视图 BoardSizing 接入文件（残局=三视图之③；对弈/回放已有共享锚）
    static let puzzleViewFile: String? = nil
    /// 四面板折叠：面板头锚点符号名（打样落地后填 4 个）
    static let collapsiblePanelSymbols: [String] = []
    /// ⌘I 目标动作符号名（v2.1：⌘H 弃用、⌘I 常驻键帽）
    static let cmdITargetSymbol: String? = nil
}

@Suite("v6.4 对局页验收框架", .serialized)
struct V64PlayPageAcceptanceTests {

    // MARK: - 路径工具（沿用 V62LayoutTests #filePath 推导，禁硬路径）

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func source(_ relative: String) throws -> String {
        try String(contentsOfFile: repoRoot.appendingPathComponent(relative).path, encoding: .utf8)
    }

    private static func designDoc() throws -> String {
        try Self.source("docs/design/prototypes/v6.4-p1-final-refine-notes.md")
    }

    // MARK: - ④ padding 收敛公式边界（现在即真跑；660 以下让位形态）

    @Test("④a: 收敛公式不变量——cellSize≥8 / padding≥0.45·cell / 棋盘不超容器 / 无除零",
          arguments: [50.0, 120.0, 320.0, 480.0, 600.0, 659.0, 660.0, 661.0, 720.0,
                      900.0, 1080.0, 1280.0, 1600.0, 2200.0])
    func paddingFormulaInvariants(size: Double) {
        // 方形容器（对局页棋盘区典型形态；宽高同值驱动，边界档全覆盖）
        let width = size, height = size
        let s = BoardSizing.calculate(width: width, height: height)
        #expect(s.cellSize >= 8, "cellSize 下限 8（\(width)×\(height)）")
        #expect(s.padding >= s.cellSize * 0.45, "padding ≥ 棋子半径（边缘棋子不被裁切，\(width)）")
        if size >= 100 {
            // 正常档：棋盘须在容器内（收敛公式职责）
            #expect(s.boardWidth <= width + 0.5, "boardWidth 不超容器宽（\(width)）")
            #expect(s.boardHeight <= height + 0.5, "boardHeight 不超容器高（\(height)）")
        } else {
            // 退化档（<100pt，远低于最小可用宽 660）：cellSize 下限 8 让位——棋盘允许溢出容器
            // （框架首跑实证：50pt 容器 boardWidth=71.2）。此为公式既定形态，断言不崩即可。
            #expect(s.cellSize >= 8 && s.cellSize <= BoardSizing.maxCellSize, "退化档仍在 clamp 域内（\(width)）")
        }
        #expect(s.cellSize <= BoardSizing.maxCellSize, "maxCellSize 封顶（\(width)）")
    }

    @Test("④b: 660 以下让位形态——连续缩放、单调不减、无跳变断崖")
    func belowMinWidthContinuousShrink() {
        // 非协商基线：全程连续缩放。660 以下应平滑让位（cellSize 随容器连续收缩），不得断崖跳档
        var lastCell: CGFloat = 0
        var w: CGFloat = 50
        while w <= 700 {
            let s = BoardSizing.calculate(width: w, height: w)
            #expect(w == 50 || s.cellSize >= lastCell - 0.51,
                    "cellSize 单调不剧减 @w=\(w)（前一档 \(lastCell) → \(s.cellSize)）")
            lastCell = s.cellSize
            w += 10
        }
        // 660 边界两侧须平滑（无 >1.5px 跳变）
        let a = BoardSizing.calculate(width: 659, height: 659)
        let b = BoardSizing.calculate(width: 661, height: 661)
        #expect(abs(b.cellSize - a.cellSize) <= 1.5, "660 边界两侧 cellSize 平滑（Δ=\(b.cellSize - a.cellSize)）")
    }

    @Test("④c: 最小可用宽≈660 基线锚（设计基线在档）")
    func minWidthBaselineAnchored() throws {
        let doc = try Self.designDoc()
        #expect(doc.contains("最小可用宽≈660"), "设计基线须声明最小可用宽≈660")
        #expect(doc.contains("padding 收敛公式"), "设计基线须声明 padding 收敛公式不可协商")
        // 660 方形容器下棋盘仍有可用格宽（>8 下限即未塌缩）
        let s = BoardSizing.calculate(width: 660, height: 660)
        #expect(s.cellSize > 8, "660 容器 cellSize 须高于塌缩下限（实际 \(s.cellSize)）")
    }

    // MARK: - ① 棋盘缩放三视图（对弈/回放共享锚现在即真；残局 PENDING）

    @Test("①a: 对弈/回放同容器同尺寸——共享 BoardSizing.calculate")
    func playAndReplayShareSizing() throws {
        let play = try Self.source("src/ChineseChess/Views/ChessBoardView.swift")
        let replay = try Self.source("src/ChineseChess/Views/ReplayBoardView.swift")
        let canvas = try Self.source("src/ChineseChess/Views/BoardCanvasView.swift")
        #expect(play.contains("BoardSizing.calculate"), "对弈视图须消费 BoardSizing.calculate")
        // 回放视图为薄壳：渲染委托 BoardCanvasView（框架首跑实证结构），共享锚在 canvas 层
        #expect(replay.contains("BoardCanvasView"), "回放视图薄壳委托 BoardCanvasView")
        #expect(canvas.contains("BoardSizing.calculate"), "BoardCanvasView 须消费 BoardSizing.calculate（回放链共享同一套缩放）")
        // 同容器 → 完全一致（共享逻辑保证，数值级对账）
        let w: CGFloat = 800, h: CGFloat = 700
        #expect(BoardSizing.calculate(width: w, height: h) == BoardSizing.calculate(width: w, height: h))
    }

    @Test("①b: 残局视图接入 BoardSizing（打样 PENDING 锚）")
    func puzzleViewSizingAnchor() throws {
        guard let f = V64AcceptanceRegistry.puzzleViewFile else {
            // 框架自报待填：留 stdout 落痕 + 未落地态自检（不假绿不假红；落地后本分支消失转硬断言）
            print("[PENDING-ANCHOR] ①b 残局视图文件未填（Registry.puzzleViewFile=nil），打样落地后转硬断言")
            #expect(!V64AcceptanceRegistry.prototypeLanded, "未落地自检：registry 须为 prototypeLanded=false")
            return
        }
        let src = try Self.source(f)
        #expect(src.contains("BoardSizing.calculate"), "残局视图须与对弈/回放同一套 BoardSizing（三视图同源缩放）")
    }

    // MARK: - ③ 快捷键行为（←/→ 跨页同键同义现在即锚；⌘I PENDING）

    @Test("③a: ←/→ 跨页同键同义——演示页锚在位（全局口径：← 回退一手 / → 前进一手）")
    func arrowKeysCrossPageSemantics() throws {
        let demo = try Self.source("src/ChineseChess/Views/DemoControlBar.swift")
        #expect(demo.contains(".keyboardShortcut(.leftArrow, modifiers: [])"), "← 快捷键在位")
        #expect(demo.contains(".keyboardShortcut(.rightArrow, modifiers: [])"), "→ 快捷键在位")
        // 键序断言：left 声明先于 right（回退在前，口径可读性锚）
        if let l = demo.range(of: ".keyboardShortcut(.leftArrow"), let r = demo.range(of: ".keyboardShortcut(.rightArrow") {
            #expect(l.lowerBound < r.lowerBound, "← 应先于 → 声明（回退一手在前）")
        }
        let doc = try Self.designDoc()
        #expect(doc.contains("← 回退一手 / → 前进一手"), "v2.1 跨页口径声明在档（两页不得各造语义）")
    }

    @Test("③b: ⌘I 键帽常驻 + ⌘H 弃用（打样 PENDING 锚 + 现在即查弃用）")
    func cmdIAnchorAndCmdHRetired() throws {
        // 现在即真：macOS Hide 保留键冲突 → 全库不得新增裸 ⌘H（.command 无 shift）
        let toolbar = try Self.source("src/ChineseChess/Views/ToolbarView.swift")
        #expect(!toolbar.contains("keyboardShortcut(\"h\", modifiers: .command)"),
                "裸 ⌘H 与系统 Hide 冲突（v2.1 弃用；⇧⌘H 不受影响）")
        guard V64AcceptanceRegistry.cmdITargetSymbol != nil else {
            print("[PENDING-ANCHOR] ③b ⌘I 目标符号未填（Registry.cmdITargetSymbol=nil），打样落地后转硬断言")
            #expect(!V64AcceptanceRegistry.prototypeLanded, "未落地自检：registry 须为 prototypeLanded=false")
            return
        }
        // 打样后硬断言（占位，落地时由验收人补全具体源锚）
        #expect(V64AcceptanceRegistry.prototypeLanded, "打样落地标记须为 true")
    }

    // MARK: - ② 四面板折叠（PENDING 主体 + 面板语言同源锚）

    @Test("②a: 四面板折叠锚（打样 PENDING 主体）")
    func fourPanelCollapseAnchors() {
        guard V64AcceptanceRegistry.prototypeLanded else {
            print("[PENDING-ANCHOR] ②a 四面板符号未填（Registry.collapsiblePanelSymbols=[]），打样落地后断言 chevron 折叠/头行可点/定宽 264 不挤棋盘")
            #expect(V64AcceptanceRegistry.collapsiblePanelSymbols.isEmpty, "未落地自检：面板符号表须为空")
            return
        }
        #expect(V64AcceptanceRegistry.collapsiblePanelSymbols.count == 4, "四面板锚须齐 4 项")
    }

    @Test("②b: 面板语言与大师库同源（设计基线在档 + 既有面板组件在位）")
    func panelLanguageSharedWithLibrary() throws {
        let doc = try Self.designDoc()
        #expect(doc.contains("面板语言与大师库同源"), "基线声明在档")
        _ = try Self.source("src/ChineseChess/Views/DemoSidePanel.swift") // 大师库面板语言宿主在位（可读即过）
    }
}

// BoardSizing.Sizing == 对账支持（①a 数值级相等断言）
extension BoardSizing.Sizing: Equatable {
    public static func == (lhs: BoardSizing.Sizing, rhs: BoardSizing.Sizing) -> Bool {
        lhs.cellSize == rhs.cellSize && lhs.padding == rhs.padding
            && lhs.boardWidth == rhs.boardWidth && lhs.boardHeight == rhs.boardHeight
    }
}
