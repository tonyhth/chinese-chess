import Foundation
import Testing
@testable import ChineseChess

// MARK: - P0 紧急修复：FEN+moveHistory 重复执行导致 AI 不工作

@Suite("P0: AI 不工作修复验证")
struct P0AIFixTests {

    // ============================
    // MARK: - 核心修复验证：空 moveHistory
    // ============================

    @Test("AIEngine.bestMove(fen: moveHistory: []) 返回有效走法")
    func aiEngineBestMoveWithEmptyHistory() async throws {
        let engine = AIEngine()
        let board = Board()
        let fen = FENParser.generate(board: board)

        // 使用空 moveHistory 调用 bestMove
        let uciMove = await engine.bestMove(
            fen: fen,
            moveHistory: [],
            difficulty: .medium,
            timeLimitMs: 0
        )

        #expect(uciMove != nil, "AI 应返回有效走法（空 moveHistory）")
        #expect(!uciMove!.isEmpty, "走法不应为空字符串")
    }

    @Test("AIEngine.bestMove(fen: moveHistory: []) 玩家走棋后仍返回有效走法")
    func aiEngineBestMoveAfterPlayerMove() async throws {
        let engine = AIEngine()
        let board = Board()

        // 玩家走一步
        let piece = board.piece(at: Position(row: 7, col: 1))!
        let move = Move(piece: piece, from: piece.position, to: Position(row: 7, col: 4), captured: nil)
        board.execute(move)

        let currentFen = FENParser.generate(board: board)

        // 修复后：使用空 moveHistory
        let uciMove = await engine.bestMove(
            fen: currentFen,
            moveHistory: [],
            difficulty: .medium,
            timeLimitMs: 0
        )

        #expect(uciMove != nil, "玩家走棋后 AI 应仍能返回有效走法")
    }

    // ============================
    // MARK: - EngineRouter 调用验证
    // ============================

    @MainActor
    @Test("EngineRouter.activeEngine() 返回可用的引擎")
    func engineRouterReturnsActiveEngine() async {
        let engine = EngineRouter.shared.activeEngine()

        #expect(engine.displayName.isEmpty == false, "引擎应有 display name")
        #expect(engine.engineType == .native, "默认应使用 native 引擎")
        let ready = await engine.isReady
        #expect(ready, "native 引擎应总是 ready")
    }

    @MainActor
    @Test("EngineRouter.activeEngine().bestMove(moveHistory: []) 返回走法")
    func engineRouterBestMoveWithEmptyHistory() async throws {
        let engine = EngineRouter.shared.activeEngine()
        let board = Board()
        let fen = FENParser.generate(board: board)

        let uciMove = await engine.bestMove(
            fen: fen,
            moveHistory: [],
            difficulty: .medium,
            timeLimitMs: 0
        )

        #expect(uciMove != nil, "EngineRouter.activeEngine 应返回有效走法")
    }

    // ============================
    // MARK: - GameViewModel isThinking 状态管理
    // ============================

    @MainActor
    @Test("GameViewModel 初始 isThinking = false")
    func gameViewModelInitialNotThinking() {
        let vm = GameViewModel()
        #expect(vm.isThinking == false, "初始状态应非 thinking")
    }

    @MainActor
    @Test("GameViewModel.requestHint() 设置 isThinking 状态")
    func gameViewModelRequestHintSetsThinking() async throws {
        let vm = GameViewModel()
        vm.requestHint()

        // requestHint 会设置 isThinking = true
        #expect(vm.isThinking == true, "requestHint 应设置 isThinking = true")

        // 等待 AI 返回
        try await Task.sleep(for: .milliseconds(500))

        // AI 返回后 isThinking 应恢复 false
        #expect(vm.isThinking == false, "AI 返回后 isThinking 应恢复 false")
    }

    @MainActor
    @Test("GameViewModel.gameVersion guard 重置 isThinking")
    func gameViewModelVersionGuardResetThinking() {
        let vm = GameViewModel()

        vm.isThinking = true
        vm.newGame()

        // newGame 会重置 isThinking = false
        #expect(vm.isThinking == false, "newGame 应重置 isThinking = false")
    }

    // ============================
    // MARK: - 综合路径测试
    // ============================

