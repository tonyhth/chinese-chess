import Testing
import Foundation
@testable import ChineseChess

// MARK: - v2.2.3 两个遗留问题修复测试

@Suite("v2.2.3 遗留问题修复")
struct V223FixTests {

    // MARK: - 问题1：英文界面 → 废弃本地化，硬编码中文

    @Test("问题1: macOS App 不再设置 AppleLanguages")
    func testMacOSNoAppleLanguages() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ChineseChessApp.swift")
            return
        }
        #expect(!content.contains("AppleLanguages"), "不应再设置 AppleLanguages")
        #expect(!content.contains(".environment(\\.locale"), "不应使用 .environment(\\.locale)")
    }

    @Test("问题1: iOS App 不再设置 AppleLanguages")
    func testiOSNoAppleLanguages() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessiOSApp.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ChineseChessiOSApp.swift")
            return
        }
        #expect(!content.contains("AppleLanguages"), "不应再设置 AppleLanguages")
        #expect(!content.contains(".environment(\\.locale"), "不应使用 .environment(\\.locale)")
    }

    @Test("问题1: AIDifficulty.displayName 返回硬编码中文")
    func testAIDifficultyDisplayName() {
        #expect(AIDifficulty.beginner.displayName == "新手")
        #expect(AIDifficulty.easy.displayName == "初级")
        #expect(AIDifficulty.medium.displayName == "中级")
        #expect(AIDifficulty.hard.displayName == "高级")
        #expect(AIDifficulty.master.displayName == "大师")
    }

    @Test("问题1: 关键 View 文件不再使用 String(localized:)")
    func testNoStringLocalizedInViews() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let views = [
            "ChineseChess/Views/GameOverOverlay.swift",
            "ChineseChess/Views/PuzzleSelectView.swift",
            "ChineseChess/Views/StatusBarView.swift",
            "ChineseChess/Views/ToolbarView.swift",
            "ChineseChess/Views/SettingsView.swift",
            "ChineseChess/Views/GameHistoryView.swift",
        ]
        for view in views {
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/\(view)"
            guard let content = try? String(contentsOfFile: path) else { continue }
            let lines = content.components(separatedBy: "\n")
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { continue }
                if trimmed.contains("String(localized:") {
                    #expect(Bool(false), "\(view) 第 \(i+1) 行仍使用 String(localized:)")
                }
            }
        }
    }

    @Test("问题1: 关键 ViewModel 不再使用 String(localized:)")
    func testNoStringLocalizedInViewModels() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let files = [
            "ChineseChess/ViewModels/GameViewModel.swift",
            "ChineseChess/ViewModels/PuzzleViewModel.swift",
        ]
        for file in files {
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/\(file)"
            guard let content = try? String(contentsOfFile: path) else { continue }
            let lines = content.components(separatedBy: "\n")
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { continue }
                if trimmed.contains("String(localized:") {
                    #expect(Bool(false), "\(file) 第 \(i+1) 行仍使用 String(localized:)")
                }
            }
        }
    }

    @Test("问题1: GameOverOverlay 使用硬编码中文")
    func testGameOverOverlayChinese() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/GameOverOverlay.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 GameOverOverlay.swift")
            return
        }
        #expect(content.contains("红方获胜"), "应有红方获胜文字")
        #expect(content.contains("黑方获胜"), "应有黑方获胜文字")
        #expect(content.contains("再来一局"), "应有再来一局按钮")
        #expect(content.contains("查看棋谱"), "应有查看棋谱按钮")
    }

    @Test("问题1: ToolbarView 使用硬编码中文")
    func testToolbarViewChinese() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ToolbarView.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ToolbarView.swift")
            return
        }
        #expect(content.contains("\"提示\""), "应有提示按钮")
        #expect(content.contains("\"AI 难度\""), "应有 AI 难度标签")
        #expect(content.contains("\"新手\""), "应有新手选项")
        #expect(content.contains("\"大师\""), "应有大师选项")
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

    @Test("问题2: macOS 最小窗口尺寸增大")
    func testMinimumWindowSize() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ChineseChessApp.swift")
            return
        }
        #expect(content.contains("minWidth: 700") || content.contains("minWidth: 760"),
               "最小宽度应增大（700+）")
        #expect(content.contains("minHeight: 820") || content.contains("minHeight: 860"),
               "最小高度应增大（820+）")
    }

    @Test("问题2: 棋盘有 minHeight 480 保护")
    func testBoardMinHeight() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let content = try? String(contentsOfFile: "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift")
        guard let content = content else {
            #expect(Bool(false), "无法读取 ChineseChessApp.swift")
            return
        }
        #expect(content.contains("minHeight: 480"), "棋盘应有 minHeight: 480 保护")
    }

    // MARK: - 回归：v2.2.2 修复不受影响

    @Test("回归: 残局数量仍为 139")
    func testPuzzleCountRegression() {
        let store = PuzzleStore.shared
        #expect(store.puzzles.count == 139, "残局应为 139 局，实际 \(store.puzzles.count)")
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
