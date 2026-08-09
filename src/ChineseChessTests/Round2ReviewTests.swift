import Testing
import Foundation
@testable import ChineseChess

// MARK: - Round 2 审查修复验证
// 注意：原源码文本匹配测试已移除（测源码文本而非行为，重构后必然失效）
// 保留行为测试

@Suite("Round 2 审查修复验证")
@MainActor
struct Round2ReviewTests {

    // MARK: - P0-2: 残局失败重试

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

    // MARK: - P1-5: 回放 Slider 进度条

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
            blackPlayer: PlayerInfo(name: "黑方", isAI: true, difficulty: .amateurLow),
            difficulty: .amateurLow, result: .redWon, totalMoves: 3, moves: moves, initialFEN: nil
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

    // MARK: - P1-6: 残局提示框

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

    // MARK: - 综合验证：所有改动文件存在

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