    @MainActor
    @Test("核心路径：玩家走棋 → AI 响应（不再卡住）")
    func playerMoveThenAIResponds() async throws {
        let vm = GameViewModel()

        // 玩家走一步红炮
        vm.selectPiece(at: Position(row: 7, col: 1))
        #expect(vm.selectedPosition == Position(row: 7, col: 1))

        vm.selectPiece(at: Position(row: 7, col: 4))

        // 走棋后轮次应切换到黑方
        #expect(vm.currentTurn == .black, "玩家走棋后应轮到黑方（AI）")

        // AI 应开始思考
        #expect(vm.isThinking == true, "AI 应开始思考")

        // 等待 AI 响应（修复后不应卡住）
        try await Task.sleep(for: .milliseconds(2000))

        // AI 应已完成思考
        #expect(vm.isThinking == false, "AI 应完成思考")

        // 轮次应切换回红方（玩家）
        #expect(vm.currentTurn == .red, "AI 走棋后应轮到红方")
    }

    @MainActor
    @Test("新对局：开始新对局后 AI 应正常工作")
    func newGameAIWorks() async throws {
        let vm = GameViewModel()

        // 先走几步
        vm.selectPiece(at: Position(row: 7, col: 1))
        vm.selectPiece(at: Position(row: 7, col: 4))
        try await Task.sleep(for: .milliseconds(2000))

        // 开始新对局
        vm.newGame()

        #expect(vm.isThinking == false, "新对局应重置 thinking 状态")
        #expect(vm.currentTurn == .red, "新对局红方先行")

        // 玩家走一步
        vm.selectPiece(at: Position(row: 7, col: 1))
        vm.selectPiece(at: Position(row: 7, col: 4))

        #expect(vm.isThinking == true, "新对局后 AI 应响应玩家走棋")

        // 等待 AI 响应
        try await Task.sleep(for: .milliseconds(2000))
        #expect(vm.isThinking == false, "AI 应完成响应")
    }
}

// MARK: - P0 修复：hint 功能验证

@Suite("P0: hint 功能修复验证")
struct P0HintTests {

    @MainActor
    @Test("提示功能：requestHint 返回有效提示")
    func requestHintReturnsHint() async throws {
        let vm = GameViewModel()

        vm.requestHint()

        // 等待 AI 计算提示
        try await Task.sleep(for: .milliseconds(500))

        // 关键是不卡住
        #expect(vm.isThinking == false, "提示请求应完成")
    }

    @MainActor
    @Test("提示功能：玩家走棋后提示仍正常")
    func hintAfterPlayerMove() async throws {
        let vm = GameViewModel()

        // 玩家走一步
        vm.selectPiece(at: Position(row: 7, col: 1))
        vm.selectPiece(at: Position(row: 7, col: 4))
        try await Task.sleep(for: .milliseconds(2000))

        // 等待轮到红方
        while vm.currentTurn != .red || vm.isThinking {
            try await Task.sleep(for: .milliseconds(100))
        }

        // 请求提示
        vm.requestHint()
        try await Task.sleep(for: .milliseconds(500))

        #expect(vm.isThinking == false, "提示请求应完成（不卡住）")
    }
}

// MARK: - P0 修复：UCIMoveConverter 行为验证

@Suite("P0: UCIMoveConverter 空历史验证")
struct P0UCIMoveConverterTests {

    @Test("UCIMoveConverter.board(fen: moves: []) 成功构建")
    func uciMoveConverterEmptyMoves() {
        let board = Board()
        let fen = FENParser.generate(board: board)

        let rebuilt = UCIMoveConverter.board(from: fen, moves: [])

        #expect(rebuilt != nil, "空 moves 应成功构建 Board")
    }

    @Test("UCIMoveConverter.board(fen: moves: []) 玩家走棋后成功构建")
    func uciMoveConverterAfterMove() throws {
        let board = Board()
        let piece = board.piece(at: Position(row: 7, col: 1))!
        let move = Move(piece: piece, from: piece.position, to: Position(row: 7, col: 4), captured: nil)
        board.execute(move)

        let currentFen = FENParser.generate(board: board)

        let rebuilt = UCIMoveConverter.board(from: currentFen, moves: [])

        #expect(rebuilt != nil, "玩家走棋后空 moves 应成功构建 Board")
    }
}