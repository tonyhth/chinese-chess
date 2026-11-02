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

    // PROBE-ANCHOR（锚重设计探针，工作树态禁 commit——Luke 总裁定第三步）：v2 摆位 10 手应将清单收割器
    // （PROBE2 证据=tp1023-fp-probe2-1028.log；判别性重设计候选素材，Vera 独立审/下批排期用）
    @Test("PROBE ≥9 应将锚设计收割")
    func probeAnchorDesign() {
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
        let checked = Board(pieces: [rg, bg, rc, ba1, ba2, bh1, bh2, be1, be2, bc1, bc2])
        checked.setCurrentTurn(.red)
        let r1 = checked.piece(at: Position(row: 3, col: 3))!
        checked.execute(Move(piece: r1, from: Position(row: 3, col: 3), to: Position(row: 3, col: 4), captured: nil))
        let responses = MoveValidator.allLegalMoves(for: .black, on: checked)
        for mv in responses {
            print("PROBE2-RESPONSE \(mv.piece.kind) \(mv.from.row),\(mv.from.col)->\(mv.to.row),\(mv.to.col) captured=\(mv.captured?.kind.rawValue ?? "none")")
        }
        #expect(responses.count >= 0)
    }

    @Test("≥9 应将局面全量校验契约：捕车拆将局面不得假阳性（P3-N1 回归锚，P2-1 补）")
    func nineResponsesFullValidationContract() {
        // 摆位推演（Ruby P2-1 回归锚；探针实证修正 2026-10-28）：红帅 (9,3)，红车 R1 (3,3)；
        // 黑将 (0,4)，士 (0,3)/(0,5)，马 (2,2)/(2,6)，相 (4,2)/(4,6)，车 (3,1)/(3,8)
        // 名实注记（T-1103-1①）：名 nineResponses 系历史命名（≥9 门槛语义），实测应将面=10 手——名实差以一行说明（快照归档批顺路落）
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

// MARK: - T-1101-1 件1：判别性杀法锚探针（路径A·炮将双轴骨架；工作树态禁 commit——约束6 探针迭代协议）
// Vera spec：docs/reviews/t1023-fp-anchor-vera-audit.md §三.A/§四；v1-v3 三败根因=合法性/排序/punish 三轴从未同验
// 迭代1 变体池：6 punish 摆位 × 固定黑方骨架（预测 110×4/90×4/60×2/30×3 十三应将；捕炮线按约束2 删除；
// 马h3(0,5) 堵将移+士a2(0,3) 占位→将移消元；rank8=90/rank9=60 干净分界，无 tie 跨界不受 sort 稳定性影响）
// dump ①应将清单 ②moveScore 三项分拆（mirror）③新旧双判定（prefix(8) 模拟 vs 全量）；收敛判据=四断言同绿
// 注：CheckmateSearch.moveScore 为 private，此处按源码 :101-140 语义镜像（走前盘面口径），冻结锚只依赖真 search，mirror 仅驱动排序模拟
// Luke 裁 ③（T-1101-1）：探针套件 env 门禁——默认关（全量批零拖累），FP_ANCHOR_PROBE=1 显式开启。
// 注意：门关时 targeted 跑本套件会因 0 tests 行触发 runner FAIL(zero-run) 计数门（挖掛起跑必须带 env）；
// 组合数双形态门（FAST/FULL）保留为第二层——门开后默认 FAST，T1101_PROBE_FULL=1 才全量挖掘。
@Suite("T1101 FP Anchor Probe", .serialized, .enabled(if: ProcessInfo.processInfo.environment["FP_ANCHOR_PROBE"] == "1"))
struct FPAnchorProbeTests {

    /// mirror CheckmateSearch.moveScore：吃子 baseValue + 邻近 max(0,6-dist)×20 + 阻挡（车between0 +60/炮between1 +30）
    private func mirrorScore(_ move: Move, on board: Board) -> (capture: Int, proximity: Int, block: Int, total: Int) {
        let capture = move.captured?.baseValue ?? 0
        var proximity = 0
        var block = 0
        if let gp = board.generalPosition(of: move.piece.side) {
            let dist = abs(move.to.row - gp.row) + abs(move.to.col - gp.col)
            proximity = max(0, 6 - dist) * 20
            let attackerSide: Side = (move.piece.side == .red) ? .black : .red
            for attacker in board.pieces(for: attackerSide) {
                guard attacker.kind == .chariot || attacker.kind == .cannon else { continue }
                let ap = attacker.position
                guard ap.row == gp.row || ap.col == gp.col else { continue }
                guard Self.isBetween(move.to, attacker: ap, general: gp) else { continue }
                let betweenCount = Self.countPiecesBetween(ap, gp, on: board)
                if attacker.kind == .chariot && betweenCount == 0 {
                    block += 60
                } else if attacker.kind == .cannon && betweenCount == 1 {
                    block += 30
                }
            }
        }
        return (capture, proximity, block, capture + proximity + block)
    }

    private static func isBetween(_ point: Position, attacker: Position, general: Position) -> Bool {
        if attacker.row == general.row {
            let minCol = min(attacker.col, general.col)
            let maxCol = max(attacker.col, general.col)
            return point.row == attacker.row && point.col > minCol && point.col < maxCol
        } else if attacker.col == general.col {
            let minRow = min(attacker.row, general.row)
            let maxRow = max(attacker.row, general.row)
            return point.col == attacker.col && point.row > minRow && point.row < maxRow
        }
        return false
    }

    private static func countPiecesBetween(_ a: Position, _ b: Position, on board: Board) -> Int {
        var count = 0
        if a.row == b.row {
            for c in (min(a.col, b.col) + 1)..<max(a.col, b.col) {
                if board.piece(at: Position(row: a.row, col: c)) != nil { count += 1 }
            }
        } else if a.col == b.col {
            for r in (min(a.row, b.row) + 1)..<max(a.row, b.row) {
                if board.piece(at: Position(row: r, col: a.col)) != nil { count += 1 }
            }
        }
        return count
    }

    /// 固定黑方骨架（迭代1）：将(0,4)/士(1,4)屏/士(0,3)/马(0,5)堵将移/马(2,2)/马(2,6)/相(4,2)/相(4,6)/车(3,1)/车(3,8)/兵(7,3)/兵(7,5)远插族
    private func blackSkeleton() -> [Piece] {
        [
            TestPieceFactory.blackGeneral(0, 4),
            TestPieceFactory.makePiece(kind: .advisor, side: .black, position: Position(row: 1, col: 4)),
            TestPieceFactory.makePiece(kind: .advisor, side: .black, position: Position(row: 0, col: 3)),
            TestPieceFactory.makePiece(kind: .horse, side: .black, position: Position(row: 0, col: 5)),
            TestPieceFactory.makePiece(kind: .horse, side: .black, position: Position(row: 2, col: 2)),
            TestPieceFactory.makePiece(kind: .horse, side: .black, position: Position(row: 2, col: 6)),
            TestPieceFactory.makePiece(kind: .elephant, side: .black, position: Position(row: 4, col: 2)),
            TestPieceFactory.makePiece(kind: .elephant, side: .black, position: Position(row: 4, col: 6)),
            TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 3, col: 1)),
            TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 3, col: 8)),
            TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 7, col: 3)),
            TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 7, col: 5)),
        ]
    }

    @Test("PROBE-A1 炮将骨架 × punish 变体池收割（迭代1）")
    func probePathAVariantPool() {
        // punish 变体（均不落 col4 rows1-7 屏道——第二屏会瓦解 C1 炮将检查；均无根检查手，防 search 走偏）
        let variants: [(String, Piece)] = [
            ("R2-5,0", TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))),
            ("R2-5,8", TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 8))),
            ("R2-0,0", TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 0, col: 0))),
            ("C2-5,0", TestPieceFactory.makePiece(kind: .cannon, side: .red, position: Position(row: 5, col: 0))),
            ("C2-5,8", TestPieceFactory.makePiece(kind: .cannon, side: .red, position: Position(row: 5, col: 8))),
            ("H2-5,2", TestPieceFactory.makePiece(kind: .horse, side: .red, position: Position(row: 5, col: 2))),
        ]

        for (label, punish) in variants {
            print("PROBEA-BEGIN variant=\(label)")
            let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 3), id: 8)
            let c1 = TestPieceFactory.makePiece(kind: .cannon, side: .red, position: Position(row: 8, col: 0))

            func buildPre() -> Board {
                let b = Board(pieces: blackSkeleton() + [rg, c1, punish])
                b.setCurrentTurn(.red)
                return b
            }

            func buildChecked() -> Board {
                let b = buildPre()
                let c1p = b.piece(at: Position(row: 8, col: 0))!
                b.execute(Move(piece: c1p, from: Position(row: 8, col: 0), to: Position(row: 8, col: 4), captured: nil))
                return b
            }

            // 根判定（新·全量校验）：整根 search 必须 nil（锚真值=非强制将杀）
            let rootSearch = CheckmateSearch.search(board: LegacySearchBoard(from: buildPre()), for: .red, maxDepth: 8, timeLimitMs: 750)
            print("PROBEA-ROOT v=\(label) search=\(rootSearch == nil ? "nil" : "MATE(\(rootSearch!.count)moves)")")

            let checked = buildChecked()
            let inCheck = MoveValidator.isInCheck(.black, on: checked)
            print("PROBEA-CHECK v=\(label) afterC1=\(inCheck ? "CHECK" : "NO-CHECK(!!)")")

            // ①应将清单 + ②moveScore 三项分拆
            let responses = MoveValidator.allLegalMoves(for: .black, on: checked)
            let scored = responses.map { mv -> (Move, Int, Int, Int, Int) in
                let s = mirrorScore(mv, on: checked)
                return (mv, s.capture, s.proximity, s.block, s.total)
            }.sorted { $0.4 > $1.4 }
            print("PROBEA-TABLE v=\(label) count=\(scored.count)")
            for (i, row) in scored.enumerated() {
                let mv = row.0
                print("PROBEA-ROW v=\(label) rank=\(i + 1) \(mv.piece.kind) \(mv.from.row),\(mv.from.col)->\(mv.to.row),\(mv.to.col) cap=\(row.1) prox=\(row.2) blk=\(row.3) total=\(row.4)")
            }

            // ③逐手真值：应将后红方剩余深度（8-2=6）内是否强制杀；true=败着(L)/false=活手(S)
            var subResults: [Bool] = []
            for row in scored {
                let subBoard = buildChecked()
                let target = subBoard.piece(at: row.0.from)!
                subBoard.execute(Move(piece: target, from: row.0.from, to: row.0.to, captured: subBoard.piece(at: row.0.to)))
                let sub = CheckmateSearch.search(board: LegacySearchBoard(from: subBoard), for: .red, maxDepth: 6, timeLimitMs: 750)
                subResults.append(sub != nil)
            }

            // ③新旧双判定：旧 prefix(8) 模拟=仅验前 8 应将全败即判杀 vs 新全量校验
            let top8AllLose = scored.count >= 8 && !subResults.prefix(8).contains(false)
            let escapeRank = subResults.firstIndex(of: false).map { $0 + 1 }
            let divergence = top8AllLose && rootSearch == nil
            print("PROBEA-VERDICT v=\(label) A1_count>=9=\(scored.count >= 9) A2_top8AllLose=\(top8AllLose) A3_escapeRank=\(escapeRank.map(String.init) ?? "none") A4_divergence=\(divergence) loseList=\(subResults.map { $0 ? "L" : "S" }.joined())")
            print("PROBEA-END v=\(label)")
        }
        #expect(true)
    }

    /// PROBE-B（路径B·挖掘式扫描器，T-1101-1 件1 兜底：迭代1 实证手摆 punish 网零杀链→机械化挖掘）
    /// 空间：黑核心骨架（将(0,4)/士屏(1,4)/士(0,3)）固定，8 curated 增援子取 5 子组合 × 6 punish 摆位 = 336 变体
    /// 三级漏斗：①应将数 9-16 ②根 search=nil ③排序逐手真值（top8 全败早退 + rank≥9 活手即命中）
    /// 命中=四断言全绿，全量 dump 供冻结锚采用；near-miss 直方图指导 curation。搜索预算 250ms/手控温
    @Test("PROBE-B 挖掘式扫描器：黑架子集 × punish 摆位")
    func probeBMiningScanner() {
        // B3 生成式宽域（A1 手摆+B1/B2 curated 共三扫皆空实证：造响应子=防守子，四断言在单 punish 结构内
        // 边界互斥）——升级万级形态：池 16 子、5-7 子混合组合、punish 10 槽、窗口 9-18、400ms、3 万上限；
        // setsid 脱离长跑，命中实时落盘（长任务脱离规约 2026-08-15）
        let extras: [(String, Piece)] = [
            ("e42", TestPieceFactory.makePiece(kind: .elephant, side: .black, position: Position(row: 4, col: 2))),
            ("e46", TestPieceFactory.makePiece(kind: .elephant, side: .black, position: Position(row: 4, col: 6))),
            ("h22", TestPieceFactory.makePiece(kind: .horse, side: .black, position: Position(row: 2, col: 2))),
            ("h26", TestPieceFactory.makePiece(kind: .horse, side: .black, position: Position(row: 2, col: 6))),
            ("h05", TestPieceFactory.makePiece(kind: .horse, side: .black, position: Position(row: 0, col: 5))),
            ("h43", TestPieceFactory.makePiece(kind: .horse, side: .black, position: Position(row: 4, col: 3))),
            ("bc31", TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 3, col: 1))),
            ("bc38", TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 3, col: 8))),
            ("p73", TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 7, col: 3))),
            ("p75", TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 7, col: 5))),
            ("p63", TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 6, col: 3))),
            ("p53", TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 5, col: 3))),
            ("p65", TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 6, col: 5))),
            ("p55", TestPieceFactory.makePiece(kind: .soldier, side: .black, position: Position(row: 5, col: 5))),
            ("bc28", TestPieceFactory.makePiece(kind: .chariot, side: .black, position: Position(row: 2, col: 8))),
        ]
        let punishes: [(String, Piece)] = [
            ("R2-0,0", TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 0, col: 0))),
            ("R2-5,6", TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 6))),
            ("R2-5,0", TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 5, col: 0))),
            ("C2-0,7", TestPieceFactory.makePiece(kind: .cannon, side: .red, position: Position(row: 0, col: 7))),
            ("H2-4,3", TestPieceFactory.makePiece(kind: .horse, side: .red, position: Position(row: 4, col: 3))),
            ("H2-5,2", TestPieceFactory.makePiece(kind: .horse, side: .red, position: Position(row: 5, col: 2))),
            ("R2-3,0", TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 3, col: 0))),
            ("C2-5,0", TestPieceFactory.makePiece(kind: .cannon, side: .red, position: Position(row: 5, col: 0))),
            ("H2-1,3", TestPieceFactory.makePiece(kind: .horse, side: .red, position: Position(row: 1, col: 3))),
            ("R2-2,7", TestPieceFactory.makePiece(kind: .chariot, side: .red, position: Position(row: 2, col: 7))),
        ]

        // 15 子池 5/6/7 混合组合（C15,5+C15,6+C15,7 = 3003+5005+6435 = 14443）
        // B3 修正：B2 去重后池=15，原循环 0..<16 致 extras[15] 越界崩溃（verify7 FPAnchorProbeTests Index out of range）
        let n = extras.count
        var subsets: [[Int]] = []
        for a in 0..<n { for b in (a + 1)..<n { for c in (b + 1)..<n { for d in (c + 1)..<n { for e in (d + 1)..<n {
            subsets.append([a, b, c, d, e])
            for g in (e + 1)..<n {
                subsets.append([a, b, c, d, e, g])
                for h in (g + 1)..<n {
                    subsets.append([a, b, c, d, e, g, h])
                }
            }
        } } } } }
        // P3-3（Ruby 审查）双形态门：默认快扫（stride25+cap2000，全量批 ~2min 不拖）；env T1101_PROBE_FULL=1
        // 切挖掘形态（stride5+cap30000）。变体说明：Ruby 原建议 suite 级 .enabled(if:) 会触发 runner
        // FAIL(zero-run) 计数门（disabled suite 打 0 tests 行→批作废），故改组合数双形态
        let fullMode = ProcessInfo.processInfo.environment["T1101_PROBE_FULL"] == "1"
        let probeStride = fullMode ? 5 : 25
        let scanCap = fullMode ? 30000 : 2000
        print("PROBEB-SPACE mode=\(fullMode ? "FULL" : "FAST") subsets=\(subsets.count) stride=\(probeStride) sampled=\(subsets.count / probeStride + 1) combos=\((subsets.count / probeStride + 1) * punishes.count) cap=\(scanCap)")

        var reasonCount: [String: Int] = [:]
        var hitCount = 0
        var scanned = 0
        var nearMissSamples: [String] = []

        func blackCore() -> [Piece] {
            [
                TestPieceFactory.blackGeneral(0, 4),
                TestPieceFactory.makePiece(kind: .advisor, side: .black, position: Position(row: 1, col: 4)),
                TestPieceFactory.makePiece(kind: .advisor, side: .black, position: Position(row: 0, col: 3)),
            ]
        }

        for (si, subset) in subsets.enumerated() {
            if hitCount >= 2 || scanned >= scanCap { break }
            if si % probeStride != 0 { continue }  // stride 采样，全索引域铺开
            let extraPieces = subset.map { extras[$0].1 }
            let extraLabels = subset.map { extras[$0].0 }.joined(separator: "+")
            for (pLabel, punish) in punishes {
                if hitCount >= 2 { break }
                // 隔夜优化①：punish 与增援子同位守卫（如 H2-4,3 vs 黑 h43）——碰撞位触发 BoardIntegrityLogger
                // 落盘 I/O 是 B3 首跑 57min 拖慢主因，跳过即免
                if extraPieces.contains(where: { $0.position == punish.position }) {
                    reasonCount["pos-collision", default: 0] += 1
                    continue
                }
                scanned += 1
                let rg = Piece(kind: .general, side: .red, position: Position(row: 9, col: 3), id: 8)
                let c1 = TestPieceFactory.makePiece(kind: .cannon, side: .red, position: Position(row: 8, col: 0))

                func buildPre() -> Board {
                    let b = Board(pieces: blackCore() + extraPieces + [rg, c1, punish])
                    b.setCurrentTurn(.red)
                    return b
                }
                func buildChecked() -> Board {
                    let b = buildPre()
                    let c1p = b.piece(at: Position(row: 8, col: 0))!
                    b.execute(Move(piece: c1p, from: Position(row: 8, col: 0), to: Position(row: 8, col: 4), captured: nil))
                    return b
                }

                let checked = buildChecked()
                guard MoveValidator.isInCheck(.black, on: checked) else {
                    reasonCount["no-check", default: 0] += 1
                    continue
                }
                let responses = MoveValidator.allLegalMoves(for: .black, on: checked)
                guard (9...18).contains(responses.count) else {
                    reasonCount["count-\(responses.count)", default: 0] += 1
                    continue
                }
                let scored = responses.map { mv -> (Move, Int) in (mv, mirrorScore(mv, on: checked).total) }.sorted { $0.1 > $1.1 }

                let root = CheckmateSearch.search(board: LegacySearchBoard(from: buildPre()), for: .red, maxDepth: 8, timeLimitMs: 250)
                guard root == nil else {
                    reasonCount["root-mate", default: 0] += 1
                    continue
                }

                // 逐手真值 + 早退：top8 中首个活手即弃（near-miss 记录）；rank≥9 活手且 top8 已全败 = 命中
                var allLose = true
                var loseList = ""
                var escapeRank: Int? = nil
                for (i, row) in scored.enumerated() {
                    let subBoard = buildChecked()
                    let target = subBoard.piece(at: row.0.from)!
                    subBoard.execute(Move(piece: target, from: row.0.from, to: row.0.to, captured: subBoard.piece(at: row.0.to)))
                    let sub = CheckmateSearch.search(board: LegacySearchBoard(from: subBoard), for: .red, maxDepth: 6, timeLimitMs: 250)
                    let loses = (sub != nil)
                    loseList += loses ? "L" : "S"
                    if loses {
                        if i == 7 { allLose = true }
                    } else {
                        if i < 8 {
                            allLose = false
                            let sample = "PROBEB-NEARMISS extras=\(extraLabels) punish=\(pLabel) firstSurviveRank=\(i + 1) count=\(scored.count) losePrefix=\(loseList)"
                            if nearMissSamples.count < 12 { nearMissSamples.append(sample) }
                            break
                        } else {
                            escapeRank = i + 1
                            break
                        }
                    }
                }

                if allLose, let er = escapeRank {
                    hitCount += 1
                    print("PROBEB-HIT#\(hitCount) extras=\(extraLabels) punish=\(pLabel) count=\(scored.count) escapeRank=\(er) loseList=\(loseList)")
                    for (i, row) in scored.enumerated() {
                        let mv = row.0
                        print("PROBEB-HITROW #\(hitCount) rank=\(i + 1) \(mv.piece.kind) \(mv.from.row),\(mv.from.col)->\(mv.to.row),\(mv.to.col) score=\(row.1)")
                    }
                    print("PROBEB-HITEND #\(hitCount)")
                } else if allLose {
                    reasonCount["no-escape-rank9", default: 0] += 1
                }
            }
        }

        print("PROBEB-SUMMARY scanned=\(scanned) hits=\(hitCount) reasons=\(reasonCount.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: " "))")
        for s in nearMissSamples { print(s) }
        #expect(true)
    }
}
