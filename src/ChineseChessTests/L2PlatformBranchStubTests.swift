import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.3 Step 3 L2 平台分支补桩（C4 定性表配套锢定）
//
// 底料：docs/test/platform-branch-matrix.md（Eric 08-28 快照，🔴 零覆盖热点）
// 定性：docs/test/os-branch-disposition-v63.md（ST1-ST12 映射索引 §五）
// 模式：iOS 分支 macOS test target 编译不可见 → 源码文本断言（V62LayoutTests T6
// /IOSToolbarAdaptationTests 既有范式）；macOS 分支可运行时处给运行时断言。
// ⚠️ 断言锚用符号/结构（非行号），抗行号漂移。

@Suite("L2 平台分支补桩", .serialized)
struct L2PlatformBranchStubTests {

    private static let repoRoot = FileManager.default.currentDirectoryPath
        + "/../.."   // xctest cwd = test bundle 目录（DerivedData 深层）→ 该范式与 V62LayoutTests 不同，改用 #filePath 锚定

    /// 源码读取：以测试文件自身 #filePath 反推仓库根（抗 DerivedData 漂移）
    private static func source(_ relative: String) throws -> String {
        // #filePath = .../src/ChineseChessTests/L2PlatformBranchStubTests.swift
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile.deletingLastPathComponent()          // .../ChineseChessTests/
            .deletingLastPathComponent()                              // .../src/
            .deletingLastPathComponent()                              // .../（worktree 根）
        return try String(contentsOf: repoRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    /// 提取 `#if os(X)` … #endif 块集合（按出现顺序）
    private static func osBlocks(_ source: String, os: String) -> [String] {
        var blocks: [String] = []
        var searchRange = source.startIndex..<source.endIndex
        let marker = "#if os(\(os))"
        while let r = source.range(of: marker, range: searchRange) {
            let rest = source[r.lowerBound...]
            guard let end = rest.range(of: "#endif") else { break }
            blocks.append(String(source[r.lowerBound..<end.upperBound]))
            searchRange = end.upperBound..<source.endIndex
        }
        return blocks
    }

    // ---------- ST1: ToolbarView（⭐参照案1，逃逸史 1189989） ----------

    @Test("ST1: ToolbarView iOS HStack 工具栏结构 + macOS 快捷键集合")
    func st1Toolbar() throws {
        let src = try Self.source("src/ChineseChess/Views/ToolbarView.swift")
        let ios = Self.osBlocks(src, os: "iOS").joined()
        #expect(ios.contains("HStack"), "iOS 工具栏应为 HStack 布局")
        #expect(ios.contains("viewModel.undoMove()"), "iOS 段应含悔棋动作")
        #expect(ios.contains("viewModel.hintMove()") || ios.contains("hint"), "iOS 段应含提示类按钮")

        let mac = Self.osBlocks(src, os: "macOS").joined()
        // ⌘N/⌘Z/⌘⇧H/⌘⇧R/⌘⇧L 快捷键族
        for key in ["\"n\"", "\"z\"", "\"h\"", "\"r\"", "\"l\""] {
            #expect(mac.contains("keyboardShortcut(\(key)"), "macOS 段应含 keyboardShortcut(\(key)（快捷键族锢定）")
        }
        #expect(mac.contains("controlSize"), "macOS 段应含 controlSize 修饰")
    }

    // ---------- ST2: StatusBarView（⭐参照案3，逃逸史 b19a4ef） ----------

    @Test("ST2: StatusBarView iOS 被吃棋子精简段（iOSCapturedPiecesSection + capturedRowHeight=24）")
    func st2StatusBar() throws {
        let src = try Self.source("src/ChineseChess/Views/StatusBarView.swift")
        #expect(src.contains("#if os(iOS)"), "StatusBarView 应有 iOS 分支")
        let ios = Self.osBlocks(src, os: "iOS").joined()
        #expect(ios.contains("iOSCapturedPiecesSection"), "iOS 分支应调用 iOSCapturedPiecesSection（原🔴零命中）")
        #expect(ios.contains("capturedRowHeight: CGFloat = 24"), "iOS capturedRowHeight 应为 24")
        #expect(!ios.contains("engineType"), "iOS 段不得复活引擎类型徽章（b19a4ef 移除锢定）")
    }

    // ---------- ST3: SettingsView E5 清账（⭐参照案2，假切换案现场） ----------

    @Test("ST3: SettingsView/macOS 菜单无引擎开关残留（E5 退场锢定）")
    func st3SettingsE5() throws {
        let settings = try Self.source("src/ChineseChess/Views/SettingsView.swift")
        let app = try Self.source("src/ChineseChess/App/ChineseChessApp.swift")
        #expect(!settings.contains("usePikafishMenu"), "SettingsView 不得残留引擎开关 Toggle（E5）")
        #expect(!app.contains("usePikafishMenu"), "macOS 菜单不得残留引擎开关 Toggle（E5）")
        #expect(settings.contains("#if os(iOS)"), "残余平台分叉（关于页导航形态）应在——只清开关不清惯例")
    }

    // ---------- ST4: GameHistoryView:158 searchable 规避分支（Eric 热点#3：回归即渲染卡死） ----------

    @Test("ST4: GameHistoryView macOS searchable→toolbar 规避分支钉住")
    func st4SearchableWorkaround() throws {
        let src = try Self.source("src/ChineseChess/Views/GameHistoryView.swift")
        let ios = Self.osBlocks(src, os: "iOS").joined()
        let mac = Self.osBlocks(src, os: "macOS").joined()
        #expect(ios.contains(".searchable("), "iOS 段应保留 searchable")
        #expect(!mac.contains(".searchable("), "macOS 段禁用 searchable（sheet 内 NavigationStack 渲染卡死规避——回归即卡死）")
        #expect(mac.contains("toolbar") || mac.contains("searchPlaceholder"), "macOS 段应有 toolbar 搜索栏替代实现")
    }

    // ---------- ST5: 剪贴板调用点计数（Eric 热点#2） ----------

    @Test("ST5: GameHistoryView/AnalysisView 剪贴板调用点在位（NSPasteboard/UIPasteboard 计数锢定）")
    func st5Pasteboard() throws {
        let history = try Self.source("src/ChineseChess/Views/GameHistoryView.swift")
        let analysis = try Self.source("src/ChineseChess/Views/AnalysisView.swift")
        // GameHistoryView: NSPasteboard ×3（导出×2+导入读取）+ UIPasteboard ×1
        #expect(history.components(separatedBy: "NSPasteboard").count - 1 >= 3, "GameHistoryView NSPasteboard 调用点应 ≥3")
        #expect(history.contains("UIPasteboard"), "GameHistoryView iOS 段应含 UIPasteboard")
        #expect(analysis.contains("NSPasteboard"), "AnalysisView 导出应走 NSPasteboard")
    }

    // ---------- ST6: DemoInfoBar（原 iosInfoBar 零命中） ----------

    @Test("ST6: DemoInfoBar 双布局（iosInfoBar/macosInfoBar）")
    func st6DemoInfoBar() throws {
        let src = try Self.source("src/ChineseChess/Views/DemoInfoBar.swift")
        let ios = Self.osBlocks(src, os: "iOS").joined()
        #expect(ios.contains("iosInfoBar"), "iOS 分支应渲染 iosInfoBar（原🔴零命中）")
        #expect(src.contains("macosInfoBar"), "macOS 段应渲染 macosInfoBar")
    }

    // ---------- ST7: MasterGameBrowserView 四零覆盖点（Eric 热点#9） ----------

    @Test("ST7: MasterGameBrowserView iosSearchSheet/搜索模式/loadIndex/focused 四点")
    func st7MasterGameBrowser() throws {
        let src = try Self.source("src/ChineseChess/Views/MasterGameBrowserView.swift")
        let ios = Self.osBlocks(src, os: "iOS").joined()
        let mac = Self.osBlocks(src, os: "macOS").joined()
        #expect(ios.contains("iosSearchSheet"), "iOS 段应含 iosSearchSheet（原🔴）")
        #expect(mac.contains("isSearching"), "macOS 段应含搜索模式 isSearching（原🔴）")
        #expect(mac.contains("loadIndex"), "macOS 段应含 loadIndex 按钮（原🔴）")
        #expect(mac.contains(".focused("), "macOS 段应含 .focused 焦点接管（原🔴）")
    }

    // ---------- ST8: navBar 惯例族 + 杂项（热点#10 族级锢定） ----------

    @Test("ST8: navBarTitleDisplayMode 族 + 触感/iPad/控件宽度杂项")
    func st8NavBarAndMisc() throws {
        // navBar 族：应出现在这些 iOS 分支文件中
        let navBarFiles = [
            "src/ChineseChess/Views/GameHistoryView.swift",
            "src/ChineseChess/Views/AboutView.swift",
            "src/ChineseChess/Views/PrivacyPolicyView.swift",
            "src/ChineseChess/Views/RankPrivilegeView.swift",
        ]
        for rel in navBarFiles {
            let src = try Self.source(rel)
            #expect(src.contains("navigationBarTitleDisplayMode") || src.contains("#if os(iOS)"),
                    "\(rel) 应含 iOS navBar 惯例分支")
        }
        // ChessBoardView 触感（iOS 硬件）
        let board = try Self.source("src/ChineseChess/Views/ChessBoardView.swift")
        #expect(board.contains("UIImpactFeedbackGenerator"), "ChessBoardView iOS 段应含触感反馈")
        // PuzzleSelectView iPad 分支
        let puzzle = try Self.source("src/ChineseChess/Views/PuzzleSelectView.swift")
        #expect(puzzle.contains("horizontalSizeClass") || Self.osBlocks(puzzle, os: "iOS").joined().contains("iPad") || puzzle.contains("UIDevice"), "PuzzleSelectView iOS 段应含 iPad 形态判断")
        // PuzzleDemoView :291 tacticalGroupFilterBar（macOS）+ :570 focused
        let demo = try Self.source("src/ChineseChess/Views/PuzzleDemoView.swift")
        #expect(demo.contains("tacticalGroupFilterBar"), "PuzzleDemoView 应含 tacticalGroupFilterBar（原🔴）")
        // StudyHubView iOSLayout
        let hub = try Self.source("src/ChineseChess/Views/StudyHubView.swift")
        #expect(hub.contains("iOSLayout") || Self.osBlocks(hub, os: "iOS").count > 0, "StudyHubView 应含 iOS 布局分支")
    }

    // ---------- ST9: SoundEngine iOS ×5（Eric 热点#1，静态上限） ----------

    @Test("ST9: SoundEngine iOS 音频会话域五分支（AudioSession 生命周期+打断）")
    func st9SoundEngine() throws {
        let src = try Self.source("src/ChineseChess/Services/SoundEngine.swift")
        let ios = Self.osBlocks(src, os: "iOS")
        #expect(ios.count >= 5, "SoundEngine 应有 ≥5 个 iOS 分支（现 \(ios.count)），全🔴→🟡")
        let joined = ios.joined()
        #expect(joined.contains("AVAudioSession") || joined.contains("audioSession"), "应含 AudioSession 会话管理")
        #expect(joined.contains("deactivateAudioSession") || joined.contains("interruption") || joined.contains("AVAudioSession.interruptionNotification"), "应含打断/停用处理")
    }

    // ---------- ST10: TranspositionTable iOS capacity precondition ----------

    @Test("ST10: TranspositionTable iOS 保守容量分支 + macOS 运行时容量语义")
    func st10TranspositionTable() throws {
        let src = try Self.source("src/ChineseChess/AI/TranspositionTable.swift")
        let ios = Self.osBlocks(src, os: "iOS").joined()
        #expect(ios.contains("precondition"), "iOS init 应含 capacity 2 的幂 precondition（原🔴）")
        // macOS 侧运行时：默认容量可构造且 store/lookup 往返
        let tt = TranspositionTable(capacity: 1 << 12)
        let mv = Move(piece: Piece(kind: .chariot, side: .red, position: Position(row: 0, col: 0), id: 1),
                      from: Position(row: 0, col: 0), to: Position(row: 1, col: 0), captured: nil)
        tt.store(hash: 0xDEAD_BEEF, depth: 8, score: 42, flag: .exact, bestMove: mv)
        let hit = tt.lookup(hash: 0xDEAD_BEEF, depth: 4, alpha: -1000, beta: 1000)
        #expect(hit != nil, "macOS 运行时 TT store/lookup 往返应命中")
    }

    // ---------- ST11: EmbeddedPikafishEngine iOS 诊断 + iOS TT 保守策略 ----------

    @Test("ST11: 引擎 iOS 分支（NNUE bundle 诊断 / <2GB 保守 TT）")
    func st11EngineIOSBranches() throws {
        let src = try Self.source("src/ChineseChess/AI/EmbeddedPikafishEngine.swift")
        let ios = Self.osBlocks(src, os: "iOS").joined()
        #expect(ios.contains("nnue") && ios.contains("Bundle"), "iOS 段应含 NNUE bundle 诊断（原🔴）")
        #expect(ios.contains("physicalMemory"), "iOS 段应含物理内存分档 TT 策略")
        #expect(ios.contains("ttSizeMB = 16"), "iOS <2GB 档应为 16MB 保守值")
    }

    // ---------- ST12: CLI 入口族 guard（SelfPlayRunner ×6 / OpeningBookExpander / argv 路由） ----------

    @Test("ST12: CLI 入口族 macOS 门禁（guard/argv 结构钉住）")
    func st12CLIEntries() throws {
        let sp = try Self.source("src/ChineseChess/AI/SelfPlayRunner.swift")
        #expect(Self.osBlocks(sp, os: "macOS").count >= 6, "SelfPlayRunner 应有 ≥6 个 macOS CLI 入口分支")
        let obe = try Self.source("src/ChineseChess/AI/OpeningBookExpander.swift")
        #expect(obe.contains("#if os(macOS)"), "OpeningBookExpander CLI 入口应有 macOS 门禁（原🔴）")
        let app = try Self.source("src/ChineseChess/App/ChineseChessApp.swift")
        #expect(app.contains("--selfplay"), "macOS App 应含 --selfplay argv 路由")
    }
}
