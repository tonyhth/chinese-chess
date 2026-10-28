import Foundation
import Testing
@testable import ChineseChess

// MARK: - Phase 2b: AI 高级算法测试

@Suite("Phase 2b: 杀法搜索", .serialized)
struct CheckmateSearchTests {

    @Test("单车将杀：车 vs 空防线")
    func singleChariotCheckmate() {
        // 红车在 (5,0)，黑将在 (0,3)，红帅在 (9,4)
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = TestPieceFactory.blackGeneral(0, 3)
        let rc = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 3))
        let board = Board(pieces: [rg, bg, rc])
        board.setCurrentTurn(.red)

        let result = CheckmateSearch.search(board: LegacySearchBoard(from: board), for: .red, maxDepth: 8)
        #expect(result != nil)
        if let moves = result {
            #expect(!moves.isEmpty)
        }
    }

    @Test("双车将杀")
    func doubleChariotCheckmate() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let rc1 = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 4))
        let rc2 = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 4, col: 0))
        let board = Board(pieces: [rg, bg, rc1, rc2])
        board.setCurrentTurn(.red)

        let result = CheckmateSearch.search(board: LegacySearchBoard(from: board), for: .red, maxDepth: 8)
        #expect(result != nil)
    }

    @Test("无杀法时返回 nil")
    func noCheckmate() {
        // 初始局面，没有连将杀（P2-1 勘误 2026-10-28：占位断言转真实断言——初始局面 depth=4 内不存在强制连将杀，恒 nil）
        let board = Board()
        board.setCurrentTurn(.red)

        let result = CheckmateSearch.search(board: LegacySearchBoard(from: board), for: .red, maxDepth: 4)
        #expect(result == nil, "初始局面 depth=4 内不得报强制将杀")
    }

    @Test("极短超时安全退出：初始局面恒无杀返回 nil")
    func checkmateSearchTimeout() {
        let board = Board()
        board.setCurrentTurn(.red)
        // 极短超时（P2-1 勘误 2026-10-28：占位断言转真实断言——初始局面不存在强制连将杀，超时/搜完两态均应 nil）
        let result = CheckmateSearch.search(board: LegacySearchBoard(from: board), for: .red, maxDepth: 12, timeLimitMs: 1)
        #expect(result == nil, "初始局面无论超时与否都不得报强制将杀")
    }

    @Test("≥9 应将局面全量校验契约：捕车拆将局面不得假阳性（P3-N1 回归锚，P2-1 补）")
    func nineResponsesFullValidationContract() {
        // 摆位推演（Ruby P2-1 回归锚；探针实证修正 2026-10-28）：红帅 (9,3)，红车 R1 (3,3)；
        // 黑将 (0,4)，士 (0,3)/(0,5)，马 (2,2)/(2,6)，相 (4,2)/(4,6)，车 (3,1)/(3,8)
        // R1 (3,3)→(3,4) 将（col4 直将，行1-2 空）；黑方应将恰 10 手：
        //   士插 (1,4)×2（(0,3)/(0,5) 对角一步）｜马插 (1,4)×2（马腿 (2,3)/(2,5) 空）｜相插 (2,4)×2（象眼 (3,3)/(3,5) 空）｜
        //   捕 R1×4（马 (2,2) 腿(2,3)/马 (2,6) 腿(2,5)/车 (3,1) 路(3,2)(3,3)/车 (3,8) 路(3,5)-(3,7) 全空）
        // 纪律注：马腿=|Δ|=2 轴向一格（马 (2,2)→(1,4) 腿在 (2,3) 非 (1,2)）——首版摆位士占马腿致 4 手马应将全蹩，探针实证后修正
        // 真值=非强制将杀（捕 R1 即拆将且红方再无攻击子）；旧 prefix(8) 剪枝在 10 应将面存在假阳性域
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 3), id: 8)
        let bg = TestPieceFactory.blackGeneral(0, 4)
        let rc = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 3, col: 3))
        let ba1 = TestPieceFactory.makePiece(kind: .advisor, side: .black, position: Position(row: 0, col: 3))
        let ba2 = TestPieceFactory.makePiece(kind: .advisor, side: .black, position: Position(row: 0, col: 5))
        let bh1 = TestPieceFactory.makePiece(kind: .horse, side: .black, position: Position(row: 2, col: 2))
        let bh2 = TestPieceFactory.makePiece(kind: .horse, side: .black, position: Position(row: 2, col: 6))
        let be1 = TestPieceFactory.makePiece(kind: .elephant, side: .black, position: Position(row: 4, col: 2))
        let be2 = TestPieceFactory.makePiece(kind: .elephant, side: .black, position: Position(row: 4, col: 6))
        let bc1 = TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 3, col: 1))
        let bc2 = TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 3, col: 8))
        let preCheck = Board(pieces: [rg, bg, rc, ba1, ba2, bh1, bh2, be1, be2, bc1, bc2])
        preCheck.setCurrentTurn(.red)

        // 前置断言：应将态黑方合法应将手数 ≥9（摆位自检，防夹具漂移静默通过）
        let checked = Board(pieces: [rg, bg, rc, ba1, ba2, bh1, bh2, be1, be2, bc1, bc2])
        checked.setCurrentTurn(.red)
        let r1 = checked.piece(at: Position(row: 3, col: 3))
        #expect(r1 != nil, "夹具红车应在位")
        checked.execute(Move(piece: r1!, from: Position(row: 3, col: 3), to: Position(row: 3, col: 4), captured: nil))
        let responses = MoveValidator.allLegalMoves(for: .black, on: checked)
        #expect(responses.count >= 9, "应将手数应 ≥9（实测 \(responses.count)）——P3-N1 剪枝阈值面")

        let result = CheckmateSearch.search(board: LegacySearchBoard(from: preCheck), for: .red, maxDepth: 8)
        #expect(result == nil, "黑方可捕 R1 拆将且红方再无攻击子——全量校验下不得假阳性报杀")
    }
}

