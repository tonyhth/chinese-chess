import Testing
import Foundation
@testable import ChineseChess

// MARK: - Ruby 审查返工：isInCheck stored property
// 注意：原源码文本匹配测试已移除（测源码文本而非行为，重构后必然失效）
// 保留行为测试

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
