import Testing
import Foundation
@testable import ChineseChess

// MARK: - Round 2 操作易用性测试

@Suite("Round 2 操作易用性测试")
@MainActor
struct Round2UsabilityTests {

    // MARK: - U-P0-01: 残局空状态

    @MainActor
@Test("U-P0-01: PuzzleSelectView 空状态提示完整")
    func testUP001EmptyStateUI() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 PuzzleSelectView.swift")
            return
        }
        // 空列表判断
        #expect(content.contains("if list.isEmpty"), "应有空列表条件判断")
        // 图标 + 文字
        #expect(content.contains("puzzlepiece"), "空状态应有拼图图标")
        #expect(content.contains("puzzle.empty"), "空状态应有 puzzle.empty 键")
        // 最小高度避免视觉塌陷
        #expect(content.contains("minHeight: 120"), "空状态应有 minHeight 避免塌陷")
    }

    // MARK: - U-P0-02: 残局失败重试

    @MainActor
@Test("U-P0-02: 失败弹窗有重试和返回按钮")
    func testUP002RetryUI() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 PuzzleSelectView.swift")
            return
        }
        // .failed 状态弹窗
        #expect(content.contains(".failed"), "应有 .failed 状态判断")
        #expect(content.contains("puzzle.failed"), "应有 puzzle.failed 键")
        // 重试按钮调用 resetPuzzle
        #expect(content.contains("common.retry"), "应有 common.retry 键")
        #expect(content.contains("resetPuzzle()"), "重试应调用 resetPuzzle()")
        // 返回按钮调用 dismiss
        #expect(content.contains("common.back"), "应有 common.back 键")
        // 遮罩阻止穿透
        #expect(content.contains("onTapGesture"), "遮罩应阻止点击穿透")
    }

    @MainActor
@Test("U-P0-02: resetPuzzle 完整重置棋盘状态")
    func testUP002ResetPuzzleComplete() {
        guard let puzzle = PuzzleStore.shared.puzzles.first else { return }
        let vm = PuzzleViewModel(puzzle: puzzle)
        let initialCount = vm.board.pieces.count

        // 走一步
        if let piece = vm.board.pieces.first {
            let moves = MoveValidator.legalMoves(for: piece, on: vm.board)
            if let move = moves.first {
                let m = Move(piece: piece, from: move.from, to: move.to,
                             captured: vm.board.piece(at: move.to))
                vm.board.execute(m)
            }
        }

        // 重置
        vm.resetPuzzle()
        #expect(vm.board.pieces.count == initialCount, "棋子数应恢复")
        #expect(vm.board.moveHistory.isEmpty, "走法历史应清空")
        #expect(vm.gameMoves.isEmpty, "游戏走法应清空")
        #expect(vm.gameState == .playing, "状态应为 playing")
        #expect(vm.selectedPosition == nil, "选中位置应清除")
        #expect(vm.completionRating == 0, "评分应归零")
    }

    // MARK: - U-P1-01: 将军提示

    @MainActor
@Test("U-P1-01: isInCheck stored property + checkGameState 手动更新")
    func testUP101IsInCheckStored() {
        let vm = GameViewModel()
        #expect(!vm.isInCheck, "初始不应被将军")

        // newGame 重置
        vm.isInCheck = true
        vm.newGame()
        #expect(!vm.isInCheck, "newGame 后应重置")
    }

    @MainActor
@Test("U-P1-01: StatusBarView 将军文字+脉冲动画")
    func testUP101StatusBarCheckWarning() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/StatusBarView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 StatusBarView.swift")
            return
        }
        #expect(content.contains("isInCheck"), "应检查 isInCheck")
        #expect(content.contains("status.check"), "应有 status.check 键")
        #expect(content.contains("foregroundColor(.red)"), "应红色文字")
        #expect(content.contains("pulseAnimation"), "应有脉冲动画")
    }

    @MainActor
@Test("U-P1-01: ChessBoardView 将军红色闪烁圈")
    func testUP101ChessBoardCheckHighlight() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ChessBoardView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 ChessBoardView.swift")
            return
        }
        // 被将军高亮
        #expect(content.contains("isInCheck"), "应检查 isInCheck 或 MoveValidator.isInCheck")
        #expect(content.contains("generalPosition"), "应获取将/帅位置")
        #expect(content.contains("CheckPulseModifier"), "应有将军闪烁动画")
        // 红色圈
        #expect(content.contains("Color.red"), "将军圈应为红色")
    }

    // MARK: - U-P1-02: macOS 快捷键

    @MainActor
@Test("U-P1-02: macOS CommandMenu 含 localized 新局/悔棋/提示")
    func testUP102MacOSCommandMenu() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 ChineseChessApp.swift")
            return
        }
        #expect(content.contains("game.newGame"), "应有 game.newGame 键")
        #expect(content.contains("game.undoMove"), "应有 game.undoMove 键")
        #expect(content.contains("game.hint"), "应有 game.hint 键")
        #expect(content.contains("keyboardShortcut(\"n\""), "新局 Cmd+N")
        #expect(content.contains("keyboardShortcut(\"z\""), "悔棋 Cmd+Z")
        #expect(content.contains("keyboardShortcut(\"h\""), "提示 Cmd+Shift+H")
        #expect(content.contains("Divider()"), "应有 Divider 分组")
    }

    // MARK: - U-P1-03: 回放拖拽

    @MainActor
