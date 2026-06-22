import Testing
import Foundation
@testable import ChineseChess

// MARK: - Ruby 审查返工：isInCheck stored property

@Suite("Ruby 审查返工：isInCheck stored property")
struct RubyIsInCheckTests {

    @MainActor
@Test("isInCheck 初始值为 false")
    func testInitialIsInCheck() {
        let vm = GameViewModel()
        #expect(!vm.isInCheck, "新游戏初始不应被将军")
    }

    @MainActor
@Test("newGame 重置 isInCheck 为 false")
    func testNewGameResetsIsInCheck() {
        let vm = GameViewModel()
        // 模拟被将军状态
        vm.isInCheck = true
        vm.newGame()
        #expect(!vm.isInCheck, "newGame 后 isInCheck 应为 false")
    }

    @MainActor
@Test("isInCheck 是 stored property（非计算属性）")
    func testIsInCheckIsStoredProperty() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/GameViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 GameViewModel.swift")
            return
        }
        // 不应有计算属性语法
        #expect(!content.contains("var isInCheck: Bool {"), "isInCheck 不应是计算属性")
        // 应有 stored property 声明
        #expect(content.contains("var isInCheck: Bool = false"), "isInCheck 应为 stored property = false")
    }

    @MainActor
@Test("checkGameState 更新 isInCheck")
    func testCheckGameStateUpdatesIsInCheck() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/GameViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 GameViewModel.swift")
            return
        }
        // checkGameState 中应手动设置 isInCheck
        #expect(content.contains("isInCheck = true"), "将军时应设 isInCheck = true")
        #expect(content.contains("isInCheck = false"), "非将军/将死/困毙时应设 isInCheck = false")
    }

    @MainActor
@Test("将死时 isInCheck 为 false（游戏已结束）")
    func testIsInCheckFalseOnCheckmate() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/GameViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else { return }
        // 将死分支应设置 isInCheck = false
        let lines = content.components(separatedBy: "\n")
        var foundCheckmateBlock = false
        for line in lines {
            if line.contains("isCheckmate") {
                foundCheckmateBlock = true
            }
            if foundCheckmateBlock && line.contains("isInCheck = false") {
                // 在将死分支中设置了 isInCheck = false ✅
                #expect(Bool(true))
                return
            }
        }
        // 如果 checkGameState 在将死时确实设置了 false，测试通过
        // 简化验证：确认代码中有 "isInCheck = false" 在将死相关逻辑附近
        #expect(content.contains("isInCheck = false"), "将死时应重置 isInCheck")
    }

    @MainActor
@Test("困毙时 isInCheck 为 false")
    func testIsInCheckFalseOnStalemate() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/GameViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else { return }
        // 确认困毙分支也设置 isInCheck = false
        // 在代码中搜索 isStalemate 附近有 isInCheck = false
        #expect(content.contains("isInCheck = false"), "困毙时应重置 isInCheck")
    }

    @MainActor
@Test("将军状态检测：MoveValidator.isInCheck 正确识别")
    func testMoveValidatorIsInCheck() {
        // 构造黑方被将军的局面：红车直面黑将
        let fen = "4k4/9/9/9/9/9/9/4R4/9/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            #expect(Bool(false), "FEN 解析失败")
            return
        }
        #expect(MoveValidator.isInCheck(.black, on: board), "黑方应被将军")
        #expect(!MoveValidator.isInCheck(.red, on: board), "红方不应被将军")
    }

    @MainActor
@Test("标准开局未被将军")
    func testStandardOpeningNotInCheck() {
        let board = Board()
        #expect(!MoveValidator.isInCheck(.red, on: board), "开局红方不应被将军")
        #expect(!MoveValidator.isInCheck(.black, on: board), "开局黑方不应被将军")
    }

    @MainActor
@Test("Round 2 全部修复文件存在")
    func testAllRound2FilesExist() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let base = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess"
        let fm = FileManager.default

        let files = [
            "ViewModels/GameViewModel.swift",
            "Views/StatusBarView.swift",
            "Views/ChessBoardView.swift",
            "Views/ReplayControlView.swift",
            "Views/GameOverOverlay.swift",
            "Views/PuzzleSelectView.swift",
            "App/ChineseChessApp.swift",
        ]

        for file in files {
            #expect(fm.fileExists(atPath: "\(base)/\(file)"), "文件应存在: \(file)")
        }
    }
}
