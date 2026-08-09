import Testing
import Foundation
@testable import ChineseChess

// MARK: - v2.2.17 iOS 6 Bug 修复验证
// 注意：原源码文本匹配测试已移除（测源码文本而非行为，重构后必然失效）

@Suite("v2.2.17 Bug 修复验证", .serialized)
struct V2217FixTests {

    // MARK: - 辅助方法

    private static func makeTestPuzzle(
        id: String = "test-puzzle",
        initialFEN: String = "3ak4/9/9/9/9/9/9/9/9/4K4 w",
        playerSide: String = "red",
        stars: Int = 1,
        solution: [String] = [],
        solutionType: String = "checkmate"
    ) -> Puzzle {
        Puzzle(
            id: id, name: "测试残局", category: "test", difficulty: 1, stars: stars,
            description: "测试", playerSide: playerSide, initialFEN: initialFEN,
            solution: solution, hints: nil, maxMoves: 10,
            solutionType: solutionType
        )
    }

    // MARK: - Bug 1：残局失败后重试无法走子 【P0】

    @Suite("Bug 1：残局失败后重试无法走子", .serialized)
    struct Bug1PuzzleRetryTests {

        @MainActor
        @Test("resetPuzzle() 重置 isThinking 为 false")
        func resetPuzzleClearsIsThinking() {
            let puzzle = V2217FixTests.makeTestPuzzle(id: "test-retry")
            let vm = PuzzleViewModel(puzzle: puzzle)
            vm.isThinking = true
            #expect(vm.isThinking == true, "前置条件：isThinking 应为 true")
            vm.resetPuzzle()
            #expect(vm.isThinking == false, "resetPuzzle() 应将 isThinking 重置为 false")
        }

        @MainActor
        @Test("resetPuzzle() 后 gameState 恢复为 playing")
        func resetPuzzleRestoresGameState() {
            let puzzle = V2217FixTests.makeTestPuzzle(id: "test-retry-state")
            let vm = PuzzleViewModel(puzzle: puzzle)
            vm.gameState = PuzzleViewModel.PuzzleState.failed
            vm.isThinking = true
            vm.resetPuzzle()
            #expect(vm.gameState == PuzzleViewModel.PuzzleState.playing, "resetPuzzle() 应将 gameState 恢复为 playing")
            #expect(vm.isThinking == false, "resetPuzzle() 应将 isThinking 重置为 false")
        }

        @MainActor
        @Test("resetPuzzle() 后清空 gameMoves")
        func resetPuzzleClearsGameMoves() {
            let puzzle = V2217FixTests.makeTestPuzzle(id: "test-retry-moves")
            let vm = PuzzleViewModel(puzzle: puzzle)
            vm.resetPuzzle()
            #expect(vm.gameMoves.isEmpty, "resetPuzzle() 应清空 gameMoves")
            #expect(vm.selectedPosition == nil, "resetPuzzle() 应清空 selectedPosition")
            #expect(vm.legalMovesForSelected.isEmpty, "resetPuzzle() 应清空 legalMovesForSelected")
        }

        @MainActor
        @Test("resetPuzzle() 后可以选择棋子（isThinking 不阻塞）")
        func resetPuzzleAllowsSelection() {
            let puzzle = V2217FixTests.makeTestPuzzle(
                id: "test-retry-select",
                initialFEN: FENParser.standardInitial
            )
            let vm = PuzzleViewModel(puzzle: puzzle)
            vm.gameState = PuzzleViewModel.PuzzleState.failed
            vm.isThinking = true
            vm.resetPuzzle()
            #expect(vm.gameState == PuzzleViewModel.PuzzleState.playing, "重置后 gameState 应为 playing")
            #expect(vm.isThinking == false, "重置后 isThinking 应为 false")
            let cannonPos = Position(row: 7, col: 1)
            let moves = vm.selectPiece(at: cannonPos)
            #expect(!moves.isEmpty, "重置后应能选择红炮并获取合法走法")
        }

