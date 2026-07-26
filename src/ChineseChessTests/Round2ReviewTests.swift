import Testing
import Foundation
@testable import ChineseChess

// MARK: - Round 2 审查修复验证

@Suite("Round 2 审查修复验证")
@MainActor
struct Round2ReviewTests {

    // MARK: - P0-1: PuzzleSelectView 空状态提示

    @MainActor
@Test("PuzzleSelectView 空状态提示代码存在")
    func testPuzzleSelectViewEmptyState() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 PuzzleSelectView.swift")
            return
        }
        #expect(content.contains("if list.isEmpty"), "应有空列表判断")
        #expect(content.contains("puzzle.empty"), "空状态应有 puzzle.empty 键")
        #expect(content.contains("puzzlepiece"), "空状态应有拼图图标")
    }

    @MainActor
@Test("PuzzleSelectView 空状态有图标和文字")
    func testPuzzleSelectViewEmptyStateComponents() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
        guard let content = try? String(contentsOfFile: filePath) else { return }
        // 空状态有 Image + Text
        #expect(content.contains("Image(systemName: \"puzzlepiece\")"), "应有拼图图标")
        #expect(content.contains("puzzle.empty"), "应有 puzzle.empty 键")
        #expect(content.contains("minHeight: 120"), "空状态应有最小高度")
    }

    // MARK: - P0-2: 残局失败重试弹窗

    @MainActor
@Test("PuzzlePlayView 失败弹窗有重试按钮")
    func testPuzzleFailedRetryButton() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 PuzzleSelectView.swift")
            return
        }
        // 失败弹窗
        #expect(content.contains(".failed"), "应有 .failed 状态判断")
        #expect(content.contains("puzzle.failed"), "应有 puzzle.failed 键")
        #expect(content.contains("common.retry"), "应有 common.retry 键")
        #expect(content.contains("resetPuzzle"), "重试应调用 resetPuzzle()")
        #expect(content.contains("common.back"), "应有 common.back 键")
    }

    @MainActor
@Test("PuzzleViewModel.resetPuzzle 恢复初始状态")
    func testResetPuzzleRestoresState() {
        guard let puzzle = PuzzleStore.shared.puzzles.first else { return }
        let vm = PuzzleViewModel(puzzle: puzzle)
        let initialPieceCount = vm.board.pieces.count
        // 走一步
        let moves = MoveValidator.legalMoves(for: vm.board.pieces.first!, on: vm.board)
        if let firstMove = moves.first {
            let piece = vm.board.piece(at: firstMove.from)!
            let move = Move(piece: piece, from: firstMove.from, to: firstMove.to, captured: vm.board.piece(at: firstMove.to))
            vm.board.execute(move)
        }
        // reset
        vm.resetPuzzle()
        #expect(vm.board.moveHistory.isEmpty, "重置后 moveHistory 应为空")
        #expect(vm.gameMoves.isEmpty, "重置后 gameMoves 应为空")
        #expect(vm.gameState == .playing, "重置后状态应为 playing")
        #expect(vm.board.pieces.count == initialPieceCount, "重置后棋子数应恢复")
    }

    // MARK: - P1-3: 将军视觉提示

    @MainActor
@Test("GameViewModel.isInCheck 属性存在")
    func testGameViewModelIsInCheck() {
        let vm = GameViewModel()
        // 初始局面未被将军
        #expect(!vm.isInCheck, "初始局面不应被将军")
    }

    @MainActor
@Test("isInCheck 游戏结束时返回 false")
    func testIsInCheckWhenGameOver() {
        let vm = GameViewModel()
        vm.gameState = .redWon
        #expect(!vm.isInCheck, "游戏结束后 isInCheck 应返回 false")
    }

    @MainActor
@Test("StatusBarView 包含将军视觉提示代码")
    func testStatusBarCheckWarning() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StatusBarView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 StatusBarView.swift")
            return
        }
        #expect(content.contains("isInCheck"), "应检查 isInCheck 属性")
        #expect(content.contains("status.check"), "应有 status.check 键")
        #expect(content.contains("pulseAnimation"), "将军提示应有脉冲动画")
    }

    @MainActor
@Test("MoveValidator.isInCheck 能检测将军状态")
    func testMoveValidatorIsInCheck() {
        // 构造一个被将军的局面
        // FEN: 车在将的正前方，无阻隔
        let fen = "4k4/9/9/9/9/9/9/4R4/9/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            #expect(Bool(false), "FEN 解析失败")
            return
        }
        // 红车在 (7,4) 直面黑将 (0,4) — 黑方被将军
        #expect(MoveValidator.isInCheck(.black, on: board), "黑方应被将军")
    }

    // MARK: - P1-4: macOS "棋局"菜单栏

    @MainActor
@Test("ChineseChessApp 包含 CommandMenu localized")
    func testMacOSCommandMenu() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 ChineseChessApp.swift")
            return
        }
        #expect(content.contains("game.menuLabel"), "应有 game.menuLabel 键")
        #expect(content.contains("game.newGame"), "应有 game.newGame 键")
        #expect(content.contains("game.undoMove"), "应有 game.undoMove 键")
        #expect(content.contains("game.hint"), "应有 game.hint 键")
        // 快捷键
        #expect(content.contains("keyboardShortcut(\"n\""), "新局应有 Cmd+N 快捷键")
        #expect(content.contains("keyboardShortcut(\"z\""), "悔棋应有 Cmd+Z 快捷键")
    }

    // MARK: - P1-5: 回放 Slider 进度条

    @MainActor
