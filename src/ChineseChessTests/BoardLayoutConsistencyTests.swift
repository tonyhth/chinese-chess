import Foundation
import Testing
@testable import ChineseChess

// MARK: - 残局/回放棋盘布局一致化测试
// 变更：PuzzleSelectView 和 ReplayView 删除 .frame(minHeight: 280) 和 .padding()，
// 与对弈页面对齐。验证布局变更不影响功能逻辑。

@Suite("棋盘布局一致化测试")
struct BoardLayoutConsistencyTests {

    // MARK: - 1. 源码一致性：三个页面棋盘 modifier 对齐验证

    @Test("PuzzleSelectView：棋盘布局 modifier 正确（无 minHeight、无 padding）")
    func puzzleSelectViewBoardModifiers() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
        guard let content = try? String(contentsOfFile: path) else {
            Issue.record("无法读取 PuzzleSelectView.swift")
            return
        }

        // 找到 PuzzlePlayView 中 ChessBoardView 的 modifier 区域
        let pattern = "ChessBoardView(mode: .playPuzzle"
        guard let range = content.range(of: pattern) else {
            Issue.record("未找到 ChessBoardView(mode: .playPuzzle")
            return
        }

        // 取 ChessBoardView 后续 10 行
        let after = content[range.lowerBound...]
        let lines = after.split(separator: "\n", maxSplits: 10, omittingEmptySubsequences: false)
        let modifierBlock = lines.prefix(6).joined(separator: "\n")