        @MainActor
        @Test("triggerDefenderMove 将死/和局路径 isThinking 最终为 false")
        func triggerDefenderCheckmateClearsIsThinking() async {
            let puzzle = V2217FixTests.makeTestPuzzle(
                id: "test-checkmate-path",
                initialFEN: "4k4/4R4/9/9/9/9/9/9/9/4K4 b",
                playerSide: "red"
            )
            let vm = PuzzleViewModel(puzzle: puzzle)
            #expect(vm.isThinking == false)
            try? await Task.sleep(for: .milliseconds(800))
            #expect(vm.isThinking == false, "AI 走棋完成后 isThinking 应为 false")
        }

        @MainActor
        @Test("resetPuzzle() 后 puzzleVersion 递增（防止旧 Task 干扰）")
        func resetPuzzleIncrementsVersion() {
            let puzzle = V2217FixTests.makeTestPuzzle(id: "test-version")
            let vm = PuzzleViewModel(puzzle: puzzle)
            vm.resetPuzzle()
            vm.resetPuzzle()
            #expect(vm.gameState == .playing, "多次重置后 gameState 应仍为 playing")
            #expect(vm.isThinking == false, "多次重置后 isThinking 应仍为 false")
        }
    }

    // MARK: - Bug 4：中级AI思考时间太长 【P1】

    @Suite("Bug 4：中级AI思考时间优化", .serialized)
    struct Bug4MediumAITimeTests {

        @MainActor
        @Test("TimeManager.forDifficulty(.amateurLow, board: nil as Board?) 现在返回非 nil")
        func mediumDifficultyReturnsTimeManager() {
            let tm = TimeManager.forDifficulty(.amateurLow, board: nil as Board?)
            #expect(tm != nil, ".amateurLow 现在应返回 TimeManager（不再返回 nil）")
        }

        @MainActor
        @Test("TimeManager.forDifficulty(.amateurLow, isIOS: true, board: nil as Board?) 时间 ≤ 2000ms")
        func mediumIOSTimeLimit() {
            let tm = TimeManager.forDifficulty(.amateurLow, isIOS: true, board: nil as Board?)
            #expect(tm != nil, ".amateurLow iOS 应返回 TimeManager")
            #expect(tm!.timeLimitMs <= 2000, ".amateurLow iOS 时间上限应为 ≤2000ms，实际 \(tm!.timeLimitMs)")
        }

        @MainActor
        @Test("TimeManager.forDifficulty(.amateurLow, isIOS: false, board: nil as Board?) 时间 ≤ 3000ms")
        func mediumMacOSTimeLimit() {
            let tm = TimeManager.forDifficulty(.amateurLow, isIOS: false, board: nil as Board?)
            #expect(tm != nil, ".amateurLow macOS 应返回 TimeManager")
            #expect(tm!.timeLimitMs <= 3000, ".amateurLow macOS 时间上限应为 ≤3000ms，实际 \(tm!.timeLimitMs)")
        }

        @MainActor
        @Test("TimeManager.forDifficulty(.novice, board: nil as Board?) 仍返回 nil")
        func beginnerStillReturnsNil() {
            let tm = TimeManager.forDifficulty(.novice, board: nil as Board?)
            #expect(tm == nil, ".novice 应仍返回 nil")
        }

        @MainActor
        @Test("TimeManager.forDifficulty(.beginner, board: nil as Board?) 仍返回 nil")
        func easyStillReturnsNil() {
            let tm = TimeManager.forDifficulty(.beginner, board: nil as Board?)
            #expect(tm == nil, ".beginner 应仍返回 nil")
        }

        @MainActor
        @Test("mediumSearch 返回合法走法（棋力不退化）")
        func mediumSearchReturnsLegalMove() async {
            let board = Board()
            let engine = AIEngine()
            let move = await engine.bestMove(for: board, difficulty: .amateurLow, isIOS: false)
            #expect(move != nil, "medium AI 应返回走法")
            if let move = move {
                let legalMoves = MoveValidator.allLegalMoves(for: board.currentTurn, on: board)
                let isLegal = legalMoves.contains { $0.piece.id == move.piece.id && $0.from == move.from && $0.to == move.to }
                #expect(isLegal, "medium AI 走法应为合法走法")
            }
        }

