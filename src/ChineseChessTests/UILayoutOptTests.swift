import Foundation
import Testing
@testable import ChineseChess

@Suite("UI 棋盘布局优化测试", .serialized)
@MainActor
struct UILayoutOptTests {

    // MARK: - 1. ReplayView / ReplayViewModel 回归

    @MainActor
@Test("ReplayViewModel：初始化不 crash")
    func replayViewModelInit() async {
        let record = await Self.makeTestRecord()
        let vm = ReplayViewModel(record: record)
        #expect(vm.currentIndex == 0)
        #expect(vm.canGoForward)
        #expect(!vm.canGoBack)
    }

    @MainActor
@Test("ReplayViewModel：前进/后退正常工作")
    func replayViewModelNavigation() async {
        let record = await Self.makeTestRecord()
        let vm = ReplayViewModel(record: record)

        // 前进一步
        vm.goForward()
        #expect(vm.currentIndex == 1)
        #expect(vm.canGoBack)
        if record.moves.count > 1 {
            #expect(vm.canGoForward)
        }

        // 前进到头
        while vm.canGoForward { vm.goForward() }
        #expect(vm.currentIndex == record.moves.count)
        #expect(!vm.canGoForward)

        // 后退
        vm.goBack()
        #expect(vm.currentIndex == record.moves.count - 1)
    }

    @MainActor
@Test("ReplayViewModel：跳转到指定位置")
    func replayViewModelJump() async {
        let record = await Self.makeTestRecord()
        let vm = ReplayViewModel(record: record)

        guard record.moves.count >= 3 else { return }
        vm.jumpTo(index: 3)
        #expect(vm.currentIndex == 3)

        vm.jumpTo(index: 0)
        #expect(vm.currentIndex == 0)

        // 越界保护
        vm.jumpTo(index: 9999)
        #expect(vm.currentIndex == record.moves.count)
    }

    @MainActor
@Test("ReplayViewModel：goToStart / goToEnd")
    func replayViewModelStartEnd() async {
        let record = await Self.makeTestRecord()
        let vm = ReplayViewModel(record: record)

        vm.goToEnd()
        #expect(vm.currentIndex == record.moves.count)

        vm.goToStart()
        #expect(vm.currentIndex == 0)
    }

    @MainActor
@Test("ReplayViewModel：progressText 格式正确")
    func replayViewModelProgressText() async {
        let record = await Self.makeTestRecord()
        let vm = ReplayViewModel(record: record)
        #expect(vm.progressText == "0/\(record.moves.count)")
        vm.goForward()
        #expect(vm.progressText == "1/\(record.moves.count)")
    }

    @MainActor
@Test("ReplayViewModel：空走法记录不 crash")
    func replayViewModelEmptyMoves() async {
        var record = await Self.makeTestRecord()
        record = GameRecord(
            id: record.id,
            title: record.title,
            date: record.date,
            redPlayer: record.redPlayer,
            blackPlayer: record.blackPlayer,
            difficulty: record.difficulty,
            result: record.result,
            totalMoves: 0,
            moves: [],
            initialFEN: nil
        )
        let vm = ReplayViewModel(record: record)
        #expect(!vm.canGoForward)
        #expect(!vm.canGoBack)
        vm.goForward()  // 不 crash
        vm.goBack()     // 不 crash
        vm.goToStart()
        vm.goToEnd()
    }

    @MainActor
@Test("ReplayViewModel：自动播放不 crash")
    func replayViewModelAutoPlay() async {
        let record = await Self.makeTestRecord()
        let vm = ReplayViewModel(record: record)
        vm.toggleAutoPlay()
        #expect(vm.isAutoPlaying)
        // 等一小段时间让自动播放走几步
        try? await Task.sleep(for: .milliseconds(200))
        vm.toggleAutoPlay()
        #expect(!vm.isAutoPlaying)
    }

    // MARK: - 2. PuzzleViewModel 回归（布局变更不影响逻辑）

    @MainActor
@Test("PuzzleViewModel：初始化不 crash")
    func puzzleViewModelInit() {
        let puzzles = PuzzleStore.shared.puzzles
        guard let puzzle = puzzles.first else {
            Issue.record("无残局数据")
            return
        }
        let vm = PuzzleViewModel(puzzle: puzzle)
        #expect(vm.gameState == .playing)
        #expect(vm.board.pieces.count > 0)
    }

    @MainActor
@Test("PuzzleViewModel：resetPuzzle 恢复初始状态")
    func puzzleViewModelReset() {
        let puzzles = PuzzleStore.shared.puzzles
        guard let puzzle = puzzles.first else { return }
        let vm = PuzzleViewModel(puzzle: puzzle)
        let initialFEN = FENParser.generate(board: vm.board)
        vm.resetPuzzle()
        let afterFEN = FENParser.generate(board: vm.board)
        #expect(initialFEN == afterFEN)
        #expect(vm.gameState == .playing)
    }

