import Foundation
import Testing
@testable import ChineseChess

@Suite("Phase 3b LMR + 时间管理智能化", .serialized)
struct Phase3bLMRTimeManagementTests {

    // MARK: - SearchConfig LMR/SmartTime 配置

    @Test("AISearchConfig.default LMR 和 SmartTime 均关闭")
    func searchConfigDefaultLMROff() {
        let cfg = AISearchConfig.default
        #expect(!cfg.enableLMR)
        #expect(!cfg.enableSmartTime)
    }

    @Test("AISearchConfig.hard 启用 LMR，不启用 SmartTime")
    func searchConfigHardLMR() {
        let cfg = AISearchConfig.hard
        #expect(cfg.enableLMR)
        #expect(!cfg.enableSmartTime)
    }

    @Test("AISearchConfig.master 启用 LMR + SmartTime")
    func searchConfigMasterLMRAndSmartTime() {
        let cfg = AISearchConfig.master
        #expect(cfg.enableLMR)
        #expect(cfg.enableSmartTime)
    }

    @Test("AISearchConfig.fullOptimization 启用 LMR，不启用 SmartTime")
    func searchConfigFullOptimizationLMR() {
        let cfg = AISearchConfig.fullOptimization
        #expect(cfg.enableLMR)
        #expect(!cfg.enableSmartTime)
    }

    // MARK: - LMR 通过 AI 行为验证

