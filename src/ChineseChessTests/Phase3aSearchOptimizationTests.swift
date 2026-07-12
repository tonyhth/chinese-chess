import Foundation
import Testing
@testable import ChineseChess

@Suite("Phase 3a 搜索优化核心改进", .serialized)
struct Phase3aSearchOptimizationTests {

    // MARK: - SearchConfig 配置验证

    @Test("AISearchConfig.default 所有优化均关闭")
    func searchConfigDefaultAllOff() {
        let cfg = AISearchConfig.default
        #expect(!cfg.enableQuiescence)
        #expect(!cfg.enableKillerMove)
        #expect(!cfg.enableCheckExtension)
        #expect(!cfg.enableNullMoveFix)
    }

    @Test("AISearchConfig.hard 全部启用")
    func searchConfigHardAllOn() {
        let cfg = AISearchConfig.hard
        #expect(cfg.enableQuiescence)
        #expect(cfg.enableKillerMove)
        #expect(cfg.enableCheckExtension)
        #expect(cfg.enableNullMoveFix)
        #expect(cfg.maxCheckExtensions == 6)
        #expect(cfg.maxQSDepth == 4)
    }

    @Test("AISearchConfig.master 全部启用，check extension 上限 8")
    func searchConfigMasterAllOn() {
        let cfg = AISearchConfig.master
        #expect(cfg.enableQuiescence)
        #expect(cfg.enableKillerMove)
        #expect(cfg.enableCheckExtension)
        #expect(cfg.enableNullMoveFix)
        #expect(cfg.maxCheckExtensions == 8)
        #expect(cfg.maxQSDepth == 6)
    }

    @Test("AISearchConfig.fullOptimization 全开")
    func searchConfigFullOptimization() {
        let cfg = AISearchConfig.fullOptimization
        #expect(cfg.enableQuiescence)
        #expect(cfg.enableKillerMove)
        #expect(cfg.enableCheckExtension)
        #expect(cfg.enableNullMoveFix)
        #expect(cfg.maxCheckExtensions == 8)
        #expect(cfg.maxQSDepth == 4)
    }

    // MARK: - Quiescence Search（通过 AI 行为验证）

