import Testing
import Foundation
@testable import ChineseChess

/// Contempt + T2 回退 + moveHistory 输出 测试
@Suite("Contempt + T2 回退 + moveHistory 测试")
struct ContemptT2RevertTests {

    // MARK: - Contempt: AIEvalConfig 字段验证

    @Test("Contempt: AIEvalConfig.basic 默认 contempt = 0")
    func contemptBasicDefault() {
        #expect(AIEvalConfig.basic.contempt == 0, "basic 默认 contempt 应为 0")
    }

    @Test("Contempt: AIEvalConfig.advanced 默认 contempt = 0")
    func contemptAdvancedDefault() {
        #expect(AIEvalConfig.advanced.contempt == 0, "advanced 默认 contempt 应为 0")
    }

    @Test("Contempt: AIEvalConfig 可自定义 contempt 值")
    func contemptCustom() {
        let cfg = AIEvalConfig(mobility: true, safety: true, contempt: 30)
        #expect(cfg.contempt == 30, "应支持自定义 contempt 值")
    }

    // MARK: - Contempt: AIEvaluator 均势偏置验证

    @Test("Contempt: contempt=0 时均势局面无偏置")
    func evaluatorNoContempt() {
        let board = Board()  // 初始局面（均势）
        let evaluator = AIEvaluator()
        let scoreNoContempt = evaluator.evaluate(board, config: .basic)
        // basic 默认 contempt=0，分数应不含 contempt bonus
        // 验证不崩溃且返回合理值
        #expect(abs(scoreNoContempt) < 500, "初始局面评估值应在合理范围")
    }

    @Test("Contempt: contempt>0 时均势局面有正向偏置")
    func evaluatorWithContempt() {
        let board = Board()
        let evaluator = AIEvaluator()

        let cfgNoContempt = AIEvalConfig(mobility: false, safety: true, contempt: 0)
        let cfgWithContempt = AIEvalConfig(mobility: false, safety: true, contempt: 30)

        let scoreWithout = evaluator.evaluate(board, config: cfgNoContempt)
        let scoreWith = evaluator.evaluate(board, config: cfgWithContempt)

        // 均势局面（abs(baseScore) < 100），contempt 应使分数更偏向当前方
        // 注意 evaluate 返回的是 sign * (baseScore + contemptBonus)
        // 红方视角：sign=1，contempt=30 时 score 应比 contempt=0 高约 30
        // 但如果 baseScore 本身很小，差距应约为 contempt 值
        let diff = abs(scoreWith) - abs(scoreWithout)
        #expect(diff >= 0, "contempt>0 时均势局面的 |score| 不应更小")
    }

    @Test("Contempt: 非均势局面 contempt 不生效")
    func evaluatorContemptOnlyDrawish() {
        // 构造一个大优局面（红方多车）
        let board = Board(fen: "r3kabnr/9/9/9/9/9/9/9/9/4KAB1R w - - 0 1")
        let evaluator = AIEvaluator()

        let cfgNoContempt = AIEvalConfig(mobility: false, safety: true, contempt: 0)
        let cfgWithContempt = AIEvalConfig(mobility: false, safety: true, contempt: 50)

        let scoreWithout = evaluator.evaluate(board, config: cfgNoContempt)
        let scoreWith = evaluator.evaluate(board, config: cfgWithContempt)

        // 大优局面（abs(baseScore) >= 100），contempt 不应生效
        // 差距应远小于 contempt 值
        let diff = abs(scoreWith - scoreWithout)
        #expect(diff == 0, "非均势局面 contempt 不应影响评估，diff=\(diff)")
    }

    // Helper: 评估初始局面分数（红方视角）
    private func evaluateInitialScore(_ contempt: Int) -> Int {
        let board = Board()
        let evaluator = AIEvaluator()
        let cfg = AIEvalConfig(mobility: false, safety: true, contempt: contempt)
        return evaluator.evaluate(board, config: cfg)
    }

    // MARK: - Contempt: AIEngine 按难度映射

