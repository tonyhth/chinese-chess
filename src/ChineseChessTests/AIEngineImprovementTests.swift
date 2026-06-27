import Foundation
import Testing
@testable import ChineseChess

@Suite("AI 引擎改进 P0 + P1-a")
struct AIEngineImprovementTests {

    // MARK: - P0：新手级平滑过渡

    @Test("beginnerMove 返回合法走法（非 nil）")
    func beginnerMoveReturnsValidMove() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .beginner)
        #expect(move != nil)
    }

    @Test("beginnerMove 走法起点有己方棋子")
    func beginnerMoveFromHasPiece() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .beginner)
        #expect(move != nil)
        if let move = move {
            let piece = board.piece(at: move.from)
            #expect(piece != nil)
        }
    }

    @Test("beginnerMove 多次调用不 crash（概率性路径覆盖）")
    func beginnerMoveMultipleCallsNoCrash() async {
        let engine = AIEngine()
        let board = Board()
        for _ in 0..<20 {
            let move = await engine.bestMove(for: board.snapshot(), difficulty: .beginner)
            #expect(move != nil)
        }
    }

    @Test("beginnerMove 走法是合法的")
    func beginnerMoveIsLegal() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .beginner)
        #expect(move != nil)
        if let move = move {
            let legalMoves = MoveValidator.allLegalMoves(for: board.currentTurn, on: board)
            let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
            #expect(isLegal)
        }
    }

    @Test("beginnerMove 100 次调用两条路径都安全")
    func beginnerMoveBothPathsSafe() async {
        let engine = AIEngine()
        let board = Board()
        // 30% 概率走 depth=1，70% 走随机。100 次必然覆盖两条路径
        for _ in 0..<100 {
            let move = await engine.bestMove(for: board.snapshot(), difficulty: .beginner)
            #expect(move != nil)
        }
    }

    @Test("其他难度不受 beginnerMove 影响：初级返回合法走法")
    func easyDifficultyStillWorks() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .easy)
        #expect(move != nil)
    }

    @Test("其他难度不受 beginnerMove 影响：中级返回合法走法")
    func mediumDifficultyStillWorks() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .medium)
        #expect(move != nil)
    }

    @Test("新手级走法不修改原棋盘")
    func beginnerMoveDoesNotMutateBoard() async {
        let engine = AIEngine()
        let board = Board()
        let snapshot = board.snapshot()
        _ = await engine.bestMove(for: board.snapshot(), difficulty: .beginner)
        // board 应该没变（bestMove 内部做了 snapshot）
        #expect(board.pieces.count == snapshot.pieces.count)
    }

    // MARK: - P1-a：杀法搜索应对方剪枝

    @Test("CheckmateSearch：初始局面无将杀")
    func checkmateSearchInitialNoCheckmate() {
        let board = Board()
        let result = CheckmateSearch.search(board: board, for: .red, maxDepth: 3)
        #expect(result == nil)
    }

    @Test("CheckmateSearch depth=1 不 crash")
    func checkmateSearchDepth1NoCrash() {
        let board = Board()
        let result = CheckmateSearch.search(board: board, for: .red, maxDepth: 1)
        _ = result
    }

    @Test("CheckmateSearch depth=6 不 crash")
    func checkmateSearchDepth6NoCrash() {
        let board = Board()
        let result = CheckmateSearch.search(board: board, for: .red, maxDepth: 6)
        _ = result
    }

    @Test("CheckmateSearch 从红方和黑方搜都不 crash")
    func checkmateSearchBothSidesNoCrash() {
        let board = Board()
        let redResult = CheckmateSearch.search(board: board, for: .red, maxDepth: 3)
        let blackResult = CheckmateSearch.search(board: board, for: .black, maxDepth: 3)
        _ = redResult
        _ = blackResult
    }

    @Test("CheckmateSearch 带超时不 crash")
    func checkmateSearchWithTimeLimitNoCrash() {
        let board = Board()
        let result = CheckmateSearch.search(board: board, for: .red, maxDepth: 8, timeLimitMs: 100)
        _ = result
    }

    @Test("CheckmateSearch 不修改原棋盘")
    func checkmateSearchDoesNotMutateBoard() {
        let board = Board()
        let pieceCount = board.pieces.count
        _ = CheckmateSearch.search(board: board, for: .red, maxDepth: 3)
        #expect(board.pieces.count == pieceCount)
    }

    @Test("CheckmateSearch dfs 剪枝：初始局面搜索速度快（< 2s）")
    func checkmateSearchPruningIsFast() {
        let board = Board()
        let start = Date()
        _ = CheckmateSearch.search(board: board, for: .red, maxDepth: 6)
        let elapsed = Date().timeIntervalSince(start)
        // 初始局面无将军走法，checkMoves 为空，应该极快返回
        #expect(elapsed < 2.0)
    }

    // MARK: - 回归：所有难度

    @Test("AI 各难度均返回合法走法")
    func allDifficultiesReturnValidMoves() async {
        let engine = AIEngine()
        let board = Board()
        for diff in AIDifficulty.allCases {
            let move = await engine.bestMove(for: board.snapshot(), difficulty: diff)
            #expect(move != nil, "难度 \(diff) 返回 nil")
            if let move = move {
                let legalMoves = MoveValidator.allLegalMoves(for: board.currentTurn, on: board)
                let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
                #expect(isLegal, "难度 \(diff) 返回非法走法")
            }
        }
    }
}
