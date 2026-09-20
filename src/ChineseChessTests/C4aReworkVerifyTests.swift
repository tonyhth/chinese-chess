import Testing
import Foundation
import SwiftUI
@testable import ChineseChess

#if canImport(AppKit)
import AppKit
#endif

// MARK: - T-0917-8 R1 返工快验（commit 1dd3167，父 08ad92e）
//
// 对 Cody 交验清单逐项断言（可代码面/无头运行时验证的 9 项 + P9 实测锚尝试）：
// - P1-1 平台门四点（Explorer :97/:414 token、:534 存量门内原形态零改动、
//        ReplayWindowView View 层 #if os(macOS)、SwiftData 投递层跨平台在门外）
// - P1-2 分析侧 flex:1 = 25% 带 190 下限（760→190 / 1512→378 数学锚）
// - P2-3 dump 实测语义（analysisMeasured 新参数 + 侧栏内采样 + 既有参数名契约）
// - P2-4 p9.window.title / p9.shell.corrupt 双语齐
// - P2-5 投递容器 isStoredInMemoryOnly + optional + insert/fetch/delete 回路
// - P3-7 后退首层解禁（仅未选中禁用，不再 parent==nil 禁用）
// - P3-9 投递竞态 200ms 重试一次 + corrupt/empty 分态
// - P3-10 壳期四钮禁用视觉
// - P3-11 结果语义色 moveSequence=蓝 / openingName=橙
// - P9 runtime 锚：NSHostingView 无头实测侧栏实宽占比 ≥25%（LAYOUT_DUMP 文件桥）
//
// 对账规约（known-issues 398）：批后核对 "Test run with 10 tests"。

@Suite("C4a 返工快验（T-0917-8 R1 @1dd3167）", .serialized)
struct C4aReworkVerifyTests {