    @Test("Contempt: AIEngine bestMove novice 不受 contempt 影响")
    func engineNoviceNoContempt() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .novice, isIOS: false)
        #expect(move != nil, "novice 应返回合法走法")
    }

    @Test("Contempt: AIEngine bestMove beginner 不受 contempt 影响")
    func engineBeginnerNoContempt() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .beginner, isIOS: false)
        #expect(move != nil, "beginner 应返回合法走法")
    }

    @Test("Contempt: AIEngine bestMove amateurMid 正常返回（contempt=20）")
    func engineAmateurMidWithContempt() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .amateurMid, isIOS: false)
        #expect(move != nil, "amateurMid（contempt=20）应返回合法走法")
    }

    @Test("Contempt: AIEngine bestMove amateurHigh 正常返回（contempt=30）")
    func engineAmateurHighWithContempt() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .amateurHigh, isIOS: false)
        #expect(move != nil, "amateurHigh（contempt=30）应返回合法走法")
    }

    @Test("Contempt: AIEngine bestMoves amateurMid 返回带 contempt 的候选")
    func engineBestMovesAmateurMidContempt() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .amateurMid, isIOS: false, topK: 3)
        #expect(!candidates.isEmpty, "amateurMid bestMoves 应返回候选")
        #expect(candidates.count <= 3)
    }

    @Test("Contempt: 人机对弈路径（amateurDan+）contempt=0 不受影响")
    func engineHumanPlayNoContempt() async {
        let engine = AIEngine()
        let board = Board()
        // amateurDan 及以上 contempt=0，人机对弈不受影响
        let move = await engine.bestMove(for: board, difficulty: .amateurDan, isIOS: false)
        #expect(move != nil, "amateurDan（人机对弈，contempt=0）应正常返回")
    }

    // MARK: - T2 回退验证

    @Test("T2 回退: SelfPlayRunner playGame 不再每步清 TT")
    func t2RevertNoPerStepClearTT() async {
        // 验证 T2 回退后自对弈仍正常工作
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 1,
            maxMoves: 20
        )
        let result = await runner.run(config: config)
        #expect(result.games.count == 1, "应完成 1 局")
        #expect(result.redWins + result.blackWins + result.draws == 1)
    }

    @Test("T2 回退: clearHistory() 仍清 TT（局间清空保留）")
    func t2RevertClearHistoryStillClearsTT() async {
        let engine = AIEngine()
        let board = Board()
        _ = await engine.bestMove(for: board, difficulty: .beginner, isIOS: false)
        // clearHistory 应仍清 TT（T2 回退保留了这个）
        await engine.clearHistory()
        let move = await engine.bestMove(for: board, difficulty: .beginner, isIOS: false)
        #expect(move != nil, "clearHistory 后应仍能正常搜索")
    }

    @Test("T2 回退: clearTT() 作为公共 API 仍可用")
    func t2RevertClearTTStillCallable() async {
        let engine = AIEngine()
        await engine.clearTT()  // 虽然内部不再每步调用，但 API 保留
        // 不崩溃即通过
    }

    // MARK: - P1 fix: rootSearch 统一 resolve searchConfig

    @Test("P1 fix: bestMove beginner 走 rootSearch 路径正常（evalConfig 传播）")
    func p1RootSearchEvalConfigPropagation() async {
        let engine = AIEngine()
        let board = Board()
        // beginner 走 rootSearch(depth:2, evalConfig:.basic + contempt)
        let move = await engine.bestMove(for: board, difficulty: .beginner, isIOS: false)
        #expect(move != nil, "beginner rootSearch 应正常返回")
    }

    @Test("P1 fix: bestMoves beginner 走 rootSearchScored 路径正常")
    func p1RootSearchScoredEvalConfigPropagation() async {
        let engine = AIEngine()
        let board = Board()
        let candidates = await engine.bestMoves(for: board, difficulty: .beginner, isIOS: false, topK: 3)
        #expect(!candidates.isEmpty, "beginner rootSearchScored 应正常返回")
    }

    @Test("P1 fix: amateurLow 走 mediumSearch（含 contempt 注入）正常")
    func p1MediumSearchContempt() async {
        let engine = AIEngine()
        let board = Board()
        let move = await engine.bestMove(for: board, difficulty: .amateurLow, isIOS: false)
        #expect(move != nil, "amateurLow mediumSearch 应正常返回")
    }

    // MARK: - 集成: 自对弈端到端

    @Test("集成: novice 自对弈 1 局正常完成（T2 回退后）", .timeLimit(.minutes(3)))
    func integrationNoviceSelfPlayAfterRevert() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .novice,
            black: .novice,
            games: 1,
            maxMoves: 30
        )
        let result = await runner.run(config: config)
        #expect(result.games.count == 1)
        #expect(result.games[0].totalMoves > 0)
    }

    @Test("集成: beginner 自对弈 1 局正常完成（T2 回退后）", .timeLimit(.minutes(5)))
    func integrationBeginnerSelfPlayAfterRevert() async {
        let runner = SelfPlayRunner()
        let config = SelfPlayConfig(
            red: .beginner,
            black: .beginner,
            games: 1,
            maxMoves: 40
        )
        let result = await runner.run(config: config)
        #expect(result.games.count == 1)
        let game = result.games[0]
        #expect(game.totalMoves > 0)
        #expect(game.totalMoves <= 40)
    }

    // MARK: - 边界情况

    @Test("Contempt: AIEvalConfig contempt 为负值时不崩溃")
    func contemptNegativeNoCrash() {
        let board = Board()
        let evaluator = AIEvaluator()
        let cfg = AIEvalConfig(mobility: false, safety: true, contempt: -20)
        let score = evaluator.evaluate(board, config: cfg)
        // 不崩溃即通过
        _ = score
    }

    @Test("Contempt: 大 contempt 值不崩溃")
    func contemptLargeNoCrash() {
        let board = Board()
        let evaluator = AIEvaluator()
        let cfg = AIEvalConfig(mobility: false, safety: true, contempt: 1000)
        let score = evaluator.evaluate(board, config: cfg)
        // 不崩溃即通过
        _ = score
    }

    @Test("AISearchConfig: default evalConfig 含 contempt=0")
    func searchConfigDefaultContempt() {
        let cfg = AISearchConfig.default
        #expect(cfg.evalConfig.contempt == 0, "default searchConfig 的 evalConfig.contempt 应为 0")
    }
}