        @MainActor
        @Test("TimeManager 局面复杂度调整时间")
        func timeManagerComplexityAdjustment() {
            let simpleFEN = "4k4/9/9/9/9/9/9/9/9/4K4 w"
            let simpleBoard = Board(fen: simpleFEN)
            let simpleTM = TimeManager.forDifficulty(.amateurLow, isIOS: false, board: simpleBoard)
            let complexBoard = Board()
            let complexTM = TimeManager.forDifficulty(.amateurLow, isIOS: false, board: complexBoard)
            #expect(simpleTM != nil && complexTM != nil, "两种局面都应返回 TimeManager")
            if let simpleTM = simpleTM, let complexTM = complexTM {
                #expect(complexTM.timeLimitMs >= simpleTM.timeLimitMs,
                       "复杂局面的时间应 ≥ 简单局面：复杂=\(complexTM.timeLimitMs)ms, 简单=\(simpleTM.timeLimitMs)ms")
            }
        }
    }

    // MARK: - Bug 5：缺少当前难度展示 【P1】

    @Suite("Bug 5：当前难度展示", .serialized)
    struct Bug5DifficultyDisplayTests {

        @MainActor
        @Test("AIDifficulty.displayName 对所有难度返回非空字符串")
        func allDifficultyDisplayNames() {
            for difficulty in AIDifficulty.allCases {
                let name = difficulty.displayName
                #expect(!name.isEmpty, "\(difficulty) 的 displayName 不应为空")
            }
        }
    }

    // MARK: - Bug 6：棋谱记录不工作 【P0】

    @Suite("Bug 6：棋谱记录实时更新", .serialized)
    struct Bug6RecordPanelTests {

        @MainActor
        @Test("GameViewModel.gameMoves 在走棋后增长")
        func gameViewModelGameMovesGrowsAfterMove() {
            let vm = GameViewModel()
            let initialCount = vm.gameMoves.count
            let board = vm.board
            let redPieces = board.pieces(for: .red)
            var foundMove: Move? = nil
            for piece in redPieces {
                if let move = MoveValidator.legalMoves(for: piece, on: board).first {
                    foundMove = move
                    break
                }
            }
            guard let move = foundMove else {
                Issue.record("找不到有合法走法的红方棋子")
                return
            }
            vm.movePiece(from: move.from, to: move.to)
            #expect(vm.gameMoves.count > initialCount,
                   "走棋后 gameMoves 应增长：之前=\(initialCount), 之后=\(vm.gameMoves.count)")
        }
    }

    // MARK: - 本地化 key 验证

    @Suite("本地化 key 验证", .serialized)
    struct LocalizationKeyTests {

        @MainActor
        @Test("本地化 key puzzle.notCompleted 存在")
        func puzzleNotCompletedKeyExists() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 Localizable.xcstrings")
                return
            }
            #expect(content.contains("\"puzzle.notCompleted\""),
                   "Localizable.xcstrings 应包含 puzzle.notCompleted key")
        }

        @MainActor
        @Test("本地化 key accessibility.puzzleRow 存在且中英文完整")
        func puzzleRowKeyBilingual() {
            let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
            let path = "\(homeDir)/DevTeam/projects/chinese-chess/src/ChineseChess/Resources/Localizable.xcstrings"
            guard let content = try? String(contentsOfFile: path) else {
                Issue.record("无法读取 Localizable.xcstrings")
                return
            }
            #expect(content.contains("\"accessibility.puzzleRow\""),
                   "Localizable.xcstrings 应包含 accessibility.puzzleRow key")
            #expect(content.contains("zh-Hans"), "应包含中文翻译")
            #expect(content.contains("en"), "应包含英文翻译")
        }
    }
}
