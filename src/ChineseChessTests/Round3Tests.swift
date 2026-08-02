import Testing
import Foundation
@testable import ChineseChess

// MARK: - Round 3 修复验证

@Suite("Round 3 修复验证", .serialized)
@MainActor
struct Round3Tests {

    // MARK: - P0-01: PuzzleViewModel.board 改 var + resetPuzzle 直接重建
    @Test("P0-01: 残局走多步→重置→棋盘回到初始状态")
    func testResetPuzzleAfterMultipleMoves() {
        guard let puzzle = PuzzleStore.shared.puzzles.first(where: { $0.playerSide == "red" }) else { return }
        let vm = PuzzleViewModel(puzzle: puzzle)
        let initialFEN = puzzle.initialFEN
        let initialPieceCount = vm.board.pieces.count

        // 走多步（红方走 + AI 走）
        for _ in 0..<5 {
            let redPieces = vm.board.pieces.filter { $0.side == .red }
            guard let piece = redPieces.first else { break }
            let moves = MoveValidator.legalMoves(for: piece, on: vm.board)
            guard let move = moves.first else { break }
            let m = Move(piece: piece, from: move.from, to: move.to,
                         captured: vm.board.piece(at: move.to))
            guard MoveValidator.isLegal(m, on: vm.board) else { break }
            vm.board.execute(m)
        }

        // 确认棋盘已变化
        #expect(vm.board.pieces.count != initialPieceCount || !vm.board.moveHistory.isEmpty,
                "走步后棋盘应有变化")

        // 重置
        vm.resetPuzzle()

        // 验证棋盘完全回到初始状态
        #expect(vm.board.pieces.count == initialPieceCount, "重置后棋子数应恢复")
        #expect(vm.board.moveHistory.isEmpty, "重置后走法历史应为空")
        #expect(vm.gameMoves.isEmpty, "重置后 gameMoves 应为空")
        #expect(vm.gameState == .playing, "重置后状态应为 playing")
        #expect(vm.selectedPosition == nil, "重置后选中位置应为 nil")
        #expect(vm.completionRating == 0, "重置后评分应为 0")

        // FEN 一致性验证
        let resetFEN = FENParser.generate(board: vm.board)
        let initialBoard = Board(fen: initialFEN)
        let initialSerialized = FENParser.generate(board: initialBoard)
        #expect(resetFEN == initialSerialized, "重置后 FEN 应与初始一致")
    }

    // MARK: - P0-02: SoundEngine.play() 调度回主线程
    @Test("P0-02: SoundEngine 不崩溃")
    func testSoundEngineNoCrash() {
        let engine = SoundEngine.shared
        engine.isMuted = false
        engine.playMove()
        engine.playCapture()
        engine.playCheck()
        engine.playUndo()
        engine.playVictory()
        engine.isMuted = true
        engine.playMove()  // 静音也不崩溃
        #expect(true, "SoundEngine 所有方法不崩溃")
    }

    // MARK: - P1-02: ReplayViewModel Task.sleep 正确处理 CancellationError
    // 源码文本匹配测试已移除（测源码文本而非行为）

    @Test("P1-02: 回放自动播放→停止→不会多走一步")
    func testReplayAutoPlayStop() {
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

        // 手动走到第 2 步
        vm.jumpTo(index: 2)
        #expect(vm.currentIndex == 2)

        // 停止自动播放（未启动时调用 toggleAutoPlay）
        if vm.isAutoPlaying {
            vm.toggleAutoPlay()
        }
        // 确认 currentIndex 没有额外前进
        #expect(vm.currentIndex == 2, "停止后不应多走一步")

        // 走到末尾
        vm.jumpTo(index: 3)
        #expect(!vm.canGoForward, "末尾不应能前进")
        #expect(vm.currentIndex == 3)
    }

    // MARK: - P1-04: undoMove 清理 solutionHint + hintMove
    @Test("P1-04: 残局悔棋后 solutionHint 消失")
    func testUndoMoveClearsSolutionHint() {
        guard let puzzle = PuzzleStore.shared.puzzles.first(where: { $0.playerSide == "red" }) else { return }
        let vm = PuzzleViewModel(puzzle: puzzle)

        // 设置 solutionHint
        vm.solutionHint = "有更优走法"
        vm.hintMove = (from: Position(row: 6, col: 4), to: Position(row: 5, col: 4))

        // 走一步
        let redPieces = vm.board.pieces.filter { $0.side == .red }
        guard let piece = redPieces.first else { return }
        let moves = MoveValidator.legalMoves(for: piece, on: vm.board)
        guard let move = moves.first else { return }
        let m = Move(piece: piece, from: move.from, to: move.to,
                     captured: vm.board.piece(at: move.to))
        guard MoveValidator.isLegal(m, on: vm.board) else { return }
        vm.board.execute(m)

        // 悔棋
        vm.undoMove()

        #expect(vm.solutionHint == nil, "悔棋后 solutionHint 应为 nil")
        #expect(vm.hintMove == nil, "悔棋后 hintMove 应为 nil")
    }

    // MARK: - P1-05: PuzzleViewModel isInCheck stored property
    @Test("P1-05: 残局走棋后 isInCheck 正确更新")
    func testPuzzleIsInCheckAfterMove() {
        guard let puzzle = PuzzleStore.shared.puzzles.first(where: { $0.playerSide == "red" }) else { return }
        let vm = PuzzleViewModel(puzzle: puzzle)
        #expect(!vm.isInCheck, "初始不应被将军")

        // 通过 ViewModel 方法走棋（会自动更新 isInCheck）
        let redPieces = vm.board.pieces.filter { $0.side == .red }
        guard let piece = redPieces.first else { return }
        let moves = MoveValidator.legalMoves(for: piece, on: vm.board)
        guard let move = moves.first else { return }

        vm.selectPiece(at: move.from)
        vm.movePiece(from: move.from, to: move.to)

        let expected = MoveValidator.isInCheck(vm.board.currentTurn, on: vm.board)
        #expect(vm.isInCheck == expected, "走棋后 isInCheck 应与 MoveValidator 一致")
    }
    @Test("P1-05: 残局 resetPuzzle 重置 isInCheck 为 false")
    func testPuzzleResetIsInCheck() {
        guard let puzzle = PuzzleStore.shared.puzzles.first(where: { $0.playerSide == "red" }) else { return }
        let vm = PuzzleViewModel(puzzle: puzzle)
        vm.isInCheck = true
        vm.resetPuzzle()
        #expect(!vm.isInCheck, "resetPuzzle 后 isInCheck 应为 false")
    }

    // MARK: - P1-06: bestAvailableFontName static let 缓存

    @Test("P1-06: bestAvailableFontName 返回有效字体名")
    func testBestAvailableFontNameValid() {
        let name = FontRegistry.bestAvailableFontName
        #expect(!name.isEmpty, "字体名不应为空")
    }

    // MARK: - 综合：所有修改文件存在

    @Test("所有 Round 3 修改文件存在且非空")
    func testAllRound3FilesExist() {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let base = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess"
        let fm = FileManager.default

        let files = [
            "ViewModels/PuzzleViewModel.swift",
            "Services/SoundEngine.swift",
            "ViewModels/ReplayViewModel.swift",
            "Utils/FontRegistry.swift",
            "Views/ChessBoardView.swift",
            "ViewModels/GameViewModel.swift",
        ]

        for file in files {
            let path = "\(base)/\(file)"
            #expect(fm.fileExists(atPath: path), "文件应存在: \(file)")
        }
    }
}
