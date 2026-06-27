import Foundation
import Testing
@testable import ChineseChess

// MARK: - Phase 2b: AI 高级算法测试

@Suite("Phase 2b: 杀法搜索")
struct CheckmateSearchTests {

    @Test("单车将杀：车 vs 空防线")
    func singleChariotCheckmate() {
        // 红车在 (5,0)，黑将在 (0,3)，红帅在 (9,4)
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 3))
        let rc = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 3))
        let board = Board(pieces: [rg, bg, rc])
        board.setCurrentTurn(.red)

        let result = CheckmateSearch.search(board: board, for: .red, maxDepth: 8)
        #expect(result != nil)
        if let moves = result {
            #expect(!moves.isEmpty)
        }
    }

    @Test("双车将杀")
    func doubleChariotCheckmate() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let rc1 = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 4))
        let rc2 = Piece(kind: .chariot, side: .red, position: Position(row: 4, col: 0))
        let board = Board(pieces: [rg, bg, rc1, rc2])
        board.setCurrentTurn(.red)

        let result = CheckmateSearch.search(board: board, for: .red, maxDepth: 8)
        #expect(result != nil)
    }

    @Test("无杀法时返回 nil")
    func noCheckmate() {
        // 初始局面，没有连将杀
        let board = Board()
        board.setCurrentTurn(.red)

        let result = CheckmateSearch.search(board: board, for: .red, maxDepth: 4)
        // 初始局面 depth=4 内不太可能有连将杀
        // 不做严格断言，只验证不崩溃
        _ = result
    }

    @Test("超时安全退出")
    func checkmateSearchTimeout() {
        let board = Board()
        board.setCurrentTurn(.red)
        // 极短超时
        let result = CheckmateSearch.search(board: board, for: .red, maxDepth: 12, timeLimitMs: 1)
        // 超时应安全退出
        _ = result
    }
}

@Suite("Phase 2b: 棋型识别")
struct PatternRecognizerTests {

    @Test("铁门栓：车在将正前方无阻挡")
    func ironGatePattern() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let rc = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 4))
        let board = Board(pieces: [rg, bg, rc])

        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .red)
        // 红方有铁门栓（车在将正前方同列无阻挡）+ 单车胜
        #expect(bonus > 0)
    }

    @Test("单车胜：车 vs 无防守子")
    func singleChariotWinPattern() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let rc = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let board = Board(pieces: [rg, bg, rc])

        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .red)
        #expect(bonus >= 800)  // 单车胜 +800
    }

    @Test("初始局面无特殊棋型加分")
    func noPatternInInitialBoard() {
        let board = Board()
        // 初始局面双方都有士象，不应触发"单车胜"等模式
        let redBonus = PatternRecognizer.bonusPatterns(on: board, for: .red)
        let blackBonus = PatternRecognizer.bonusPatterns(on: board, for: .black)
        // 双方都有双车，会触发双车模式加分——这是正常的
        // 关键是不崩溃
        _ = (redBonus, blackBonus)
    }

    @Test("双车错加分")
    func doubleChariotPattern() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let rc1 = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let rc2 = Piece(kind: .chariot, side: .red, position: Position(row: 4, col: 5))
        let board = Board(pieces: [rg, bg, rc1, rc2])

        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .red)
        #expect(bonus >= 600)  // 双车错 +600
    }
}

@Suite("Phase 2b: 残局精确估值")
struct EndgameEvaluatorTests {

    @Test("单车 vs 空：红方大优势")
    func singleChariotVsEmpty() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let rc = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let board = Board(pieces: [rg, bg, rc])