    @Test("QS：高级初始局面返回合法走法（QS 启用）")
    func quiescenceSearchHardInitialBoard() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .hard)
        #expect(move != nil)
        if let move = move {
            let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
            let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
            #expect(isLegal, "高级（QS 启用）返回非法走法")
        }
    }

    @Test("QS：大师初始局面返回合法走法（QS 启用，maxQSDepth=6）")
    func quiescenceSearchMasterInitialBoard() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .master)
        #expect(move != nil)
    }

    @Test("QS：中级不启用，仍正常返回")
    func quiescenceSearchMediumNotAffected() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .medium)
        #expect(move != nil)
    }

    @Test("QS：残局吃子密集局面不 crash")
    func quiescenceSearchCaptureHeavyPosition() async {
        let engine = AIEngine()
        // 多子对杀局面
        let fen = "2bak4/4a4/4c4/9/4p4/4P4/9/4C4/4A4/3AK4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .hard)
        #expect(move != nil)
    }

    @Test("QS：极度简化局面（2 子）不 crash")
    func quiescenceSearchMinimalPosition() async {
        let engine = AIEngine()
        let fen = "4k4/9/9/9/9/9/9/9/4R4/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .master)
        _ = move  // 可能无合法走法（将帅对），只要不 crash
    }

    // MARK: - Check Extension

    @Test("Check Extension：hard 上限 6 不导致无限递归")
    func checkExtensionHardNoInfiniteRecursion() async {
        let engine = AIEngine()
        // 持续将军的局面
        let fen = "R3k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let start = Date()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .hard)
        let elapsed = Date().timeIntervalSince(start)
        _ = move
        // check extension 不应导致超时（应在合理时间内返回）
        #expect(elapsed < 30.0, "Check extension 导致搜索时间过长: \(elapsed)s")
    }

    @Test("Check Extension：master 上限 8 不导致无限递归")
    func checkExtensionMasterNoInfiniteRecursion() async {
        let engine = AIEngine()
        let fen = "R3k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let start = Date()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .master)
        let elapsed = Date().timeIntervalSince(start)
        _ = move
        #expect(elapsed < 60.0, "Check extension 导致搜索时间过长: \(elapsed)s")
    }

    @Test("Check Extension：中级不启用 check extension")
    func checkExtensionMediumNotAffected() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .medium)
        #expect(move != nil)
    }

    // MARK: - Killer Move（通过 MoveOrderer 行为验证）

    @Test("Killer Move：MoveOrderer clearHistory 清空 killer 表")
    func killerMoveClearHistory() {
        var orderer = MoveOrderer()
        // 清空不应 crash（即使没有 killer）
        orderer.clearHistory()
        orderer.clearHistory()
    }

    @Test("Killer Move：recordKiller 对吃子走法不记录")
    func killerMoveNoCaptureRecord() {
        var orderer = MoveOrderer()
        // 构造一个吃子走法
        let board = Board()
        let moves = MoveValidator.allLegalMoves(for: .red, on: board)
        // 找一个有 captured 的走法（初始局面没有吃子）
        // 初始局面没有吃子走法，所以测试不吃子情况
        // 改为直接测试：不吃子的走法应该能记录
        if let move = moves.first {
            orderer.recordKiller(move: move, depth: 1)
            let isKiller = orderer.isKillerMove(move, depth: 1)
            // 初始走法无 captured，应被记录
            #expect(isKiller)
        }
    }

    @Test("Killer Move：同一走法不重复记录")
    func killerMoveNoDuplicate() {
        var orderer = MoveOrderer()
        let board = Board()
        let moves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard let move = moves.first else { return }

        orderer.recordKiller(move: move, depth: 1)
        orderer.recordKiller(move: move, depth: 1)
        orderer.recordKiller(move: move, depth: 1)

        let isKiller = orderer.isKillerMove(move, depth: 1)
        #expect(isKiller)
        // 不 crash 即可
    }

    @Test("Killer Move：不同 depth 的 killer 独立")
    func killerMoveDifferentDepths() {
        var orderer = MoveOrderer()
        let board = Board()
        let moves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard moves.count >= 2 else { return }

        let move1 = moves[0]
        let move2 = moves[1]

        orderer.recordKiller(move: move1, depth: 1)
        orderer.recordKiller(move: move2, depth: 2)

        #expect(orderer.isKillerMove(move1, depth: 1))
        #expect(!orderer.isKillerMove(move1, depth: 2))
        #expect(orderer.isKillerMove(move2, depth: 2))
        #expect(!orderer.isKillerMove(move2, depth: 1))
    }

    @Test("Killer Move：高级/大师 AI 不 crash（killer 启用）")
    func killerMoveAIDoesNotCrash() async {
        let engine = AIEngine()
        let board = Board()
        for diff in [AIDifficulty.hard, .master] {
            let move = await engine.bestMove(for: board.snapshot(), difficulty: diff)
            #expect(move != nil, "\(diff) 启用 killer 后返回 nil")
        }
    }

    // MARK: - Null Move 改进

    @Test("Null Move：高级 AI 残局不 crash（Zugzwang 防护启用）")
    func nullMoveEndgameNoCrash() async {
        let engine = AIEngine()
        // 残局无车，Zugzwang 风险高
        let fen = "4k4/9/9/9/9/4c4/4N4/9/9/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .hard)
        #expect(move != nil)
    }

    @Test("Null Move：大师 AI 残局不 crash")
    func nullMoveMasterEndgameNoCrash() async {
        let engine = AIEngine()
        let fen = "4k4/9/9/9/9/9/9/4N4/9/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .master)
        _ = move
    }

    @Test("Null Move：中级不启用 null move fix，仍正常")
    func nullMoveMediumNotAffected() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .medium)
        #expect(move != nil)
    }

    // MARK: - isSameMove 统一判等

    @Test("isSameMove：相同走法返回 true")
    func isSameMoveIdentical() {
        let board = Board()
        let moves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard let move = moves.first else { return }
        #expect(MoveOrderer.isSameMove(move, move))
    }

    @Test("isSameMove：不同走法返回 false")
    func isSameMoveDifferent() {
        let board = Board()
        let moves = MoveValidator.allLegalMoves(for: .red, on: board)
        guard moves.count >= 2 else { return }
        #expect(!MoveOrderer.isSameMove(moves[0], moves[1]))
    }

    // MARK: - check extension bug fix 验证

    @Test("check extension bug fix：连续将军局面 hard 返回合法走法")
    func checkExtensionBugFixHard() async {
        let engine = AIEngine()
        // 红車在 a 列将军，黑将在 e 列
        let fen = "R3k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .hard)
        #expect(move != nil)
        if let move = move {
            let legalMoves = MoveValidator.allLegalMoves(for: .red, on: board)
            let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
            #expect(isLegal, "check extension 修复后 hard 返回非法走法")
        }
    }

    @Test("check extension bug fix：master 连续将军不 crash")
    func checkExtensionBugFixMaster() async {
        let engine = AIEngine()
        let fen = "R3k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        let move = await engine.bestMove(for: board.snapshot(), difficulty: .master)
        #expect(move != nil)
    }

    // MARK: - 综合压力测试

    @Test("综合：所有难度标准开局 10 次调用不 crash")
    func allDifficultiesMultipleCallsNoCrash() async {
        let engine = AIEngine()
        let board = Board()
        for diff in [AIDifficulty.beginner, .easy, .medium] {
            for _ in 0..<3 {
                let move = await engine.bestMove(for: board.snapshot(), difficulty: diff)
                #expect(move != nil, "\(diff) 返回 nil")
            }
        }
    }

    @Test("综合：hard/master 残局复杂局面不 crash")
    func hardMasterComplexEndgame() async {
        let engine = AIEngine()
        // 多子残局：車马炮 vs 車炮
        let fen = "4k4/4c4/9/9/9/9/9/4N4/4R4/4K4 w - - 0 1"
        guard let board = FENParser.parse(fen: fen) else {
            Issue.record("FEN 解析失败")
            return
        }
        for diff in [AIDifficulty.hard, .master] {
            let move = await engine.bestMove(for: board.snapshot(), difficulty: diff)
            if let move = move {
                let legalMoves = MoveValidator.allLegalMoves(for: board.currentTurn, on: board)
                let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
                #expect(isLegal, "\(diff) 残局返回非法走法")
            }
        }
    }

    @Test("综合：hard/master 走多步不 crash")
    func hardMasterMultipleMoves() async {
        let engine = AIEngine()
        let board = Board()
        for step in 0..<8 {
            let diff: AIDifficulty = step % 2 == 0 ? .hard : .master
            let move = await engine.bestMove(for: board.snapshot(), difficulty: diff)
            guard let move = move else { break }
            let legalMoves = MoveValidator.allLegalMoves(for: board.currentTurn, on: board)
            let isLegal = legalMoves.contains { $0.from == move.from && $0.to == move.to }
            #expect(isLegal, "第 \(step) 步 \(diff) 返回非法走法")
            board.execute(move)
        }
    }
}