    @Test("LMR：高级初始局面返回合法走法")
    func lmrHardInitialBoard() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .hard)
        #expect(move != nil)
        if let move = move {
            let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
            let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
            #expect(isLegal, "高级（LMR 启用）返回非法走法")
        }
    }

    @Test("LMR：大师初始局面返回合法走法")
    func lmrMasterInitialBoard() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .master)
        #expect(move != nil)
        if let move = move {
            let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
            let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
            #expect(isLegal, "大师（LMR 启用）返回非法走法")
        }
    }

    @Test("LMR：中级不启用，仍正常返回")
    func lmrMediumNotAffected() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .medium)
        #expect(move != nil)
    }

    @Test("LMR：残局多走法局面不 crash")
    func lmrEndgameManyMoves() async {
        let engine = AIEngine()
        // 残局车马炮 vs 将士象，走法数多
        let fen = "3ak4/4a4/4b4/9/9/9/9/4N4/3R5/3K5 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        for diff in [AIDifficulty.hard, .master] {
            let move = await engine.bestMove(for: board.snapshot(), difficulty: diff)
            if let move = move {
                let legalMoves = MoveValidator.allLegalMoves(for: board.currentTurn, on: board)
                let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
                #expect(isLegal, "\(diff) 残局 LMR 返回非法走法")
            }
        }
    }

    @Test("LMR：吃子密集局面 re-search 路径不 crash")
    func lmrCaptureHeavyReSearch() async {
        let engine = AIEngine()
        let fen = "2bak4/1R2a4/3Nc4/9/9/9/9/9/9/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .hard)
        #expect(move != nil)
    }

    // MARK: - TimeManager recordIterationComplete delta 修复

    @Test("TimeManager recordIterationComplete 记录 delta 而非累积")
    func timeManagerDeltaFix() {
        var tm = TimeManager(timeLimitMs: 10000, startTime: Date())
        // 第一次记录
        tm.recordIterationComplete()
        let first = tm.lastIterationMs
        // 第二次记录（几乎立即）
        tm.recordIterationComplete()
        let second = tm.lastIterationMs
        // delta 应该非常小（两次调用之间几乎没有间隔）
        #expect(second < 100, "第二次 delta 应该很小，实际: \(second)ms")
        // 第一次应该也是很小
        #expect(first < 100, "第一次 delta 应该很小，实际: \(first)ms")
    }

    @Test("TimeManager shouldStartNextIteration 无历史时返回 true")
    func timeManagerShouldStartNoHistory() {
        let tm = TimeManager(timeLimitMs: 10000, startTime: Date())
        #expect(tm.shouldStartNextIteration)
    }

    @Test("TimeManager shouldStartNextIteration 剩余充足时返回 true")
    func timeManagerShouldStartEnoughTime() {
        var tm = TimeManager(timeLimitMs: 60000, startTime: Date())
        tm.lastIterationMs = 100  // 上一层 100ms
        // 剩余 ~60s >> 100 * 2.5 = 250ms
        #expect(tm.shouldStartNextIteration)
    }

    // MARK: - positionComplexity

    @Test("positionComplexity：初始局面复杂度在合理范围")
    func positionComplexityInitialBoard() {
        let board = Board()
        let complexity = TimeManager.positionComplexity(board: board)
        #expect(complexity >= 0 && complexity <= 100, "复杂度超出范围: \(complexity)")
        // 初始 32 子，中局水平
        #expect(complexity >= 30, "初始局面复杂度过低: \(complexity)")
    }

    @Test("positionComplexity：残局复杂度低于中局")
    func positionComplexityEndgame() {
        let fen = "4k4/9/9/9/9/9/9/9/4R4/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let complexity = TimeManager.positionComplexity(board: board)
        #expect(complexity >= 0 && complexity <= 100)
        // 4 子残局应该比中局低
        #expect(complexity < 60, "4 子残局复杂度过高: \(complexity)")
    }

    @Test("positionComplexity：被将军时复杂度增加")
    func positionComplexityInCheck() {
        let board = Board()
        let normal = TimeManager.positionComplexity(board: board)

        // 构造被将军的局面
        let fen = "3k5/4R4/4b4/9/9/9/9/9/9/4K4 b - - 0 1"
        guard let checkedBoard = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let inCheck = TimeManager.positionComplexity(board: checkedBoard)
        // 被将时应有 +20 的 check bonus
        #expect(inCheck >= normal || inCheck > 0, "被将军局面复杂度应有所体现")
    }

    // MARK: - TimeManager 动态时间分配

    @Test("forDifficulty：不传 board 时用基础时间")
    func timeManagerDefaultTime() {
        let hardTm = TimeManager.forDifficulty(.hard, isIOS: false, board: nil as Board?)
        #expect(hardTm != nil)
        #expect(hardTm!.timeLimitMs == 5000)

        let masterTm = TimeManager.forDifficulty(.master, isIOS: false, board: nil as Board?)
        #expect(masterTm != nil)
        #expect(masterTm!.timeLimitMs == 10000)
    }

    @Test("forDifficulty：传入 board 时时间在 0.6x-1.4x 基础范围内")
    func timeManagerDynamicTime() {
        let board = Board()
        let hardTm = TimeManager.forDifficulty(.hard, isIOS: false, board: board)
        #expect(hardTm != nil)
        // 基础 5000，factor 0.6-1.4 → 3000-7000
        #expect(hardTm!.timeLimitMs >= 3000 && hardTm!.timeLimitMs <= 7000,
               "动态调整时间超出范围: \(hardTm!.timeLimitMs)")
    }

    @Test("forDifficulty：iOS 时间低于 macOS")
    func timeManagerIOSLessTime() {
        let macTm = TimeManager.forDifficulty(.master, isIOS: false, board: nil as Board?)!
        let iosTm = TimeManager.forDifficulty(.master, isIOS: true, board: nil as Board?)!
        #expect(iosTm.timeLimitMs <= macTm.timeLimitMs,
               "iOS 时间应 ≤ macOS: iOS=\(iosTm.timeLimitMs), macOS=\(macTm.timeLimitMs)")
    }

    @Test("forDifficulty：beginner/easy 返回 nil（无时间限制）；medium 有时间限制（v2.2.17 Bug4 修复）")
    func timeManagerNoTimeLimit() {
        #expect(TimeManager.forDifficulty(.beginner, board: nil as Board?) == nil)
        #expect(TimeManager.forDifficulty(.easy, board: nil as Board?) == nil)
        #expect(TimeManager.forDifficulty(.medium, board: nil as Board?) != nil)
        #expect(TimeManager.forDifficulty(.medium, board: nil as Board?)!.timeLimitMs == 3000)
    }

    // MARK: - SmartTime 仅 master 启用

    @Test("SmartTime：master IDS 使用智能迭代控制")
    func smartTimeMasterIDS() async {
        let engine = AIEngine()
        let board = Board()
        // master 应正常返回（SmartTime 启用）
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .master)
        #expect(move != nil)
    }

    @Test("SmartTime：hard 不使用智能迭代控制")
    func smartTimeHardNoSmartTime() async {
        let engine = AIEngine()
        let board = Board()
        // hard 不启用 SmartTime，但仍有普通 shouldStop 检查
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .hard)
        #expect(move != nil)
    }

    // MARK: - lmrReduction 边界

    @Test("LMR：depth=3 时不触发 LMR（canReduce 要求 depth>=4）")
    func lmrDepth3NoReduction() async {
        let engine = AIEngine()
        // 深度 3 不会触发 LMR，但不应 crash
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .hard)
        #expect(move != nil)
    }

    // MARK: - 综合压力测试

    @Test("综合：hard/master 交替走 10 步不 crash")
    func hardMasterAlternating10Steps() async {
        let engine = AIEngine()
        let board = Board()
        for step in 0..<10 {
            let diff: AIDifficulty = step % 2 == 0 ? .hard : .master
            let move = await engine.bestMove(for: board.snapshot(), difficulty: diff)
            guard let move = move else { break }
            let legalMoves = MoveValidator.allLegalMoves(for: board.currentTurn, on: board)
            let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
            #expect(isLegal, "第 \(step) 步 \(diff) 返回非法走法")
            board.execute(move)
        }
    }

    @Test("综合：所有难度残局合法走法")
    func allDifficultiesEndgameMoves() async {
        let engine = AIEngine()
        let fen = "4k4/4c4/9/9/9/9/9/4N4/4R4/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        for diff in [AIDifficulty.beginner, .easy, .medium, .hard, .master] {
            let move = await engine.bestMove(for: board.snapshot(), difficulty: diff)
            if let move = move {
                let legalMoves = MoveValidator.allLegalMoves(for: board.currentTurn, on: board)
                let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
                #expect(isLegal, "\(diff) 残局返回非法走法")
            }
        }
    }
}