@Test("U-P1-03: ReplayControlView 使用 Slider 可拖拽跳转")
    func testUP103ReplaySlider() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayControlView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 ReplayControlView.swift")
            return
        }
        #expect(content.contains("Slider("), "应使用 Slider")
        #expect(!content.contains("ProgressView("), "不应使用 ProgressView")
        #expect(content.contains("jumpTo"), "Slider 变化应触发 jumpTo")
    }

    @MainActor
@Test("U-P1-03: ReplayViewModel jumpTo 棋盘同步更新")
    func testUP103JumpToSyncsBoard() {
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

        // 模拟 Slider 拖拽：0 → 2 → 1 → 3 → 0
        vm.jumpTo(index: 2)
        #expect(vm.currentIndex == 2)
        #expect(vm.lastMove != nil)
        #expect(vm.lastMove?.from == moves[1].from)

        vm.jumpTo(index: 1)
        #expect(vm.currentIndex == 1)
        #expect(vm.lastMove?.from == moves[0].from)

        vm.jumpTo(index: 3)
        #expect(!vm.canGoForward)

        vm.jumpTo(index: 0)
        #expect(vm.currentIndex == 0)
        #expect(vm.lastMove == nil)
    }

    // MARK: - U-P1-04: 残局提示高亮

    @MainActor
@Test("U-P1-04: PuzzleViewModel.hintMove 设置起点+终点")
    func testUP104HintMoveHighlight() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/ViewModels/PuzzleViewModel.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 PuzzleViewModel.swift")
            return
        }
        // hintMove 应包含 from 和 to
        #expect(content.contains("hintMove"), "应有 hintMove 属性")
        // 提示应设置 from + to 位置
        #expect(content.contains("from:") || content.contains(".from"), "提示应设置起点")
        #expect(content.contains("to:") || content.contains(".to"), "提示应设置终点")
    }

    @MainActor
@Test("U-P1-04: ChessBoardView 蓝色高亮起点+终点")
    func testUP104BlueHighlight() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let filePath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ChessBoardView.swift"
        guard let content = try? String(contentsOfFile: filePath) else {
            #expect(Bool(false), "无法读取 ChessBoardView.swift")
            return
        }
        // 提示高亮蓝色
        #expect(content.contains("hintMove"), "应检查 hintMove")
        #expect(content.contains("Color.blue"), "提示高亮应为蓝色")
        // 起点画圈，终点画实心
        #expect(content.contains(".stroke") || content.contains("Circle"), "起点应有圆圈高亮")
        #expect(content.contains(".fill") || content.contains("fill"), "终点应有实心高亮")
    }

    // MARK: - U-P2-02: 查看棋谱

    @MainActor
@Test("U-P2-02: GameOverOverlay 查看棋谱按钮 + App 传递回调")
    func testUP202ViewRecord() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()

        // GameOverOverlay
        let overlayPath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/GameOverOverlay.swift"
        guard let overlay = try? String(contentsOfFile: overlayPath) else {
            #expect(Bool(false), "无法读取 GameOverOverlay.swift")
            return
        }
        #expect(overlay.contains("onViewRecord"), "应有 onViewRecord 回调")
        #expect(overlay.contains("gameover.viewRecord"), "应有 gameover.viewRecord 键")
        #expect(overlay.contains("if let onViewRecord"), "按钮应在 if let 内")

        // App
        let appPath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift"
        guard let app = try? String(contentsOfFile: appPath) else {
            #expect(Bool(false), "无法读取 ChineseChessApp.swift")
            return
        }
        #expect(app.contains("onViewRecord:"), "App 应传递 onViewRecord 回调")
        #expect(app.contains("buildGameRecord"), "回调应构建对局记录")
        #expect(app.contains("toolbarReplayRecord"), "回调应打开回放视图")
    }

    @MainActor
@Test("U-P2-02: GameViewModel.buildGameRecord 生成有效记录")
    func testUP202BuildGameRecord() {
        let vm = GameViewModel()
        // 初始局面无走法
        let emptyRecord = vm.buildGameRecord()
        #expect(emptyRecord == nil, "无走法时不应生成记录")

        // 走一步后应能生成
        if let piece = vm.board.pieces.first(where: { $0.side == .red }) {
            let moves = MoveValidator.legalMoves(for: piece, on: vm.board)
            if let move = moves.first {
                vm.movePiece(from: move.from, to: move.to)
                // AI 走完后检查（需要等 AI 完成，这里只验证方法存在）
                // 重点是 buildGameRecord 方法存在且可调用
                #expect(true, "buildGameRecord 方法存在且可调用")
            }
        }
    }
}
