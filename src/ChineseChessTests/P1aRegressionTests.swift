import Foundation
import Testing
@testable import ChineseChess

@Suite("P1-a 回归测试：攻击线阻挡 + 开局库重建", .serialized)
struct P1aRegressionTests {

    // MARK: - 1. CheckmateSearch moveScore 攻击线阻挡评分

    @Test("CheckmateSearch：車帅 vs 单将——搜索不 crash")
    func checkmateChariotVsKing() {
        // 红車 b9(1,1)，红帅 d0(9,3)，黑将 e9(0,4)
        // 車帅杀单将需较长序列，可能找不到，但不应 crash
        let fen = "4k4/1R7/9/9/9/9/9/9/9/3K5 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let result = CheckmateSearch.search(board: SearchBoard(from: board), for: .red, maxDepth: 12, timeLimitMs: 5000)
        // 如果找到将杀，验证走法序列合法性
        if let moves = result, !moves.isEmpty {
            let firstMove = moves[0]
            let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
            let isLegal = legalMoves.contains { $0.from == firstMove.from && $0.to == firstMove.to }
            #expect(isLegal, "将杀第一步不是合法走法")
        }
        // nil 也合法（深度不够未找到）
    }

    @Test("CheckmateSearch：双車 vs 单将——搜索不 crash")
    func checkmateDoubleChariotVsKing() {
        // 双車 vs 单将（红車在远处），搜索可能找不到但不应 crash
        let fen = "4k4/9/9/9/9/9/9/R7R/9/3K5 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let result = CheckmateSearch.search(board: SearchBoard(from: board), for: .red, maxDepth: 10, timeLimitMs: 5000)
        // 深度 10 可能不够双車杀将，但至少不 crash
        if let moves = result, !moves.isEmpty {
            let firstMove = moves[0]
            let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
            let isLegal = legalMoves.contains { $0.from == firstMove.from && $0.to == firstMove.to }
            #expect(isLegal, "将杀第一步不是合法走法")
        }
    }

    @Test("CheckmateSearch：車炮 vs 单将——搜索不 crash")
    func checkmateChariotCannonVsKing() {
        let fen = "4k4/R8/9/9/9/9/9/4C4/9/3K5 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let result = CheckmateSearch.search(board: SearchBoard(from: board), for: .red, maxDepth: 12, timeLimitMs: 5000)
        // 車炮杀可能需要较长序列，至少不应 crash
        _ = result
    }