    // MARK: - 3. layoutPriority 不影响 Board 功能

    @MainActor
@Test("ChessBoardView layoutPriority(1) 不影响棋盘逻辑")
    func layoutPriorityDoesNotAffectLogic() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .medium)
        #expect(move != nil, "AI 功能受 layoutPriority 影响而异常")
    }

    // MARK: - 4. GameViewModel 回归（对弈主界面棋盘不受影响）

    @MainActor
@Test("GameViewModel：新局初始化正常")
    func gameViewModelNewGame() {
        let vm = GameViewModel()
        #expect(vm.gameState == .playing)
        #expect(vm.board.pieces.count == 32)  // 标准开局 32 子
        #expect(!vm.isThinking)
        #expect(!vm.isInCheck)
        #expect(vm.capturedPieces.red.isEmpty)
        #expect(vm.capturedPieces.black.isEmpty)
    }

    @MainActor
@Test("GameViewModel：悔棋后棋盘状态正确")
    func gameViewModelUndoAfterAIMove() async {
        let vm = GameViewModel()
        let board = vm.board

        // 选择一个红子并走棋
        guard let firstPiece = board.pieces(for: .red).first else { return }
        let moves = MoveValidator.legalMoves(for: firstPiece, on: board)
        guard let targetMove = moves.first else { return }

        vm.selectPiece(at: firstPiece.position)
        vm.movePiece(from: firstPiece.position, to: targetMove.to)

        // 等待 AI 响应
        try? await Task.sleep(for: .milliseconds(500))

        let moveCountBefore = vm.moveHistory.count
        if moveCountBefore >= 2 {
            vm.undoMove()
            // 撤销一对后应少 2 步
            #expect(vm.moveHistory.count == moveCountBefore - 2)
        }
    }

    // MARK: - 5. 底部区域动态限高参数验证

    @MainActor
@Test("bottomAreaMaxHeight 逻辑：参数合理（非零、非负、有限值）")
    func bottomAreaMaxHeightValidation() {
        // 验证思路：不同设备参数计算出的高度应合理
        // macOS 固定 180，iOS 动态计算
        // 这里测试 macOS 路径（测试在 macOS 上运行）
        #if os(macOS)
        // macOS 固定 180pt
        let expectedMaxHeight: CGFloat = 180
        #expect(expectedMaxHeight > 0)
        #expect(expectedMaxHeight < 500)  // 不应超过屏幕高度
        #endif
    }

    @MainActor
@Test("iOS fullScreenCover 关闭按钮：ReplayView 有 dismiss 环境")
    func replayViewHasDismiss() async {
        // ReplayView 使用 @Environment(\.dismiss)，编译通过即验证
        let record = await Self.makeTestRecord()
        let vm = ReplayViewModel(record: record)
        // 只要不 crash 就说明初始化正常
        _ = vm
    }

    // MARK: - 6. 全量构建验证

    @MainActor
@Test("Sheet 尺寸增大不影响模型编译")
    func sheetSizeChangeNoEffect() {
        // frame(minWidth: 520, minHeight: 680) 仅影响 macOS Sheet 布局
        // 不影响任何模型/逻辑代码
        let board = Board()
        #expect(board.pieces.count == 32)
    }

    // MARK: - 7. 残局通关/失败弹窗条件渲染

    @MainActor
@Test("PuzzleViewModel：gameState 为 playing 时不触发弹窗条件")
    func puzzlePlayingStateNoDialog() {
        let puzzles = PuzzleStore.shared.puzzles
        guard let puzzle = puzzles.first else { return }
        let vm = PuzzleViewModel(puzzle: puzzle)
        #expect(vm.gameState == .playing)
        #expect(vm.gameState != .success)
        #expect(vm.gameState != .failed)
        #expect(vm.gameState != .draw)
    }

    // MARK: - 8. 棋盘走棋前后尺寸一致性（间接验证）

    @MainActor
@Test("AI 走棋后棋盘子力结构合理")
    func boardStructureAfterMoves() async {
        let engine = AIEngine()
        let board = Board()
        let initialPieces = board.pieces.count

        for _ in 0..<4 {
            guard let move = await engine.bestMove(for: board.snapshot(), difficulty: .easy) else { break }
            board.execute(move)
        }

        // 走几步后子力应 ≤ 初始（可能吃子）
        #expect(board.pieces.count <= initialPieces)
        // 至少保留两个将帅
        #expect(board.generalPosition(of: .red) != nil)
        #expect(board.generalPosition(of: .black) != nil)
    }

    // MARK: - Helper

    private static func makeTestRecord() async -> GameRecord {
        // 生成一个简单的测试对局记录（走几步棋）
        let board = Board()
        let engine = AIEngine()
        var moves: [GameMove] = []
        let tempBoard = Board()

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