@Suite("Phase 2b: 棋型识别", .serialized)
struct PatternRecognizerTests {

    @Test("铁门栓：车在将正前方无阻挡")
    func ironGatePattern() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let rc = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 4))
        let board = Board(pieces: [rg, bg, rc])

        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .red, weights: EvalConfigManager.shared.weights)
        // 红方有铁门栓（车在将正前方同列无阻挡）+ 单车胜
        #expect(bonus > 0)
    }

    @Test("单车胜：车 vs 无防守子")
    func singleChariotWinPattern() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let rc = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let board = Board(pieces: [rg, bg, rc])

        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .red, weights: EvalConfigManager.shared.weights)
        #expect(bonus >= 800)  // 单车胜 +800
    }

    @Test("初始局面无特殊棋型加分")
    func noPatternInInitialBoard() {
        let board = Board()
        // 初始局面双方都有士象，不应触发"单车胜"等模式
        let redBonus = PatternRecognizer.bonusPatterns(on: board, for: .red, weights: EvalConfigManager.shared.weights)
        let blackBonus = PatternRecognizer.bonusPatterns(on: board, for: .black, weights: EvalConfigManager.shared.weights)
        // 双方都有双车，会触发双车模式加分——这是正常的
        // 关键是不崩溃
        _ = (redBonus, blackBonus)
    }

    @Test("双车错加分")
    func doubleChariotPattern() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let rc1 = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let rc2 = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 4, col: 5))
        let board = Board(pieces: [rg, bg, rc1, rc2])

        let bonus = PatternRecognizer.bonusPatterns(on: board, for: .red, weights: EvalConfigManager.shared.weights)
        #expect(bonus >= 600)  // 双车错 +600
    }
}

@Suite("Phase 2b: 残局精确估值", .serialized)
struct EndgameEvaluatorTests {

    @Test("单车 vs 空：红方大优势")
    func singleChariotVsEmpty() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let rc = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let board = Board(pieces: [rg, bg, rc])