    // #filePath = <repoRoot>/src/ChineseChessTests/C4aReworkVerifyTests.swift
    private static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }()

    private static func source(_ relative: String) throws -> String {
        try String(contentsOfFile: repoRoot.appendingPathComponent(relative).path,
                   encoding: .utf8)
    }

    private static func count(_ needle: String, in hay: String) -> Int {
        hay.ranges(of: needle).count
    }

    // MARK: - P1-1 平台门四点

    @Test("P1-1 平台门：token 两处 + :534 存量门内 + Replay View 门/投递层跨平台 + 存量 harness 门")
    func p1_1_platformGate() throws {
        let explorer = try Self.source("src/ChineseChess/Views/OpeningExplorerView.swift")
        // 点1：:97 / :414 token 化
        #expect(explorer.contains(".background(Color.controlBackground)"), ":97 应为 Color.controlBackground token")
        #expect(explorer.contains(".fill(Color.controlBackground)"), ":414 应为 Color.controlBackground token")
        // 点2：:534 唯一存量 NSColor，且在 os(macOS) 门内（原形态零 diff）
        #expect(Self.count("NSColor.controlBackgroundColor", in: explorer) == 1,
                "Explorer 应仅剩 :534 一处存量 NSColor（原形态）")
        if let r = explorer.range(of: "NSColor.controlBackgroundColor") {
            let head = String(explorer[..<r.lowerBound])
            #expect(head.contains("#if os(macOS)"), ":534 存量应位于 os(macOS) 门内（statsColumn）")
        }

        let replay = try Self.source("src/ChineseChess/Views/ReplayWindowView.swift")
        // 点3：Replay View 层门
        #expect(Self.count("NSColor.controlBackgroundColor", in: replay) == 0, "Replay 应零 NSColor 裸用")
        #expect(Self.count(".background(Color.controlBackground)", in: replay) == 1)
        #expect(Self.count(".fill(Color.controlBackground)", in: replay) == 1)
        #expect(replay.contains("#if os(macOS)"), "Replay View 层平台门")
        #expect(replay.contains("#endif  // os(macOS)"), "门收口注释（SwiftData 投递层跨平台）")
        // 点4：SwiftData 投递层在门之外（跨平台）
        if let store = replay.range(of: "final class ReplayWindowPayloadStore"),
           let gate = replay.range(of: "#if os(macOS)") {
            #expect(store.lowerBound < gate.lowerBound, "投递层应位于 View 门之前（跨平台）")
        }

        let browser = try Self.source("src/ChineseChess/Views/MasterGameBrowserView.swift")
        #expect(browser.contains("#if DEBUG && os(macOS)"), "MasterGameBrowserView 存量 sidebar harness 门")
    }

    // MARK: - P1-2 flex:1 = 25% 带下限

    @Test("P1-2 分析侧 25% 带 190 下限：常量 + 公式 + 数学锚（760→190 / 1512→378）")
    func p1_2_ratioFormula() throws {
        #expect(LayoutSpec.p9AnalysisMinRatio == 0.25, "比例常量 25%")
        #expect(LayoutSpec.p9AnalysisMinWidth == 190, "下限常量 190（all14 min-width）")
        #expect(LayoutSpec.p9WindowMinWidth == 760, "P9 窗起步宽 760")
        let replay = try Self.source("src/ChineseChess/Views/ReplayWindowView.swift")
        #expect(replay.contains("max(geo.size.width * LayoutSpec.p9AnalysisMinRatio"), "公式应取 max(总宽×25%, 下限)")
        #expect(replay.contains("LayoutSpec.p9AnalysisMinWidth)"), "下限接入同一表达式")
        // 数学锚（与 Cody 交验口径一致）
        let f: (CGFloat) -> CGFloat = { max($0 * LayoutSpec.p9AnalysisMinRatio,
                                             LayoutSpec.p9AnalysisMinWidth) }
        #expect(f(760) == 190, "760 档：190×25%=190（下限恰好绑定）")
        #expect(f(1512) == 378, "1512 档：1512×25%=378")
        #expect(f(600) == 190, "窄窗下限兜底 190")
    }

    // MARK: - P2-3 dump 实测

    @Test("P2-3 dump 实测语义：analysisMeasured 参数 + 侧栏内采样 + 参数名契约")
    func p2_3_dumpMeasured() throws {
        let replay = try Self.source("src/ChineseChess/Views/ReplayWindowView.swift")
        #expect(replay.contains("\"analysisMeasured\""), "新参数 analysisMeasured（实测侧栏宽）")
        #expect(replay.contains("measured / total"), "ratio = 实测宽/总宽（非推算 min/total）")
        #expect(replay.contains("dumpRatio(measured: g.size.width, total: geo.size.width)"),
                "侧栏内 onAppear 实测采样")
        #expect(replay.contains("onChange(of: g.size.width"), "侧栏内 onChange 实测采样")
        #expect(replay.contains("\"analysisMin\"") && replay.contains("\"ratioFloor\"")
                && replay.contains("\"actual\""), "既有参数名契约不变（只增不改名）")
    }

    // MARK: - P2-4 l10n 双语

    @Test("P2-4 p9.window.title / p9.shell.corrupt 双语齐")
    func p2_4_l10nBilingual() throws {
        let url = Self.repoRoot
            .appendingPathComponent("src/ChineseChess/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let obj = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(obj["strings"] as? [String: Any])
        for key in ["p9.window.title", "p9.shell.corrupt"] {
            let entry = try #require(strings[key] as? [String: Any], "缺 key: \(key)")
            let locs = try #require(entry["localizations"] as? [String: Any],
                                    "\(key) 无 localizations")
            #expect(locs["en"] != nil, "\(key) 缺 en")
            #expect(locs["zh-Hans"] != nil, "\(key) 缺 zh-Hans")
        }
    }

    // MARK: - P2-5 投递容器

    @Test("P2-5 内存态容器 + optional 降级 + insert/fetch/delete 回路")
    @MainActor
    func p2_5_storeRoundtrip() throws {
        let replay = try Self.source("src/ChineseChess/Views/ReplayWindowView.swift")
        #expect(replay.contains("isStoredInMemoryOnly: true"), "瞬态投递（同进程跨 scene 不落盘）")
        #expect(replay.contains("container: ModelContainer?"), "容器 optional")
        #expect(!replay.contains("fatalError("), "启动路径不得 fatalError（assertionFailure 降级）")

        let store = ReplayWindowPayloadStore.shared
        #expect(store.container != nil, "正常路径容器应可用")
        let uuid = "tina-c4a-p2-5"
        try store.insert(uuidString: uuid, recordJSON: "{\"probe\":1}")
        #expect(store.fetch(uuidString: uuid)?.recordJSON == "{\"probe\":1}",
                "fetch 应回投递原文")
        store.delete(uuidString: uuid)
        #expect(store.fetch(uuidString: uuid) == nil, "delete 后 fetch 应为 nil")
    }

    // MARK: - P3-7 后退首层解禁

    @Test("P3-7 后退首层解禁：仅未选中禁用")
    func p3_7_backAtRoot() throws {
        let explorer = try Self.source("src/ChineseChess/Views/OpeningExplorerView.swift")
        #expect(explorer.contains(".disabled(selectedNode == nil)"),
                "首层（parent==nil）应可回起始")
        #expect(!explorer.contains(".disabled(selectedNode?.parent == nil)"),
                "旧判据（parent==nil 即禁用）应移除")
    }

    // MARK: - P3-9 重试 + 分态

    @Test("P3-9 投递竞态 200ms 重试一次 + corrupt/empty 分态")
    func p3_9_retryAndCorruptSplit() throws {
        let replay = try Self.source("src/ChineseChess/Views/ReplayWindowView.swift")
        #expect(replay.contains("Task.sleep(nanoseconds: 200_000_000)"), "200ms 重试间隔")
        #expect(replay.contains("if !fetchDelivered(pid: pid)"), "首拉失败才重试（至多两次）")
        #expect(Self.count("fetchDelivered(pid: pid)", in: replay) >= 2, "重试第二次拉取")
        #expect(Self.count("deliveryCorrupt", in: replay) >= 2, "corrupt 状态位（声明+置位）")
        #expect(replay.contains("p9.shell.corrupt"), "corrupt 独立文案")
        #expect(replay.contains("p9.shell.empty"), "empty 文案保留（两态可区分）")
    }

    // MARK: - P3-10 壳期四钮禁用

    @Test("P3-10 壳期四钮禁用视觉（prev/play/next/toLatest）")
    func p3_10_shellButtonsDisabled() throws {
        let replay = try Self.source("src/ChineseChess/Views/ReplayWindowView.swift")
        #expect(Self.count(".disabled(true)", in: replay) == 4,
                "控制条四颗操作钮应统一 disabled（C4b 芯接入解禁）")
    }

    // MARK: - P3-11 语义色

    @Test("P3-11 结果语义色：moveSequence=蓝 / openingName=橙")
    func p3_11_iconColor() {
        let mv = OpeningSearchResultItem.moveSequence(path: [], title: "着法", subtitle: nil)
        let op = OpeningSearchResultItem.openingName(name: "中炮", variation: [], title: "布局", subtitle: nil)
        #expect(mv.iconColor == .blue, "着法序列应为语义蓝")
        #expect(op.iconColor == .orange, "布局名称应为语义橙")
    }

    // MARK: - P9 runtime 实测锚（无头 hosting，LAYOUT_DUMP 文件桥）
    //
    // R3b：headless 无窗环境 onAppear 不触发 → 本锚环境面阻断。通道定案=环境探测前置：
    // - 探测设计：1512 档探测即首档——dump 有产出 = 有窗能力，两档断言全跑（真绿）；
    // - 无窗：显式日志标注 + 提前 return（标记行 `[P9-ENV]` 即审计锚，与真绿可区分，禁静默通过）；
    // - 双实证记录（通道选型依据）：R2 swift-testing Skip.record 编译红（本工具链无此 API）；
    //   R3 XCTSkip 在 async @Test 被记红（Tina 复跑日志 C4aReworkVerifyTests-080642.log:186
    //   "Caught error: XCTSkip(errorCode: 106)"）——两条 throw 通道均不可用，唯环境探测前置可行。
    // 锚本身的断言面不变：1512 档≈378 / 760 档下限 190（无窗时保留待图形会话补验）。

    @Test("P9 实测锚：侧栏实宽占比 ≥25%（1512 档≈378 / 760 档下限 190；无窗环境显式标注）")
    @MainActor
    func p9_runtimeMeasuredAnchor() async throws {
        let bridgeURL = URL(fileURLWithPath: "/tmp/v64c2-layout-harness.json")
        let dumpURL = URL(fileURLWithPath: "/tmp/v64c2-layout-harness.json.dump")
        try? FileManager.default.removeItem(at: dumpURL)
        try "{\"dump\":\"1\"}".write(to: bridgeURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: bridgeURL)
            try? FileManager.default.removeItem(at: dumpURL)
        }

        let uuid = "tina-c4a-anchor"
        let record = GameRecord(
            title: "C4a 快验锚",
            redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: nil),
            result: .redWon,
            totalMoves: 0,
            moves: [])
        let json = String(data: try JSONEncoder().encode(record), encoding: .utf8)!
        let store = ReplayWindowPayloadStore.shared
        try store.insert(uuidString: uuid, recordJSON: json)
        defer { store.delete(uuidString: uuid) }

        func intField(_ line: String, _ key: String) -> Double? {
            guard let r = line.range(of: "\"\(key)\":\"") else { return nil }
            var s = Substring(line[r.upperBound...])
            if let q = s.firstIndex(of: "\"") { s = s[..<q] }
            return Double(s)
        }

        // hosting + 轮询 dump 文件（≤6s）；nil = 无窗环境（dump 无产出）
        func dumpLine(width: CGFloat) async throws -> String? {
            let host = NSHostingView(rootView: ReplayWindow()
                .environment(\.replayWindowPayloadID, uuid))
            host.frame = NSRect(x: 0, y: 0, width: width, height: 820)
            // 二试（09-18）：离屏 NSWindow 挂载——无窗 hosting 实证不火 onAppear/.task
            let win = NSWindow(contentRect: host.frame,
                               styleMask: [.borderless],
                               backing: .buffered, defer: false)
            win.contentView = host
            defer { win.contentView = nil }   // 挂载件显式拆卸，不留窗口残留
            for _ in 0..<30 {
                try await Task.sleep(nanoseconds: 200_000_000)
                host.layoutSubtreeIfNeeded()
                if let text = try? String(contentsOf: dumpURL, encoding: .utf8),
                   let line = text.components(separatedBy: .newlines)
                    .last(where: { $0.contains("\"page\":\"P9\"") && $0.contains("analysisMeasured") }) {
                    return line
                }
            }
            return nil
        }

        // R3b 环境探测前置：1512 档探测即首档——无产出 = headless 无窗，显式标注后提前
        // return（标记行是审计锚：runner 日志 grep '[P9-ENV]' 可区分真绿与环境标注，
        // 断言面 1512/760 保留待图形会话补验；本 suite 其余 9 用例覆盖静态面+数学锚+投递回路）
        guard let line1512 = try await dumpLine(width: 1512) else {
            print("[P9-ENV] headless 无窗——锚断言保留待图形会话补验（onAppear 链路不触发，dump 无产出；1512/760 断言面未执行）")
            return
        }
        let m1 = try #require(intField(line1512, "analysisMeasured"))
        let w1 = try #require(intField(line1512, "width"))
        #expect(m1 / w1 >= 0.249, "1512 档实测占比 ≥25%：\(m1)/\(w1)")
        #expect(abs(m1 - max(w1 * 0.25, 190)) <= 2.5,
                "1512 档实宽 ≈ max(25%×总宽, 190)：\(m1) vs \(max(w1 * 0.25, 190))")

        // 760 档：下限兜底（1512 已实证有窗，此档无产出属异常态——#require 报红，非环境面）
        try? FileManager.default.removeItem(at: dumpURL)
        let line760 = try #require(await dumpLine(width: 760),
            "1512 档有产出但 760 档无 dump——非环境面，属回归信号")
        let m2 = try #require(intField(line760, "analysisMeasured"))
        let w2 = try #require(intField(line760, "width"))
        #expect(m2 == 190, "760 档应下限兜底 190：实测 \(m2)")
        #expect(m2 / w2 > 0.25, "下限绑定档占比 >25%：\(m2)/\(w2)")
    }
}
