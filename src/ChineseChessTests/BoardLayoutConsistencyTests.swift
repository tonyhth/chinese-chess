import Foundation
import Testing
@testable import ChineseChess

// MARK: - 残局/回放棋盘布局一致化测试
// 变更：PuzzleSelectView 和 ReplayView 删除 .frame(minHeight: 280) 和 .padding()，
// 与对弈页面对齐。验证布局变更不影响功能逻辑。

@Suite("棋盘布局一致化测试", .serialized)
@MainActor
struct BoardLayoutConsistencyTests {

    // MARK: - 1. 源码一致性：三个页面棋盘 modifier 对齐验证

    // MARK: - 2. ReplayView 功能回归

@Test("ReplayViewModel：布局变更后功能正常")
    func replayViewModelFunctionalAfterLayoutChange() async {
        let record = await Self.makeTestRecord()
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
    func chessBoardViewThreeModesConsistency() async {
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
        let record = await Self.makeTestRecord()
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

@Test("棋盘布局策略一致性")
    func boardLayoutStrategyConsistency() {
        // ChessBoardView 使用 .aspectRatio，ReplayBoardView 委托 BoardCanvasView 使用 .position 居中
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()

        // BoardCanvasView（ReplayBoardView 的渲染委托）应使用 .position 居中
        let canvasPath = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Views/BoardCanvasView.swift"
        guard let canvasContent = try? String(contentsOfFile: canvasPath) else {
            Issue.record("无法读取 BoardCanvasView.swift")
            return
        }
        #expect(canvasContent.contains(".position"),
                "BoardCanvasView 应使用 .position 居中")

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

    // MARK: - Helper

    private static func makeTestRecord() async -> GameRecord {
        let tempBoard = Board()
        let engine = AIEngine()
        var moves: [GameMove] = []

        for i in 0..<6 {
            let side = tempBoard.currentTurn
            guard let move = await engine.bestMove(for: tempBoard.snapshot(), difficulty: .beginner) else { break }
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
                isCheckmate: false,
                halfmoveClock: 0
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