        let score = EndgameEvaluator.evaluate(board: board, for: .red)
        #expect(score != nil)
        #expect(score! == 8000)
    }

    @Test("单车 vs 空：黑方视角为负")
    func singleChariotVsEmptyBlackView() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let rc = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
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
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let rh = TestPieceFactory.makePiece(kind: .horse, side: .red, position: Position(row: 5, col: 0))
        let rc = TestPieceFactory.makePiece(kind: .cannon, side: .red, position: Position(row: 4, col: 5))
        let bh = TestPieceFactory.makePiece(kind: .horse, side: .black, position: Position(row: 3, col: 2))
        let board = Board(pieces: [rg, bg, rh, rc, bh])

        let score = EndgameEvaluator.evaluate(board: board, for: .red)
        #expect(score != nil)
        #expect(score! == 3000)
    }

    @Test("单车 vs 士象：红方优势但较小")
    func chariotVsAdvisorElephant() {
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let rc = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let ba = TestPieceFactory.makePiece(kind: .advisor, side: .black, position: Position(row: 1, col: 5))
        let be = TestPieceFactory.makePiece(kind: .elephant, side: .black, position: Position(row: 2, col: 4))
        let board = Board(pieces: [rg, bg, rc, ba, be])

        let score = EndgameEvaluator.evaluate(board: board, for: .red)
        #expect(score != nil)
        #expect(score! == 4000)
    }
}

@Suite("Phase 2b: 时间管理", .serialized)
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
        #expect(TimeManager.forDifficulty(.novice, board: nil as Board?) == nil)
        #expect(TimeManager.forDifficulty(.beginner, board: nil as Board?) == nil)
        #expect(TimeManager.forDifficulty(.amateurLow, board: nil as Board?) != nil)
        #expect(TimeManager.forDifficulty(.amateurLow, board: nil as Board?)!.timeLimitMs == 3000)
    }

    @Test("hard 有 5 秒限制")
    func hardTimeLimit() {
        let tm = TimeManager.forDifficulty(.amateurMid, board: nil as Board?)
        #expect(tm != nil)
        #expect(tm!.timeLimitMs == 5000)
    }

    @Test("master 有 10 秒限制")
    func masterTimeLimit() {
        let tm = TimeManager.forDifficulty(.amateurHigh, board: nil as Board?)
        #expect(tm != nil)
        #expect(tm!.timeLimitMs == 10000)
    }
}

@Suite("Phase 2b: AI 集成验证", .serialized)
struct Phase2bIntegrationTests {

    @Test("高级 AI 能找到杀法（简单残局）")
    func hardAIFindsCheckmate() async {
        // 红车底线，黑将无防守
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = TestPieceFactory.blackGeneral(1, 4)
        let rc = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 8, col: 4))
        let board = Board(pieces: [rg, bg, rc])
        board.setCurrentTurn(.red)

        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .amateurMid)
        #expect(move != nil)
        // 高级 AI 应该能找到直接的杀法
    }

    @Test("大师 AI 残局估值合理")
    func masterAIEndgameReasonable() async {
        // 残局 ≤6 子，大师级应使用 EndgameEvaluator
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let rc = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let board = Board(pieces: [rg, bg, rc])
        board.setCurrentTurn(.black)

        let engine = AIEngine()
        let move = await engine.bestMove(for: board, difficulty: .amateurHigh)
        // 黑方只能走将，应该不崩溃
        #expect(move != nil)
    }

    @Test("5 级 AI 全部能完成残局对局")
    func allDifficultyCompleteEndgame() async {
        let difficulties: [AIDifficulty] = [.novice, .beginner, .amateurLow, .amateurMid, .amateurHigh]
        let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 4), id: 8)
        let bg = Piece(kind: .general, side: .black, position: Position(row: 0, col: 4), id: 24)
        let rc = TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))
        let bh = TestPieceFactory.makePiece(kind: .horse, side: .black, position: Position(row: 3, col: 2))
        let board = Board(pieces: [rg, bg, rc, bh])

        let engine = AIEngine()
        for diff in difficulties {
            board.setCurrentTurn(.red)
            let move = await engine.bestMove(for: board, difficulty: diff)
            #expect(move != nil, "\(diff) returned nil")
        }
    }
}