@Test("ReplayControlView 使用 Slider 替代 ProgressView")
    func testReplaySlider() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayControlView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 ReplayControlView.swift")
            return
        }
        #expect(content.contains("Slider("), "应使用 Slider 替代 ProgressView")
        #expect(!content.contains("ProgressView("), "不应再使用 ProgressView")
        // Slider 绑定 jumpTo
        #expect(content.contains("jumpTo"), "Slider 值变化应调用 jumpTo")
    }

    @MainActor
@Test("ReplayViewModel.jumpTo 正确跳转")
    func testReplayJumpTo() {
        let moves = [
            GameMove(id: UUID(), piece: Piece(kind: .soldier, side: .red, position: Position(row: 6, col: 4), id: 13),
                     from: Position(row: 6, col: 4), to: Position(row: 5, col: 4), captured: nil,
                     turnNumber: 1, notation: "兵五进一", timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0),
            GameMove(id: UUID(), piece: Piece(kind: .soldier, side: .black, position: Position(row: 3, col: 4), id: 29),
                     from: Position(row: 3, col: 4), to: Position(row: 4, col: 4), captured: nil,
                     turnNumber: 1, notation: "卒5进1", timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0),
            GameMove(id: UUID(), piece: Piece(kind: .chariot, side: .red, position: Position(row: 9, col: 0), id: 0),
                     from: Position(row: 9, col: 0), to: Position(row: 9, col: 4), captured: nil,
                     turnNumber: 2, notation: "车九平五", timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0),
        ]
        let record = GameRecord(
            id: UUID(), title: "测试", date: Date(),
            redPlayer: PlayerInfo(name: "红方", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑方", isAI: true, difficulty: .medium),
            difficulty: .medium, result: .redWon, totalMoves: 3, moves: moves, initialFEN: nil
        )
        let vm = ReplayViewModel(record: record)

        // Slider 拖到中间
        vm.jumpTo(index: 1)
        #expect(vm.currentIndex == 1)
        #expect(vm.lastMove != nil)
        #expect(vm.lastMove?.from == moves[0].from)

        // Slider 拖到末尾
        vm.jumpTo(index: 3)
        #expect(vm.currentIndex == 3)
        #expect(!vm.canGoForward)

        // Slider 拖回开头
        vm.jumpTo(index: 0)
        #expect(vm.currentIndex == 0)
        #expect(vm.lastMove == nil)
    }

    // MARK: - P1-6: 残局提示框"继续"按钮

    @MainActor
@Test("PuzzlePlayView 提示框有'继续'按钮")
    func testPuzzleHintContinueButton() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 PuzzleSelectView.swift")
            return
        }
        #expect(content.contains("currentHint"), "应显示 currentHint")
        #expect(content.contains("puzzle.continueLabel"), "提示框应有 puzzle.continueLabel 键")
        #expect(content.contains("dismissHint"), "继续按钮应调用 dismissHint()")
    }

    @MainActor
@Test("PuzzleViewModel.showHint/dismissHint 正常工作")
    func testPuzzleShowDismissHint() {
        guard let puzzle = PuzzleStore.shared.puzzles.first(where: { $0.playerSide == "red" }) else { return }
        let vm = PuzzleViewModel(puzzle: puzzle)
        // 初始无提示
        #expect(vm.currentHint == nil)
        // 显示提示
        vm.showHint()
        // 提示可能有也可能没有（取决于棋步）
        // 但 dismissHint 应该能正常调用
        vm.dismissHint()
        #expect(vm.currentHint == nil, "dismissHint 后提示应清除")
    }

    // MARK: - P2-8: GameOverOverlay "查看棋谱"按钮

    @MainActor
@Test("GameOverOverlay 有 onViewRecord 回调")
    func testGameOverOverlayViewRecord() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/GameOverOverlay.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 GameOverOverlay.swift")
            return
        }
        #expect(content.contains("onViewRecord"), "应有 onViewRecord 回调参数")
        #expect(content.contains("gameover.viewRecord"), "应有 gameover.viewRecord 键")
    }

    @MainActor
@Test("GameOverOverlay onViewRecord 为可选（不传时不显示按钮）")
    func testGameOverOverlayViewRecordOptional() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/GameOverOverlay.swift"
        guard let content = try? String(contentsOfFile: filePath) else { return }
        // onViewRecord 应为可选
        #expect(content.contains("onViewRecord: (() -> Void)?"), "onViewRecord 应为可选闭包")
        // 按钮应在 if let onViewRecord 内
        #expect(content.contains("if let onViewRecord"), "查看棋谱按钮应在 if let 内")
    }

    @MainActor
@Test("ChineseChessApp 传递 onViewRecord 回调给 GameOverOverlay")
    func testAppPassesViewRecordCallback() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift"
        guard let content = try? String(contentsOfFile: filePath) else { return }
        // App 中 GameOverOverlay 应有 onViewRecord 参数
        #expect(content.contains("onViewRecord:"), "App 应传递 onViewRecord 回调")
        #expect(content.contains("buildGameRecord"), "回调应构建对局记录")
        #expect(content.contains("toolbarReplayRecord"), "回调应打开回放视图")
    }

    // MARK: - 综合验证：所有改动文件

    @MainActor
@Test("所有 Round 2 修改文件存在且非空")
    func testAllModifiedFilesExistAndNonEmpty() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let base = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess"
        let fm = FileManager.default

        let files = [
            "App/ChineseChessApp.swift",
            "ViewModels/GameViewModel.swift",
            "Views/GameOverOverlay.swift",
            "Views/PuzzleSelectView.swift",
            "Views/ReplayControlView.swift",
            "Views/StatusBarView.swift",
        ]

        for file in files {
            let path = "\(base)/\(file)"
            #expect(fm.fileExists(atPath: path), "文件应存在: \(file)")
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                #expect(data.count > 100, "文件不应为空: \(file)")
            }
        }
    }
}