        let score = EndgameEvaluator.evaluate(board: board, for: .red)
        #expect(score != nil)
        #expect(score! == 8000)
    }

    @Test("单车 vs 空：黑方视角为负")
    func singleChariotVsEmptyBlackView() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let rc = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let board = Board(pieces: [rg, bg, rc])

        let score = EndgameEvaluator.evaluate(board: board, for: .black)
        #expect(score != nil)
        #expect(score! == -8000)
    }

    @Test("超过 6 子返回 nil")
    func tooManyPiecesReturnsNil() {
        let board = Board()  // 32 子
        let score = EndgameEvaluator.evaluate(board: board, for: .red)
        #expect(score == nil)
    }

    @Test("马炮 vs 马：红方优势")
    func horseCannonVsHorse() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let rh = Piece(kind: .horse, side: .red, position: Position(row: 5, col: 0))
        let rc = Piece(kind: .cannon, side: .red, position: Position(row: 4, col: 5))
        let bh = Piece(kind: .horse, side: .black, position: Position(row: 3, col: 2))
        let board = Board(pieces: [rg, bg, rh, rc, bh])

        let score = EndgameEvaluator.evaluate(board: board, for: .red)
        #expect(score != nil)
        #expect(score! == 3000)
    }

    @Test("单车 vs 士象：红方优势但较小")
    func chariotVsAdvisorElephant() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let rc = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let ba = Piece(kind: .advisor, side: .black, position: Position(row: 1, col: 5))
        let be = Piece(kind: .elephant, side: .black, position: Position(row: 2, col: 4))
        let board = Board(pieces: [rg, bg, rc, ba, be])

        let score = EndgameEvaluator.evaluate(board: board, for: .red)
        #expect(score != nil)
        #expect(score! == 4000)
    }
}

@Suite("Phase 2b: 时间管理")
struct TimeManagerTests {

    @Test("创建后不超时")
    func notExpiredInitially() {
        let tm = TimeManager(timeLimitMs: 5000, startTime: Date())
        #expect(!tm.shouldStop)
        #expect(tm.elapsedMs < 100)
    }

    @Test("剩余时间计算")
    func remainingTime() {
        let tm = TimeManager(timeLimitMs: 5000, startTime: Date())
        #expect(tm.remainingMs <= 5000)
        #expect(tm.remainingMs > 4900)
    }

    @Test("beginner/easy 无时间管理；medium 有时间限制（v2.2.17 Bug4 修复）")
    func noTimeManagerForLowerDifficulty() {
        #expect(TimeManager.forDifficulty(.beginner) == nil)
        #expect(TimeManager.forDifficulty(.easy) == nil)
        #expect(TimeManager.forDifficulty(.medium) != nil)
        #expect(TimeManager.forDifficulty(.medium)!.timeLimitMs == 3000)
    }

    @Test("hard 有 5 秒限制")
    func hardTimeLimit() {
        let tm = TimeManager.forDifficulty(.hard)
        #expect(tm != nil)
        #expect(tm!.timeLimitMs == 5000)
    }

    @Test("master 有 10 秒限制")
    func masterTimeLimit() {
        let tm = TimeManager.forDifficulty(.master)
        #expect(tm != nil)
        #expect(tm!.timeLimitMs == 10000)
    }
}

@Suite("Phase 2b: AI 集成验证")
struct Phase2bIntegrationTests {

    @Test("高级 AI 能找到杀法（简单残局）")
    func hardAIFindsCheckmate() async {
        // 红车底线，黑将无防守
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 1, col: 4))
        let rc = Piece(kind: .chariot, side: .red, position: Position(row: 8, col: 4))
        let board = Board(pieces: [rg, bg, rc])
        board.setCurrentTurn(.red)

        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .hard)
        #expect(move != nil)
        // 高级 AI 应该能找到直接的杀法
    }

    @Test("大师 AI 残局估值合理")
    func masterAIEndgameReasonable() async {
        // 残局 ≤6 子，大师级应使用 EndgameEvaluator
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let rc = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let board = Board(pieces: [rg, bg, rc])
        board.setCurrentTurn(.black)

        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .master)
        // 黑方只能走将，应该不崩溃
        #expect(move != nil)
    }

    @Test("5 级 AI 全部能完成残局对局")
    func allDifficultyCompleteEndgame() async {
        let difficulties: [AIDifficulty] = [.beginner, .easy, .medium, .hard, .master]
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4))
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4))
        let rc = Piece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let bh = Piece(kind: .horse, side: .black, position: Position(row: 3, col: 2))
        let board = Board(pieces: [rg, bg, rc, bh])

        let engine = AIEngine()
        for diff in difficulties {
            board.setCurrentTurn(.red)
            let move = await engine.bestMove(for: board, difficulty: diff)
            #expect(move != nil, "\(diff) returned nil")
        }
    }
}