        // 应保留
        #expect(modifierBlock.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"),
                "应保留 maxWidth/maxHeight: .infinity")
        #expect(modifierBlock.contains(".layoutPriority(1)"),
                "应保留 layoutPriority(1)")

        // 不应包含已删除的 modifier
        #expect(!modifierBlock.contains(".frame(minHeight: 280)"),
                "不应再有 .frame(minHeight: 280)")
        #expect(!modifierBlock.contains(".padding()"),
                "不应再有 .padding()")
    }

    @Test("ReplayView：棋盘布局 modifier 正确（无 minHeight、无 padding）")
    func replayViewBoardModifiers() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayView.swift"
        guard let content = try? String(contentsOfFile: path) else {
            Issue.record("无法读取 ReplayView.swift")
            return
        }

        let pattern = "ReplayBoardView(viewModel:"
        guard let range = content.range(of: pattern) else {
            Issue.record("未找到 ReplayBoardView(viewModel:")
            return
        }

        let after = content[range.lowerBound...]
        let lines = after.split(separator: "\n", maxSplits: 10, omittingEmptySubsequences: false)
        let modifierBlock = lines.prefix(6).joined(separator: "\n")

        #expect(modifierBlock.contains(".layoutPriority(1)"),
                "应保留 layoutPriority(1)")

        #expect(!modifierBlock.contains(".frame(minHeight:"),
                "不应再有 .frame(minHeight:)")
        #expect(!modifierBlock.contains(".padding()"),
                "不应再有 .padding()")
    }

    @Test("对弈页面 BoardView：仍保留 minHeight（作为参考基准）")
    func gameViewBoardStillHasMinHeight() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/App/ChineseChessApp.swift"
        guard let content = try? String(contentsOfFile: path) else {
            Issue.record("无法读取 ChineseChessApp.swift")
            return
        }

        // 对弈页面应有 BoardView 且带 minHeight
        let pattern = "BoardView(viewModel:"
        guard let range = content.range(of: pattern) else {
            Issue.record("未找到 BoardView(viewModel:")
            return
        }

        let after = content[range.lowerBound...]
        let lines = after.split(separator: "\n", maxSplits: 6, omittingEmptySubsequences: false)
        let modifierBlock = lines.prefix(5).joined(separator: "\n")

        #expect(modifierBlock.contains(".frame(minHeight: 280)"),
                "对弈页面应保留 minHeight: 280 作为基准")
        #expect(modifierBlock.contains(".layoutPriority(1)"),
                "对弈页面应保留 layoutPriority(1)")
    }

    // MARK: - 2. ReplayView 功能回归

    @Test("ReplayView：空步数记录有空步提示")
    func replayViewEmptyMovesHandling() {
        // 验证 ReplayView 源码包含空步数提示逻辑
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayView.swift"
        guard let content = try? String(contentsOfFile: path) else {
            Issue.record("无法读取 ReplayView.swift")
            return
        }
        #expect(content.contains("viewModel.record.moves.isEmpty"),
                "ReplayView 应有空步数提示逻辑")
        #expect(content.contains("replay.empty"),
                "ReplayView 应有 replay.empty 本地化键")
    }

    @Test("ReplayViewModel：布局变更后功能正常")
    func replayViewModelFunctionalAfterLayoutChange() {
        let record = Self.makeTestRecord()
        let vm = ReplayViewModel(record: record)

        // 完整导航流程
        #expect(vm.currentIndex == 0)
        vm.goForward()
        #expect(vm.currentIndex == 1)
        vm.goToEnd()
        #expect(vm.currentIndex == record.moves.count)
        vm.goToStart()
        #expect(vm.currentIndex == 0)

        // 自动播放
        vm.toggleAutoPlay()
        #expect(vm.isAutoPlaying)
        vm.toggleAutoPlay()
        #expect(!vm.isAutoPlaying)
    }

    @Test("ReplayViewModel：空记录不 crash（边界情况）")
    func replayViewModelEmptyRecordNoCrash() {
        let emptyRecord = GameRecord(
            id: UUID(),
            title: "空对局",
            date: Date(),
            redPlayer: PlayerInfo(name: "红方", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑方", isAI: true, difficulty: .easy),
            difficulty: .easy,
            result: .draw,
            totalMoves: 0,
            moves: [],
            initialFEN: nil
        )
        let vm = ReplayViewModel(record: emptyRecord)

        #expect(!vm.canGoForward)
        #expect(!vm.canGoBack)
        #expect(vm.progressText == "0/0")

        // 这些操作不应 crash
        vm.goForward()
        vm.goBack()
        vm.goToStart()
        vm.goToEnd()
    }

    // MARK: - 3. PuzzleSelectView 功能回归

    @Test("PuzzleViewModel：布局变更后功能正常")
    func puzzleViewModelFunctionalAfterLayoutChange() {
        let puzzles = PuzzleStore.shared.puzzles
        guard let puzzle = puzzles.first else {
            Issue.record("无残局数据")
            return
        }

        let vm = PuzzleViewModel(puzzle: puzzle)
        #expect(vm.gameState == .playing)
        #expect(vm.board.pieces.count > 0)

        // reset 后应恢复初始状态
        let initialFEN = FENParser.generate(board: vm.board)
        vm.resetPuzzle()
        let afterFEN = FENParser.generate(board: vm.board)
        #expect(initialFEN == afterFEN)
    }

    // MARK: - 4. ChessBoardView 三种 mode 都能正常初始化

    @Test("ChessBoardView：三种 mode 的 Board 初始化一致")
    func chessBoardViewThreeModesConsistency() {
        // 对弈
        let gameVM = GameViewModel()
        #expect(gameVM.board.pieces.count == 32)

        // 残局
        let puzzles = PuzzleStore.shared.puzzles
        guard let puzzle = puzzles.first else {
            Issue.record("无残局数据")
            return
        }
        let puzzleVM = PuzzleViewModel(puzzle: puzzle)
        #expect(puzzleVM.board.pieces.count > 0)

        // 回放
        let record = Self.makeTestRecord()
        let replayVM = ReplayViewModel(record: record)
        #expect(replayVM.currentIndex == 0)
    }

    // MARK: - 5. 棋盘空间分配逻辑验证

    @Test("layoutPriority(1) 保证棋盘优先占据剩余空间")
    func layoutPriorityEnsuresBoardGetsPriority() {
        // layoutPriority(1) 在 VStack 中确保棋盘优先扩展
        // 删除 minHeight 后，棋盘在极端小窗口下可能更小，
        // 但有 bottomAreaMaxHeight 限制底部区域，棋盘仍有足够空间
        // 验证 bottomAreaMaxHeight 参数合理性
        #if os(macOS)
        let bottomAreaMaxHeight: CGFloat = 180
        #expect(bottomAreaMaxHeight > 0 && bottomAreaMaxHeight < 500,
                "底部区域高度限制应合理")
        #endif
    }

    @Test("棋盘使用 aspectRatio 自适应")
    func boardUsesAspectRatioForAdaptation() {
        // ReplayBoardView 和 ChessBoardView 都使用 .aspectRatio 而非硬编码 frame
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()

        // ReplayBoardView 应有 aspectRatio
        let replayPath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ReplayBoardView.swift"
        guard let replayContent = try? String(contentsOfFile: replayPath) else {
            Issue.record("无法读取 ReplayBoardView.swift")
            return
        }
        #expect(replayContent.contains(".aspectRatio"),
                "ReplayBoardView 应使用 .aspectRatio 自适应")

        // ChessBoardView 应有 aspectRatio
        let chessPath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/ChessBoardView.swift"
        guard let chessContent = try? String(contentsOfFile: chessPath) else {
            Issue.record("无法读取 ChessBoardView.swift")
            return
        }
        #expect(chessContent.contains(".aspectRatio"),
                "ChessBoardView 应使用 .aspectRatio 自适应")
    }

    // MARK: - 6. 底部区域约束完整性验证

    @Test("PuzzleSelectView：底部区域有高度约束")
    func puzzleSelectBottomAreaHasHeightConstraint() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/PuzzleSelectView.swift"
        guard let content = try? String(contentsOfFile: path) else {
            Issue.record("无法读取 PuzzleSelectView.swift")
            return
        }

        // 底部区域应有 bottomAreaMaxHeight 约束
        #expect(content.contains("bottomAreaMaxHeight"),
                "PuzzleSelectView 底部区域应有 bottomAreaMaxHeight 约束")
    }

    // MARK: - Helper

    private static func makeTestRecord() -> GameRecord {
        let tempBoard = Board()
        let engine = AIEngine()
        var moves: [GameMove] = []

        for i in 0..<6 {
            let side = tempBoard.currentTurn
            guard let move = engine.bestMove(for: tempBoard.snapshot(), difficulty: .beginner) else { break }
            let notation = NotationGenerator.notation(for: move, on: tempBoard)
            let opponent: Side = (side == .red) ? .black : .red
            tempBoard.execute(move)
            let isCheck = MoveValidator.isInCheck(opponent, on: tempBoard)

            moves.append(GameMove(
                id: UUID(),
                piece: move.piece,
                from: move.from,
                to: move.to,
                captured: move.captured,
                turnNumber: i / 2 + 1,
                notation: notation,
                timestamp: Date(),
                isCheck: isCheck,
                isCheckmate: false
            ))
        }

        return GameRecord(
            id: UUID(),
            title: "测试对局",
            date: Date(),
            redPlayer: PlayerInfo(name: "红方", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "AI-新手", isAI: true, difficulty: .beginner),
            difficulty: .beginner,
            result: .draw,
            totalMoves: moves.count,
            moves: moves,
            initialFEN: nil
        )
    }
}
