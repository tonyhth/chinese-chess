import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.2 P1-2 空状态统一源码锚验收（Vera P1-2 / Luke 派单 2026-08-16 晚）
//
// 依据：docs/reviews/v6.2-p1-2-decision-eric.md（裁定：全量 ContentUnavailableView，
// 判据 = deploymentTarget macOS 14.0 / iOS 17.0 双达标）
// ⚠️ 自动化边界（沿 V62LayoutTests 口径）：本测试锚定源码结构——空态分支使用
//   ContentUnavailableView + icon/key 配对正确 + MGBV 防回退；空态的视觉呈现
//   （布局/尺寸/双平台渲染）归 M4 手工对照，勿将源码锚误当视觉全验。
// 范围裁定锚：ChapterSelectView 实测无页面级空态（入口降级语义），豁免统一（Luke 裁）；
//   MGBV:484 已是目标形态零改动。

@Suite("v6.2 P1-2 空状态统一")
struct P12EmptyStateTests {

    // MARK: - 路径工具（V62LayoutTests 同款 #filePath 推导）

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ChineseChessTests/
            .deletingLastPathComponent()   // src/
            .deletingLastPathComponent()   // worktree 根
    }

    private static func source(_ relative: String) throws -> String {
        let url = repoRoot.appendingPathComponent(relative)
        return try String(contentsOfFile: url.path, encoding: .utf8)
    }

    private static func view(_ name: String) throws -> String {
        try Self.source("src/ChineseChess/Views/\(name).swift")
    }

    // MARK: - T1-T5 五视图空态分支锚（替换 commit 0ab60ac）

    @Test func t1_gameHistoryUsesCUV() throws {
        let s = try Self.view("GameHistoryView")
        #expect(s.contains("ContentUnavailableView"))
        #expect(s.contains(#""history.empty""#))
        #expect(s.contains(#""history.empty.hint""#))
        #expect(s.contains(#"systemImage: "clock.arrow.circlepath""#))
    }

    @Test func t2_puzzleSelectDualStateCUV() throws {
        let s = try Self.view("PuzzleSelectView")
        // 双态显式分支：非搜索态（puzzlepiece + empty + hint）/ 搜索态（magnifyingglass + noMatch）
        #expect(s.contains("ContentUnavailableView"))
        #expect(s.contains(#""puzzle.empty""#))
        #expect(s.contains(#""puzzle.empty.hint""#))
        #expect(s.contains(#""puzzle.noMatch""#))
        #expect(s.contains(#"systemImage: "puzzlepiece""#))
        #expect(s.contains(#"systemImage: "magnifyingglass""#))
    }

    @Test func t3_achievementUsesCUV() throws {
        let s = try Self.view("AchievementView")
        #expect(s.contains("ContentUnavailableView"))
        #expect(s.contains(#""achievement.empty.title""#))
        #expect(s.contains(#""achievement.empty.hint""#))
        #expect(s.contains(#"systemImage: "trophy""#))
    }

    @Test func t4_openingExplorerCUVWithAction() throws {
        let s = try Self.view("OpeningExplorerView")
        #expect(s.contains("ContentUnavailableView"))
        #expect(s.contains(#""opening.explorer.unlock""#))
        #expect(s.contains(#"systemImage: "lock.circle""#))
        // 唯一 action 通道场景：close 按钮迁入 CUV actions
        #expect(s.contains("actions:"))
        #expect(s.contains(#""common.close""#))
    }

    @Test func t5_dailyChallengeUsesCUV() throws {
        let s = try Self.view("DailyChallengeView")
        #expect(s.contains("ContentUnavailableView"))
        #expect(s.contains(#""daily.view.noRecord""#))
    }

    // MARK: - T6 MGBV 防回退锚（零改动验证：仍为目标形态标杆）

    @Test func t6_masterGameBrowserCUVIntact() throws {
        let s = try Self.view("MasterGameBrowserView")
        #expect(s.contains("ContentUnavailableView"))
        #expect(s.contains(#""master.search.noResult""#))
        #expect(s.contains(#"systemImage: "magnifyingglass""#))
    }

    // MARK: - T7 l10n key 存在性（零新 key 全复用验证）

    @Test func t7_l10nKeysExist() throws {
        let xcstrings = try Self.source("src/ChineseChess/Resources/Localizable.xcstrings")
        let keys = [
            "history.empty", "history.empty.hint",
            "puzzle.empty", "puzzle.empty.hint", "puzzle.noMatch",
            "achievement.empty.title", "achievement.empty.hint",
            "daily.view.noRecord",
            "opening.explorer.unlock",
            "master.search.noResult",
            "common.close",
        ]
        for key in keys {
            #expect(xcstrings.contains("\"\(key)\": {"), "缺 key: \(key)")
        }
    }

    // MARK: - T8 范围裁定锚：ChapterSelect 豁免（入口降级非空态）

    @Test func t8_chapterSelectExempt() throws {
        let s = try Self.view("ChapterSelectView")
        // 豁免理由锚：无页面级空态分支，demoPuzzleCount==0 是入口降级（DemoEntryCard 恒在）
        #expect(!s.contains("ContentUnavailableView"), "ChapterSelect 若引入 CUV 需重审豁免裁定")
        #expect(s.contains("DemoEntryCard"))
    }
}
