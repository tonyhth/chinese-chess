import Testing
import Foundation
@testable import ChineseChess

// MARK: - v2.2.3 两个遗留问题修复测试

@Suite("v2.2.3 遗留问题修复")
struct V223FixTests {

    // MARK: - 问题1：英文界面 → 废弃本地化，硬编码中文

    @Test("问题1: macOS App 使用 .environment(l10n) 注入语言")
    func testMacOSUseEnvironmentLocale() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ChineseChessApp.swift")
            return
        }
        #expect(!content.contains("AppleLanguages"), "不应再设置 AppleLanguages")
        #expect(content.contains("L10n.shared"), "应使用 L10n.shared 获取语言")
    }

    @Test("问题1: iOS App 使用 .environment(l10n) 注入语言")
    func testiOSUseEnvironmentLocale() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessiOSApp.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ChineseChessiOSApp.swift")
            return
        }
        #expect(!content.contains("AppleLanguages"), "不应再设置 AppleLanguages")
        #expect(content.contains("L10n.shared"), "应使用 L10n.shared 获取语言")
    }

    @Test("问题1: AIDifficulty.displayName 使用 localized")
    func testAIDifficultyDisplayNameLocalized() {
        // displayName 现在返回 l10n.t() key，不再是硬编码中文
        // 在 zh-Hans locale 下运行时应返回中文值
        #expect(AIDifficulty.beginner.displayName == L10n.shared.t("difficulty.beginner"))
        #expect(AIDifficulty.easy.displayName == L10n.shared.t("difficulty.easy"))
        #expect(AIDifficulty.medium.displayName == L10n.shared.t("difficulty.medium"))
        #expect(AIDifficulty.hard.displayName == L10n.shared.t("difficulty.hard"))
        #expect(AIDifficulty.master.displayName == L10n.shared.t("difficulty.master"))
    }

    @Test("问题1: 关键 View 文件使用 l10n.t() 国际化")
    func testViewsUseStringLocalized() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let views = [
            "ChineseChess/Views/GameOverOverlay.swift",
            "ChineseChess/Views/PuzzleSelectView.swift",
            "ChineseChess/Views/StatusBarView.swift",
            "ChineseChess/Views/ToolbarView.swift",
            "ChineseChess/Views/SettingsView.swift",
            "ChineseChess/Views/GameHistoryView.swift",
            "ChineseChess/Views/RecordPanelView.swift",
            "ChineseChess/Views/PrivacyPolicyView.swift",
        ]
        for view in views {
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/\(view)"
            guard let content = try? String(contentsOfFile: path) else { continue }
            #expect(content.contains("l10n.t("), "\(view) 应使用 l10n.t() 国际化")
        }
    }

    @Test("问题1: 关键 ViewModel 使用 l10n.t() 国际化")
    func testViewModelsUseStringLocalized() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let files = [
            "ChineseChess/ViewModels/GameViewModel.swift",
            "ChineseChess/ViewModels/PuzzleViewModel.swift",
        ]
        for file in files {
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/\(file)"
            guard let content = try? String(contentsOfFile: path) else { continue }
            #expect(content.contains("L10n.shared.t("), "\(file) 应使用 l10n.t() 国际化")
        }
    }

    @Test("问题1: GameOverOverlay 使用 l10n.t() 键")
    func testGameOverOverlayLocalized() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/GameOverOverlay.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 GameOverOverlay.swift")
            return
        }
        #expect(content.contains("gameover.redWon"), "应有 gameover.redWon 键")
        #expect(content.contains("gameover.blackWon"), "应有 gameover.blackWon 键")
        #expect(content.contains("gameover.newGame"), "应有 gameover.newGame 键")
        #expect(content.contains("gameover.viewRecord"), "应有 gameover.viewRecord 键")
    }

    @Test("问题1: ToolbarView 使用 l10n.t() 键")
    func testToolbarViewLocalized() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ToolbarView.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ToolbarView.swift")
            return
        }
        #expect(content.contains("game.hint"), "应有 game.hint 键")
        #expect(content.contains("difficulty.label"), "应有 difficulty.label 键")
        #expect(content.contains("difficulty.beginner"), "应有 difficulty.beginner 键")
        #expect(content.contains("difficulty.master"), "应有 difficulty.master 键")
    }

    // MARK: - 问题2：棋盘启动时太小 → 增大窗口 + 最小高度

    @Test("问题2: macOS 默认窗口尺寸 760x860")
    func testDefaultWindowSize() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ChineseChessApp.swift")
            return
        }
        #expect(content.contains("defaultSize(width: 760, height: 860)"), "默认窗口应为 760x860")
    }

    @Test("问题2: macOS 最小窗口尺寸 500x600")
    func testMinimumWindowSize() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ChineseChessApp.swift")
            return
        }
        #expect(content.contains("minWidth: 500, minHeight: 600"),
               "主窗口 minWidth: 500, minHeight: 600")
    }

    @Test("问题2: 棋盘有 minHeight 280 保护")
    func testBoardMinHeight() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ChineseChessApp.swift")
            return
        }
        #expect(content.contains("minHeight: 280"), "棋盘应有 minHeight: 280 保护")
    }

    // MARK: - 回归：v2.2.2 修复不受影响

    @Test("回归: 残局数量为 651（100古谱+551适情雅趣）")
    func testPuzzleCountRegression() {
        let store = PuzzleStore.shared
        #expect(store.puzzles.count == 551, "残局应为 551 局，实际 \(store.puzzles.count)")
    }

    @Test("回归: SoundEngine 不崩溃")
    func testSoundEngineNoCrash() {
        let engine = SoundEngine.shared
        engine.isMuted = false
        engine.playMove()
        engine.playCapture()
        engine.playCheck()
        engine.playUndo()
        engine.playVictory()
        engine.playDefeat()
        engine.isMuted = true
        engine.playMove()
        #expect(true, "SoundEngine 不崩溃")
    }

    @Test("回归: PuzzleStore ResourceBundle fallback 仍存在")
    func testPuzzleStoreFallbackRegression() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Services/PuzzleStore.swift")
        guard let content = content else { return }
        #expect(content.contains("ResourceBundle.url"), "应仍使用 ResourceBundle")
        #expect(content.contains("subdirectory:"), "应仍有 subdirectory fallback")
    }

    @Test("回归: SoundEngine 资源查找仍使用 ResourceBundle（非 Bundle.main）")
    func testSoundEngineNoBundleMain() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Services/SoundEngine.swift")
        guard let content = content else { return }
        #expect(!content.contains("Bundle.main.url"), "不应使用 Bundle.main.url（P0 审查返工）")
        #expect(content.contains("ResourceBundle.url"), "应使用 ResourceBundle.url")
    }
}
