import Foundation
import SwiftUI
import Testing
@testable import ChineseChess

// MARK: - v6.2 macOS 左右布局自动化验收（T1-T10）
//
// 依据：docs/reviews/macOS-layout-review-round3-tina.md §三 + v1.2 §七
// ⚠️ T1/T2 语义迁移（Luke 2026-08-17 开工令裁定一，权威依据）：
//   Tina §三原表 T1/T2 写"使用 HSplitView"（清单成文于方案决选前）；方案 B 定选后
//   语义锚 = 交接说明（禁回头 HSplitView）→ 断言改为 ManagedSplitView 组件存在 +
//   macosPlayLayout / macosLayout 接入之。
// 源码定位：#filePath 相对推导（不重蹈 MasterGameFixTests 主树硬路径的混读坑）
// ⚠️ 自动化边界（Ruby 整审 P2 建议采纳 2026-08-16）：T1-T10 锚定源码存在性与结构；
//   拖拽持久化/点击跳转/宽度可用性等交互行为归 M4 手工清单（Tina 11 项制）验证，
//   勿将源码锚误当行为全验。

@Suite("v6.2 macOS 左右布局 T1-T10")
struct V62LayoutTests {

    // MARK: - 路径工具

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)          // .../src/ChineseChessTests/V62LayoutTests.swift
            .deletingLastPathComponent()          // .../src/ChineseChessTests/
            .deletingLastPathComponent()          // .../src/
            .deletingLastPathComponent()          // .../（worktree 根）
    }

    private static func source(_ relative: String) throws -> String {
        let url = repoRoot.appendingPathComponent(relative)
        return try String(contentsOfFile: url.path, encoding: .utf8)
    }

    /// 提取函数区域源码（从 func 声明行到其后首个 #endif，覆盖 #if os(macOS) 块）
    private static func funcRegion(_ source: String, funcName: String) throws -> String {
        guard let funcRange = source.range(of: "private func \(funcName)") else {
            throw NSError(domain: "V62Layout", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "未找到函数 \(funcName)"])
        }
        let rest = source[funcRange.lowerBound...]
        guard let endifRange = rest.range(of: "#endif") else {
            throw NSError(domain: "V62Layout", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "\(funcName) 区域未找到 #endif"])
        }
        return String(rest[..<endifRange.upperBound])
    }

    // MARK: - T1/T2：两演示页面接入 ManagedSplitView（语义迁移版，见文件头裁定注记）

    @Test("T1: MasterGameBrowserView macosPlayLayout 使用 ManagedSplitView 左右布局")
    func t1MasterBrowserUsesManagedSplit() throws {
        let src = try Self.source("src/ChineseChess/Views/MasterGameBrowserView.swift")
        let region = try Self.funcRegion(src, funcName: "macosPlayLayout")
        #expect(region.contains("ManagedSplitView"), "macosPlayLayout 应接入 ManagedSplitView（方案 B，Luke 裁定语义迁移）")
        #expect(region.contains("DemoSidePanel"), "macosPlayLayout 应接入右侧面板 DemoSidePanel")
        #expect(!region.contains("CommentaryOverlay"), "macOS 点评应由右侧面板承载，overlay 退出 macosPlayLayout（iOS 路径 overlay 不受影响）")
        #expect(region.contains("minWidth: 800"), "页面 frame minWidth 应为 800（左右布局最低需求）")
    }

    @Test("T2: PuzzleDemoView macosLayout 使用 ManagedSplitView 左右布局")
    func t2PuzzleDemoUsesManagedSplit() throws {
        let src = try Self.source("src/ChineseChess/Views/PuzzleDemoView.swift")
        let region = try Self.funcRegion(src, funcName: "macosLayout")
        #expect(region.contains("ManagedSplitView"), "macosLayout 应接入 ManagedSplitView（方案 B，Luke 裁定语义迁移）")
        #expect(region.contains("DemoSidePanel"), "macosLayout 应接入右侧面板 DemoSidePanel")
        #expect(region.contains("minWidth: 800"), "页面 frame minWidth 应为 800")
    }

    // MARK: - T3/T4/T5：组件存在性（类型实例化 = 编译期存在性 + 运行期可创建）

    @Test("T3: CommentaryPanel 存在且可创建（点评常驻 + 空态）")
    @MainActor
    func t3CommentaryPanelExists() {
        let panel = CommentaryPanel(commentary: nil)
        #expect(panel.body != nil, "CommentaryPanel 空态可创建（暂无点评占位，P2-1）")
    }

    @Test("T4: MoveRecordPanel 存在且两页面均有走法记录（经 DemoSidePanel 承载）")
    @MainActor
    func t4MoveRecordPanelExists() throws {
        let panel = MoveRecordPanel(notations: ["炮二平五"], currentIndex: 1, onMoveTap: { _ in })
        #expect(panel.body != nil)

        // 两页面均经 DemoSidePanel 承载走法记录（v1.2 §三.1：两个演示页面都加）
        for rel in ["src/ChineseChess/Views/MasterGameBrowserView.swift",
                    "src/ChineseChess/Views/PuzzleDemoView.swift"] {
            let src = try Self.source(rel)
            #expect(src.contains("DemoSidePanel"), "\(rel) 应含 DemoSidePanel（内含 MoveRecordPanel）")
        }
        // 面板容器确实内嵌走法记录
        let sidePanelSrc = try Self.source("src/ChineseChess/Views/DemoSidePanel.swift")
        #expect(sidePanelSrc.contains("MoveRecordPanel"), "DemoSidePanel 应内嵌 MoveRecordPanel")
    }

    @Test("T5: DemoSidePanel 存在且可创建（header/footer 插槽）")
    @MainActor
    func t5DemoSidePanelExists() {
        let panel = DemoSidePanel(
            commentary: nil,
            notations: [],
            currentIndex: 0,
            onMoveTap: { _ in },
            header: { Text("h") },
            footer: { Text("f") }
        )
        #expect(panel.body != nil)
    }

    // MARK: - T6：新增组件 #if os(macOS) 保护（iOS 编译门禁的源码面防线）

    @Test("T6: 四个新增 macOS 组件文件均有顶层 #if os(macOS) 保护")
    func t6MacOSGuard() throws {
        let files = [
            "src/ChineseChess/Views/ManagedSplitView.swift",
            "src/ChineseChess/Views/CommentaryPanel.swift",
            "src/ChineseChess/Views/MoveRecordPanel.swift",
            "src/ChineseChess/Views/DemoSidePanel.swift",
        ]
        for rel in files {
            let src = try Self.source(rel)
            let head = src.prefix(1500)  // 文件头区（长版权/设计注释后应立即见保护，先于任何代码）
            #expect(head.contains("#if os(macOS)"), "\(rel) 头部应有 #if os(macOS)（NSCursor 等 AppKit 依赖不得泄漏 iOS）")
            #expect(src.hasSuffix("#endif\n"), "\(rel) 应以 #endif 收尾")
        }
    }

    // MARK: - T7：sheet minWidth（硬门槛仅 .puzzles/.studyHub=800，其余不动——Luke 裁定二）

    @Test("T7: 演示 sheet minWidth=800 且其余 sheet 未动（恰好两处 800）")
    func t7SheetMinWidth() throws {
        let src = try Self.source("src/ChineseChess/App/ChineseChessApp.swift")
        let count800 = src.components(separatedBy: "minWidth: 800").count - 1
        #expect(count800 == 2, "minWidth: 800 应恰好 2 处（.puzzles + .studyHub），实际 \(count800)——多了=超边界，少了=布局放不下")
        #expect(src.contains("case .toolbarReplay"), "对照组存在性：toolbarReplay")
    }

    // MARK: - T8：主窗口 minHeight 750→600（仅尺寸，布局不动）

    @Test("T8: 主窗口 minHeight 600")
    func t8MainWindowMinHeight() throws {
        let src = try Self.source("src/ChineseChess/App/ChineseChessApp.swift")
        #expect(src.contains("minWidth: 900, minHeight: 600"), "主窗口应为 (900, 600)——v1.2 P0-1 仅降 minHeight")
        #expect(!src.contains("minWidth: 900, minHeight: 750"), "旧 750 约束应已移除")
    }

    // MARK: - T9：DemoControlBar 适配（macOS 控制条在面板宽度下工作，源码面）

    @Test("T9: DemoControlBar macOS 版存在且为面板宽度适配形态")
    func t9ControlBarAdapted() throws {
        let src = try Self.source("src/ChineseChess/Views/DemoControlBar.swift")
        #expect(src.contains("macosControlBar"), "macOS 控制条实现存在")
        // 空间节省设计（Menu 替代 segmented）是面板宽度适配的既有基础
        #expect(src.contains("Menu"), "macOS 控制条应使用 Menu 紧凑形态适配面板宽度")
    }

    // MARK: - T10：iOS 路径保持不变

    @Test("T10: iOS 走法记录路径 iosRecordPanel 保持不变")
    func t10iOSPathUntouched() throws {
        let src = try Self.source("src/ChineseChess/Views/PuzzleDemoView.swift")
        #expect(src.contains("iosRecordPanel"), "iOS 棋谱面板实现应保留（macOS 独立实现不复用不重构）")
        #expect(src.contains("iosLayout"), "iOS 布局路径应保留")
    }

    // MARK: - 附加：面板 l10n key 就位（AboutView 漏成员前车之鉴）

    @Test("附加: 面板 l10n key 中英双语就位")
    func panelL10nKeysPresent() throws {
        let src = try Self.source("src/ChineseChess/Resources/Localizable.xcstrings")
        for key in ["commentary.title", "commentary.empty", "moveRecord.title"] {
            #expect(src.contains("\"\(key)\": {"), "xcstrings 应含 \(key)")
        }
        let data = try JSONDecoder().decode(XcstringsRoot.self, from: Data(src.utf8))
        for key in ["commentary.title", "commentary.empty", "moveRecord.title"] {
            let entry = data.strings[key]
            #expect(entry?.localizations["en"] != nil, "\(key) 缺 en")
            #expect(entry?.localizations["zh-Hans"] != nil, "\(key) 缺 zh-Hans")
        }
    }
    // MARK: - T11：v6.2.1 速度菜单窄态零渲染回归锚（洪涛实机回归，Ruby 像素差分定性）

    @Test("T11: 控制条 ViewThatFits 双态自适应 + rightMin/minWidth 同步 340 止血")
    func t11SpeedMenuNarrowStateAnchors() throws {
        // 锚1：DemoControlBar macOS 控制条接入 ViewThatFits 双态（窄态不再零渲染）
        let bar = try Self.source("src/ChineseChess/Views/DemoControlBar.swift")
        guard let varRange = bar.range(of: "private var macosControlBar") else {
            throw NSError(domain: "V62Layout", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "未找到 macosControlBar"])
        }
        let barRegion = String(bar[varRange.lowerBound...])
        #expect(barRegion.contains("ViewThatFits(in: .horizontal)"), "控制条应有 ViewThatFits 水平双态自适应")
        #expect(barRegion.contains("compact: false") && barRegion.contains("compact: true"), "应存在宽/窄双变体")
        #expect(bar.contains("func controlRow("), "双态行应抽为 controlRow 复用")
        // 锚2：快捷键统一承载（防 ViewThatFits 变体切换丢快捷键）
        #expect(bar.contains("playbackShortcuts") && bar.contains("speedShortcuts"), "快捷键应统一承载不随变体丢夫")

        // 锚3：止血值同步——rightMin 与 DemoSidePanel minWidth 一致 ≥ 340
        let split = try Self.source("src/ChineseChess/Views/ManagedSplitView.swift")
        #expect(split.contains("rightMin: CGFloat = 340"), "rightMin 应为 340（Luke 修复单 A 止血值）")
        let panel = try Self.source("src/ChineseChess/Views/DemoSidePanel.swift")
        #expect(panel.contains("minWidth: 340"), "DemoSidePanel minWidth 应与 rightMin 同步 340")
    }
}

/// xcstrings 最小解码面（仅本套件断言所需字段）
private struct XcstringsRoot: Decodable {
    struct Entry: Decodable {
        struct Localization: Decodable { }
        let localizations: [String: Localization]
        enum CodingKeys: String, CodingKey { case localizations }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            localizations = (try? c.decode([String: Localization].self, forKey: .localizations)) ?? [:]
        }
    }
    let strings: [String: Entry]
}