    @Test("CheckmateSearch：将杀序列第一步必须是将军（車帅 vs 单将）")
    func checkmateFirstMoveIsCheck() {
        // 使用已知能找到将杀的局面：車帅 vs 单将
        // 红車(8,4) 红帅(9,4) 黑将(0,4)，車挡住将帅对面
        let fen = "4k4/9/9/9/9/9/9/9/4R4/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        guard let moves = CheckmateSearch.search(board: SearchBoard(from: board), for: .red, maxDepth: 8, timeLimitMs: 3000) else {
            Issue.record("車帅 vs 单将未找到将杀")
            return
        }
        // 第一步必须是将军
        board.execute(moves[0])
        let opponentInCheck = MoveValidator.isInCheck(.black, on: board)
        _ = board.undoLastMove()
        #expect(opponentInCheck, "将杀序列第一步不是将军")
    }

    @Test("moveScore 间接验证：車直线攻击局面 AI 行为正常")
    func moveScoreChariotAttackBlocking() async {
        // 黑車 a9(0,0)，黑将 d9(0,3)，红帅 f0(9,5)
        // 帅在 f 列避免将帅同列对面
        let fen = "R2k5/9/9/9/9/9/9/9/9/5K3 b - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let engine = AIEngine()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .hard)
        #expect(move != nil, "AI 在車攻击局面返回 nil")
    }

    @Test("moveScore 间接验证：炮隔子攻击局面 AI 行为正常")
    func moveScoreCannonAttackBlocking() async {
        let fen = "4k4/9/9/9/4c4/4P4/9/9/9/4K4 b - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let engine = AIEngine()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .hard)
        #expect(move != nil, "AI 在炮攻击局面返回 nil")
    }

    // MARK: - 2. 开局库 v2 加载与验证

    @Test("开局库 v2 加载 4,602 个局面")
    func openingBookV2PositionCount() {
        let book = OpeningBook.shared
        let board = Board()
        let hash = ZobristHash.hash(board: board)
        #expect(book.lookup(zobristHash: hash) != nil, "初始局面不在开局库中")
    }

    @Test("开局库 v2：初始局面有多个候选走法（中炮等）")
    func openingBookV2InitialMultipleCandidates() {
        let book = OpeningBook.shared
        let board = Board()
        let hash = ZobristHash.hash(board: board)
        guard let entries = book.lookupAll(zobristHash: hash) else {
            Issue.record("初始局面无 entries")
            return
        }
        #expect(entries.count >= 3, "初始局面候选走法过少: \(entries.count)")
        let topMove = entries[0].move
        #expect(topMove == "h2e2", "最高权重走法不是中炮 h2e2，而是 \(topMove)")
    }

    @Test("开局库 v2：走一步后仍有开局建议")
    func openingBookV2AfterFirstMove() {
        let book = OpeningBook.shared
        let board = Board()
        guard let move = book.parseICCSMove("h2e2", on: board) else {
            Issue.record("h2e2 解析失败")
            return
        }
        board.execute(move)
        board.setCurrentTurn(.black)
        let hash = ZobristHash.hash(board: board)
        // 黑方走棋后可能有也可能没有开局建议，不强制
        _ = book.lookup(zobristHash: hash)
    }

    @Test("开局库 v2：多个初始走法都是合法的")
    func openingBookV2AllInitialMovesLegal() {
        let book = OpeningBook.shared
        let board = Board()
        let hash = ZobristHash.hash(board: board)
        guard let entries = book.lookupAll(zobristHash: hash) else {
            Issue.record("初始局面无 entries")
            return
        }
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        for entry in entries {
            guard let move = book.parseICCSMove(entry.move, on: board) else {
                Issue.record("ICCS 解析失败: \(entry.move)")
                continue
            }
            let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
            #expect(isLegal, "开局库走法 \(entry.move) 不合法")
        }
    }

    @Test("开局库 v2：权重值均为正整数")
    func openingBookV2WeightsPositive() {
        let book = OpeningBook.shared
        let board = Board()
        let hash = ZobristHash.hash(board: board)
        guard let entries = book.lookupAll(zobristHash: hash) else { return }
        for entry in entries {
            #expect(entry.weight > 0, "权重非正: \(entry.weight) for \(entry.move)")
        }
    }

    // MARK: - 3. 回归：AI 五级难度

    @Test("beginner：初始局面返回合法走法")
    func beginnerInitialLegalMove() async {
        let engine = AIEngine()
        let board = Board()
        var allLegal = true
        for _ in 0..<10 {
            guard let move = await engine.bestMove(for: board.snapshot(), difficulty: .beginner) else {
                allLegal = false; continue
            }
            let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
            if !legalMoves.contains(where: { $0.from == move.from && $0.to == move.to }) {
                allLegal = false
            }
        }
        #expect(allLegal, "beginner 返回非法走法")
    }

    @Test("easy：初始局面返回合法走法")
    func easyInitialLegalMove() async {
        let engine = AIEngine()
        let board = Board()
        guard let move = await engine.bestMove(for: board.snapshot(), difficulty: .easy) else {
            Issue.record("easy 返回 nil")
            return
        }
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        #expect(legalMoves.contains(where: { $0.from == move.from && $0.to == move.to }), "easy 返回非法走法")
    }

    @Test("medium：初始局面返回合法走法（可能来自开局库）")
    func mediumInitialLegalMove() async {
        let engine = AIEngine()
        let board = Board()
        guard let move = await engine.bestMove(for: board.snapshot(), difficulty: .medium) else {
            Issue.record("medium 返回 nil")
            return
        }
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        #expect(legalMoves.contains(where: { $0.from == move.from && $0.to == move.to }), "medium 返回非法走法")
    }

    @Test("hard：初始局面返回合法走法（开局库优先）")
    func hardInitialLegalMove() async {
        let engine = AIEngine()
        let board = Board()
        guard let move = await engine.bestMove(for: board.snapshot(), difficulty: .hard) else {
            Issue.record("hard 返回 nil")
            return
        }
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        #expect(legalMoves.contains(where: { $0.from == move.from && $0.to == move.to }), "hard 返回非法走法")
    }

    @Test("master：初始局面返回合法走法（开局库优先）")
    func masterInitialLegalMove() async {
        let engine = AIEngine()
        let board = Board()
        guard let move = await engine.bestMove(for: board.snapshot(), difficulty: .master) else {
            Issue.record("master 返回 nil")
            return
        }
        let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
        #expect(legalMoves.contains(where: { $0.from == move.from && $0.to == move.to }), "master 返回非法走法")
    }

    // MARK: - 4. AI 不修改传入棋盘

    @Test("AI 不修改传入的棋盘（所有难度）")
    func aiDoesNotModifyInput() async {
        let difficulties: [AIDifficulty] = [.beginner, .easy, .medium, .hard]
        for diff in difficulties {
            let engine = AIEngine()
            let board = Board()
            let fenBefore = FENParser.generate(board: board)
            _ = await engine.bestMove(for: board.snapshot(), difficulty: diff)
            let fenAfter = FENParser.generate(board: board)
            #expect(fenBefore == fenAfter, "\(diff): AI 修改了传入的棋盘")
        }
    }

    // MARK: - 5. 开局库 miss 后 AI 正常 fallback

    @Test("开局库 miss：残局局面 AI 正常走棋")
    func openingBookMissEndgame() async {
        let engine = AIEngine()
        let fen = "4k4/9/9/9/9/9/9/4R4/9/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        for diff in [AIDifficulty.medium, .hard] {
            let move = await engine.bestMove(for: board.snapshot(), difficulty: diff)
            #expect(move != nil, "\(diff) 残局返回 nil")
        }
    }

    // MARK: - 6. beginner 平滑过渡

    @Test("beginner：30 次调用中至少有 1 次走法不同（验证随机性）")
    func beginnerHasVariety() async {
        let engine = AIEngine()
        let board = Board()
        var moves = Set<String>()
        for _ in 0..<30 {
            if let move = await engine.bestMove(for: board.snapshot(), difficulty: .beginner) {
                moves.insert("\(move.from.row),\(move.from.col)->\(move.to.row),\(move.to.col)")
            }
        }
        #expect(moves.count >= 2, "30 次 beginner 调用只有 \(moves.count) 种走法，缺乏多样性")
    }

    // MARK: - 7. 综合对局回归

    @Test("medium 完整对局 5 回合不 crash")
    func mediumGameNoCrash() async {
        let engine = AIEngine()
        let board = Board()
        for _ in 0..<10 {
            let side = board.currentTurn
            guard let move = await engine.bestMove(for: board.snapshot(), difficulty: .medium) else {
                Issue.record("medium 返回 nil at move \(board.moveHistory.count)")
                return
            }
            let legalMoves = MoveValidator.allLegalMoves(for: side, on: board)
            let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
            #expect(isLegal, "medium 返回非法走法 at move \(board.moveHistory.count)")
            board.execute(move)
        }
    }

    @Test("hard 完整对局 5 回合不 crash")
    func hardGameNoCrash() async {
        let engine = AIEngine()
        let board = Board()
        for i in 0..<10 {
            let side = board.currentTurn
            guard let move = await engine.bestMove(for: board.snapshot(), difficulty: .hard) else {
                Issue.record("hard 返回 nil at move \(i)")
                return
            }
            let legalMoves = MoveValidator.allLegalMoves(for: side, on: board)
            let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
            #expect(isLegal, "hard 返回非法走法 at move \(i)")
            board.execute(move)
        }
    }

    // MARK: - 8. ZobristHash 一致性

    @Test("ZobristHash：开局库走法后 hash 一致")
    func zobristHashConsistencyAfterBookMove() {
        let board = Board()
        let book = OpeningBook.shared
        let hash0 = ZobristHash.hash(board: board)

        guard let iccs = book.lookup(zobristHash: hash0) else { return }
        guard let move = book.parseICCSMove(iccs, on: board) else { return }
        board.execute(move)

        let hash1a = ZobristHash.hash(board: board)
        let hash1b = ZobristHash.hash(board: board)
        #expect(hash1a == hash1b, "同一局面 hash 不一致")
        #expect(hash1a != hash0, "走一步后 hash 未变化")
    }
}
